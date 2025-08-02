# terraform/api_gateway.tf
# Oruby Drawing Helper の API Gateway 設定

# REST API の作成
resource "aws_api_gateway_rest_api" "oruby_api" {
  name        = "oruby-drawing-helper-api"
  description = "API for Oruby Drawing Helper Application"
  
  # エンドポイントタイプ（リージョナル = 東京リージョン内）
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = {
    Name = "Oruby API"
    Environment = "development"
  }
}

# リソース作成: /analyze
resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  parent_id   = aws_api_gateway_rest_api.oruby_api.root_resource_id
  path_part   = "analyze"
}

# POSTメソッドの設定
resource "aws_api_gateway_method" "analyze_post" {
  rest_api_id   = aws_api_gateway_rest_api.oruby_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = "NONE"  # 認証なし（開発用）
}

# Lambda統合の設定
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.analyze_post.http_method
  
  # Lambda Proxy統合（リクエスト/レスポンスをそのまま渡す）
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.oruby_processor.invoke_arn
}

# Lambda実行権限の付与
# API GatewayがLambda関数を呼び出せるようにする
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.oruby_processor.function_name
  principal     = "apigateway.amazonaws.com"
  
  # このAPI Gatewayからの呼び出しのみ許可
  source_arn = "${aws_api_gateway_rest_api.oruby_api.execution_arn}/*/*"
}

# ========================================
# CORS設定（フロントエンドからアクセス可能にする）
# ========================================

# OPTIONSメソッド（プリフライトリクエスト用）
resource "aws_api_gateway_method" "analyze_options" {
  rest_api_id   = aws_api_gateway_rest_api.oruby_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONSメソッドのモック統合
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.analyze_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# OPTIONSメソッドのレスポンス設定
resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.analyze_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# OPTIONSメソッドの統合レスポンス
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.analyze_options.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ========================================
# デプロイメント
# ========================================

# APIのデプロイ
resource "aws_api_gateway_deployment" "oruby_deployment" {
  rest_api_id = aws_api_gateway_rest_api.oruby_api.id
  
  # 依存関係を明示（これらのリソースが作成されてからデプロイ）
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration
  ]
  
  # 変更を検知するためのトリガー
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.analyze,
      aws_api_gateway_method.analyze_post,
      aws_api_gateway_integration.lambda_integration,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# ステージ（dev環境）
resource "aws_api_gateway_stage" "dev_stage" {
  deployment_id = aws_api_gateway_deployment.oruby_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.oruby_api.id
  stage_name    = "dev"
  
  # アクセスログの設定（オプション）
  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_logs.arn
  #   format = jsonencode({
  #     requestId      = "$context.requestId"
  #     ip             = "$context.identity.sourceIp"
  #     requestTime    = "$context.requestTime"
  #     httpMethod     = "$context.httpMethod"
  #     resourcePath   = "$context.resourcePath"
  #     status         = "$context.status"
  #     responseLength = "$context.responseLength"
  #   })
  # }
  
  tags = {
    Name = "Oruby API Dev Stage"
  }
}

# ========================================
# 出力
# ========================================

# APIエンドポイントのURL
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.dev_stage.invoke_url}/analyze"
}

# curlコマンドの例
output "test_command" {
  description = "Test command for the API"
  value = <<-EOT
    curl -X POST ${aws_api_gateway_stage.dev_stage.invoke_url}/analyze \
      -H "Content-Type: application/json" \
      -d '{"image": "base64_encoded_image_data"}'
  EOT
}

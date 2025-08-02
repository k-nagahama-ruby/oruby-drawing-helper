# terraform/lambda.tf
# Lambda関数のリソース定義

# Lambda関数
resource "aws_lambda_function" "oruby_processor" {
  filename         = "lambda_function.zip"
  function_name    = "oruby-drawing-helper"
  role            = aws_iam_role.lambda_role.arn
  
  # Rubyの設定
  handler         = "handler.handler"  # ファイル名.関数名
  runtime         = "ruby3.2"
  
  # メモリとタイムアウトの設定
  memory_size     = 256  # MB (最小128、最大10240)
  timeout         = 30   # 秒 (最大900)
  
  # 環境変数の設定
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.first_bucket.id
      # 後で追加: BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }
  
  # ソースコードのハッシュ（変更検知用）
  source_code_hash = filebase64sha256("lambda_function.zip")
  
  # Lambdaが作成される前にロールが必要
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_s3_policy
  ]
  
  tags = {
    Name = "oruby Drawing Helper Lambda"
    Environment = "development"
  }
}

# CloudWatch Logsのロググループ（自動作成されるが、明示的に定義）
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.oruby_processor.function_name}"
  retention_in_days = 7  # ログの保持期間（日数）
  
  tags = {
    Name = "oruby Lambda Logs"
  }
}

# Lambda関数のARNを出力
output "lambda_function_arn" {
  description = "Lambda関数のARN"
  value       = aws_lambda_function.oruby_processor.arn
}

output "lambda_function_name" {
  description = "Lambda関数名"
  value       = aws_lambda_function.oruby_processor.function_name
}

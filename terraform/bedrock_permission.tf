
# terraform/bedrock_permissions.tf
# Bedrock APIアクセス権限の追加

# Lambda用のBedrock権限を追加
resource "aws_iam_role_policy" "lambda_bedrock_policy" {
  name = "oruby-lambda-bedrock-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          # Claude 3 Sonnet モデルへのアクセス
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-sonnet-*",
          # Claude 3 Haiku（より高速・低コスト）も使用可能に
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-haiku-*"
        ]
      }
    ]
  })
}

data "aws_region" "current" {}

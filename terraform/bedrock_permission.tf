
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
          # Inference profiles へのアクセス
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-haiku-*"
        ]
      }
    ]
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

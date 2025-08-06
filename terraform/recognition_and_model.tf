# terraform/rekognition_and_model.tf
# Rekognition権限とモデル保存用の設定

# 統計モデル保存用のS3バケット
resource "aws_s3_bucket" "model_bucket" {
  bucket = "oruby-models-bucket-prod"
  force_destroy = true
  
  tags = {
    Name        = "Oruby Statistical Models"
    Environment = "development"
    Purpose     = "Golden Ratio Models Storage"
  }

  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
  }
}

resource "aws_s3_bucket_public_access_block" "model_bucket_pab" {
  bucket = aws_s3_bucket.model_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lambda用のRekognition権限を追加（既存のIAMポリシーに追加）
resource "aws_iam_role_policy" "lambda_rekognition_policy" {
  name = "oruby-lambda-rekognition-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectFaces",
          "rekognition:DetectText",
          "rekognition:DetectModerationLabels"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda用のモデルバケットアクセス権限
resource "aws_iam_role_policy" "lambda_model_bucket_policy" {
  name = "oruby-lambda-model-bucket-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.model_bucket.arn,
          "${aws_s3_bucket.model_bucket.arn}/*"
        ]
      }
    ]
  })
}

# 出力
output "model_bucket_name" {
  description = "統計モデル保存用バケット名"
  value       = aws_s3_bucket.model_bucket.id
}

# モデルアップロード用のコマンド
output "upload_model_command" {
  description = "統計モデルをアップロードするコマンド"
  value       = "aws s3 cp ../models/golden_ratio.json s3://${aws_s3_bucket.model_bucket.id}/models/"
}

resource "aws_iam_role" "lambda_role" {
  name = "oruby-lambda-execution-role"

  # 信頼ポリシー: Lambdaサービスがこのロールを使用できるようにする
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Oruby Lambda Execution Role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# カスタムポリシー: S3へのアクセス権限
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "oruby-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",     # ファイルのアップロード
          "s3:GetObject",     # ファイルの読み取り
          "s3:ListBucket"     # バケット内のファイル一覧
        ]
        Resource = [
          aws_s3_bucket.first_bucket.arn,          # バケット自体
          "${aws_s3_bucket.first_bucket.arn}/*"    # バケット内のオブジェクト
        ]
      }
    ]
  })
}

# 出力: 作成したロールのARN（後で確認用）
output "lambda_role_arn" {
  description = "Lambda実行ロールのARN"
  value       = aws_iam_role.lambda_role.arn
}

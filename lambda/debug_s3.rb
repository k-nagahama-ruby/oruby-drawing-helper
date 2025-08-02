# lambda/debug_s3.rb
# S3アクセスの問題を診断するスクリプト

require 'aws-sdk-s3'
require 'json'

puts "🔍 S3アクセスのデバッグを開始します..."

# 1. 現在の認証情報を確認
sts_client = Aws::STS::Client.new
identity = sts_client.get_caller_identity
puts "\n📋 現在の認証情報:"
puts "  Account: #{identity.account}"
puts "  User ARN: #{identity.arn}"
puts "  User ID: #{identity.user_id}"

# 2. S3クライアントの設定を確認
s3_client = Aws::S3::Client.new(region: 'ap-northeast-1')
puts "\n🔧 S3クライアント設定:"
puts "  Region: #{s3_client.config.region}"
puts "  Credentials: #{s3_client.config.credentials.class}"

# 3. バケット名を入力
print "\nバケット名を入力してください: "
bucket_name = gets.chomp

# 4. バケットの存在確認
begin
  puts "\n📦 バケットの確認中..."
  response = s3_client.head_bucket(bucket: bucket_name)
  puts "✅ バケットが見つかりました"
rescue Aws::S3::Errors::NotFound
  puts "❌ バケットが見つかりません"
  exit 1
rescue Aws::S3::Errors::Forbidden => e
  puts "❌ バケットへのアクセスが拒否されました"
  puts "  詳細: #{e.message}"
end

# 5. バケットのACLを確認（可能な場合）
begin
  puts "\n🔐 バケットのACLを確認中..."
  acl = s3_client.get_bucket_acl(bucket: bucket_name)
  puts "  Owner: #{acl.owner.display_name} (#{acl.owner.id})"
rescue => e
  puts "  ACLの取得に失敗: #{e.message}"
end

# 6. テストアップロード（小さなファイル）
puts "\n📤 テストアップロードを実行..."
test_key = "test/debug-#{Time.now.to_i}.txt"
test_content = "Debug test at #{Time.now}"

begin
  s3_client.put_object(
    bucket: bucket_name,
    key: test_key,
    body: test_content
  )
  puts "✅ アップロード成功: #{test_key}"
  
  # アップロードしたファイルを削除
  s3_client.delete_object(bucket: bucket_name, key: test_key)
  puts "🗑️  テストファイルを削除しました"
rescue Aws::S3::Errors::AccessDenied => e
  puts "❌ アクセス拒否エラー:"
  puts "  エラーメッセージ: #{e.message}"
  puts "  エラーコード: #{e.code}"
  puts "  リクエストID: #{e.context.metadata[:request_id]}"
rescue => e
  puts "❌ その他のエラー: #{e.class}"
  puts "  #{e.message}"
end

# 7. バケットポリシーの確認
begin
  puts "\n📜 バケットポリシーを確認中..."
  policy = s3_client.get_bucket_policy(bucket: bucket_name)
  puts "  ポリシーが設定されています:"
  puts JSON.pretty_generate(JSON.parse(policy.policy.read))
rescue Aws::S3::Errors::NoSuchBucketPolicy
  puts "  バケットポリシーは設定されていません"
rescue => e
  puts "  ポリシーの取得に失敗: #{e.message}"
end

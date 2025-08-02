# lambda/s3_test.rb
# このスクリプトでS3の基本操作を学びます

require 'aws-sdk-s3'
require 'securerandom'

# S3クライアントを初期化
# AWSの認証情報は自動的に読み込まれます（aws configureで設定したもの）
s3_client = Aws::S3::Client.new(region: 'ap-northeast-1')

# Terraformで作成したバケット名を取得
# （後で環境変数から読むように改善します）
puts "📦 Terraformで作成したバケット名を入力してください："
bucket_name = gets.chomp

# 1. テキストファイルをアップロード
puts "\n🚀 テキストファイルをアップロードします..."

file_content = <<~TEXT
  これは最初のテストファイルです！
  作成日時: #{Time.now}
  
  おるびー絵描きヘルパーのテスト
TEXT

key = "test-files/first-test-#{SecureRandom.hex(4)}.txt"

begin
  s3_client.put_object(
    bucket: bucket_name,
    key: key,
    body: file_content
  )
  puts "✅ アップロード成功: s3://#{bucket_name}/#{key}"
rescue => e
  puts "❌ エラー: #{e.message}"
  exit 1
end

# 2. アップロードしたファイルを確認
puts "\n📋 バケット内のファイル一覧:"
response = s3_client.list_objects_v2(bucket: bucket_name)

if response.contents.empty?
  puts "バケットは空です"
else
  response.contents.each do |object|
    puts "  - #{object.key} (#{object.size} bytes)"
  end
end

# 3. ファイルを読み込んでみる
puts "\n📖 アップロードしたファイルを読み込みます..."
get_response = s3_client.get_object(
    bucket: bucket_name,
    key: key
)

puts "内容:"
puts get_response.body.read

# 4. 画像ファイルのアップロードをシミュレート
puts "\n🎨 画像アップロードのシミュレーション..."

# 実際の画像の代わりに、仮のバイナリデータを使用
fake_image_data = "これは画像データのプレースホルダーです"
image_key = "uploads/test-image-#{SecureRandom.uuid}.jpg"

s3_client.put_object(
  bucket: bucket_name,
  key: image_key,
  body: fake_image_data,
  content_type: 'image/jpeg'  # 重要：適切なContent-Typeを設定
)

puts "✅ 画像アップロード成功: s3://#{bucket_name}/#{image_key}"

puts "\n🎉 S3の基本操作を理解できました！"

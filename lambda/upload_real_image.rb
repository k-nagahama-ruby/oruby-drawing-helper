# lambda/upload_real_image.rb
# 実際の画像ファイルをアップロードしてみる

require 'aws-sdk-s3'
require 'base64'

s3_client = Aws::S3::Client.new(region: 'ap-northeast-1')

# バケット名を環境変数から取得（より実践的な方法）
bucket_name = ENV['BUCKET_NAME'] || (print "バケット名: "; gets.chomp)

# アップロードする画像ファイルのパス
print "アップロードする画像ファイルのパス（例: ~/Desktop/oruby.png）: "
file_path = gets.chomp.gsub('~', Dir.home)

unless File.exist?(file_path)
  puts "❌ ファイルが見つかりません: #{file_path}"
  exit 1
end

# ファイルサイズをチェック
file_size = File.size(file_path)
puts "📊 ファイルサイズ: #{file_size / 1024.0 / 1024.0} MB"

# 画像をBase64エンコード（Lambdaで受け取る形式をシミュレート）
image_data = File.binread(file_path)
base64_data = Base64.encode64(image_data)
puts "📏 Base64エンコード後のサイズ: #{base64_data.length} 文字"

# S3にアップロード
key = "uploads/real-image-#{Time.now.to_i}.jpg"

begin
  s3_client.put_object(
    bucket: bucket_name,
    key: key,
    body: image_data,  # 実際のバイナリデータをアップロード
    content_type: 'image/jpeg',
    metadata: {
      'uploaded-at' => Time.now.to_s,
      'original-filename' => File.basename(file_path)
    }
  )
  
  puts "✅ アップロード成功！"
  puts "🔗 S3 URL: s3://#{bucket_name}/#{key}"
  
  # 署名付きURL（一時的なアクセスURL）を生成
  presigner = Aws::S3::Presigner.new(client: s3_client)
  url = presigner.presigned_url(
    :get_object,
    bucket: bucket_name,
    key: key,
    expires_in: 3600  # 1時間有効
  )
  
  puts "🌐 一時アクセスURL（1時間有効）:"
  puts url
  
rescue => e
  puts "❌ エラー: #{e.message}"
end

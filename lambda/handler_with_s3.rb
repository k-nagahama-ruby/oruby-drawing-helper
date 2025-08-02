# lambda/handler_with_s3.rb
# S3と連携するLambda関数

require 'json'
require 'base64'
require 'aws-sdk-s3'
require 'securerandom'

# Lambda関数で使う定数
# 実際の運用では環境変数から読み込みます
BUCKET_NAME = ENV['BUCKET_NAME'] || 'orbie-helper-test-20250802'

def handler(event:, context:)
  puts "🚀 画像処理Lambda開始"
  
  begin
    # 1. リクエストボディから画像データを取得
    body = parse_body(event)
    
    # 2. 画像データをデコード
    image_data = decode_image(body['image'])
    
    # 3. S3に画像を保存
    s3_key = upload_to_s3(image_data)
    
    # 4. 簡単な分析（今はファイルサイズだけ）
    analysis = analyze_image(image_data)
    
    # 5. 成功レスポンスを返す
    {
      statusCode: 200,
      headers: default_headers,
      body: JSON.generate({
        message: "画像を受け付けました！",
        s3_location: "s3://#{BUCKET_NAME}/#{s3_key}",
        analysis: analysis,
        timestamp: Time.now.iso8601
      })
    }
    
  rescue => e
    # エラーが発生した場合
    puts "❌ エラー発生: #{e.message}"
    puts e.backtrace
    
    {
      statusCode: 500,
      headers: default_headers,
      body: JSON.generate({
        error: "処理中にエラーが発生しました",
        message: e.message
      })
    }
  end
end

# リクエストボディをパース
def parse_body(event)
  return {} unless event['body']
  
  # API Gatewayからの場合、bodyは文字列
  if event['body'].is_a?(String)
    JSON.parse(event['body'])
  else
    event['body']
  end
end

# Base64画像データをデコード
def decode_image(base64_string)
  return nil unless base64_string
  
  # データURLスキーム（data:image/jpeg;base64,...）の場合の処理
  if base64_string.start_with?('data:')
    base64_string = base64_string.split(',')[1]
  end
  
  Base64.decode64(base64_string)
end

# S3に画像をアップロード
def upload_to_s3(image_data)
  s3_client = Aws::S3::Client.new(region: 'ap-northeast-1')
  
  # ユニークなファイル名を生成
  timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
  key = "uploads/#{timestamp}-#{SecureRandom.hex(4)}.jpg"
  
  puts "📤 S3にアップロード: #{key}"
  
  s3_client.put_object(
    bucket: BUCKET_NAME,
    key: key,
    body: image_data,
    content_type: 'image/jpeg',
    metadata: {
      'uploaded-via' => 'lambda',
      'uploaded-at' => Time.now.to_s
    }
  )
  
  key
end

# 画像の簡単な分析
def analyze_image(image_data)
  {
    size_bytes: image_data.bytesize,
    size_mb: (image_data.bytesize / 1024.0 / 1024.0).round(2),
    # 将来的にここでRekognitionを呼び出します
    placeholder_analysis: "まだ実装されていません"
  }
end

# デフォルトのレスポンスヘッダー
def default_headers
  {
    'Content-Type' => 'application/json',
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Headers' => 'Content-Type',
    'Access-Control-Allow-Methods' => 'POST, OPTIONS'
  }
end

# ローカルテスト
if __FILE__ == $0
  require 'pry' if Gem.loaded_specs.has_key?('pry')
  
  puts "=== S3連携Lambda関数のテスト ==="
  
  # テスト用の小さな画像データ（1x1ピクセルの赤い画像）
  test_image = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xDB\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\f\x14\r\f\v\v\f\x19\x12\x13\x0F\x14\x1D\x1A\x1F\x1E\x1D\x1A\x1C\x1C $.' \",#\x1C\x1C(7),01444\x1F'9=82<.342\xFF\xC0\x00\v\x08\x00\x01\x00\x01\x01\x01\x11\x00\xFF\xC4\x00\x1F\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\a\x08\t\n\v\xFF\xC4\x00\xB5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01}\x01\x02\x03\x00\x04\x11\x05\x12!1A\x06\x13Qa\x07\"q\x142\x81\x91\xA1\x08#B\xB1\xC1\x15R\xD1\xF0$3br\x82\t\n\x16\x17\x18\x19\x1A%&'()*456789:CDEFGHIJSTUVWXYZcdefghijstuvwxyz\x83\x84\x85\x86\x87\x88\x89\x8A\x92\x93\x94\x95\x96\x97\x98\x99\x9A\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFF\xDA\x00\x08\x01\x01\x00\x00?\x00\xFB\xD4\xD7\xFF\xD9"
  
  test_event = {
    'httpMethod' => 'POST',
    'body' => JSON.generate({
      'image' => Base64.encode64(test_image)
    })
  }
  
  print "バケット名を入力（Enter でスキップ）: "
  bucket_input = gets.chomp
  ENV['BUCKET_NAME'] = bucket_input unless bucket_input.empty?
  
  if ENV['BUCKET_NAME'].nil? || ENV['BUCKET_NAME'].empty?
    puts "⚠️  バケット名が設定されていません。S3アップロードはスキップされます。"
  end
  
  result = handler(event: test_event, context: {})
  
  puts "\n=== 実行結果 ==="
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end

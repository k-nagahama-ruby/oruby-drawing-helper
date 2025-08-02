# lambda/test_api.rb
# API Gateway経由でOruby Drawing Helperをテスト

require 'net/http'
require 'json'
require 'base64'
require 'uri'

class OrubyApiTester
  def initialize
    # Terraformの出力からAPIエンドポイントを取得
    Dir.chdir('../terraform') do
      @api_endpoint = `terraform output -raw api_endpoint`.strip
    end
    puts "🌐 API Endpoint: #{@api_endpoint}"
  end
  
  def test_simple_request
    puts "\n📝 Test 1: シンプルなテストリクエスト"
    
    # テスト用の小さな画像データ
    test_image = "小さなテスト画像データ"
    
    payload = {
      image: Base64.encode64(test_image),
      test_mode: true
    }
    
    response = make_request(payload)
    display_response(response)
  end
  
  def test_with_real_image(image_path)
    puts "\n🖼️  Test 2: 実際の画像でテスト"
    
    unless File.exist?(image_path)
      puts "❌ 画像ファイルが見つかりません: #{image_path}"
      return
    end
    
    # 画像を読み込んでBase64エンコード
    image_data = File.binread(image_path)
    puts "📊 画像サイズ: #{image_data.bytesize / 1024.0} KB"
    
    payload = {
      image: Base64.encode64(image_data),
      filename: File.basename(image_path)
    }
    
    response = make_request(payload)
    display_response(response)
  end
  
  def test_cors_preflight
    puts "\n🔍 Test 3: CORS プリフライトリクエスト"
    
    uri = URI(@api_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Options.new(uri.path)
    request['Origin'] = 'http://localhost:3000'
    request['Access-Control-Request-Method'] = 'POST'
    request['Access-Control-Request-Headers'] = 'Content-Type'
    
    response = http.request(request)
    
    puts "ステータス: #{response.code}"
    puts "CORS Headers:"
    response.each_header do |key, value|
      puts "  #{key}: #{value}" if key.downcase.include?('access-control')
    end
  end
  
  private
  
  def make_request(payload)
    uri = URI(@api_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30  # Lambda timeout に合わせる
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(payload)
    
    puts "🚀 リクエスト送信中..."
    start_time = Time.now
    
    response = http.request(request)
    
    elapsed = Time.now - start_time
    puts "⏱️  応答時間: #{elapsed.round(2)}秒"
    
    response
  end
  
  def display_response(response)
    puts "\n📥 レスポンス:"
    puts "ステータスコード: #{response.code}"
    
    if response.code == '200'
      body = JSON.parse(response.body)
      puts JSON.pretty_generate(body)
      
      # S3のURLが含まれていれば表示
      if body['s3_location']
        puts "\n✅ 画像がS3に保存されました:"
        puts "   #{body['s3_location']}"
      end
    else
      puts "エラー内容:"
      puts response.body
    end
  end
end

# メイン実行部分
if __FILE__ == $0
  tester = OrubyApiTester.new
  
  puts "\n=== Oruby Drawing Helper API テスト ==="
  puts "どのテストを実行しますか？"
  puts "1. シンプルなテスト"
  puts "2. 実際の画像でテスト"
  puts "3. CORS設定の確認"
  puts "4. すべて実行"
  
  print "選択 (1-4): "
  choice = gets.chomp
  
  case choice
  when '1'
    tester.test_simple_request
  when '2'
    print "画像ファイルのパス: "
    path = gets.chomp.gsub('~', Dir.home)
    tester.test_with_real_image(path)
  when '3'
    tester.test_cors_preflight
  when '4'
    tester.test_simple_request
    tester.test_cors_preflight
    # 画像テストはスキップ（パスが必要なため）
  else
    puts "無効な選択です"
  end
end

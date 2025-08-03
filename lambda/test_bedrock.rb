# lambda/test_bedrock.rb
# Bedrock統合版のテスト

require 'net/http'
require 'json'
require 'base64'
require 'uri'

class BedrockApiTester
  def initialize
    Dir.chdir('../terraform') do
      @api_endpoint = `terraform output -raw api_endpoint`.strip
    end
    puts "🌐 API Endpoint: #{@api_endpoint}"
  end
  
  def test_with_image(image_path)
    puts "\n🤖 Bedrock AIエージェントによる分析テスト"
    
    unless File.exist?(image_path)
      puts "❌ 画像ファイルが見つかりません: #{image_path}"
      return
    end
    
    # 画像を読み込んでBase64エンコード
    image_data = File.binread(image_path)
    puts "📊 画像サイズ: #{image_data.bytesize / 1024.0} KB"
    
    payload = {
      image: Base64.encode64(image_data),
      filename: File.basename(image_path),
      request_ai_analysis: true  # AI分析を明示的にリクエスト
    }
    
    puts "🚀 AIエージェントを呼び出し中..."
    puts "⏳ Bedrock応答には10-20秒かかる場合があります..."
    
    start_time = Time.now
    response = make_request(payload)
    elapsed = Time.now - start_time
    
    puts "\n⏱️  応答時間: #{elapsed.round(2)}秒"
    display_ai_response(response)
  end
  
  private
  
  def make_request(payload)
    uri = URI(@api_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60  # Bedrock用に長めのタイムアウト
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(payload)
    
    http.request(request)
  end
  
  def display_ai_response(response)
    puts "\n📥 レスポンス:"
    puts "ステータスコード: #{response.code}"
    
    if response.code == '200'
      body = JSON.parse(response.body)
      
      puts "\n🎯 AI評価結果:"
      puts "総合スコア: #{body['score']}点"
      puts "AI評価: #{body['ai_evaluation']}"
      
      if body['ai_advice']
        puts "\n💡 AIからのアドバイス:"
        puts body['ai_advice']
        
        puts "\n📝 改善のヒント:"
        body['improvement_tips']&.each_with_index do |tip, i|
          puts "#{i + 1}. #{tip}"
        end
      end
      
      puts "\n🏷️  Rekognitionラベル:"
      body['rekognition_labels']&.each do |label|
        puts "- #{label['name']} (#{label['confidence']}%)"
      end
      
      if body['s3_location']
        puts "\n✅ 画像保存先: #{body['s3_location']}"
      end
    else
      puts "エラー内容:"
      puts response.body
    end
  end
end

# メイン実行
if __FILE__ == $0
  tester = BedrockApiTester.new
  
  puts "\n=== Oruby Drawing Helper - Bedrock AI分析テスト ==="
  
  if ARGV.empty?
    print "分析する画像ファイルのパス: "
    path = gets.chomp.gsub('~', Dir.home)
  else
    path = ARGV[0].gsub('~', Dir.home)
    puts "分析する画像ファイルのパス: #{path}"
  end
  
  tester.test_with_image(path)
  
  puts "\n💡 ヒント:"
  puts "- Bedrockの初回呼び出しは時間がかかることがあります"
  puts "- より詳細な分析結果が得られます"
  puts "- エラーの場合は基本分析にフォールバックします"
end

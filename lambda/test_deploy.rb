# lambda/test_deployed.rb
# AWSにデプロイしたLambda関数をテストするスクリプト

require 'json'
require 'base64'
require 'open3'

def test_deployed_lambda
  puts "🧪 デプロイされたLambda関数をテストします..."
  
  # Lambda関数名を取得
  Dir.chdir('../terraform') do
    function_name = `terraform output -raw lambda_function_name`.strip
    puts "📌 関数名: #{function_name}"
    
    # テスト用のイベントデータ
    test_event = {
      httpMethod: 'POST',
      path: '/analyze',
      body: JSON.generate({
        image: Base64.encode64("これはテスト画像データです"),
        test_mode: true
      })
    }
    
    # イベントデータをファイルに保存（AWS CLIで使用）
    File.write('test_event.json', JSON.generate(test_event))
    
    puts "\n🚀 Lambda関数を呼び出し中..."
    
    # AWS CLIでLambda関数を呼び出し
    cmd = "aws lambda invoke " \
          "--function-name #{function_name} " \
          "--payload file://test_event.json " \
          "--cli-binary-format raw-in-base64-out " \
          "response.json"
    
    stdout, stderr, status = Open3.capture3(cmd)
    
    if status.success?
      puts "✅ 呼び出し成功！"
      
      # レスポンスを読み込み
      response = JSON.parse(File.read('response.json'))
      
      puts "\n📤 Lambda関数のレスポンス:"
      puts JSON.pretty_generate(response)
      
      # ボディをパース（Lambda関数が正しい形式で返している場合）
      if response['body']
        body = JSON.parse(response['body'])
        puts "\n📊 解析されたボディ:"
        puts JSON.pretty_generate(body)
      end
      
      # CloudWatch Logsの確認方法を案内
      puts "\n💡 ヒント: ログを確認するには:"
      puts "aws logs tail /aws/lambda/#{function_name} --follow"
      
    else
      puts "❌ エラーが発生しました:"
      puts stderr
    end
    
    # クリーンアップ
    File.delete('test_event.json') if File.exist?('test_event.json')
    File.delete('response.json') if File.exist?('response.json')
  end
end

# 簡易的なログ確認機能
def check_logs
  Dir.chdir('../terraform') do
    function_name = `terraform output -raw lambda_function_name`.strip
    
    puts "\n📋 最新のログを確認中..."
    system("aws logs tail /aws/lambda/#{function_name} --since 5m")
  end
end

if __FILE__ == $0
  puts "どの操作を実行しますか？"
  puts "1. Lambda関数をテスト"
  puts "2. ログを確認"
  puts "3. 両方実行"
  
  print "選択 (1-3): "
  choice = gets.chomp
  
  case choice
  when '1'
    test_deployed_lambda
  when '2'
    check_logs
  when '3'
    test_deployed_lambda
    check_logs
  else
    puts "無効な選択です"
  end
end

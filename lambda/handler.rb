require 'json'

# Lambda関数のエントリーポイント
# event: Lambda関数に渡されるデータ（APIからのリクエストなど）
# context: Lambda実行環境の情報（タイムアウトまでの残り時間など）
def handler(event:, context:)
  puts "🚀 Lambda関数が呼ばれました！"
  
  # eventの中身を確認（デバッグ用）
  puts "📥 受信したevent:"
  puts JSON.pretty_generate(event)
  
  # 1. 最初は固定のレスポンスを返すだけ
  response = {
    statusCode: 200,
    headers: {
      'Content-Type' => 'application/json',
      'Access-Control-Allow-Origin' => '*'  # CORS対応
    },
    body: JSON.generate({
      message: "こんにちは！おるびー絵描きヘルパーです",
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      ruby_version: RUBY_VERSION,
      received_event: event  # 受け取ったデータをそのまま返す（デバッグ用）
    })
  }
  
  puts "📤 レスポンス:"
  puts JSON.pretty_generate(response)
  
  response
end

# ローカルテスト用のコード
# Lambdaとして実行される時は、このブロックは無視されます
if __FILE__ == $0
  puts "=== ローカルテストモード ==="
  
  # テスト用のイベントデータ
  test_event = {
    'httpMethod' => 'POST',
    'path' => '/analyze',
    'body' => JSON.generate({
      'image' => 'base64エンコードされた画像データがここに入ります',
      'user_name' => 'テストユーザー'
    })
  }
  
  # Lambda関数を実行
  result = handler(event: test_event, context: {})
  
  puts "\n=== 実行結果 ==="
  puts "ステータスコード: #{result[:statusCode]}"
  puts "ボディ:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end

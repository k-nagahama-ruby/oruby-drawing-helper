
require 'json'
require 'base64'
require 'aws-sdk-s3'
require 'aws-sdk-rekognition'
require 'aws-sdk-bedrockruntime'
require 'securerandom'

# AWSクライアント
S3_CLIENT = Aws::S3::Client.new
REKOGNITION_CLIENT = Aws::Rekognition::Client.new
BEDROCK_CLIENT = Aws::BedrockRuntime::Client.new(region: 'ap-northeast-1')

# 環境変数
BUCKET_NAME = ENV['BUCKET_NAME']
MODEL_BUCKET_NAME = ENV['MODEL_BUCKET_NAME']
BEDROCK_MODEL_ID = ENV['BEDROCK_MODEL_ID'] || 'anthropic.claude-3-sonnet-20240229-v1:0'

def handler(event:, context:)
  puts "🎨 Oruby Drawing Helper with Bedrock - 処理開始"
  puts "使用モデル: #{BEDROCK_MODEL_ID}"
  
  begin
    # リクエスト解析
    body = parse_body(event)
    image_data = decode_image(body['image'])
    
    # S3に画像を保存
    s3_key = upload_to_s3(image_data)
    s3_url = "s3://#{BUCKET_NAME}/#{s3_key}"
    
    # 統計モデルを取得
    model_data = get_golden_ratio_model
    
    # Rekognitionで画像分析
    rekognition_result = analyze_with_rekognition(BUCKET_NAME, s3_key)
    
    # Bedrockエージェントによる高度な分析
    puts "🤖 Bedrockエージェントによる分析開始..."
    
    # エージェント1: 評価エージェント
    evaluation_result = run_evaluation_agent(
      rekognition_result, 
      model_data,
      s3_url
    )
    
    # エージェント2: アドバイスエージェント
    advice_result = run_advice_agent(
      rekognition_result,
      evaluation_result,
      model_data
    )
    
    # 最終的なレスポンス生成
    {
      statusCode: 200,
      headers: default_headers,
      body: JSON.generate({
        message: "AI分析が完了しました！",
        s3_location: s3_url,
        score: evaluation_result[:score],
        ai_evaluation: evaluation_result[:evaluation],
        rekognition_labels: rekognition_result[:labels].first(5),
        ai_advice: advice_result[:advice],
        improvement_tips: advice_result[:tips],
        timestamp: Time.now.iso8601
      })
    }
    
  rescue Aws::BedrockRuntime::Errors::ServiceError => e
    puts "❌ Bedrockエラー: #{e.message}"
    # Bedrockエラー時は従来の分析にフォールバック
    fallback_to_basic_analysis(e.message)
  rescue => e
    puts "❌ エラー発生: #{e.message}"
    puts e.backtrace.first(5)
    
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

# エージェント1: 評価エージェント
def run_evaluation_agent(rekognition_result, model_data, s3_url)
  puts "🎯 評価エージェント実行中..."
  
  prompt = build_evaluation_prompt(rekognition_result, model_data)
  
  begin
    response = BEDROCK_CLIENT.invoke_model(
      model_id: BEDROCK_MODEL_ID,
      body: {
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 1500,
        temperature: 0.3,  # 評価は一貫性重視で低めの温度
        messages: [
          {
            role: "user",
            content: prompt
          }
        ]
      }.to_json,
      content_type: 'application/json'
    )
    
    result = JSON.parse(response.body.read)
    ai_response = JSON.parse(result['content'][0]['text'])
    
    puts "✅ 評価エージェント完了: スコア #{ai_response['score']}"
    
    {
      score: ai_response['score'],
      evaluation: ai_response['evaluation'],
      breakdown: ai_response['breakdown']
    }
    
  rescue => e
    puts "⚠️  評価エージェントエラー: #{e.message}"
    # フォールバック
    {
      score: calculate_basic_score(rekognition_result),
      evaluation: "AIによる詳細評価は利用できませんでした",
      breakdown: {}
    }
  end
end

# エージェント2: アドバイスエージェント
def run_advice_agent(rekognition_result, evaluation_result, model_data)
  puts "💡 アドバイスエージェント実行中..."
  
  prompt = build_advice_prompt(rekognition_result, evaluation_result, model_data)
  
  begin
    response = BEDROCK_CLIENT.invoke_model(
      model_id: BEDROCK_MODEL_ID,
      body: {
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 1500,
        temperature: 0.7,  # アドバイスは創造性を持たせて高めの温度
        messages: [
          {
            role: "user",
            content: prompt
          }
        ]
      }.to_json,
      content_type: 'application/json'
    )
    
    result = JSON.parse(response.body.read)
    ai_response = JSON.parse(result['content'][0]['text'])
    
    puts "✅ アドバイスエージェント完了"
    
    {
      advice: ai_response['main_advice'],
      tips: ai_response['improvement_tips']
    }
    
  rescue => e
    puts "⚠️  アドバイスエージェントエラー: #{e.message}"
    # フォールバック
    {
      advice: "絵をもっと楽しんで描いてみましょう！",
      tips: ["色を増やしてみる", "キャラクターを大きく描く", "笑顔を追加する"]
    }
  end
end

# 評価エージェント用プロンプト構築
def build_evaluation_prompt(rekognition_result, model_data)
  labels = rekognition_result[:labels].map { |l| "#{l[:name]} (#{l[:confidence]}%)" }.join(", ")
  
  <<~PROMPT
    あなたは「Oruby」の絵を評価する専門家AIです。
    Orubyは、Rubyプログラミング言語をモチーフにした親しみやすいキャラクターです。
    
    以下の情報を基に、この絵を0-100点で評価してください。
    
    【検出されたラベル】
    #{labels}
    
    【Orubyの理想的な特徴（黄金比）】
    - 構図: キャラクターが画面の30-60%を占める
    - 色使い: 暖色系（特に赤・オレンジ）を基調とし、3-7色使用
    - スタイル: 丸みを帯びた形状、笑顔、ルビーモチーフ
    - 技術: 線の滑らかさと一貫性
    
    【重要度】
    - 構図: 30%
    - 色使い: 25%
    - スタイル: 35%
    - 技術品質: 10%
    
    必ず以下のJSON形式で回答してください：
    {
      "score": 総合スコア（0-100の整数）,
      "evaluation": "全体的な評価コメント（日本語で親しみやすく）",
      "breakdown": {
        "composition": 構図スコア,
        "color": 色使いスコア,
        "style": スタイルスコア,
        "technical": 技術スコア
      }
    }
    
    評価は建設的で励みになるものにしてください。
  PROMPT
end

# アドバイスエージェント用プロンプト構築
def build_advice_prompt(rekognition_result, evaluation_result, model_data)
  prompt = <<~PROMPT
    画像分析結果: #{labels}
    
    0-100点で評価し、改善点を3つ挙げてください。
    JSON形式で回答:
    {"score": 数値, "advice": ["アドバイス1", "アドバイス2", "アドバイス3"]}
  PROMPT
end

# 基本的なスコア計算（フォールバック用）
def calculate_basic_score(rekognition_result)
  labels = rekognition_result[:labels]
  
  # キーワードに基づく簡易スコアリング
  score = 50  # 基本スコア
  
  positive_keywords = ['drawing', 'art', 'illustration', 'cartoon', 'creative', 'colorful']
  character_keywords = ['person', 'character', 'face', 'smile']
  
  labels.each do |label|
    label_lower = label[:name].downcase
    score += 5 if positive_keywords.any? { |kw| label_lower.include?(kw) }
    score += 10 if character_keywords.any? { |kw| label_lower.include?(kw) }
  end
  
  [score, 100].min
end

# Bedrockエラー時のフォールバック
def fallback_to_basic_analysis(error_message)
  puts "⚠️  Bedrockが利用できないため、基本分析にフォールバック"
  
  {
    statusCode: 200,
    headers: default_headers,
    body: JSON.generate({
      message: "基本分析を実行しました（AI分析は一時的に利用できません）",
      error_detail: error_message,
      score: 65,
      evaluation: "AIサービスが一時的に利用できないため、簡易評価を行いました",
      advice: [
        "絵を描き続けることが上達への近道です！",
        "Orubyらしい赤色を使ってみましょう",
        "笑顔のキャラクターは見る人を幸せにします"
      ],
      timestamp: Time.now.iso8601
    })
  }
end

# === 以下、既存のユーティリティ関数 ===

def get_golden_ratio_model
  puts "📊 統計モデルを取得中..."
  
  begin
    response = S3_CLIENT.get_object(
      bucket: MODEL_BUCKET_NAME,
      key: 'models/golden_ratio.json'
    )
    JSON.parse(response.body.read)
  rescue => e
    puts "⚠️  モデル取得エラー: #{e.message}"
    {}
  end
end

def analyze_with_rekognition(bucket, key)
  puts "🔍 Rekognitionで画像分析中..."
  
  labels_response = REKOGNITION_CLIENT.detect_labels(
    image: {
      s3_object: {
        bucket: bucket,
        name: key
      }
    },
    max_labels: 20,
    min_confidence: 60
  )
  
  {
    labels: labels_response.labels.map { |label|
      {
        name: label.name,
        confidence: label.confidence.round(2),
        categories: label.categories&.map(&:name) || []
      }
    },
    metadata: {
      orientation: labels_response.orientation_correction
    }
  }
end

def parse_body(event)
  return {} unless event['body']
  
  if event['body'].is_a?(String)
    JSON.parse(event['body'])
  else
    event['body']
  end
end

def decode_image(base64_string)
  return nil unless base64_string
  
  if base64_string.start_with?('data:')
    base64_string = base64_string.split(',')[1]
  end
  
  Base64.decode64(base64_string)
end

def upload_to_s3(image_data)
  timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
  key = "uploads/#{timestamp}-#{SecureRandom.hex(4)}.jpg"
  
  puts "📤 S3にアップロード: #{key}"
  
  S3_CLIENT.put_object(
    bucket: BUCKET_NAME,
    key: key,
    body: image_data,
    content_type: 'image/jpeg',
    metadata: {
      'uploaded-via' => 'lambda',
      'analyzed-with' => 'rekognition-and-bedrock'
    }
  )
  
  key
end

def default_headers
  {
    'Content-Type' => 'application/json',
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Headers' => 'Content-Type',
    'Access-Control-Allow-Methods' => 'POST, OPTIONS'
  }
end

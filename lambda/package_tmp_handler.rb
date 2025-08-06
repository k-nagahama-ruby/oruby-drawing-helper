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
BEDROCK_MODEL_ID = ENV['BEDROCK_MODEL_ID'] || 'anthropic.claude-3-haiku-20240307-v1:0'

# Helper method to extract JSON from Claude's response
def extract_json_from_response(text)
  # Claude may include explanation text before/after JSON
  # Match the outermost JSON object
  json_match = text.match(/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/m)
  if json_match
    JSON.parse(json_match[0])
  else
    raise "No valid JSON found in response: #{text}"
  end
end

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
    
    # Oruby特化のスコア計算
    score_result = calculate_score(rekognition_result, model_data)
    
    # Bedrockエージェントによる高度な分析
    puts "🤖 Bedrockエージェントによる分析開始..."
    
    # エージェント1: 評価エージェント
    evaluation_result = run_evaluation_agent(
      rekognition_result, 
      model_data,
      s3_url,
      score_result  # 事前計算スコアを渡す
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
        oruby_features: score_result[:oruby_features],  # Oruby特徴の判定結果
        timestamp: Time.now.iso8601
      })
    }
    
  rescue Aws::BedrockRuntime::Errors::ServiceError => e
    puts "❌ Bedrockエラー: #{e.message}"
    # Bedrockエラー時は従来の分析にフォールバック
    fallback_to_basic_analysis(e.message, rekognition_result, model_data)
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

# Oruby特化のスコア計算
def calculate_score(rekognition_result, model_data)
  puts "🎯 Orubyスコアを計算中..."
  
  # Orubyの必須要素をチェック
  oruby_bonus = calculate_oruby_features_bonus(rekognition_result)
  
  scores = {
    composition: calculate_composition_score(rekognition_result, model_data),
    complexity: calculate_complexity_score(rekognition_result),
    completeness: calculate_completeness_score(rekognition_result)
  }
  
  weights = {
    'composition' => 0.3,
    'complexity' => 0.2,     # 10%→20%（バランスを取る）
    'completeness' => 0.5    # 60%→50%
  }
  
  # 基本スコア計算
  base_score = scores.sum { |category, score|
    score * weights[category.to_s]
  }.round
  
  # Oruby特徴ボーナスを加算（影響を抑える）
  total_score = base_score + (oruby_bonus * 0.7).round  # ボーナスの影響を70%に
  
  # 範囲制限
  total_score = [[total_score, 100].min, 10].max

  # 平均60点になるように全体調整
  # 基準点60からの偏差を計算
  if total_score > 60
    # 60点以上は上昇を緩やかに
    total_score = 60 + ((total_score - 60) * 0.8).round
  else
    # 60点以下は下降を緩やかに
    total_score = 60 - ((60 - total_score) * 0.8).round
  end
  
  {
    total_score: total_score,
    details: scores.merge(oruby_bonus: oruby_bonus),
    score_range: determine_score_range(total_score, model_data),
    oruby_features: check_oruby_features(rekognition_result)
  }
end

def check_oruby_features(rekognition_result)
  labels = rekognition_result[:labels]
  
  {
    # Drawing/Sketch/Artも含めて判定
    has_bird: labels.any? { |l| 
      l[:name].match?(/bird|beak|wing|feather|avian|animal|character|mascot/i) ||
      (l[:name].match?(/drawing|sketch|illustration|art/i) && labels.size > 3)
    },
    # Shapeも含めて判定
    has_gem: labels.any? { |l| 
      l[:name].match?(/gem|jewel|jewelry|crystal|stone|ornament|accessory|diamond|shape|triangle/i)
    },
    # DrawingやArtも可愛さとして判定
    is_cute: labels.any? { |l| 
      l[:name].match?(/cute|adorable|cartoon|toy|plush|kawaii|drawing|sketch|doodle|simple/i)
    },
    bird_confidence: labels.select { |l| l[:name].match?(/bird|animal/i) }.map { |l| l[:confidence] }.max || 75
  }
end

def calculate_oruby_features_bonus(rekognition_result)
  features = check_oruby_features(rekognition_result)
  labels = rekognition_result[:labels]
  bonus = 0
  
  # 線画として認識されていれば基礎点（控えめ）
  if labels.any? { |l| l[:name].match?(/drawing|sketch|illustration|art|doodle/i) }
    bonus += 5  # 15→5
  end
  
  # 鳥要素（必須に近い）
  if features[:has_bird]
    bonus += 5  # 10→5
  elsif labels.any? { |l| l[:name].match?(/animal|character|mascot/i) }
    bonus += 2  # 5→2
  else
    bonus -= 10  # 鳥として認識されないと減点
  end
  
  # 宝石要素（重要）
  if features[:has_gem] || labels.any? { |l| l[:name].match?(/shape|geometric/i) }
    bonus += 3  # 5→3
  else
    bonus -= 5  # 宝石がないと減点
  end
  
  # シンプルさは加点しない（基準に含まれる）
  
  bonus
end

def calculate_composition_score(rekognition_result, model_data)
  labels = rekognition_result[:labels]
  
  # 主要な要素が明確に認識されているか
  main_subject = labels.select { |l| l[:confidence] > 75 }.first(3)
  
  if main_subject.any?
    # 主題の明確さでスコア決定（厳しく）
    avg_confidence = main_subject.map { |l| l[:confidence] }.sum / main_subject.size.to_f
    base_score = ((avg_confidence - 50) * 1.2).round  # 基準を厳しく
    
    # 中央配置ボーナス（控えめ）
    if labels.any? { |l| l[:name].match?(/bird|animal|character/i) && l[:confidence] > 70 }
      base_score += 5  # 10→5
    end
    
    [base_score, 85].min  # 最大85点
  else
    30  # 40→30（主題が不明確）
  end
end

def calculate_complexity_score(rekognition_result)
  labels = rekognition_result[:labels]
  label_count = labels.count
  
  # 線画用の基礎点を下げる
  base_score = if labels.any? { |l| l[:name].match?(/drawing|sketch|illustration|doodle/i) }
    30  # 60→30
  else
    0
  end
  
  # ラベル数による加点（厳しく）
  case label_count
  when 0..2
    base_score + 10  # 最低限
  when 3..5
    base_score + 20  # 基本的
  when 6..9
    base_score + 30  # 適切
  when 10..15
    base_score + 25  # やや多い
  else
    base_score + 20  # 多すぎ
  end
end

def calculate_completeness_score(rekognition_result)
  labels = rekognition_result[:labels]
  
  # 基本スコアを下げる
  score = 40  # 60→40
  
  # 線画として認識されたら少し加点
  if labels.any? { |l| l[:name].match?(/drawing|illustration|art|sketch|doodle/i) }
    score += 10  # 20→10
  end
  
  # 高信頼度ラベルによる加点（厳しく）
  high_confidence_count = labels.count { |l| l[:confidence] > 80 }  # 75→80
  very_high_confidence_count = labels.count { |l| l[:confidence] > 90 }
  
  score += high_confidence_count * 2  # 3→2
  score += very_high_confidence_count * 2  # 追加ボーナス
  
  # 平均信頼度による調整
  if labels.any?
    avg_confidence = labels.map { |l| l[:confidence] }.sum / labels.size.to_f
    if avg_confidence > 85  # 70→85（厳しく）
      score += 10
    elsif avg_confidence < 70
      score -= 5
    end
  end
  
  [[score, 20].max, 90].min  # 最大値も90に制限
end

# スコアレンジ判定（Oruby版）
def determine_score_range(score, model_data)
  case score
  when 90..100
    { 'label' => '完璧なOruby！理想的な作品です！' }
  when 80..89
    { 'label' => '素晴らしいOruby！プロ級の仕上がりです' }
  when 70..79
    { 'label' => '良いOruby！必須要素が揃っています' }
  when 60..69
    { 'label' => 'まずまずのOruby。もう少し丁寧に' }
  when 50..59
    { 'label' => 'Orubyの特徴が不足。基本を確認しましょう' }
  when 40..49
    { 'label' => '要改善。必須要素を意識して描きましょう' }
  else
    { 'label' => '基礎から練習しましょう。お手本を参考に！' }
  end
end

# エージェント1: 評価エージェント
def run_evaluation_agent(rekognition_result, model_data, s3_url, score_result = nil)
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
    response_text = result['content'][0]['text']
    ai_response = extract_json_from_response(response_text)
    
    puts "✅ 評価エージェント完了: スコア #{ai_response['score']}"
    
    {
      score: ai_response['score'],
      evaluation: ai_response['evaluation'],
      breakdown: ai_response['breakdown']
    }
    
  rescue => e
    puts "⚠️  評価エージェントエラー: #{e.message}"
    # フォールバック（事前計算スコアを使用）
    fallback_score = score_result ? score_result[:total_score] : 50
    {
      score: fallback_score,
      evaluation: "AIによる詳細評価は利用できませんでした",
      breakdown: score_result ? score_result[:details] : {}
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
    response_text = result['content'][0]['text']
    ai_response = extract_json_from_response(response_text)
    
    puts "✅ アドバイスエージェント完了"
    
    {
      advice: ai_response['main_advice'],
      tips: ai_response['improvement_tips']
    }
    
  rescue => e
    puts "⚠️  アドバイスエージェントエラー: #{e.message}"
    # フォールバック
    features = check_oruby_features(rekognition_result)
    default_tips = []
    default_tips << "鳥の特徴（くちばしや羽）を明確に描きましょう" unless features[:has_bird]
    default_tips << "尻尾に宝石を追加してOrubyらしさを出しましょう" unless features[:has_gem]
    default_tips << "もっと可愛らしい表情にしてみましょう" unless features[:is_cute]
    
    {
      advice: "Orubyの特徴をもっと強調してみましょう！",
      tips: default_tips.any? ? default_tips : ["構図を大きく描く", "描き込みを増やす", "キャラクターの表情を豊かに"]
    }
  end
end

# 評価プロンプト（Oruby特化版）
def build_evaluation_prompt(rekognition_result, model_data)
  labels = rekognition_result[:labels]
  label_count = labels.count
  features = check_oruby_features(rekognition_result)
  
  # 事前計算スコア（参考値）
  comp_score = calculate_composition_score(rekognition_result, model_data)
  complex_score = calculate_complexity_score(rekognition_result)
  complete_score = calculate_completeness_score(rekognition_result)
  oruby_bonus = calculate_oruby_features_bonus(rekognition_result)
  
 <<~PROMPT
    「Oruby（おるびー）」の絵を評価してください。
    Orubyは宝石（ルビー）を尻尾につけた可愛い鳥のキャラクターです。
    
    【重要な評価方針】
    - これは白黒の線画作品です
    - 厳格な評価基準を適用してください
    - 必須要素：くちばし、丸い体、ダイヤモンド型の装飾
    
    【検出された要素】
    #{labels.first(5).map { |l| "#{l[:name]}(#{l[:confidence].round}%)" }.join(", ")}
    
    【評価配分】
    1. 構図（30%）: 中央配置、バランス
    2. 必須要素（40%）: くちばし、体、宝石の明確な表現
    3. 完成度（30%）: 全体的なまとまりと仕上がり
    
    【採点基準（厳格）】
    - 平均60点を基準とする
    - 70点以上：必須要素がすべて明確に表現されている
    - 80点以上：構図・バランスも優れている
    - 90点以上：ほぼ完璧な作品
    - 100点：理想的な見本レベルのみ
    
    【減点要素】
    - 必須要素の欠如：各-15点
    - バランスの悪さ：-10点
    - 不明瞭な表現：-10点
    
    JSON形式のみで回答：
    {"score": 総合点, "evaluation": "評価コメント", "breakdown": {"composition": 点, "essential_features": 点, "completeness": 点}}
  PROMPT
end

# アドバイスプロンプト（Oruby特化版）
def build_advice_prompt(rekognition_result, evaluation_result, model_data)
  features = check_oruby_features(rekognition_result)
  score = evaluation_result[:score]
  
  missing_features = []
  missing_features << "鳥の特徴（くちばしや羽）" unless features[:has_bird]
  missing_features << "宝石（尻尾のアクセサリー）" unless features[:has_gem]
  missing_features << "可愛らしさ" unless features[:is_cute]
  
  <<~PROMPT
    Orubyの絵の改善アドバイスをしてください。
    
    【現在の評価】
    スコア: #{score}点
    不足要素: #{missing_features.any? ? missing_features.join("、") : "なし"}
    
    【Orubyの特徴】
    - 鳥のキャラクター（くちばし、羽が重要）
    - 尻尾に宝石（ルビー）がついている
    - 可愛らしい表情
    
    必須要素が欠けている場合は、それを最優先でアドバイスしてください。
    白黒イラストなので、形やデザインでの表現方法を提案してください。
    
    JSON形式で回答：
    {
      "main_advice": "最も重要な改善点",
      "improvement_tips": [
        "具体的な改善方法1",
        "具体的な改善方法2",
        "具体的な改善方法3"
      ]
    }
  PROMPT
end

# Bedrockエラー時のフォールバック（改良版）
def fallback_to_basic_analysis(error_message, rekognition_result = nil, model_data = nil)
  puts "⚠️  Bedrockが利用できないため、基本分析にフォールバック"
  
  # Rekognitionの結果があれば、それを使ってスコア計算
  if rekognition_result
    score_result = calculate_score(rekognition_result, model_data || {})
    score = score_result[:total_score]
    features = score_result[:oruby_features]
    
    advice = []
    advice << "鳥の特徴をもっと明確に描きましょう" unless features[:has_bird]
    advice << "尻尾に宝石を追加してOrubyらしさを出しましょう" unless features[:has_gem]
    advice << "可愛らしい表情を意識しましょう" unless features[:is_cute]
    advice << "構図を大きく、はっきりと描きましょう" if advice.empty?
  else
    score = 50
    advice = ["絵を描き続けることが上達への近道です！"]
  end
  
  {
    statusCode: 200,
    headers: default_headers,
    body: JSON.generate({
      message: "基本分析を実行しました（AI分析は一時的に利用できません）",
      score: score,
      evaluation: "Rekognitionベースの分析を行いました",
      advice: advice,
      timestamp: Time.now.iso8601
    })
  }
end

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
    min_confidence: 45
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
  
  # 画像形式を検出
  extension = 'jpg'
  content_type = 'image/jpeg'
  
  if image_data[0..3].bytes == [0x89, 0x50, 0x4E, 0x47]  # PNG signature
    extension = 'png'
    content_type = 'image/png'
  elsif image_data[0..1].bytes == [0xFF, 0xD8]  # JPEG signature
    extension = 'jpg'
    content_type = 'image/jpeg'
  elsif image_data[0..2] == 'GIF'  # GIF signature
    extension = 'gif'
    content_type = 'image/gif'
  end
  
  key = "uploads/#{timestamp}-#{SecureRandom.hex(4)}.#{extension}"
  
  puts "📤 S3にアップロード: #{key} (#{content_type})"
  
  S3_CLIENT.put_object(
    bucket: BUCKET_NAME,
    key: key,
    body: image_data,
    content_type: content_type,
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

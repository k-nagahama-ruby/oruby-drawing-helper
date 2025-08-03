require 'json'
require 'base64'
require 'aws-sdk-s3'
require 'aws-sdk-rekognition'
require 'securerandom'

# AWSクライアント
S3_CLIENT = Aws::S3::Client.new
REKOGNITION_CLIENT = Aws::Rekognition::Client.new

# 環境変数
BUCKET_NAME = ENV['BUCKET_NAME']
MODEL_BUCKET_NAME = ENV['MODEL_BUCKET_NAME']

def handler(event:, context:)
  puts "🎨 Oruby Drawing Helper - 処理開始"
  
  begin
    # リクエスト解析
    body = parse_body(event) # JSONにする
    image_data = decode_image(body['image']) # binary_dataに変換
    
    # S3に画像を保存
    s3_key = upload_to_s3(image_data)
    
    # 統計モデルを取得
    model_data = get_golden_ratio_model
    
    # Rekognitionで画像分析
    rekognition_result = analyze_with_rekognition(BUCKET_NAME, s3_key)
    
    # スコアリング
    score_result = calculate_score(rekognition_result, model_data)
    
    # レスポンス生成
    {
      statusCode: 200,
      headers: default_headers,
      body: JSON.generate({
        message: "分析が完了しました！",
        s3_location: "s3://#{BUCKET_NAME}/#{s3_key}",
        score: score_result[:total_score],
        details: score_result[:details],
        rekognition_labels: rekognition_result[:labels].first(5), # 上位5つのラベル
        advice: generate_advice(score_result),
        timestamp: Time.now.iso8601
      })
    }
    
  rescue => e
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

# 統計モデルを取得
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
    # フォールバック用のデフォルトモデル
    {
      'composition' => { 'ideal_ratios' => {} },
      'colors' => { 'metrics' => {} },
      'style_features' => { 'required_elements' => {} }
    }
  end
end

# Rekognitionで画像分析
def analyze_with_rekognition(bucket, key)
  puts "🔍 Rekognitionで画像分析中..."
  
  # ラベル検出
  labels_response = REKOGNITION_CLIENT.detect_labels(
    image: {
      s3_object: {
        bucket: bucket,
        name: key
      }
    },
    max_labels: 20,
    min_confidence: 70
  )
  
  # 顔検出（オプション）
  faces_response = begin
    REKOGNITION_CLIENT.detect_faces(
      image: {
        s3_object: {
          bucket: bucket,
          name: key
        }
      },
      attributes: ['ALL']
    )
  rescue => e
    puts "顔検出はスキップ: #{e.message}"
    nil
  end
  
  {
    labels: labels_response.labels.map { |label|
      {
        name: label.name,
        confidence: label.confidence.round(2),
        categories: label.categories&.map(&:name) || []
      }
    },
    faces: faces_response&.face_details || [],
    metadata: {
      orientation: labels_response.orientation_correction
    }
  }
end

# スコア計算
def calculate_score(rekognition_result, model_data)
  puts "🎯 スコアを計算中..."
  
  scores = {
    composition: calculate_composition_score(rekognition_result, model_data),
    colors: calculate_color_score(rekognition_result, model_data),
    style_features: calculate_style_score(rekognition_result, model_data),
    technical_quality: 70 # 仮の値（将来的に実装）
  }
  
  # 重み付け
  weights = model_data.dig('scoring', 'weights') || {
    'composition' => 0.3,
    'colors' => 0.25,
    'style_features' => 0.35,
    'technical_quality' => 0.1
  }
  
  total_score = scores.sum { |category, score|
    score * weights[category.to_s]
  }.round
  
  {
    total_score: total_score,
    details: scores,
    score_range: determine_score_range(total_score, model_data)
  }
end

# 構図スコア計算
def calculate_composition_score(rekognition_result, model_data)
  # Rekognitionのラベルから構図を推定
  labels = rekognition_result[:labels]
  
  # キャラクターや人物が検出されているか
  character_labels = labels.select { |l|
    l[:name].match?(/person|character|cartoon|drawing|illustration/i)
  }
  
  if character_labels.any?
    # 信頼度の平均をスコアとして使用
    base_score = character_labels.map { |l| l[:confidence] }.sum / character_labels.size
    
    # 顔が検出されていればボーナス
    face_bonus = rekognition_result[:faces].any? ? 10 : 0
    
    [base_score + face_bonus, 100].min
  else
    50 # キャラクターが検出されない場合は基本スコア
  end
end

# 色スコア計算
def calculate_color_score(rekognition_result, model_data)
  # ラベルから色の多様性を推定
  color_related_labels = rekognition_result[:labels].select { |l|
    l[:name].match?(/color|bright|vivid|pastel|warm|cool/i)
  }
  
  if color_related_labels.any?
    80 + color_related_labels.size * 2 # 色関連のラベル数に応じてスコアアップ
  else
    65 # 基本スコア
  end
end

# スタイルスコア計算
def calculate_style_score(rekognition_result, model_data)
  style_keywords = ['cartoon', 'drawing', 'illustration', 'art', 'creative', 'cute', 'happy', 'smile']
  
  matching_labels = rekognition_result[:labels].select { |l|
    style_keywords.any? { |keyword| l[:name].downcase.include?(keyword) }
  }
  
  # マッチするラベルの数と信頼度でスコア計算
  if matching_labels.any?
    base_score = 60
    bonus = matching_labels.size * 5
    confidence_bonus = matching_labels.map { |l| l[:confidence] }.max / 10
    
    [base_score + bonus + confidence_bonus, 100].min.round
  else
    55
  end
end

# スコアレンジ判定
def determine_score_range(score, model_data)
  ranges = model_data.dig('scoring', 'score_ranges') || {}
  
  case score
  when 85..100
    ranges['excellent'] || { 'label' => '素晴らしい！' }
  when 70..84
    ranges['good'] || { 'label' => '良い感じ！' }
  when 50..69
    ranges['fair'] || { 'label' => 'もう少し！' }
  else
    ranges['needs_improvement'] || { 'label' => '練習あるのみ！' }
  end
end

# アドバイス生成
def generate_advice(score_result)
  advice = []
  
  # 各カテゴリーのスコアに基づいてアドバイス
  if score_result[:details][:composition] < 70
    advice << "構図をもっと大胆に！キャラクターを中央に大きく描いてみましょう"
  end
  
  if score_result[:details][:colors] < 70
    advice << "もっとカラフルに！明るい色を使って楽しい雰囲気を出しましょう"
  end
  
  if score_result[:details][:style_features] < 70
    advice << "Orubyらしさを追加！笑顔やルビーモチーフを取り入れてみては？"
  end
  
  advice.empty? ? ["素晴らしい作品です！この調子で続けてください！"] : advice
end

# === 以下、前のコードと同じユーティリティ関数 ===

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
      'analyzed-with' => 'rekognition'
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

# ローカルテスト
if __FILE__ == $0
  puts "=== Rekognition統合版のローカルテスト ==="
  puts "⚠️  注意: ローカル環境ではRekognitionは使用できません"
  puts "代わりにモックデータを使用します"
  
  # テスト実装...
end

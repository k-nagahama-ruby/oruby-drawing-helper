# lambda/package.rb
# Lambda関数のデプロイパッケージを作成するスクリプト（改良版）

require 'fileutils'
require 'open3'

def package_lambda
  puts "📦 Lambda デプロイパッケージを作成します..."
  
  # 作業ディレクトリの準備
  work_dir = 'package_tmp'
  FileUtils.rm_rf(work_dir)
  FileUtils.mkdir_p(work_dir)
  
  begin
    # 1. 必要なファイルをコピー
    puts "📄 Lambdaコードをコピー中..."
    
    # メインのhandlerファイルを決定
    if File.exist?('handler_with_s3.rb')
      FileUtils.cp('handler_with_s3.rb', File.join(work_dir, 'handler.rb'))
      puts "  ✓ handler_with_s3.rb を handler.rb としてコピー"
    else
      FileUtils.cp('handler.rb', work_dir)
      puts "  ✓ handler.rb をコピー"
    end
    
    # GemfileとGemfile.lock をコピー
    FileUtils.cp('Gemfile', work_dir)
    FileUtils.cp('Gemfile.lock', work_dir) if File.exist?('Gemfile.lock')
    
    # 2. Gemをvendor/bundleにインストール
    puts "\n💎 Gemをインストール中..."
    Dir.chdir(work_dir) do
      # Bundlerの設定
      system('bundle config set --local path vendor/bundle')
      system('bundle config set --local without development test')
      
      # Gemのインストール
      success = system('bundle install')
      unless success
        raise "Gemのインストールに失敗しました"
      end
    end
    
    # 3. ZIPファイルを作成（複数の方法を試す）
    puts "\n🗜️  ZIPファイルを作成中..."
    
    # 絶対パスで指定
    zip_path = File.expand_path('../terraform/lambda_function.zip')
    FileUtils.rm_f(zip_path)
    
    # terraformディレクトリが存在するか確認
    terraform_dir = File.expand_path('../terraform')
    unless File.directory?(terraform_dir)
      puts "  📁 terraformディレクトリを作成します..."
      FileUtils.mkdir_p(terraform_dir)
    end
    
    success = false
    
    Dir.chdir(work_dir) do
      # 方法1: zipコマンドを使用（推奨）
      if system('which zip > /dev/null 2>&1')
        puts "  使用方法: zipコマンド"
        cmd = "zip -r #{zip_path} . -x '*.DS_Store' -x '__MACOSX/*'"
        stdout, stderr, status = Open3.capture3(cmd)
        
        if status.success?
          success = true
          puts "  ✓ ZIP作成成功（zipコマンド）"
        else
          puts "  ⚠️  zipコマンドでエラー: #{stderr}"
        end
      end
      
      # 方法2: Ruby標準ライブラリを使用（フォールバック）
      unless success
        puts "  使用方法: Ruby Zip gem"
        begin
          require 'zip'
          create_zip_with_ruby(zip_path, '.')
          success = true
          puts "  ✓ ZIP作成成功（Ruby gem）"
        rescue LoadError
          puts "  ⚠️  zip gemがインストールされていません"
          puts "  実行してください: gem install rubyzip"
        end
      end
    end
    
    unless success
      raise "ZIPファイルの作成に失敗しました。zip gemをインストールしてください: gem install rubyzip"
    end
    
    # 4. ファイルサイズを確認
    if File.exist?(zip_path)
      zip_size = File.size(zip_path) / 1024.0 / 1024.0
      puts "\n📊 パッケージ情報:"
      puts "  - ファイルパス: #{zip_path}"
      puts "  - ファイルサイズ: #{zip_size.round(2)} MB"
      
      if zip_size > 50
        puts "  ⚠️  警告: 50MBを超えています。Lambda直接アップロードの上限に注意"
      end
      
      puts "\n✅ パッケージ作成完了！"
    else
      raise "ZIPファイルが作成されていません"
    end
    
  rescue => e
    puts "\n❌ エラーが発生しました: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
    exit 1
  ensure
    # クリーンアップ
    FileUtils.rm_rf(work_dir)
  end
end

# Ruby gemを使ったZIP作成
def create_zip_with_ruby(zip_path, source_dir)
  require 'zip'
  
  Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
    Dir[File.join(source_dir, '**', '**')].each do |file|
      file_relative_path = file.sub("#{source_dir}/", '')
      next if file_relative_path.include?('.DS_Store') || file_relative_path.include?('__MACOSX')
      
      if File.directory?(file)
        zipfile.mkdir(file_relative_path) unless zipfile.find_entry(file_relative_path)
      else
        zipfile.add(file_relative_path, file)
      end
    end
  end
end

# スクリプトとして実行された場合
if __FILE__ == $0
  package_lambda
end

"use client";

import { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import axios from "axios";

// API エンドポイント（環境変数から取得）
const API_ENDPOINT =
  process.env.NEXT_PUBLIC_API_ENDPOINT || "YOUR_API_ENDPOINT_HERE";

interface AnalysisResult {
  score: number;
  ai_evaluation: string;
  ai_advice: string;
  improvement_tips: string[];
  rekognition_labels: Array<{
    name: string;
    confidence: number;
  }>;
}

export default function Home() {
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        setSelectedImage(e.target?.result as string);
        setResult(null);
        setError(null);
      };
      reader.readAsDataURL(file);
    }
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "image/*": [".jpeg", ".jpg", ".png", ".gif"],
    },
    maxFiles: 1,
  });

  const analyzeImage = async () => {
    if (!selectedImage) return;

    setIsAnalyzing(true);
    setError(null);

    try {
      // Base64データからプレフィックスを除去
      const base64Data = selectedImage.split(",")[1];

      const response = await axios.post(API_ENDPOINT, {
        image: base64Data,
      });

      setResult(response.data);
    } catch (err: any) {
      console.error("Analysis error:", err);
      setError("分析中にエラーが発生しました。もう一度お試しください。");
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-red-50 to-orange-50 p-8">
      <div className="max-w-4xl mx-auto">
        <header className="text-center mb-12">
          <h1 className="text-5xl font-bold text-red-600 mb-4">
            🎨 Oruby Drawing Helper
          </h1>
          <p className="text-xl text-gray-700">
            AIがあなたのOrubyの絵を分析してアドバイスします！
          </p>
        </header>

        {/* 画像アップロードエリア */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <div
            {...getRootProps()}
            className={`
              border-4 border-dashed rounded-xl p-12 text-center cursor-pointer
              transition-all duration-200
              ${
                isDragActive
                  ? "border-red-500 bg-red-50"
                  : "border-gray-300 hover:border-red-400 hover:bg-red-50"
              }
            `}
          >
            <input {...getInputProps()} />
            {selectedImage ? (
              <div className="space-y-4">
                <img
                  src={selectedImage}
                  alt="Selected"
                  className="max-w-md mx-auto rounded-lg shadow-lg"
                />
                <p className="text-gray-600">
                  別の画像を選択するにはクリックまたはドラッグ
                </p>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="text-6xl">📤</div>
                <p className="text-xl text-gray-600">
                  {isDragActive
                    ? "ここにドロップ！"
                    : "画像をドラッグ&ドロップ または クリックして選択"}
                </p>
              </div>
            )}
          </div>

          {selectedImage && !result && (
            <button
              onClick={analyzeImage}
              disabled={isAnalyzing}
              className={`
                mt-8 w-full py-4 rounded-lg font-bold text-xl text-white
                transition-all duration-200
                ${
                  isAnalyzing
                    ? "bg-gray-400 cursor-not-allowed"
                    : "bg-red-600 hover:bg-red-700 active:scale-95"
                }
              `}
            >
              {isAnalyzing ? (
                <span className="flex items-center justify-center">
                  <svg
                    className="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      className="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      strokeWidth="4"
                    ></circle>
                    <path
                      className="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    ></path>
                  </svg>
                  AIが分析中... (5-10秒かかります)
                </span>
              ) : (
                "🤖 AI分析を開始"
              )}
            </button>
          )}
        </div>

        {/* エラー表示 */}
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg mb-8">
            {error}
          </div>
        )}

        {/* 分析結果 */}
        {result && (
          <div className="space-y-8">
            {/* スコア */}
            <div className="bg-white rounded-2xl shadow-xl p-8">
              <h2 className="text-3xl font-bold text-center mb-6">
                総合スコア
              </h2>
              <div className="text-center">
                <div className="text-8xl font-bold text-red-600">
                  {result.score}
                </div>
                <div className="text-2xl text-gray-600 mt-2">/ 100点</div>
              </div>
              <p className="text-center text-lg text-gray-700 mt-6">
                {result.ai_evaluation}
              </p>
            </div>

            {/* AIアドバイス */}
            <div className="bg-white rounded-2xl shadow-xl p-8">
              <h2 className="text-2xl font-bold mb-4 flex items-center">
                💡 AIからのアドバイス
              </h2>
              <p className="text-lg text-gray-700 mb-6">{result.ai_advice}</p>

              <h3 className="text-xl font-semibold mb-3">改善のヒント：</h3>
              <ul className="space-y-2">
                {result.improvement_tips.map((tip, index) => (
                  <li key={index} className="flex items-start">
                    <span className="text-red-600 mr-2">✓</span>
                    <span className="text-gray-700">{tip}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* 検出された要素 */}
            <div className="bg-white rounded-2xl shadow-xl p-8">
              <h2 className="text-2xl font-bold mb-4">🏷️ 検出された要素</h2>
              <div className="flex flex-wrap gap-2">
                {result.rekognition_labels.map((label, index) => (
                  <span
                    key={index}
                    className="px-3 py-1 bg-red-100 text-red-700 rounded-full text-sm"
                  >
                    {label.name} ({label.confidence}%)
                  </span>
                ))}
              </div>
            </div>

            {/* もう一度ボタン */}
            <button
              onClick={() => {
                setSelectedImage(null);
                setResult(null);
                setError(null);
              }}
              className="w-full py-4 bg-gray-600 hover:bg-gray-700 text-white font-bold text-xl rounded-lg transition-all duration-200"
            >
              🎨 別の絵を分析する
            </button>
          </div>
        )}
      </div>
    </main>
  );
}

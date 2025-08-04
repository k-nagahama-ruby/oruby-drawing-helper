import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Oruby Drawing Helper - AIがあなたの絵を分析',
  description: 'Bedrockマルチエージェントを使用したOrubyの絵の分析・アドバイスアプリ',
  keywords: 'Oruby, Ruby, AI, 画像分析, Bedrock, AWS',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  )
}

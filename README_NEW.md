t# narou_analyzer

「小説家になろう」のランキングデータを取得し、AIで分析してDiscordに投稿するRubyアプリケーション。

## 機能

- なろうAPIから週間ランキングを取得
- Safari User-Agentを使用して小説本文を取得
- 短編・長編の選択が可能
- Cohere APIを使用してAI分析
- Discord Webhookで結果を投稿
- 包括的なエラーハンドリングで安定動作

## 環境設定

`.env`ファイルを作成し、以下の環境変数を設定してください：

```env
# Cohere API設定
COHERE_API_KEY=your_api_key_here
COHERE_API_ENDPOINT=https://api.cohere.com/v2/

# Discord Webhook URL
DISCORD_WEBHOOK_URL=your_discord_webhook_url_here

# 小説タイプ設定
# "t" = 短編, "re" = 長編(連載中), "r" = 長編(完結済み)
NOVEL_TYPE=re

# ランキング取得数
RANKING_SIZE=20
```

`.env.example`ファイルをコピーして使用できます。

## 使用方法

```bash
ruby bin/main.rb
```

## エラーハンドリング

このアプリケーションは以下のエラーに対して堅牢に動作します：

- ネットワークエラー・タイムアウト
- API呼び出しの失敗
- 個別小説の取得失敗（スキップして続行）
- Discord投稿の失敗（ログを記録して続行）
- JSONパースエラー
- ファイル保存エラー

エラーが発生しても、処理可能な部分は継続して実行されます。

## ファイル構成

- `bin/main.rb` - メインプログラム
- `lib/narou.rb` - なろうAPI/Webクライアント
- `lib/openai.rb` - AI APIクライアント
- `data/genre.rb` - ジャンル定義
- `data/system.txt` - AIシステムプロンプト
- `response/` - API応答の保存先

## 依存パッケージ

- httparty
- nokogiri
- dotenv
- json

```bash
bundle install
```

## 小説タイプについて

環境変数`NOVEL_TYPE`で取得する小説のタイプを指定できます：

- `t` - 短編小説
- `re` - 長編（連載中）
- `r` - 長編（完結済み）

デフォルトは`re`（長編・連載中）です。


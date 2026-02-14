# my-devcontainer

Node.js / Claude Code 開発用の Dev Container テンプレートです。

## 機能

### Dev Container 環境

VS Code Dev Containers 上で動作する開発環境を提供します。

- **ベースイメージ**: `mcr.microsoft.com/devcontainers/base:trixie` (Debian Trixie)
- **Node.js 24**: `ghcr.io/devcontainers/features/node:1` による導入
- **Claude Code**: `ghcr.io/anthropics/devcontainer-features/claude-code:1.0` による Anthropic 公式 CLI の統合
- **ポートフォワーディング**: ポート 3000 を自動転送

### カスタム Feature: node-modules-volume

`node_modules` を Docker の名前付きボリュームとしてマウントするカスタム Dev Container Feature です。

- コンテナごとに `node_modules-${devcontainerId}` という一意のボリュームを作成
- `${containerWorkspaceFolder}/node_modules` にマウント
- コンテナ作成後に `sudo chown` で適切な所有権を設定
- ホストとのバインドマウントを避けることで、`npm install` のパフォーマンスを向上

## 使い方

1. このリポジトリをクローンまたはテンプレートとして使用
2. VS Code で「Dev Containers: Reopen in Container」を実行
3. コンテナが起動すると Node.js 24 と Claude Code が利用可能

## ディレクトリ構成

```
.devcontainer/
├── devcontainer.json                          # Dev Container 設定
└── features/
    └── node-modules-volume/
        ├── devcontainer-feature.json          # カスタム Feature 定義
        └── install.sh                         # Feature インストールスクリプト
```

## 今後の予定

- **外部通信の制限**: コンテナ内部から意図しない外部通信が発生しないよう、ホワイトリスト方式でネットワークアクセスを制限する（`registry.npmjs.org`、`api.anthropic.com` 等の必要なドメインのみ許可）

## ライセンス

MIT
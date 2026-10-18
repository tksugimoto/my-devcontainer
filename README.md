# my-devcontainer

Node.js / Claude Code 開発用の Dev Container テンプレートです。

## 機能

### Dev Container 環境

VS Code Dev Containers 上で動作する開発環境を提供します。

- **ベースイメージ**: `mcr.microsoft.com/devcontainers/base:trixie` (Debian Trixie)
- **Node.js 24**: `ghcr.io/devcontainers/features/node:1` による導入
- **GitHub CLI**: `ghcr.io/devcontainers/features/github-cli:1` による `gh` コマンドの導入
- **Claude Code**: `ghcr.io/anthropics/devcontainer-features/claude-code:1.0` による Anthropic 公式 CLI の統合
- **ポートフォワーディング**: ポート 3000 を自動転送
- **タイムゾーン**: `containerEnv` で `TZ=Asia/Tokyo` を設定し、コンテナ内の時刻表示を統一

### カスタム Feature: claude-code-bell

Claude Code が入力を待っている時にターミナルベルで通知するカスタム Dev Container Feature です。

- Claude Code の `Stop` / `Notification` フックでターミナルベル (`\a`) を送出
- 許可プロンプトやサブエージェントの入力待ちでも通知
- バックグラウンドのサブエージェント実行中は抑制し、全て完了してから 1 回だけ鳴らす
  （`/simplify` のような並列実行で 5 回鳴るのを防ぐ）
- 60 秒アイドル通知は対象外
- VS Code のビジュアルベルとサウンドを自動で有効化
- ベル持続時間を 60 秒に設定し、通知を見逃しにくくする
- スクリプトは `/usr/local/share/claude-code-bell/` に置き、設定は managed settings の drop-in
  (`/etc/claude-code/managed-settings.d/claude-code-bell.json`) として入れる。
  利用者の `settings.json` は書き換えず、hooks は利用者のものと合算される

### カスタム Feature: claude-code-statusline

Claude Code のステータスラインに実行状況を表示するカスタム Dev Container Feature です。

- モデル名、git ブランチ、コンテキスト使用量、レートリミット使用量を 1 行で表示
- コンテキスト使用量は 10 段階のゲージ + パーセンテージ（`●●●●○○○○○○ 40%`）
- レートリミットは 5 時間枠と週次枠を、それぞれのリセット時刻付きで表示（`5h:23% (→02:20) 7d:61% (→07/31 02:20)`）
- レートリミットは Claude.ai サブスクリプション利用時のみ取得できるため、値が無い場合は該当区画ごと非表示
- スクリプトは `/usr/local/share/claude-code-statusline/` に置き、設定は managed settings の drop-in
  (`/etc/claude-code/managed-settings.d/claude-code-statusline.json`) として入れる。
  statusLine は managed が優先されるため、個人の設定では上書きできない

### カスタム Feature: claude-config-volume

Claude Code の設定ディレクトリを Docker の名前付きボリュームとして永続化するカスタム Dev Container Feature です。

- `CLAUDE_CONFIG_DIR=/home/vscode/.claude` を設定し、そこを `claude-config-${devcontainerId}` ボリュームにマウント
- 会話履歴 (`/resume`)・ログイン情報・memory・`.claude.json` 相当の設定が**リビルドしても消えない**
- ボリュームは devcontainer (フォルダ) ごとに分かれ、別フォルダ (worktree など) とは共有しない。
  複数のコンテナから同じ `.claude.json` を同時に書き換えないため。ログインはフォルダごとに 1 回ずつ要る
- ボリュームがイメージ側の `~/.claude` を隠すため、claude-code-bell / claude-code-statusline は
  `~/.claude` に何も置かず、`/usr/local/share` と managed settings の drop-in を使う

ログイン情報を含むので、完全に消すにはホスト側でボリュームを削除します。

```bash
docker volume ls --filter name=claude-config-
docker volume rm <上で表示されたボリューム名>
```

### カスタム Feature: gh-auth-volume

`gh` の認証情報 (`~/.config/gh`) を Docker の名前付きボリュームとして永続化するカスタム Dev Container Feature です。

- `my-devcontainer-gh-auth` ボリュームにマウントし、**リビルドしても `gh auth login` し直さなくてよい**
- ボリューム名は固定なので、同じホスト上の別フォルダ (worktree など) の devcontainer とも認証を共有する。
  **別プロジェクトで使うときは、ボリューム名をプロジェクト名に変える**
  (同じ名前のままだと、そのホストの全プロジェクトで同じトークンを共有する)。
  変え方は[別プロジェクトから Feature を使う](#別プロジェクトから-feature-を使う)を参照
- `postStartCommand` で起動のたびに `gh auth setup-git` を実行し、gh のトークンを git の credential helper にする。
  VS Code の credential helper が非対話で呼ばれてハングするのを避けるため
- ボリュームを作った直後の 1 回だけログインが必要。ログイン直後のコンテナでは `gh auth setup-git` も手で実行する

```bash
gh auth login
gh auth setup-git
```

トークンを含むコマンドは、Claude Code のプロンプト (`!` 付き) ではなく別のターミナルで実行してください
(`!` 経由だとトークンがエージェントの文脈に残ります)。
ボリュームはコンテナを削除しても残るので、トークンを完全に消すにはホスト側で削除します。

```bash
docker volume rm my-devcontainer-gh-auth
```

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

## 別プロジェクトから Feature を使う

このリポジトリを別プロジェクトの `.devcontainer/my-devcontainer` に git submodule として取り込むと、
カスタム Feature をローカルパスで参照できます (ローカルの Feature は `.devcontainer` の下に置く必要があるため)。

```bash
git submodule add https://github.com/tksugimoto/my-devcontainer.git .devcontainer/my-devcontainer
```

### ボリューム名を上書きする

Feature が宣言するボリューム名は、利用側の `devcontainer.json` の `mounts` で同じ `target` を指定すれば上書きできます。
`mounts` は `target` ごとに後勝ちで、`devcontainer.json` は Feature より後に適用されるためです。
Feature の `postCreateCommand` / `postStartCommand` はそのまま使われるので、Feature をコピーする必要はありません。

```jsonc
{
	"features": {
		"./my-devcontainer/.devcontainer/features/claude-config-volume": {},
		"./my-devcontainer/.devcontainer/features/gh-auth-volume": {}
	},
	// Override the volume names the features declare.
	"mounts": [
		{
			"source": "<project>-claude-config-${devcontainerId}",
			"target": "/home/vscode/.claude",
			"type": "volume"
		},
		{
			"source": "<project>-gh-auth",
			"target": "/home/vscode/.config/gh",
			"type": "volume"
		}
	]
}
```

上書きできているかは、マージ後の設定で確かめられます (各 `target` のマウントが 1 つずつになっていればよい)。

```bash
npx @devcontainers/cli read-configuration --workspace-folder . --include-merged-configuration
```

## ディレクトリ構成

```
.devcontainer/
├── devcontainer.json                          # Dev Container 設定
├── devcontainer-lock.json                     # Feature のバージョン固定
└── features/
    ├── claude-code-bell/
    │   ├── devcontainer-feature.json          # Feature 定義
    │   ├── claude-settings.json               # Claude Code のフック設定
    │   ├── bell.sh                            # ターミナルベル送出スクリプト
    │   └── install.sh                         # Feature インストールスクリプト
    ├── claude-code-statusline/
    │   ├── devcontainer-feature.json          # Feature 定義
    │   ├── claude-settings.json               # Claude Code の statusLine 設定
    │   ├── statusline.sh                      # ステータスライン生成スクリプト
    │   └── install.sh                         # Feature インストールスクリプト
    ├── claude-config-volume/
    │   ├── devcontainer-feature.json          # Feature 定義 (ボリュームマウント)
    │   └── install.sh                         # Feature インストールスクリプト
    ├── gh-auth-volume/
    │   ├── devcontainer-feature.json          # Feature 定義 (ボリュームマウント)
    │   └── install.sh                         # Feature インストールスクリプト
    └── node-modules-volume/
        ├── devcontainer-feature.json          # Feature 定義
        └── install.sh                         # Feature インストールスクリプト
```

## 今後の予定

- **外部通信の制限**: コンテナ内部から意図しない外部通信が発生しないよう、ホワイトリスト方式でネットワークアクセスを制限する（`registry.npmjs.org`、`api.anthropic.com` 等の必要なドメインのみ許可）

## ライセンス

MIT

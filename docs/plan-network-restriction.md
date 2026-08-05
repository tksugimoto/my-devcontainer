# 外部通信の制限 - 実装プラン

## Context

README の「今後の予定」に記載されている機能。コンテナ内部から意図しない外部通信が発生しないよう、ホワイトリスト方式でネットワークアクセスを制限する。

## アプローチ: iptables + ipset によるカスタム Feature

**選定理由**: カーネルレベルのパケットフィルタリングのため、ユーザースペースのプロセスからバイパス不可能。Squid プロキシ方式は `HTTP_PROXY` を尊重しないツールにバイパスされる。iptables string マッチは暗号化通信で不安定。

## 作成するファイル

```
.devcontainer/features/network-restriction/
├── devcontainer-feature.json   # Feature 定義 (capAdd: NET_ADMIN, postStartCommand)
├── install.sh                  # iptables, ipset, dnsutils のインストール + ファイル配置
├── network-restriction.sh      # ドメイン解決 → ipset 登録 → iptables ルール適用
└── whitelist.conf              # ホワイトリスト (1行1ドメイン)
```

## 変更するファイル

- `.devcontainer/devcontainer.json` - `"./features/network-restriction": {}` を追加

## 実装詳細

### 1. `devcontainer-feature.json`

- `capAdd: ["NET_ADMIN"]` で iptables 操作権限を付与
- `postStartCommand` で毎回コンテナ起動時にルール適用（iptables ルールはコンテナ停止時に消えるため）

```json
{
    "id": "network-restriction",
    "version": "1.0.0",
    "name": "Network Restriction",
    "description": "Restricts outbound network access to whitelisted domains only",
    "capAdd": ["NET_ADMIN"],
    "postStartCommand": "sudo /usr/local/bin/network-restriction.sh /usr/local/etc/network-restriction/whitelist.conf"
}
```

### 2. `install.sh`

- `iptables`, `ipset`, `dnsutils` をインストール（ポータビリティのため）
- `network-restriction.sh` を `/usr/local/bin/` にコピー
- `whitelist.conf` を `/usr/local/etc/network-restriction/` にコピー

```bash
#!/bin/bash
set -e

apt-get update -y
apt-get install -y --no-install-recommends iptables ipset dnsutils
apt-get clean -y

cp network-restriction.sh /usr/local/bin/network-restriction.sh
chmod 755 /usr/local/bin/network-restriction.sh

mkdir -p /usr/local/etc/network-restriction
cp whitelist.conf /usr/local/etc/network-restriction/whitelist.conf
chmod 644 /usr/local/etc/network-restriction/whitelist.conf

echo "Network restriction feature installed."
```

### 3. `network-restriction.sh` (コアロジック)

1. `whitelist.conf` からドメイン一覧を読み取り
2. 各ドメインを `dig +short A` で IP 解決
3. 解決した IP を ipset (`hash:ip`) に登録
4. iptables OUTPUT チェインに以下のルールを適用:

| 順序 | ルール | 理由 |
|------|--------|------|
| 1 | `ACCEPT -o lo` | ループバック（localhost 通信） |
| 2 | `ACCEPT -d 172.16.0.0/12` | Docker ネットワーク（ホスト通信・ポートフォワーディング） |
| 3 | `ACCEPT -p udp/tcp --dport 53 -d <DNS>` | DNS 解決（`/etc/resolv.conf` のネームサーバーのみ） |
| 4 | `ACCEPT -m state ESTABLISHED,RELATED` | 確立済み接続の応答パケット |
| 5 | `ACCEPT -m set --match-set whitelist_v4 dst` | ipset に含まれる宛先 IP |
| 6 | `DROP` (デフォルトポリシー) | 上記以外すべて拒否 |

**設計ポイント**:
- ipset を使用し、1ドメインが複数 IP に解決されても単一の iptables ルールで対応（O(1) ハッシュルックアップ）
- `iptables -F OUTPUT` で冪等性を確保（再実行しても安全）
- DNS 解決失敗時はそのドメインをスキップして継続（fail-closed: 許可リストが小さくなる方向に倒す）

### 4. `whitelist.conf` (デフォルト)

```
# npm
registry.npmjs.org

# Anthropic API
api.anthropic.com

# GitHub
github.com
api.github.com

# Dev Container features / extensions
ghcr.io
containers.dev

# Claude Code telemetry/error tracking
api.statsig.com
featureassets.org
o4509008331808768.ingest.us.sentry.io
```

### 5. `devcontainer.json` 変更

`features` に `"./features/network-restriction": {}` を追加するのみ。`capAdd` は Feature 側で宣言するため `devcontainer.json` への追加は不要。

## 検証方法

```bash
# 許可されたドメインへの通信 → 成功すること
curl -I https://registry.npmjs.org
curl -I https://api.anthropic.com
npm view express version

# 許可されていないドメインへの通信 → タイムアウトすること
curl --connect-timeout 5 https://example.com

# ルール確認
sudo iptables -L OUTPUT -n -v
sudo ipset list whitelist_v4
```

## 既知の制限事項

- IP アドレス変更時は `sudo /usr/local/bin/network-restriction.sh` で再適用が必要
- IPv6 は対象外（Docker bridge が IPv4 のみのため v1 では省略）
- ワイルドカードドメイン非対応（サブドメインは個別に記載）

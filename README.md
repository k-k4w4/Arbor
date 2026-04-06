# Arbor

Gitの履歴を眺めるためだけの macOS アプリ。commit も push も一切できない、完全読み取り専用。既存のGUIクライアントは操作機能が多すぎて、ログを読みたいだけのときに邪魔に感じたので作った。

## 機能

- Unified / Split diff（行番号付き）
- コミットグラフ描画
- `git log --grep` ベースの全文・作者検索
- ブランチの ahead/behind をサイドバーに常時表示
- 200件ずつ遅延ロードするのでリポジトリが大きくても重くない

macOS 14.0+。libgit2 等の依存なし、shell で git を直叩きしてる。

## インストール

```
git clone https://github.com/k-k4w4/Arbor.git
cd Arbor
xcodegen generate
xcodebuild -scheme Arbor -configuration Release build
```

## 使い方

1. 「リポジトリを追加」でフォルダを選ぶ（ドロップでも可）
2. サイドバーでブランチ・タグ・スタッシュを切り替え
3. コミットを選んで diff を確認
4. ⌘R で更新

## 開発

```bash
xcodegen generate  # project.yml 変更後に必要
xcodebuild -scheme Arbor -configuration Debug build
xcodebuild -scheme Arbor -destination 'platform=macOS' test
```

## ライセンス

MIT

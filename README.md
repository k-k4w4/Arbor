# Arbor

Gitの履歴を眺めるためだけの macOS アプリ。commit も push も一切できない、完全読み取り専用。既存のGUIクライアントは操作機能が多すぎて、ログを読みたいだけのときに邪魔に感じたので作った。

## 機能

- **Diff 表示**: Unified / Split diff（行番号付き）、構文ハイライト対応（50+ 言語）
- **コミットグラフ**: レーン幅カスタマイズ可
- **検索**: `git log --grep` ベースの全文・作者検索、ファイルパス検索（グロブ対応）
- **ブランチ比較**: 2つの ref を選んで差分を表示
- **サイドバー**: ブランチ ahead/behind 表示、リモートグループ折りたたみ、セクション折りたたみ、ドラッグ並べ替え
- **作業中の変更**: 未コミットの staged/unstaged 変更を表示
- **ファイルツリー**: 変更ファイルをツリー/フラット切り替え
- **バイナリプレビュー**: 画像インライン表示、非画像は Quick Look / 保存
- **Gravatar**: コミット作者のアバター表示（ON/OFF 可）
- **ナビゲーション**: SHA ジャンプ、親コミットリンク、⌘1/2/3 ペイン移動、前回の状態復元
- **Diff 設定**: フォントサイズ、タブ幅、行間のカスタマイズ
- **200件ずつ遅延ロード**: リポジトリが大きくても重くない

macOS 14.0+。Git 操作は shell で直接呼び出し。構文ハイライトに [HighlightSwift](https://github.com/appstefan/HighlightSwift) を使用。

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
4. ツールバーの比較ボタンでブランチ間比較
5. ⌘R で更新

## 開発

```bash
xcodegen generate  # project.yml 変更後に必要
xcodebuild -scheme Arbor -configuration Debug build
xcodebuild -scheme Arbor -destination 'platform=macOS' test
```

## ライセンス

MIT

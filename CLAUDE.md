# GitViewer

macOSネイティブの閲覧専用Gitビューアー。書き込み操作は一切なし。

## 技術スタック

- Swift 5.9 / SwiftUI / macOS 14.0+
- `@Observable` マクロ（strict concurrency は未適用）
- Git操作: `Process` クラスで shell 呼び出し（依存ゼロ、libgit2 不使用）
- サンドボックス: **無効**（entitlements で `app-sandbox = false`）
- ビルド: `xcodebuild -scheme GitViewer -configuration Debug build`

## アーキテクチャ

MVVM。ViewModel 間の通信は必ず `AppViewModel` 経由。子 VM 同士は直接参照しない。

```
AppViewModel (@Observable, @MainActor)
  ├── SidebarViewModel    ← ブランチ/タグ一覧
  ├── CommitListViewModel ← コミット一覧 + ページング
  └── DetailViewModel     ← コミット詳細 + diff
```

`AppViewModel` は `Environment` で全 View に配布。`GitService` も `AppViewModel` 経由で渡す。

## ディレクトリ構成

```
GitViewer/
├── App/           GitViewerApp.swift, AppCommands.swift
├── Models/        Repository, Commit, GitRef(Branch.swift), CommitGraph, DiffFile, DiffHunk
├── Services/      GitService(actor), GitLogParser, GitDiffParser, GraphLayoutEngine, RepositoryStore
├── ViewModels/    AppViewModel, SidebarViewModel, CommitListViewModel, DetailViewModel
├── Views/
│   ├── Root/      RootView(NavigationSplitView 3ペイン), WelcomeView
│   ├── Sidebar/   SidebarView, RepositoryListSection, BranchListSection, etc.
│   ├── CommitList/ CommitListView, CommitRow, CommitGraphView, RefBadge
│   ├── Detail/    DetailView, CommitInfoHeader, ChangedFilesList, UnifiedDiffView, etc.
│   └── Shared/    EmptyStateView, LoadingView
├── Extensions/    Color+GitViewer.swift, Date+RelativeFormat.swift, String+SHA.swift
└── Resources/     Assets.xcassets, GitViewer.entitlements
```

## 主要クラス・設計メモ

### GitService (actor)
- `run(_ arguments: [String]) async throws -> String` がすべての git コマンドの基盤
- stdout/stderr を並行読み込み（パイプバッファのデッドロック対策）
- キャンセレーション対応
- エラー型: `GitError.notARepository` / `.commandFailed(stderr)` / `.parseError(msg)`

### ページネーション
- `CommitListViewModel.pageSize = 200`
- `fetchOffset` をまたいだグラフ状態を `graphActiveLanes` で保持（`GraphLayoutEngine.compute` に渡す）
- リスト末尾 `.onAppear` でトリガー

### コミットグラフ
- `GraphLayoutEngine.compute(commits:activeLanes:)` がステートフルなレーン割り当て
- `activeLanes: [String?]`（インデックス=レーン番号、値=追いかけている親SHA）
- 各 `CommitRow` 内の `CommitGraphView` が `Canvas` で描画
- `rowHeight=28pt`, `laneWidth=14pt`, ノード半径`4pt`

### Diff 表示
- `fetchDiff(commit:)` → ファイル一覧 (`--name-status`)
- `fetchDiffContent(commit:file:)` → unified diff (`git show <sha> -- <file>`)
- `GitDiffParser.parseDiffContent` が DiffHunk/DiffLine に変換
- `UnifiedDiffView` で `LazyVStack` + 行番号/prefix/背景色

### ⌘R リフレッシュ
- `AppViewModel.refresh()` → commitList の `loadInitial` + sidebar の `load` を並行実行
- `AppCommands` から `@FocusedValue(\.appViewModel)` 経由で呼び出し
- `GitViewerApp` の root view に `.focusedValue(\.appViewModel, appViewModel)` が必要

## カラーシステム (`Color+GitViewer.swift`)

| 用途 | 色名 |
|------|------|
| ローカルブランチ badge | `gitViewerBranch` (accentColor) |
| タグ badge | `gitViewerTag` (orange) |
| diff 追加行背景 | `diffAdded` |
| diff 削除行背景 | `diffDeleted` |
| hunk ヘッダ背景 | `diffHunk` |
| グラフノード | `Color.graphColor(forLane:)` (10色パレット) |

## 実装済み機能

### v1（Phase 1〜6）
- リポジトリ追加（ドロップ/ダイアログ）
- サイドバー: ブランチ/リモート/タグ/スタッシュ一覧
- コミットリスト: グラフ付き、ページネーション（200件/page）、検索、↑↓ナビ
- コミット詳細: ファイル一覧 + unified diff
- ツールバー: ブランチ名ラベル + ⌘R リフレッシュ
- コンテキストメニュー: SHA コピー、Finder で表示
- 起動時に最初のリポジトリを自動選択

### v2（Phase 7〜）
- **Phase 7 完了**: リポジトリ管理改善
  - サイドバー内「リポジトリを追加」行（フォルダ選択）
  - リポジトリ行の右クリック削除
  - パス不在時の警告アイコン表示（`RepositoryCell`）
- **Phase 8 完了**: Diff表示改善
  - `ChangedFilesList` の高さ固定（160pt）廃止 → `VSplitView` でリサイズ可能に
  - diff 行を常時折り返し表示（`wrapLines` 固定、トグルなし）

## テスト

`GitViewerTests/` に 81 件のユニットテスト（2026-04-01 時点）。
対象: `GitLogParser`, `GitDiffParser`, `GraphLayoutEngine`, `Date+RelativeFormat`, `String+SHA`

実行: `xcodebuild -scheme GitViewer -destination 'platform=macOS' test`

## 将来拡張（ロードマップ）

詳細は memory の `project_roadmap.md` を参照。概要：
- Phase 8.5: UI修正（ウィンドウ再オープン・diff枠サイズ固定）【High】
- Phase 9: 検索改善（全履歴 grep・日時切り替え）【High】
- Phase 10: 情報表示充実（ahead/behind・committer表示）【Medium】
- Phase 11: Preferences 画面【Medium】
- Phase 12: サイドバーブランチ/タグページング【Medium】
- Phase 13: ローカル差分（未コミット変更）表示【Medium】
- Phase 14: 構文ハイライト・Gravatar・Split diff・ファイルツリー・Quick Look【Low】
- Phase 15: ブランチ間比較・マルチウィンドウ【Low】
- Phase 16: セクション省略/全表示トグル【Low】

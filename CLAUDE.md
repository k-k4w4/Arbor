# Arbor

macOSネイティブの閲覧専用Gitビューアー。書き込み操作は一切なし。

## 技術スタック

- Swift 5.9 / SwiftUI / macOS 14.0+
- `@Observable` マクロ（strict concurrency は未適用）
- Git操作: `Process` クラスで shell 呼び出し（libgit2 不使用）
- 構文ハイライト: [HighlightSwift](https://github.com/appstefan/HighlightSwift) v1.1（highlight.js + JavaScriptCore）
- サンドボックス: **無効**（entitlements で `app-sandbox = false`）
- ビルド: `xcodebuild -scheme Arbor -configuration Debug build`

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
Arbor/
├── App/           ArborApp.swift, AppCommands.swift
├── Models/        Repository, Commit, GitRef(Branch.swift), CommitGraph, DiffFile, DiffHunk
├── Services/      GitService(actor), GitLogParser, GitDiffParser, GraphLayoutEngine, RepositoryStore
├── ViewModels/    AppViewModel, SidebarViewModel, CommitListViewModel, DetailViewModel, CompareViewModel
├── Views/
│   ├── Root/      RootView(NavigationSplitView 3ペイン), WelcomeView
│   ├── Sidebar/   SidebarView, RepositoryListSection, BranchListSection, etc.
│   ├── CommitList/ CommitListView, CommitRow, CommitGraphView, RefBadge
│   ├── Detail/    DetailView, CompareView, CommitInfoHeader, ChangedFilesList, UnifiedDiffView, etc.
│   └── Shared/    EmptyStateView, LoadingView
├── Extensions/    Color+Arbor.swift, Date+RelativeFormat.swift, String+SHA.swift
└── Resources/     Assets.xcassets, Arbor.entitlements
```

## 主要クラス・設計メモ

### GitService (actor)
- `run(_ arguments: [String]) async throws -> String` がすべての git コマンドの基盤
- stdout/stderr を並行読み込み（パイプバッファのデッドロック対策）
- `process.environment` に `LC_ALL=C`, `GIT_TERMINAL_PROMPT=0` を設定（ローカライズ対策）
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
- バイナリ/大容量（5MB超）は `DetailViewModel.diffInfoMessage` でフォールバック表示

### ログフォーマット
`git log` の `--format` フィールド（NUL区切り、RS区切り）:
`0:SHA 1:parents 2:authorName 3:authorEmail 4:authorDate 5:committerName 6:committerEmail 7:committerDate 8:subject 9:body 10:decoration`

### ahead/behind
- `GitRef` に `ahead: Int`, `behind: Int` フィールドあり
- `listBranches()` で `%(upstream:track)` をパースして設定
- `BranchCell` でローカルブランチのみ `↑N ↓M` バッジ表示

### ウィンドウタイトル
- `AppViewModel.windowTitle` → `"リポジトリ名 — ブランチ名"` (ref.gitRef 使用)
- `RootView` で `.navigationTitle(appViewModel.windowTitle)` を適用

### ⌘R リフレッシュ
- `AppViewModel.refresh()` → commitList の `loadInitial` + sidebar の `load` を並行実行
- `AppCommands` から `@FocusedValue(\.appViewModel)` 経由で呼び出し
- `ArborApp` の root view に `.focusedValue(\.appViewModel, appViewModel)` が必要

### サイドバークリック判定
- `List(selection:)` を使わず、`listRowInsets(EdgeInsets())` + セル内パディング方式
- `BranchListSection` / `RepositoryListSection` で `EdgeInsets(top:6, leading:10, bottom:6, trailing:10)` をセル内側に付与し、行インセットをゼロに
- `contentShape(Rectangle())` + `onTapGesture` がセル全体（`listRowBackground` と同領域）をカバー
- リポジトリとブランチは独立した `listRowBackground` でそれぞれハイライト（同時選択可能）

## カラーシステム (`Color+Arbor.swift`)

| 用途 | 色名 |
|------|------|
| ローカルブランチ badge | `arborBranch` (accentColor) |
| タグ badge | `arborTag` (orange) |
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
- **Phase 8.5 完了**: UI修正
  - ウィンドウ再オープン（`applicationShouldHandleReopen`）
  - diff枠サイズ固定（`isLoadingDiff` 中も `minHeight` 維持）
- **Phase 9 完了**: 検索改善
  - `git log --grep` による全履歴検索（300msデバウンス）
  - `--author` 並行検索・OR結合
  - 絶対/相対日時トグル（`AppViewModel.showAbsoluteDates`、時計/カレンダーアイコン）
  - コミットbody展開（CommitRow 内「もっと見る」ボタン）
- **Phase 10 完了**: 情報表示充実
  - ブランチ ahead/behind カウント表示（`BranchCell` に `↑N ↓M` バッジ）
  - committer 表示（author と name/email が異なる場合、`CommitInfoHeader` に追加）
  - ウィンドウタイトル「リポジトリ名 — ブランチ名」反映
  - バイナリ/大容量ファイルのフォールバック表示
  - `LC_ALL=C` で git 出力のローカライズ問題を防止
- **サイドバークリック判定修正**: `listRowInsets(EdgeInsets())` + 内側パディング方式で全幅タップ対応
- **Phase 35 完了**: ファイルパスをコピー
  - ChangedFilesList / FileTreeView のコンテキストメニューに「パスをコピー」追加
- **Phase 36 完了**: Gravatar ON/OFF
  - `AppSettings.showGravatar` トグル（Preferences「一般」セクション）
  - OFF時は CommitInfoHeader でアバター非表示
- **Phase 23 完了**: 構文ハイライト
  - HighlightSwift（highlight.js + JavaScriptCore）による構文ハイライト
  - 50+ 言語対応、ファイル拡張子から言語自動検出
  - `SyntaxHighlightService` actor（LRUキャッシュ2000行）
  - `HighlightedText` ビューで非同期ハイライト（プレーン表示→カラー表示）
  - ダーク/ライトモード自動対応
  - UnifiedDiffView / SplitDiffView 両方に適用
- **Phase 21 完了**: ブランチ間比較
  - ツールバーの比較ボタンで比較モードに切り替え
  - 2つの ref（ブランチ/タグ）をピッカーで選択、入れ替えボタン付き
  - `git diff base...target --name-status -z` でファイル一覧、`--stat` で変更統計
  - ファイル選択で unified/split diff 表示（既存コンポーネント再利用）
  - CompareViewModel + CompareView 新設、AppViewModel に `isCompareMode` 追加
  - ⌘R リフレッシュが比較モードにも対応
- **Phase 39 完了**: 変更ファイルパス検索
  - 検索バーに「メッセージ」/「パス」スコープ切り替え追加（`.searchScopes`）
  - パスモード時は `git log -- <path>` で検索（グロブパターン対応、例: `*.swift`）
  - `CommitListViewModel.searchMode` で検索モードを管理
  - リポジトリ/ブランチ切り替え時にモードをリセット
- **Phase 37 完了**: diff 表示設定
  - `AppSettings.diffTabWidth`（1〜16、デフォルト4）— diff 表示時にタブをスペースに展開
  - `AppSettings.diffFontSize`（8〜24pt、デフォルト11）— UnifiedDiffView / SplitDiffView のフォントサイズ
  - `AppSettings.diffLineSpacing`（0〜8pt、デフォルト1）— diff 行の縦パディング
  - Preferences「Diff」セクション新設
- **Phase 38 完了**: グラフ幅・Git パス指定
  - `AppSettings.graphLaneWidth`（6〜40pt、デフォルト14）→ CommitGraphView に反映
  - `AppSettings.customGitPath`（空=自動検出）→ GitService 生成時に使用
  - Preferences「高度な設定」セクション新設
  - `AppViewModel` が `init(settings:)` で AppSettings を受け取る設計に変更

## テスト

`ArborTests/` に 99 件のユニットテスト（2026-04-09 時点）。
対象: `GitLogParser`, `GitDiffParser`, `GraphLayoutEngine`, `Date+RelativeFormat`, `String+SHA`

実行: `xcodebuild -scheme Arbor -destination 'platform=macOS' test`

## 将来拡張（ロードマップ）

詳細は memory の `project_roadmap.md` を参照。概要：
- Phase 12: サイドバーブランチ/タグページング【Medium ✅】
- Phase 37: diff 表示設定（タブ幅・フォントサイズ・行間）【Medium ✅】
- Phase 39: 変更ファイルパス検索【Medium ✅】
- Phase 21: ブランチ間比較【Large ✅】
- Phase 23: 構文ハイライト【Large ✅】

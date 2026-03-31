# GitViewer — UI デザイン仕様書

## 概要

macOS ネイティブの「閲覧専用」Git ビューアー。SwiftUI + AppKit Bridge で実装する。SourceTree の閲覧機能を参考に、書き込み操作をすべて排除してシンプルさと情報密度を両立させる。

---

## 1. レイアウト構成

### 1-1. ウィンドウ全体

```
┌─────────────────────────────────────────────────────────────────┐
│  Toolbar (NSToolbar / unified style)                            │
├──────────────┬──────────────────────────┬───────────────────────┤
│              │                          │                       │
│  Left Panel  │   Center Panel           │   Right Panel         │
│  (Sidebar)   │   (Commit List)          │   (Detail)            │
│              │                          │                       │
│  240 pt      │   flexible               │   360 pt              │
│  (min 180)   │   (min 320)              │   (min 280)           │
│              │                          │                       │
└──────────────┴──────────────────────────┴───────────────────────┘
```

- **NSSplitView** で 3 ペイン分割。各ペインは drag でリサイズ可能
- ウィンドウ最小サイズ: 960 × 600 pt
- 推奨初期サイズ: 1280 × 800 pt
- タブ対応（複数リポジトリを同一ウィンドウでタブ切り替え）

### 1-2. Toolbar

```
[←][→]  [Branch Selector ▾]          [Search ⌘F]  [⚙]
```

| 要素 | 型 | 説明 |
|---|---|---|
| Back / Forward | NSToolbarItem (button) | コミット選択の履歴移動 |
| Branch Selector | NSPopUpButton | 現在 checkout 中のブランチ表示（ read-only ラベル） |
| Search | NSSearchField | コミットメッセージ・著者・SHA でフィルタ |
| Settings | NSToolbarItem (button) | アプリ設定シート |

---

## 2. Left Panel — サイドバー

### 2-1. 構造

```
REPOSITORIES
  ├─ my-project          ← 現在開いているリポジトリ（アクティブ）
  └─ another-repo

BRANCHES  (my-project)
  ├─ LOCAL
  │   ├─ ● main          ← HEAD（チェックマーク付き）
  │   ├─   develop
  │   └─   feature/foo
  ├─ REMOTE
  │   ├─   origin/main
  │   └─   origin/develop
  ├─ TAGS
  │   └─   v1.0.0
  └─ STASHES
      └─   On main: WIP
```

### 2-2. コンポーネント

**リポジトリセル**
- アイコン（SF Symbol: `folder.fill.badge.gearshape`）
- リポジトリ名（.body weight: semibold）
- 未読 badge（アンフェッチのリモート変更数 — 将来拡張）

**セクションヘッダー**
- 大文字テキスト（.caption2、letter-spacing 0.06em）
- Disclosure triangle で折りたたみ可能

**ブランチセル**
- インデント 8 pt（リモートはさらに +8 pt）
- HEAD ブランチ: `.checkmark` SF Symbol + font weight semibold
- ブランチ名を選択するとコミットリストをそのブランチ先頭にジャンプ

### 2-3. インタラクション

| アクション | 結果 |
|---|---|
| ブランチ選択 | コミットリストをそのブランチの先頭コミットにスクロール＋ハイライト |
| タグ選択 | 対応コミットにジャンプ |
| リポジトリダブルクリック | Finder でパスを開く |
| ドラッグ＆ドロップ（.git フォルダ or ディレクトリ） | リポジトリを追加 |

---

## 3. Center Panel — コミットリスト

### 3-1. 構造

```
┌─────────────────────────────────────────────────────┐
│  Graph  │  Message             │ Author  │ Date      │
├─────────┼──────────────────────┼─────────┼───────────┤
│  ─●─    │ ● main  Merge feat.. │ Alice   │ 2 hrs ago │
│   │     │   fix: null check    │ Bob     │ yesterday │
│  ─●─    │ ● origin/develop     │         │           │
│   │\    │   feat: new modal    │ Charlie │ Mar 28    │
│   │ ●   │   chore: deps update │ Alice   │ Mar 27    │
└─────────┴──────────────────────┴─────────┴───────────┘
```

### 3-2. コミット行セル

```
[Graph 56pt] [Refs + Message  flexible] [Author 120pt] [Date 80pt]
```

**グラフカラム**
- グラフ描画は `Canvas` (SwiftUI) または `CALayer` で実装
- ブランチごとに一意の色を割り当て（後述のカラーパレット参照）
- マージコミットは複数の親線を描画
- 現在選択行はハイライト背景（`List` selection style）

**メッセージカラム**
- ブランチ Ref badge: `Capsule` 背景 + ブランチ名（.caption weight: medium）
  - HEAD: `accentColor` 塗り
  - リモート: `gray` 塗り
  - タグ: `orange` 塗り
- コミットメッセージ 1 行目のみ表示（truncated）
- SHA（短縮 7 桁）を右端に `monospaced .caption` で表示

**Author カラム**
- アバター画像（Gravatar 取得、失敗時は initials のプレースホルダー） 16×16 pt
- 表示名テキスト

**Date カラム**
- 直近 7 日: 相対表示（"2 hrs ago"）
- それ以前: "Mar 28" 形式

### 3-3. インタラクション

| アクション | 結果 |
|---|---|
| 行クリック | 右パネルにコミット詳細を表示 |
| 行ダブルクリック | コミット詳細をシートまたは新規ウィンドウで展開（設定で切り替え） |
| 右クリック | コンテキストメニュー（SHA コピー、Finder で表示、ブラウザで開く） |
| ⌘クリック | 複数選択（diff 比較モードへ） |
| スペースキー | Quick Look でコミット差分をプレビュー |
| ⌘F | Toolbar の Search にフォーカス |

### 3-4. フィルタリング

Search Field に入力すると以下をリアルタイムにフィルタ：
- コミットメッセージ（部分一致）
- 著者名・メールアドレス
- SHA（前方一致）
- 変更ファイルパス（`--all` 検索オプション ON 時）

---

## 4. Right Panel — 詳細ビュー

右パネルは内部的に **縦分割の NSSplitView**（上: ファイルリスト / 下: diff）で構成する。

```
┌───────────────────────────────────────────┐
│  Commit Info Header                       │
│  abc1234  "feat: add login"               │
│  Alice <alice@example.com>  Mar 28, 2025  │
│  Parent: def5678                          │
├───────────────────────────────────────────┤
│  CHANGED FILES (3)         [Tree | List ⊞]│
│  ├─ M  src/auth/login.swift               │
│  ├─ A  src/auth/models.swift              │
│  └─ D  src/old/legacy.swift               │
├───────────────────────────────────────────┤
│  DIFF  — src/auth/login.swift             │
│  [Unified | Split ⊞]      [⌥ Wrap lines] │
│                                           │
│   @@ -12,7 +12,9 @@                       │
│ - let old = ...                           │
│ + let new = ...                           │
│ + let added = ...                         │
│   let unchanged = ...                     │
└───────────────────────────────────────────┘
```

### 4-1. Commit Info Header

| フィールド | 表示形式 |
|---|---|
| SHA | `monospaced .headline`、クリックでコピー |
| メッセージ | `.title3 semibold`、折り返しあり |
| 著者 | アバター 20pt + 名前 + メール |
| 日時 | 絶対日時（ツールチップで相対時間） |
| 親コミット | 短縮 SHA のリンクボタン（クリックで中央ペインにジャンプ） |

### 4-2. Changed Files リスト

**ファイルステータスバッジ**

| 記号 | 色 | 意味 |
|---|---|---|
| M | blue | Modified |
| A | green | Added |
| D | red | Deleted |
| R | orange | Renamed |
| C | teal | Copied |

- **Tree / List 切り替えトグル**: ディレクトリツリー表示 ↔ フラットリスト
- ファイル選択で下部 diff ビューを更新
- ファイル右クリック: 「Finder で表示」「パスをコピー」

### 4-3. Diff ビュー

**表示モード**
- **Unified**: 1 カラムで追加/削除を `+/-` で表示（デフォルト）
- **Split**: 2 カラムで左旧/右新を並列表示

**行スタイル**

| 行種別 | 背景色 (Light) | 背景色 (Dark) |
|---|---|---|
| 追加行 `+` | `#e6ffed` | `#1a3a1a` |
| 削除行 `-` | `#ffeef0` | `#3a1a1a` |
| ヒートヘッダ `@@` | `#f1f8ff` | `#1a2a3a` |
| コンテキスト行 | 標準背景 | 標準背景 |

- フォント: `NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)`
- 行番号表示（旧/新それぞれ）
- 構文ハイライト: `highlight.js` ベースの WebView、または SwiftUI の `AttributedString` で対応言語ごとに着色
- 長い行は折り返しなし（横スクロール）／設定でソフトラップ切り替え可

---

## 5. デザイントークン

### 5-1. カラー

```swift
// Semantic tokens
Color.gitViewerBranch     // accentColor alias
Color.gitViewerRemote     // Color(.sRGB, r:0.5, g:0.5, b:0.5)
Color.gitViewerTag        // .orange
Color.gitViewerAdded      // .green
Color.gitViewerDeleted    // .red
Color.gitViewerModified   // .blue
Color.gitViewerRenamed    // .orange

// Diff backgrounds (define in Assets.xcassets with light/dark variants)
Color("diffAdded")        // Light: #e6ffed / Dark: #1a3a1a
Color("diffDeleted")      // Light: #ffeef0 / Dark: #3a1a1a
Color("diffHunk")         // Light: #f1f8ff / Dark: #1a2a3a
```

**ブランチグラフカラーパレット**（10 色ループ）

```
#4B9EFF  #FF6B6B  #51CF66  #FFD43B  #CC5DE8
#FF922B  #20C997  #F06595  #74C0FC  #A9E34B
```

ダークモードでは同 Hue・Saturation を維持しつつ Lightness を +15% して視認性を確保する。

### 5-2. タイポグラフィ

| 用途 | SwiftUI Font | サイズ |
|---|---|---|
| セクションヘッダー | `.caption2.uppercaseSmallCaps()` | 10 pt |
| サイドバー項目 | `.callout` | 13 pt |
| コミットメッセージ | `.body` | 13 pt |
| SHA | `.system(.caption, design:.monospaced)` | 11 pt |
| Diff コード | `Font.custom("SF Mono", size: 12)` | 12 pt |
| Commit Header メッセージ | `.title3.weight(.semibold)` | 15 pt |

### 5-3. スペーシング

```
xs:  4 pt
sm:  8 pt
md: 12 pt
lg: 16 pt
xl: 24 pt
```

### 5-4. コーナーラジウス

| 要素 | 値 |
|---|---|
| Ref badge | 4 pt（capsule） |
| ステータスバッジ | 3 pt |
| アバター | circular |

---

## 6. インタラクション仕様

### 6-1. アニメーション

すべてのトランジションは `prefers-reduced-motion` 相当の macOS アクセシビリティ設定（`Reduce Motion`）を尊重する。

| トランジション | Duration | Easing |
|---|---|---|
| パネル選択変更 | 150 ms | easeOut |
| Sidebar disclosure | 200 ms | spring(response: 0.3) |
| diff 表示切り替え | 100 ms | easeInOut |
| ローディング Skeleton | — | shimmer loop |

### 6-2. ローディング状態

- リポジトリ読み込み中: 中央ペインに `ProgressView()` + "Loading commits…"
- Diff 取得中: diff エリアに Skeleton プレースホルダー（10 行分の灰色矩形）
- Gravatar 取得中: initials アバターをプレースホルダーとして即表示

### 6-3. 空状態

| 状況 | 表示 |
|---|---|
| リポジトリ未追加 | SF Symbol `rectangle.dashed` + "リポジトリをドロップしてください" |
| 検索結果ゼロ | SF Symbol `magnifyingglass` + "コミットが見つかりませんでした" |
| コミット未選択 | SF Symbol `cursorarrow.click` + "コミットを選択してください" |

### 6-4. コンテキストメニュー（コミット行）

```
SHA をコピー           ⌘C
コミット URL をコピー
Finder でリポジトリを開く
────────────────────
このコミットとの差分を表示   （別コミット選択後に有効化）
────────────────────
GitHub/GitLab で開く       （remote URL から自動判定）
```

---

## 7. キーボードショートカット

| キー | アクション |
|---|---|
| `⌘1` | サイドバー表示切り替え |
| `⌘2` | コミットリスト / ファイルツリー切り替え |
| `↑ ↓` | コミット選択移動 |
| `⌘↑ ⌘↓` | 最初 / 最後のコミットへ |
| `⌘F` | 検索フォーカス |
| `ESC` | 検索クリア |
| `⌘[` `⌘]` | ブランチ間移動（選択履歴） |
| `Space` | Quick Look |
| `⌘R` | リフレッシュ（fetch dry-run、書き込みなし） |

---

## 8. アクセシビリティ

### 8-1. VoiceOver

- コミット行: `accessibilityLabel` に "コミット [SHA], [著者], [日時], [メッセージ]" を設定
- Ref badge: "ブランチ [名前]" / "タグ [名前]" とアナウンス
- Diff 行: 追加/削除/コンテキストの種別を prefix として読み上げ（例: "追加: let new = …"）

### 8-2. カラーコントラスト

- 通常テキスト vs 背景: WCAG AA 4.5:1 以上
- Ref badge テキスト: badge 背景に対して 4.5:1 以上（白テキスト on accentColor で達成）
- Diff ハイライト: テキスト色に依存しないよう背景色のみで区別し、`+/-` 記号を必ず表示

### 8-3. キーボードフォーカス

- すべてのインタラクティブ要素はタブ停止を持つ
- フォーカスリング: macOS 標準（`.focusable()` / `focusRingType`）
- フォーカスリングコントラスト: 3:1 以上

### 8-4. 要手動確認項目

- グラフカラー 10 色の色覚多様性対応（Deuteranopia/Protanopia シミュレーション）
- Split diff の 2 カラムレイアウトが小フォントサイズ設定で崩れないか
- VoiceOver で diff 全行を連続読み上げした際のパフォーマンス

---

## 9. ダーク / ライトモード

`Color(.systemBackground)` 等の macOS Semantic Color を使用し、基本的にシステムが自動切り替えを処理する。カスタムカラー（Diff 背景等）は `Assets.xcassets` に Light / Dark の 2 variant を登録する。

アプリ設定でシステムに関わらず強制ライト/ダーク切り替えオプションを提供する。

---

## 10. 設定 (Preferences)

`NSWindowStyleMask.titled + .miniaturizable` のシートまたは独立ウィンドウ。

| セクション | 項目 |
|---|---|
| 表示 | フォントサイズ、行間、グラフの幅 |
| Diff | デフォルト表示モード（Unified/Split）、構文ハイライト ON/OFF、タブ幅 |
| アバター | Gravatar 取得 ON/OFF |
| 外観 | テーマ（System / Light / Dark） |
| 高度 | Git パス指定、SSH エージェント設定 |

---

## 11. ファイルツリービュー（オプション）

コミットリストペインの上部にタブバーを追加し「コミット」「ファイルツリー」を切り替え可能にする。

**ファイルツリータブ**
- 選択ブランチ HEAD のファイルツリーを `OutlineView` で表示
- ファイルクリックで右パネルにそのファイルの blob コンテンツ表示（構文ハイライト付き）
- パスを `NSPasteboard` でコピー可能
- 検索で絞り込み可能（ファイル名・パス）

---

## 12. 画面遷移フロー

```
起動
 └─ 前回開いていたリポジトリを自動復元
     ├─ リポジトリあり → メインウィンドウ（コミットリスト表示）
     └─ リポジトリなし → ウェルカムウィンドウ（Open / Drop）

メインウィンドウ
 ├─ ブランチ選択 → コミットリストスクロール（同一ウィンドウ内）
 ├─ コミット選択 → 右パネル更新（同一ウィンドウ内）
 ├─ ファイル選択 → diff 更新（同一ウィンドウ内）
 └─ コミットダブルクリック → 詳細シート（オーバーレイ）

設定: ⌘, → Preferences ウィンドウ
```

---

## 付録: SwiftUI コンポーネント構成（参考）

```
GitViewerApp
├── MainWindow (WindowGroup)
│   └── RootView
│       ├── SidebarView
│       │   ├── RepositoryListSection
│       │   └── BranchListSection
│       │       ├── LocalBranchList
│       │       ├── RemoteBranchList
│       │       └── TagList
│       ├── CommitListView
│       │   ├── CommitListToolbar
│       │   ├── CommitGraph (Canvas)
│       │   └── CommitRow
│       │       ├── GraphLane
│       │       ├── RefBadge
│       │       ├── CommitMessage
│       │       └── AuthorAvatar
│       └── DetailView
│           ├── CommitInfoHeader
│           ├── ChangedFilesList
│           │   └── FileStatusBadge
│           └── DiffView
│               ├── UnifiedDiffView
│               └── SplitDiffView
├── WelcomeWindow
└── PreferencesWindow
```

import SwiftUI

private struct SplitDiffRow: Identifiable {
    let id: String
    let left: DiffLine?
    let right: DiffLine?
}

private func buildSplitRows(hunkID: String, for hunk: DiffHunk) -> [SplitDiffRow] {
    var rows: [SplitDiffRow] = []
    var i = 0
    let lines = hunk.lines
    while i < lines.count {
        let line = lines[i]
        switch line.type {
        case .context, .noNewline:
            rows.append(SplitDiffRow(id: "\(hunkID)-ctx-\(line.id)", left: line, right: line))
            i += 1
        case .deleted, .added:
            var deleted: [DiffLine] = []
            var added: [DiffLine] = []
            while i < lines.count && (lines[i].type == .deleted || lines[i].type == .added) {
                if lines[i].type == .deleted {
                    deleted.append(lines[i])
                } else {
                    added.append(lines[i])
                }
                i += 1
            }
            let count = max(deleted.count, added.count)
            for j in 0..<count {
                let l = j < deleted.count ? deleted[j] : nil
                let r = j < added.count ? added[j] : nil
                rows.append(SplitDiffRow(id: "\(hunkID)-chg-\(l?.id ?? "nil")-\(r?.id ?? "nil")-\(j)", left: l, right: r))
            }
        }
    }
    return rows
}

struct SplitDiffView: View {
    let hunks: [DiffHunk]
    var language: String? = nil
    @Environment(AppSettings.self) private var settings
    private let hunkRows: [(DiffHunk, [SplitDiffRow])]

    init(hunks: [DiffHunk], language: String? = nil) {
        self.hunks = hunks
        self.language = language
        self.hunkRows = hunks.map { ($0, buildSplitRows(hunkID: $0.id, for: $0)) }
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(hunkRows, id: \.0.id) { hunk, rows in
                hunkHeaderRow(hunk)
                ForEach(rows) { row in
                    splitRow(row)
                }
            }
        }
        .font(.system(size: settings.diffFontSize, design: .monospaced))
    }

    @ViewBuilder
    private func hunkHeaderRow(_ hunk: DiffHunk) -> some View {
        HStack(spacing: 0) {
            Text(hunk.header)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
            Divider()
            Text(hunk.header)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
        }
        .background(Color.diffHunk)
    }

    @ViewBuilder
    private func splitRow(_ row: SplitDiffRow) -> some View {
        HStack(spacing: 0) {
            sideCell(line: row.left, isLeft: true)
            Divider()
            sideCell(line: row.right, isLeft: false)
        }
        .padding(.vertical, settings.diffLineSpacing)
    }

    @ViewBuilder
    private func sideCell(line: DiffLine?, isLeft: Bool) -> some View {
        HStack(spacing: 0) {
            if let line {
                lineNumberCell(isLeft ? line.oldLineNumber : line.newLineNumber)
                if line.type == .noNewline {
                    Text(line.content)
                        .foregroundStyle(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 22) // align with content column
                } else {
                    Text(linePrefix(line.type))
                        .frame(width: 14, alignment: .center)
                        .foregroundStyle(prefixColor(line.type))
                    HighlightedText(code: expandTabs(line.content), language: language)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Color.clear.frame(width: 42)
                Color.clear.frame(width: 14)
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(backgroundFor(line: line))
    }

    @ViewBuilder
    private func lineNumberCell(_ number: Int?) -> some View {
        if let n = number {
            Text("\(n)")
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .trailing)
                .padding(.trailing, 4)
        } else {
            Color.clear.frame(width: 42)
        }
    }

    private func linePrefix(_ type: DiffLineType) -> String {
        switch type {
        case .added:   return "+"
        case .deleted: return "-"
        default:       return " "
        }
    }

    private func prefixColor(_ type: DiffLineType) -> Color {
        switch type {
        case .added:   return .arborAdded
        case .deleted: return .arborDeleted
        default:       return .secondary
        }
    }

    private func expandTabs(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: String(repeating: " ", count: settings.diffTabWidth))
    }

    private func backgroundFor(line: DiffLine?) -> Color {
        guard let line else { return Color.secondary.opacity(0.04) }
        switch line.type {
        case .added:   return .diffAdded
        case .deleted: return .diffDeleted
        default:       return .clear
        }
    }
}

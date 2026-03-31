import SwiftUI

struct UnifiedDiffView: View {
    let hunks: [DiffHunk]
    var wrapLines: Bool = false

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(hunks) { hunk in
                hunkHeaderRow(hunk)
                ForEach(hunk.lines) { line in
                    diffLineRow(line)
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
    }

    @ViewBuilder
    private func hunkHeaderRow(_ hunk: DiffHunk) -> some View {
        Text(hunk.header)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.diffHunk)
    }

    @ViewBuilder
    private func diffLineRow(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            lineNumberCell(line.oldLineNumber)
            lineNumberCell(line.newLineNumber)
            Text(linePrefix(line.type))
                .frame(width: 14, alignment: .center)
                .foregroundStyle(prefixColor(line.type))
            Text(line.content)
                .lineLimit(wrapLines ? nil : 1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(lineBackground(line.type))
        .accessibilityLabel(diffLineAccessibilityLabel(line))
    }

    private func diffLineAccessibilityLabel(_ line: DiffLine) -> String {
        switch line.type {
        case .added:   return "追加: \(line.content)"
        case .deleted: return "削除: \(line.content)"
        default:       return line.content
        }
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
        case .added: return "+"
        case .deleted: return "-"
        default: return " "
        }
    }

    private func prefixColor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: return .gitViewerAdded
        case .deleted: return .gitViewerDeleted
        default: return .secondary
        }
    }

    private func lineBackground(_ type: DiffLineType) -> Color {
        switch type {
        case .added: return .diffAdded
        case .deleted: return .diffDeleted
        default: return .clear
        }
    }
}

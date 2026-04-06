import SwiftUI

struct CommitRow: View {
    let commit: Commit
    let showAbsoluteDates: Bool

    private var dateText: String {
        showAbsoluteDates ? commit.authorDate.absoluteDisplay : commit.authorDate.relativeDisplay
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = []
        if !commit.refs.isEmpty {
            let refLabels = commit.refs.map { ref in
                switch ref.refType {
                case .localBranch:  return "ブランチ \(ref.shortName)"
                case .remoteBranch: return "リモートブランチ \(ref.shortName)"
                case .tag:          return "タグ \(ref.shortName)"
                case .stash:        return "スタッシュ \(ref.shortName)"
                }
            }
            parts.append(contentsOf: refLabels)
        }
        parts.append(commit.subject)
        parts.append(commit.authorName)
        parts.append(dateText)
        parts.append("SHA \(commit.shortSHA)")
        return parts.joined(separator: ", ")
    }

    var body: some View {
        if commit.isWorkingTreeSentinel {
            workingTreeRow
        } else {
            commitRow
        }
    }

    private var workingTreeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
                .font(.body)
                .frame(width: 22)
            Text(commit.subject)
                .font(.body)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.leading, 6)
        .padding(.vertical, 2)
        .accessibilityLabel(commit.subject)
    }

    private var commitRow: some View {
        HStack(alignment: .top, spacing: 0) {
            if let node = commit.graphNode {
                CommitGraphView(node: node)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                if !commit.refs.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(commit.refs) { ref in
                            RefBadge(ref: ref)
                        }
                    }
                }
                Text(commit.subject)
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(commit.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(commit.shortSHA)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 6)
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }
}

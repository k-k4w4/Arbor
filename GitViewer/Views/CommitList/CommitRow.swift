import SwiftUI

struct CommitRow: View {
    let commit: Commit

    var body: some View {
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
                Text(commit.authorDate.relativeDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(commit.shortSHA)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

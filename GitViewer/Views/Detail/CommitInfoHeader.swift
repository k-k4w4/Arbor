import SwiftUI

struct CommitInfoHeader: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(commit.subject)
                .font(.headline)
                .lineLimit(2)

            let bodyText = messageBody
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                Label(commit.shortSHA, systemImage: "number")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Label(commit.authorName, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Label(commit.authorDate.relativeDisplay, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageBody: String {
        let lines = commit.message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
        return lines.dropFirst().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

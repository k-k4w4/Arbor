import SwiftUI

struct CommitInfoHeader: View {
    let commit: Commit
    let commitBody: String
    let showAbsoluteDates: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if commit.isWorkingTreeSentinel {
                Label(commit.subject, systemImage: "pencil.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    GravatarView(email: commit.authorEmail, name: commit.authorName, size: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.subject)
                            .font(.headline)
                            .lineLimit(2)

                        if !commitBody.isEmpty {
                            Text(commitBody)
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
                            Label(
                                showAbsoluteDates ? commit.authorDate.absoluteDisplay : commit.authorDate.relativeDisplay,
                                systemImage: showAbsoluteDates ? "calendar" : "clock"
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if commit.committerName != commit.authorName || commit.committerEmail != commit.authorEmail {
                                Label(commit.committerName, systemImage: "person.badge.clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

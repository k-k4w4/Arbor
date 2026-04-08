import SwiftUI
import AppKit

private struct ParentSHALink: View {
    let sha: String
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(String(sha.prefix(7)))
            .font(.caption.monospaced())
            .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
            .onHover { isHovered = $0 }
            .onTapGesture { onTap() }
            .help("親コミットへジャンプ")
    }
}

struct CommitInfoHeader: View {
    @Environment(AppSettings.self) private var settings
    let commit: Commit
    let commitBody: String
    let showAbsoluteDates: Bool
    var onJumpToSHA: ((String) -> Void)? = nil
    @State private var shaHovered = false
    @State private var shaCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if commit.isWorkingTreeSentinel {
                Label(commit.subject, systemImage: "pencil.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    if settings.showGravatar {
                        GravatarView(email: commit.authorEmail, name: commit.authorName, size: 36)
                    }

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
                            // SHA — click to copy full SHA
                            HStack(spacing: 4) {
                                Image(systemName: shaCopied ? "checkmark" : "number")
                                    .font(.caption)
                                Text(shaCopied ? "コピーしました" : commit.shortSHA)
                                    .font(.caption.monospaced())
                            }
                            .foregroundStyle(shaCopied ? Color.green : (shaHovered ? .primary : .secondary))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                (shaCopied || shaHovered) ? Color.primary.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 3)
                            )
                            .animation(.easeInOut(duration: 0.15), value: shaCopied)
                            .onHover { isHovered in
                                if !shaCopied { shaHovered = isHovered }
                            }
                            .onTapGesture {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(commit.id, forType: .string)
                                shaHovered = false
                                shaCopied = true
                            }
                            .task(id: shaCopied) {
                                guard shaCopied else { return }
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                shaCopied = false
                            }
                            .help("クリックでフルSHAをコピー")

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

                        // Parent SHA links
                        if let onJumpToSHA, !commit.parentSHAs.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.up.left")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                ForEach(commit.parentSHAs.prefix(2), id: \.self) { sha in
                                    ParentSHALink(sha: sha) { onJumpToSHA(sha) }
                                }
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

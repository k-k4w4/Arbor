import SwiftUI

struct RefBadge: View {
    let ref: GitRef

    var body: some View {
        Text(ref.shortName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(badgeColor.opacity(0.35), lineWidth: 0.5))
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch ref.refType {
        case .localBranch:          return "ブランチ \(ref.shortName)"
        case .remoteBranch:         return "リモートブランチ \(ref.shortName)"
        case .tag:                  return "タグ \(ref.shortName)"
        case .stash:                return "スタッシュ \(ref.shortName)"
        }
    }

    private var badgeColor: Color {
        switch ref.refType {
        case .localBranch:  return .gitViewerBranch
        case .remoteBranch: return .gray
        case .tag:          return .gitViewerTag
        case .stash:        return .gray
        }
    }
}

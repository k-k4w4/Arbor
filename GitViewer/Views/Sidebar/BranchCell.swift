import SwiftUI

struct BranchCell: View {
    let ref: GitRef
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 14)
            Text(ref.shortName)
                .lineLimit(1)
            Spacer()
            if ref.isHead {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private var icon: String {
        switch ref.refType {
        case .localBranch:  return "arrow.triangle.branch"
        case .remoteBranch: return "network"
        case .tag:          return "tag"
        case .stash:        return "tray"
        }
    }
}

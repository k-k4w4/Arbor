import SwiftUI

struct BranchCell: View {
    let ref: GitRef

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(ref.shortName)
                .lineLimit(1)
            Spacer()
            if case .localBranch = ref.refType, (ref.ahead > 0 || ref.behind > 0) {
                HStack(spacing: 2) {
                    if ref.ahead > 0 {
                        Text("↑\(ref.ahead)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if ref.behind > 0 {
                        Text("↓\(ref.behind)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if ref.isHead {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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

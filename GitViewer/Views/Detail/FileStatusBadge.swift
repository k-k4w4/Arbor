import SwiftUI

struct FileStatusBadge: View {
    let status: FileStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: 20)
            .padding(.vertical, 2)
            .background(badgeColor, in: RoundedRectangle(cornerRadius: 3))
    }

    private var badgeColor: Color {
        switch status {
        case .modified: return .gitViewerModified
        case .added: return .gitViewerAdded
        case .deleted: return .gitViewerDeleted
        case .renamed: return .gitViewerRenamed
        case .copied: return .teal
        case .typeChanged: return .orange
        case .unmerged: return .red
        case .untracked: return .gray
        }
    }
}

import SwiftUI

struct BranchListSection: View {
    let title: String
    let refs: [GitRef]
    let limit: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(Array(refs.prefix(limit))) { ref in
                    BranchCell(ref: ref)
                        .tag(ref.id)
                }
                if refs.count > limit {
                    Button {
                        onLoadMore()
                    } label: {
                        Text("さらに \(refs.count - limit) 件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            SectionToggleHeader(title: title, isCollapsed: isCollapsed, onToggle: onToggle)
        }
    }
}

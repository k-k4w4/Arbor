import SwiftUI

private let rowInsets = EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)

struct BranchListSection: View {
    let title: String
    let refs: [GitRef]
    let sidebarVM: SidebarViewModel
    let limit: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(Array(refs.prefix(limit))) { ref in
                    let isSelected = sidebarVM.selectedRef?.id == ref.id
                    BranchCell(ref: ref, isSelected: isSelected)
                        .padding(rowInsets)
                        .contentShape(Rectangle())
                        .onTapGesture { sidebarVM.selectedRef = ref }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
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
                    .padding(rowInsets)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        } header: {
            SectionToggleHeader(title: title, isCollapsed: isCollapsed, onToggle: onToggle)
        }
    }
}

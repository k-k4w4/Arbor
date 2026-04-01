import SwiftUI

private let rowInsets = EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)

struct BranchListSection: View {
    let title: String
    let refs: [GitRef]
    let sidebarVM: SidebarViewModel

    var body: some View {
        Section(title) {
            ForEach(refs) { ref in
                let isSelected = sidebarVM.selectedRef?.id == ref.id
                BranchCell(ref: ref, isSelected: isSelected)
                    // Padding inside + zero row insets → contentShape covers full row width
                    .padding(rowInsets)
                    .contentShape(Rectangle())
                    .onTapGesture { sidebarVM.selectedRef = ref }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            }
        }
    }
}

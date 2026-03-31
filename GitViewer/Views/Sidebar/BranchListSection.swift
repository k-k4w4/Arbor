import SwiftUI

struct BranchListSection: View {
    let title: String
    let refs: [GitRef]
    let sidebarVM: SidebarViewModel

    var body: some View {
        Section(title) {
            ForEach(refs) { ref in
                BranchCell(ref: ref, isSelected: sidebarVM.selectedRef?.id == ref.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sidebarVM.selectedRef = ref
                    }
            }
        }
    }
}

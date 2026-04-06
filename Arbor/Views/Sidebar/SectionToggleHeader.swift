import SwiftUI

struct SectionToggleHeader: View {
    let title: String
    let isCollapsed: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .padding(.trailing, 8)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onToggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCollapsed ? "Expand \(title) section" : "Collapse \(title) section")
        .accessibilityAddTraits(.isButton)
    }
}

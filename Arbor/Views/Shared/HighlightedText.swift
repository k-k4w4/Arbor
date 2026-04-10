import SwiftUI

struct HighlightedText: View {
    let code: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted: AttributedString?

    var body: some View {
        Group {
            if let highlighted {
                Text(highlighted)
            } else {
                Text(code)
            }
        }
        .task(id: "\(language ?? "")\0\(colorScheme == .dark)\0\(code)") {
            // HTML conversion collapses leading whitespace.
            // Split into indent + code, highlight only the code part.
            let indent = String(code.prefix(while: { $0 == " " || $0 == "\t" }))
            let trimmed = String(code.dropFirst(indent.count))
            guard !trimmed.isEmpty else { return }
            if let result = await SyntaxHighlightService.shared.highlight(
                trimmed, language: language, isDark: colorScheme == .dark
            ) {
                highlighted = AttributedString(indent) + result
            }
        }
    }
}

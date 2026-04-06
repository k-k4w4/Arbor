import SwiftUI

struct GravatarView: View {
    let email: String
    let name: String
    let size: CGFloat

    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .animation(.easeIn(duration: 0.2), value: nsImage != nil)
        .task(id: email) {
            nsImage = nil
            nsImage = await GravatarCache.shared.image(for: email)
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(avatarColor)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // Deterministic color derived from the email string.
    // Use bitwise AND instead of abs() to avoid Int.min undefined behavior.
    private var avatarColor: Color {
        let palette: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .cyan]
        let hash = email.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0x7FFF_FFFF_FFFF_FFFF }
        return palette[hash % palette.count]
    }
}

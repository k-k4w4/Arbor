import SwiftUI
import AppKit

// Inline image preview for binary image files (png/jpg/jpeg/gif/webp).
// Hover to reveal a save overlay; click anywhere on the image to open the save panel.
struct BinaryImagePreview: View {
    let data: Data
    let filename: String
    @State private var isHovering = false

    var body: some View {
        if let nsImage = NSImage(data: data) {
            ZStack {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Color.black
                    .opacity(isHovering ? 0.35 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture {
                saveFile(data: data, filename: filename)
            }
        } else {
            EmptyStateView(icon: "photo", message: "画像を表示できません")
        }
    }
}

// Open / save panel for non-image binary files.
struct BinaryFilePreview: View {
    let data: Data
    let filename: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(filename)
                .font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("アプリで開く") {
                    openWithDefaultApp(data: data, filename: filename)
                }
                Button("保存...") {
                    saveFile(data: data, filename: filename)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Write to a UUID-scoped temp directory to avoid filename collisions across commits/repos.
// Schedules deletion 5 minutes later so the receiving app has time to open the file.
private func openWithDefaultApp(data: Data, filename: String) {
    do {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tempURL = dir.appendingPathComponent(filename)
        try data.write(to: tempURL)
        NSWorkspace.shared.open(tempURL)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) {
            try? FileManager.default.removeItem(at: dir)
        }
    } catch {
        // ignore; user sees nothing happen
    }
}

private func saveFile(data: Data, filename: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = filename
    panel.canCreateDirectories = true
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            try? data.write(to: url)
        }
    }
}

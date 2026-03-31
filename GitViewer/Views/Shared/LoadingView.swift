import SwiftUI

struct LoadingView: View {
    var message: String = "読み込み中..."

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

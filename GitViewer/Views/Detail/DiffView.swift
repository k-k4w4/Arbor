import SwiftUI

// Phase 4: Diff view container (unified mode for v1)
struct DiffView: View {
    let hunks: [DiffHunk]

    var body: some View {
        UnifiedDiffView(hunks: hunks)
    }
}

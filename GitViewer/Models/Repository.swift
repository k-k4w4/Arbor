import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: URL
    var headBranchName: String
    var addedAt: Date

    init(path: URL) {
        self.id = UUID()
        self.name = path.lastPathComponent
        self.path = path
        self.headBranchName = "HEAD"
        self.addedAt = Date()
    }
}

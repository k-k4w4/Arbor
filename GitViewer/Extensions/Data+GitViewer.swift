import Foundation

extension Data {
    var utf8OrLatin1: String {
        String(data: self, encoding: .utf8)
            ?? String(data: self, encoding: .isoLatin1) ?? ""
    }
}

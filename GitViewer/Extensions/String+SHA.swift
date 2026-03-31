import Foundation

extension String {
    var shortSHA: String {
        String(prefix(7))
    }
}

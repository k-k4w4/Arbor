import Foundation

extension Date {
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var absoluteDisplay: String {
        Self.absoluteFormatter.string(from: self)
    }

    var relativeDisplay: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hr ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "yesterday" : "\(days) days ago"
        } else {
            return Self.shortDateFormatter.string(from: self)
        }
    }
}

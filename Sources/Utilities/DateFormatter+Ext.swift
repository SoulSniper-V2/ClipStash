import Foundation

extension Date {
    /// Returns a human-friendly relative time string.
    /// "just now", "2m ago", "1h ago", "yesterday", "Mar 14"
    var relativeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 5 {
            return "just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if interval < 172800 {
            return "yesterday"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            if Calendar.current.isDate(self, equalTo: now, toGranularity: .year) {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            return formatter.string(from: self)
        }
    }
}

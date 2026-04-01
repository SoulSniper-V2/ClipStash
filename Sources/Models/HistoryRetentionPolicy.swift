import Foundation

/// User-configurable retention window for non-pinned clipboard history.
enum HistoryRetentionPolicy: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case forever = "forever"

    static let userDefaultsKey = "historyRetentionPolicy"
    static let defaultValue: HistoryRetentionPolicy = .forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "30 Days"
        case .forever:
            return "Forever"
        }
    }

    var description: String {
        switch self {
        case .sevenDays:
            return "Keep non-pinned clips for one week."
        case .thirtyDays:
            return "Keep non-pinned clips for one month."
        case .forever:
            return "Keep non-pinned clips until you delete them."
        }
    }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .forever:
            return nil
        }
    }

    static var current: HistoryRetentionPolicy {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        return rawValue.flatMap(Self.init(rawValue:)) ?? defaultValue
    }
}

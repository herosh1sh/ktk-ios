import Foundation

extension Date {
    /// Start of week (Monday)
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// End of week (Sunday)
    var endOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    /// Format as Russian weekday
    var russianWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self).capitalized
    }

    /// Format as "d MMMM" in Russian
    var russianDayMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: self)
    }

    /// Format as "yyyy-MM-dd" for API
    var apiFormat: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

extension Calendar {
    /// Current academic year (starts in September)
    var currentAcademicYear: Int {
        let now = Date()
        let components = dateComponents([.year, .month], from: now)
        let year = components.year ?? 2024
        let month = components.month ?? 1
        // Academic year starts in September (month 9)
        return month >= 9 ? year : year - 1
    }
}
import Foundation

/// An anniversary is a calendar day, not a moment in time.
///
/// It is stored as 12:00 UTC on that day. Reading it back uses the UTC year-month-day,
/// so partners in different time zones see the same date.
nonisolated enum AnniversaryCalendar {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Noon UTC on the calendar day `date` shows in `calendar`.
    static func storageDate(from date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return utc.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? date
    }

    /// The stored instant as noon on that same calendar day in `calendar`.
    static func localDate(fromStored date: Date, calendar: Calendar = .current) -> Date {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? date
    }

    /// Whole calendar days from `anniversary` through today.
    static func daysTogether(since anniversary: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: anniversary)
        let end = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }
}

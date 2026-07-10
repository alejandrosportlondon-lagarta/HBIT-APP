import Foundation

/// Calendar-day keys ("yyyy-MM-dd"). A morning's key is the calendar day
/// *in the user's timezone at alarm time*; once minted, keys are plain
/// calendar dates and all streak math happens on them in UTC — which is
/// what makes streaks immune to DST shifts and timezone travel.
public enum MorningDateKey {
    public static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func key(for date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return "" }
        return key(year: year, month: month, day: day)
    }

    /// The key `days` calendar days away (negative = past). Uses noon UTC
    /// internally so day arithmetic can never straddle a DST boundary.
    public static func offset(_ key: String, by days: Int) -> String? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else { return nil }
        calendar.timeZone = utc
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        guard let base = calendar.date(from: comps),
              let shifted = calendar.date(byAdding: .day, value: days, to: base)
        else { return nil }
        return self.key(for: shifted, in: utc)
    }

    public static func previous(_ key: String) -> String? { offset(key, by: -1) }
    public static func next(_ key: String) -> String? { offset(key, by: 1) }
}

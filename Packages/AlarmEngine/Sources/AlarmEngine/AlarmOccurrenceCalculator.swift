import Foundation

/// Computes the next concrete fire instant for a wall-clock alarm time.
///
/// Rules (CLAUDE.md): times are *stored* as UTC instants (`Date`), but
/// *scheduling* happens in the user's timezone — an "07:00" alarm means
/// 07:00 on the user's clock, whatever UTC offset that day has. DST is
/// delegated to `Calendar`, with the two edge cases pinned by tests:
///
/// - Spring forward (the wall-clock time doesn't exist that day): the alarm
///   fires at the first instant after the gap (`.nextTime`).
/// - Fall back (the wall-clock time exists twice): the alarm fires at the
///   first occurrence (`.first`) — waking early beats ringing twice.
public enum AlarmOccurrenceCalculator {
    /// The next instant strictly after `reference` at which the user's
    /// clock in `timeZone` reads `hour:minute`. Returns nil only for
    /// nonsensical components (e.g. hour 25).
    public static func nextFireDate(
        hour: Int,
        minute: Int,
        timeZone: TimeZone,
        after reference: Date
    ) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.nextDate(
            after: reference,
            matching: DateComponents(hour: hour, minute: minute),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}

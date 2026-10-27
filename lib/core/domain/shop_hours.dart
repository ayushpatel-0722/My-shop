import '../models/company.dart';

/// Pure rules for a shop's weekly opening hours.
///
/// These mirror how the shopper app reads the timetable (`StoreHours`):
///  * `00:00` to `00:00` on an open day means **open all day**;
///  * a closing time before the opening time is an **overnight** shift
///    (22:00 to 02:00 closes at 2 AM the next morning).

/// Minutes since midnight for an "HH:mm" string, or null if malformed.
int? hoursToMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// "HH:mm" for a time of day given as hours and minutes.
String formatHours(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// True for an open day marked "open 24 hours" (00:00 to 00:00).
bool isOpenAllDay(WeeklyHours day) =>
    !day.isClosed && day.openTime == '00:00' && day.closeTime == '00:00';

/// True for an open day whose closing time falls on the next morning.
bool isOvernight(WeeklyHours day) {
  if (day.isClosed || isOpenAllDay(day)) return false;
  final open = hoursToMinutes(day.openTime);
  final close = hoursToMinutes(day.closeTime);
  return open != null && close != null && close < open;
}

enum HoursIssueKind {
  /// A time is missing or not "HH:mm".
  invalidTime,

  /// Opening and closing are the same time (other than the 24-hour 00:00).
  sameTime,

  /// Every day is closed.
  noOpenDay,
}

/// A problem found in the timetable. It carries no text, so the screen can
/// show it in the user's language.
class HoursIssue {
  final HoursIssueKind kind;

  /// The day it concerns (empty for [HoursIssueKind.noOpenDay]).
  final String day;

  const HoursIssue(this.kind, [this.day = '']);

  @override
  bool operator ==(Object other) =>
      other is HoursIssue && other.kind == kind && other.day == day;

  @override
  int get hashCode => Object.hash(kind, day);

  @override
  String toString() => 'HoursIssue($kind, $day)';
}

/// First problem in [week], or null when every open day is valid.
///
/// Closed days are never checked. Overnight shifts and 24-hour days are valid.
HoursIssue? validateWeeklyHours(List<WeeklyHours> week) {
  var openDays = 0;
  for (final day in week) {
    if (day.isClosed) continue;
    openDays++;
    final open = hoursToMinutes(day.openTime);
    final close = hoursToMinutes(day.closeTime);
    if (open == null || close == null) {
      return HoursIssue(HoursIssueKind.invalidTime, day.day);
    }
    if (isOpenAllDay(day)) continue;
    if (open == close) return HoursIssue(HoursIssueKind.sameTime, day.day);
  }
  if (week.isNotEmpty && openDays == 0) {
    return const HoursIssue(HoursIssueKind.noOpenDay);
  }
  return null;
}

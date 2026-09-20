import '../models/company.dart';
import '../models/review.dart';

/// Weekly-opening-hours maths for the store front.
///
/// The shopper app needs three things from a shop's timetable:
///  * is it open **right now**,
///  * when does it close (for the green "Open Now · Closes 9 PM" pill),
///  * when does it reopen (for the red "Closed · Opens 9 AM Mon" pill).
///
/// The old `Company.isOpenNow` answered only the first question, printed no
/// labels, and treated an overnight shift ("22:00" → "06:00") as always open.
/// Everything lives here so it can be unit-tested without Firestore.
class StoreHours {
  const StoreHours._();

  static const List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "21:00" -> 1260 minutes. 0 for unparseable input.
  static int toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return -1;
    return h * 60 + m;
  }

  /// "21:00" -> "9 PM" (12-hour, no leading zero, on-the-hour minutes kept).
  static String prettyTime(String hhmm) {
    final minutes = toMinutes(hhmm);
    if (minutes < 0) return hhmm;
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return m == 0 ? '$h12 $suffix' : '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  static WeeklyHours? _hoursFor(Company company, int weekday) {
    if (company.weeklyHours.isEmpty) return null;
    if (weekday < 1 || weekday > company.weeklyHours.length) return null;
    return company.weeklyHours[weekday - 1];
  }

  /// True when the timetable says the shop is serving customers at [now].
  ///
  /// * An empty timetable means "always open" (the previous behaviour).
  /// * A day marked closed means closed.
  /// * `closeTime <= openTime` is an **overnight** shift (e.g. 22:00 → 06:00):
  ///   open from `openTime` to midnight, and from midnight to `closeTime` on
  ///   the *following* day.
  static bool isOpenAt(Company company, DateTime now) {
    if (company.weeklyHours.isEmpty) return true;

    final today = _hoursFor(company, now.weekday);
    if (today == null) return true;

    final minutes = now.hour * 60 + now.minute;
    final open = toMinutes(today.openTime);
    final close = toMinutes(today.closeTime);

    if (today.isClosed) return false;
    if (open < 0 || close < 0) return true;
    if (open == 0 && close == 0) return true; // open all day

    if (close > open) {
      return minutes >= open && minutes < close;
    }

    // Overnight shift: still open after midnight if *yesterday* ran late.
    if (minutes < close) return true;
    if (minutes >= open) return true;

    // Between close and open: check whether yesterday's shift spills over.
    final yesterday = _hoursFor(
      company,
      now.weekday == 1 ? 7 : now.weekday - 1,
    );
    if (yesterday == null || yesterday.isClosed) return false;
    final yOpen = toMinutes(yesterday.openTime);
    final yClose = toMinutes(yesterday.closeTime);
    final isOvernight = yClose <= yOpen && !(yOpen == 0 && yClose == 0);
    return isOvernight && minutes < yClose;
  }

  /// The hours entry currently in effect **for display**: today's row, or
  /// yesterday's row when an overnight shift is still running.
  static WeeklyHours? activeHours(Company company, DateTime now) {
    final today = _hoursFor(company, now.weekday);
    if (today == null) return null;
    if (isOpenAt(company, now)) {
      // If we are past midnight inside an overnight shift, show yesterday.
      final minutes = now.hour * 60 + now.minute;
      final open = toMinutes(today.openTime);
      final close = toMinutes(today.closeTime);
      final todayIsOvernight = close <= open && !(open == 0 && close == 0);
      if (!todayIsOvernight && minutes < open) {
        final yesterday = _hoursFor(
          company,
          now.weekday == 1 ? 7 : now.weekday - 1,
        );
        if (yesterday != null) {
          final yOpen = toMinutes(yesterday.openTime);
          final yClose = toMinutes(yesterday.closeTime);
          if (yClose <= yOpen && !(yOpen == 0 && yClose == 0) && minutes < yClose) {
            return yesterday;
          }
        }
      }
      return today;
    }
    return today;
  }

  /// The next moment the shop opens after [now] (null when always open).
  static DateTime? nextOpening(Company company, DateTime now) {
    if (company.weeklyHours.isEmpty) return null;
    for (var addDays = 0; addDays <= 7; addDays++) {
      final day = now.add(Duration(days: addDays));
      final row = _hoursFor(company, day.weekday);
      if (row == null || row.isClosed) continue;
      final open = toMinutes(row.openTime);
      if (open < 0) continue;
      final opensAt = DateTime(day.year, day.month, day.day, open ~/ 60, open % 60);
      if (opensAt.isAfter(now)) return opensAt;
    }
    return null;
  }

  /// Green pill label while open: `"Open Now · Closes 9 PM"`.
  static String openLabel(Company company, DateTime now) {
    final hours = activeHours(company, now);
    final close = hours == null ? '' : prettyTime(hours.closeTime);
    final closeSuffix = hours != null &&
            toMinutes(hours.closeTime) <= toMinutes(hours.openTime) &&
            !(toMinutes(hours.openTime) == 0 && toMinutes(hours.closeTime) == 0)
        ? ' (late)'
        : '';
    return close.isEmpty ? 'Open Now' : 'Open Now · Closes $close$closeSuffix';
  }

  /// Red pill label while closed: `"Closed · Opens 9 AM Mon"`.
  static String closedLabel(Company company, DateTime now) {
    final next = nextOpening(company, now);
    if (next == null) return 'Closed';
    final time = prettyTime(
      '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}',
    );
    final sameDay = next.year == now.year &&
        next.month == now.month &&
        next.day == now.day;
    final day = sameDay ? '' : ' ${_dayNames[next.weekday - 1]}';
    return 'Closed · Opens $time$day';
  }
}

/// Aggregate numbers shown on a store page (rating, review count, followers).
///
/// Previously every screen recomputed these inline — and the store page
/// invented a 5.0 rating when a shop had no reviews yet. One definition now.
class StoreStats {
  final double averageRating;
  final int reviewCount;
  final int followerCount;

  const StoreStats({
    this.averageRating = 0,
    this.reviewCount = 0,
    this.followerCount = 0,
  });

  /// Average over the **visible** reviews; 0 (not 5.0) when there are none.
  factory StoreStats.fromReviews(
    List<Review> reviews, {
    int followerCount = 0,
  }) {
    final visible = reviews.where((r) => r.isVisible).toList();
    final total = visible.fold<int>(0, (sum, r) => sum + r.rating);
    return StoreStats(
      averageRating: visible.isEmpty ? 0 : total / visible.length,
      reviewCount: visible.length,
      followerCount: followerCount,
    );
  }

  /// "4.6" / "New" — never fabricates a rating for an unreviewsed shop.
  String get ratingLabel =>
      reviewCount == 0 ? 'New' : averageRating.toStringAsFixed(1);

  /// "128 followers" / "1 follower".
  String get followerLabel =>
      followerCount == 1 ? '1 follower' : '$followerCount followers';
}

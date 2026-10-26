import 'package:intl/intl.dart';

/// Supported date range presets for admin reports.
enum ReportDatePreset {
  last7Days,
  last30Days,
  previousMonth,
  last90Days,
  currentYear,
  previousYear,
  custom;

  String get label {
    switch (this) {
      case ReportDatePreset.last7Days:
        return 'Last 7 Days';
      case ReportDatePreset.last30Days:
        return 'Last 30 Days';
      case ReportDatePreset.previousMonth:
        return 'Previous Month';
      case ReportDatePreset.last90Days:
        return 'Last 90 Days';
      case ReportDatePreset.currentYear:
        return 'Current Year';
      case ReportDatePreset.previousYear:
        return 'Previous Year';
      case ReportDatePreset.custom:
        return 'Custom Range';
    }
  }
}

/// Immutable date range filter with inclusive [startDate] and [endDate] bounds.
class ReportDateRange {
  final ReportDatePreset preset;
  final DateTime startDate;
  final DateTime endDate;

  const ReportDateRange({
    required this.preset,
    required this.startDate,
    required this.endDate,
  });

  /// Factory constructor that calculates exact date bounds for any preset.
  /// Accepts an optional [now] timestamp for deterministic testing.
  factory ReportDateRange.fromPreset(ReportDatePreset preset, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final endOfToday = DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999);

    switch (preset) {
      case ReportDatePreset.last7Days:
        // Rolling 7 days ending today (today - 6 days through today)
        return ReportDateRange(
          preset: preset,
          startDate: today.subtract(const Duration(days: 6)),
          endDate: endOfToday,
        );
      case ReportDatePreset.last30Days:
        // Rolling 30 days ending today (today - 29 days through today)
        return ReportDateRange(
          preset: preset,
          startDate: today.subtract(const Duration(days: 29)),
          endDate: endOfToday,
        );
      case ReportDatePreset.previousMonth:
        // Full previous calendar month: 1st through last day
        final prevMonthYear = ref.month == 1 ? ref.year - 1 : ref.year;
        final prevMonth = ref.month == 1 ? 12 : ref.month - 1;
        final start = DateTime(prevMonthYear, prevMonth, 1);
        final lastDay = DateTime(prevMonthYear, prevMonth + 1, 0).day;
        final end = DateTime(
          prevMonthYear,
          prevMonth,
          lastDay,
          23,
          59,
          59,
          999,
        );
        return ReportDateRange(preset: preset, startDate: start, endDate: end);
      case ReportDatePreset.last90Days:
        // Rolling 90 days ending today (today - 89 days through today)
        return ReportDateRange(
          preset: preset,
          startDate: today.subtract(const Duration(days: 89)),
          endDate: endOfToday,
        );
      case ReportDatePreset.currentYear:
        // Jan 1 through today
        return ReportDateRange(
          preset: preset,
          startDate: DateTime(ref.year, 1, 1),
          endDate: endOfToday,
        );
      case ReportDatePreset.previousYear:
        // Full previous calendar year: Jan 1 through Dec 31
        final prevYear = ref.year - 1;
        return ReportDateRange(
          preset: preset,
          startDate: DateTime(prevYear, 1, 1),
          endDate: DateTime(prevYear, 12, 31, 23, 59, 59, 999),
        );
      case ReportDatePreset.custom:
        return ReportDateRange(
          preset: preset,
          startDate: today,
          endDate: endOfToday,
        );
    }
  }

  /// Builds a custom date range with start-of-day [start] and end-of-day [end].
  factory ReportDateRange.custom(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return ReportDateRange(
      preset: ReportDatePreset.custom,
      startDate: s,
      endDate: e,
    );
  }

  /// Check whether [date] falls within [startDate] and [endDate] (inclusive).
  bool contains(DateTime? date) {
    if (date == null) return false;
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  /// Human-friendly display label for the active range.
  String get label => preset.label;

  /// Formatted date range representation (e.g. "12 Oct 2026 – 18 Oct 2026").
  String get formattedRange {
    final f = DateFormat('dd MMM yyyy');
    return '${f.format(startDate)} – ${f.format(endDate)}';
  }

  /// Safe slug formatted for exported file names (e.g. "20261012_20261018").
  String get fileDateSlug {
    final f = DateFormat('yyyyMMdd');
    return '${f.format(startDate)}_${f.format(endDate)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportDateRange &&
        other.preset == preset &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(preset, startDate, endDate);

  @override
  String toString() => 'ReportDateRange($label: $formattedRange)';
}

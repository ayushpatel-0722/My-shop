import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/report_date_range.dart';

void main() {
  group('ReportDateRange', () {
    // Reference date: Wednesday, 18 October 2026, 14:30:00
    final ref = DateTime(2026, 10, 18, 14, 30, 0);

    test('last7Days computes rolling 7 days inclusive of today', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.last7Days,
        now: ref,
      );
      expect(range.preset, ReportDatePreset.last7Days);
      expect(range.startDate, DateTime(2026, 10, 12, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2026, 10, 18, 23, 59, 59, 999));
      expect(range.contains(DateTime(2026, 10, 12, 0, 0, 0)), isTrue);
      expect(range.contains(DateTime(2026, 10, 18, 23, 59, 59)), isTrue);
      expect(range.contains(DateTime(2026, 10, 11, 23, 59, 59)), isFalse);
      expect(range.contains(DateTime(2026, 10, 19, 0, 0, 0)), isFalse);
    });

    test('last30Days computes rolling 30 days inclusive of today', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.last30Days,
        now: ref,
      );
      expect(range.startDate, DateTime(2026, 9, 19, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2026, 10, 18, 23, 59, 59, 999));
      expect(range.contains(DateTime(2026, 9, 19)), isTrue);
      expect(range.contains(DateTime(2026, 9, 18, 23, 59)), isFalse);
    });

    test('previousMonth computes full previous calendar month', () {
      // For October 2026, previous month is September 2026 (30 days)
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.previousMonth,
        now: ref,
      );
      expect(range.startDate, DateTime(2026, 9, 1, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2026, 9, 30, 23, 59, 59, 999));
      expect(range.contains(DateTime(2026, 9, 15)), isTrue);
      expect(range.contains(DateTime(2026, 10, 1)), isFalse);
    });

    test(
      'previousMonth across year boundary (January -> previous December)',
      () {
        final jan = DateTime(2026, 1, 15, 10, 0, 0);
        final range = ReportDateRange.fromPreset(
          ReportDatePreset.previousMonth,
          now: jan,
        );
        expect(range.startDate, DateTime(2025, 12, 1, 0, 0, 0, 0));
        expect(range.endDate, DateTime(2025, 12, 31, 23, 59, 59, 999));
        expect(range.contains(DateTime(2025, 12, 25)), isTrue);
        expect(range.contains(DateTime(2026, 1, 1)), isFalse);
      },
    );

    test('last90Days computes rolling 90 days ending today', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.last90Days,
        now: ref,
      );
      expect(
        range.startDate,
        DateTime(2026, 10, 18).subtract(const Duration(days: 89)),
      );
      expect(range.endDate, DateTime(2026, 10, 18, 23, 59, 59, 999));
    });

    test('currentYear computes Jan 1 through today', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.currentYear,
        now: ref,
      );
      expect(range.startDate, DateTime(2026, 1, 1, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2026, 10, 18, 23, 59, 59, 999));
      expect(range.contains(DateTime(2026, 1, 1)), isTrue);
      expect(range.contains(DateTime(2025, 12, 31)), isFalse);
    });

    test('previousYear computes full previous calendar year', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.previousYear,
        now: ref,
      );
      expect(range.startDate, DateTime(2025, 1, 1, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2025, 12, 31, 23, 59, 59, 999));
      expect(range.contains(DateTime(2025, 6, 15)), isTrue);
      expect(range.contains(DateTime(2026, 1, 1)), isFalse);
    });

    test('custom range handles user-selected dates', () {
      final start = DateTime(2026, 5, 10);
      final end = DateTime(2026, 5, 20);
      final range = ReportDateRange.custom(start, end);
      expect(range.preset, ReportDatePreset.custom);
      expect(range.startDate, DateTime(2026, 5, 10, 0, 0, 0, 0));
      expect(range.endDate, DateTime(2026, 5, 20, 23, 59, 59, 999));
      expect(range.contains(DateTime(2026, 5, 15)), isTrue);
      expect(range.contains(DateTime(2026, 5, 9)), isFalse);
      expect(range.contains(DateTime(2026, 5, 21)), isFalse);
    });

    test('contains returns false on null date', () {
      final range = ReportDateRange.fromPreset(
        ReportDatePreset.last7Days,
        now: ref,
      );
      expect(range.contains(null), isFalse);
    });
  });
}

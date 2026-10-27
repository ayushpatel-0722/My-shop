import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/shop_hours.dart';
import 'package:myshop/core/models/company.dart';

WeeklyHours day(
  String name,
  String open,
  String close, {
  bool closed = false,
}) =>
    WeeklyHours(day: name, openTime: open, closeTime: close, isClosed: closed);

void main() {
  group('hoursToMinutes / formatHours', () {
    test('parses valid times', () {
      expect(hoursToMinutes('00:00'), 0);
      expect(hoursToMinutes('09:30'), 570);
      expect(hoursToMinutes('23:59'), 1439);
    });

    test('rejects malformed times', () {
      for (final bad in ['', '9', '24:00', '12:60', 'ab:cd', '09:30:00']) {
        expect(hoursToMinutes(bad), isNull, reason: bad);
      }
    });

    test('formats with leading zeros', () {
      expect(formatHours(9, 5), '09:05');
      expect(formatHours(21, 0), '21:00');
    });
  });

  group('isOpenAllDay / isOvernight', () {
    test('00:00 to 00:00 on an open day is open all day', () {
      expect(isOpenAllDay(day('Mon', '00:00', '00:00')), isTrue);
      expect(isOpenAllDay(day('Mon', '00:00', '00:00', closed: true)), isFalse);
      expect(isOpenAllDay(day('Mon', '09:00', '21:00')), isFalse);
    });

    test('closing before opening is an overnight shift', () {
      expect(isOvernight(day('Fri', '22:00', '02:00')), isTrue);
      expect(isOvernight(day('Fri', '09:00', '21:00')), isFalse);
      expect(isOvernight(day('Fri', '00:00', '00:00')), isFalse);
      expect(isOvernight(day('Fri', '22:00', '02:00', closed: true)), isFalse);
      expect(isOvernight(day('Fri', 'xx', '02:00')), isFalse);
    });
  });

  group('validateWeeklyHours', () {
    test('accepts a normal week with a closed Sunday', () {
      expect(
        validateWeeklyHours([
          day('Mon', '09:00', '21:00'),
          day('Sun', '00:00', '00:00', closed: true),
        ]),
        isNull,
      );
    });

    test('accepts an overnight shift', () {
      expect(validateWeeklyHours([day('Fri', '22:00', '02:00')]), isNull);
    });

    test('accepts an open-all-day day', () {
      expect(validateWeeklyHours([day('Sat', '00:00', '00:00')]), isNull);
    });

    test('rejects the same opening and closing time, naming the day', () {
      expect(
        validateWeeklyHours([day('Wed', '10:00', '10:00')]),
        const HoursIssue(HoursIssueKind.sameTime, 'Wed'),
      );
      expect(
        validateWeeklyHours([day('Wed', '23:59', '23:59')])?.kind,
        HoursIssueKind.sameTime,
      );
    });

    test('closed days are not checked', () {
      expect(
        validateWeeklyHours([
          day('Mon', '09:00', '21:00'),
          day('Sun', '10:00', '10:00', closed: true),
        ]),
        isNull,
      );
    });

    test('malformed times are rejected, naming the day', () {
      expect(
        validateWeeklyHours([day('Thu', 'xx', '21:00')]),
        const HoursIssue(HoursIssueKind.invalidTime, 'Thu'),
      );
      expect(
        validateWeeklyHours([day('Thu', '09:00', '25:00')])?.kind,
        HoursIssueKind.invalidTime,
      );
    });

    test('a shop must stay open at least one day', () {
      expect(
        validateWeeklyHours([
          day('Mon', '09:00', '21:00', closed: true),
          day('Tue', '09:00', '21:00', closed: true),
        ]),
        const HoursIssue(HoursIssueKind.noOpenDay),
      );
    });

    test('an empty week is not an error', () {
      expect(validateWeeklyHours(const []), isNull);
    });

    test('the first problem found is reported', () {
      expect(
        validateWeeklyHours([
          day('Mon', '09:00', '21:00'),
          day('Tue', '10:00', '10:00'),
          day('Wed', 'xx', '21:00'),
        ]),
        const HoursIssue(HoursIssueKind.sameTime, 'Tue'),
      );
    });
  });
}

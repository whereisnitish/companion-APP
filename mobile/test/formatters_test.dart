import 'package:companion/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format.whenLabel', () {
    test('calls an evening today "Tonight"', () {
      final DateTime now = DateTime.now();
      final DateTime tonight = DateTime(now.year, now.month, now.day, 20, 30);
      expect(Format.whenLabel(tonight), startsWith('Tonight · '));
    });

    test('calls a morning today "Today"', () {
      final DateTime now = DateTime.now();
      final DateTime morning = DateTime(now.year, now.month, now.day, 9, 0);
      expect(Format.whenLabel(morning), startsWith('Today · '));
    });

    test('names tomorrow explicitly', () {
      final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
        Format.whenLabel(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19)),
        startsWith('Tomorrow · '),
      );
    });

    test('uses the weekday inside the coming week', () {
      final DateTime inThreeDays = DateTime.now().add(const Duration(days: 3));
      final String label = Format.whenLabel(
        DateTime(inThreeDays.year, inThreeDays.month, inThreeDays.day, 18),
      );
      expect(label, contains(','));
      expect(label, isNot(contains('Tomorrow')));
    });

    test('crosses midnight by calendar day, not by elapsed hours', () {
      // 23:30 today and 00:30 tomorrow are one hour apart but different days.
      final DateTime now = DateTime.now();
      final DateTime lateTonight = DateTime(now.year, now.month, now.day, 23, 30);
      final DateTime earlyTomorrow =
          DateTime(now.year, now.month, now.day, 23, 30).add(const Duration(hours: 1));
      expect(Format.whenLabel(lateTonight), startsWith('Tonight'));
      expect(Format.whenLabel(earlyTomorrow), startsWith('Tomorrow'));
    });
  });

  group('Format.relative', () {
    test('reads "just now" under a minute', () {
      expect(Format.relative(DateTime.now().subtract(const Duration(seconds: 20))), 'just now');
    });

    test('counts minutes, then hours, then days', () {
      expect(Format.relative(DateTime.now().subtract(const Duration(minutes: 12))), '12m');
      expect(Format.relative(DateTime.now().subtract(const Duration(hours: 3))), '3h');
      expect(Format.relative(DateTime.now().subtract(const Duration(days: 2))), '2d');
    });

    test('falls back to a date beyond a week', () {
      final String label = Format.relative(DateTime.now().subtract(const Duration(days: 30)));
      expect(label, isNot(endsWith('d')));
    });
  });

  group('Format.distance', () {
    test('switches to metres below a kilometre', () {
      expect(Format.distance(0.42), '420 m away');
    });

    test('keeps one decimal under ten kilometres', () {
      expect(Format.distance(2.44), '2.4 km away');
    });

    test('drops the decimal beyond ten kilometres', () {
      expect(Format.distance(24.4), '24 km away');
    });

    test('renders nothing when distance is hidden', () {
      expect(Format.distance(null), '');
    });
  });

  group('Format.lastSeen', () {
    test('prefers live presence over a timestamp', () {
      final DateTime longAgo = DateTime.now().subtract(const Duration(days: 3));
      expect(Format.lastSeen(longAgo, isOnline: true), 'Active now');
    });

    test('degrades gracefully with no timestamp', () {
      expect(Format.lastSeen(null, isOnline: false), 'Offline');
    });
  });

  group('Format.initials', () {
    test('takes first and last initials', () => expect(Format.initials('Sara Mehta'), 'SM'));
    test('handles a single name', () => expect(Format.initials('Nitish'), 'N'));
    test('handles a middle name', () => expect(Format.initials('A B C'), 'AC'));
    test('never throws on empty input', () => expect(Format.initials('   '), '?'));
  });
}

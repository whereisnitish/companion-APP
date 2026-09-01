import 'package:intl/intl.dart';

/// Every date, time and distance string in the product comes from here, so the
/// same moment never reads two different ways on two screens.
abstract final class Format {
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _weekdayTime = DateFormat('EEEE, h:mm a');
  static final DateFormat _dateTime = DateFormat('EEE d MMM, h:mm a');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _fullDate = DateFormat('d MMMM yyyy');
  static final DateFormat _messageDay = DateFormat('EEEE, d MMMM');

  /// "Tonight · 8:30 PM", "Tomorrow · 7:00 AM", "Saturday, 8:30 PM".
  static String whenLabel(DateTime when) {
    final DateTime now = DateTime.now();
    final int days = _dayDelta(now, when);

    if (days == 0) {
      final String prefix = when.hour >= 17 ? 'Tonight' : 'Today';
      return '$prefix · ${_time.format(when)}';
    }
    if (days == 1) return 'Tomorrow · ${_time.format(when)}';
    if (days > 1 && days < 7) return _weekdayTime.format(when);
    return _dateTime.format(when);
  }

  /// The compact form used inside dense cards.
  static String whenShort(DateTime when) {
    final int days = _dayDelta(DateTime.now(), when);
    if (days == 0) return _time.format(when);
    if (days == 1) return 'Tmrw ${_time.format(when)}';
    if (days > 1 && days < 7) return DateFormat('EEE h:mm a').format(when);
    return '${_dayMonth.format(when)} · ${_time.format(when)}';
  }

  static String time(DateTime when) => _time.format(when);
  static String fullDate(DateTime when) => _fullDate.format(when);
  static String messageDay(DateTime when) {
    final int days = _dayDelta(DateTime.now(), when);
    if (days == 0) return 'Today';
    if (days == -1) return 'Yesterday';
    return _messageDay.format(when);
  }

  /// "just now", "12m", "3h", "2d", then a date.
  static String relative(DateTime when) {
    final Duration elapsed = DateTime.now().difference(when);
    if (elapsed.inSeconds < 60) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h';
    if (elapsed.inDays < 7) return '${elapsed.inDays}d';
    return _dayMonth.format(when);
  }

  /// "Active now", "Active 2h ago".
  static String lastSeen(DateTime? when, {required bool isOnline}) {
    if (isOnline) return 'Active now';
    if (when == null) return 'Offline';
    final Duration elapsed = DateTime.now().difference(when);
    if (elapsed.inMinutes < 5) return 'Active just now';
    if (elapsed.inMinutes < 60) return 'Active ${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return 'Active ${elapsed.inHours}h ago';
    if (elapsed.inDays < 7) return 'Active ${elapsed.inDays}d ago';
    return 'Active recently';
  }

  static String distance(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
  }

  static String distanceShort(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)}km';
  }

  /// Calendar-day difference, ignoring the clock.
  static int _dayDelta(DateTime from, DateTime to) {
    final DateTime a = DateTime(from.year, from.month, from.day);
    final DateTime b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static String initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

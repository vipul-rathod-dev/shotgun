// utils/date_formatter.dart
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DateFormatter {
  static String formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    try {
      if (ts is Timestamp) return DateFormat.yMMMd().add_jm().format(ts.toDate());
      if (ts is DateTime) return DateFormat.yMMMd().add_jm().format(ts);
      return ts.toString();
    } catch (_) {
      try {
        if (ts is Timestamp) return DateFormat.yMMMd().format(ts.toDate());
      } catch (_) {}
      return ts.toString();
    }
  }
}

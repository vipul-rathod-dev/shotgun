// controllers/order_status_mapper.dart
class OrderStatusMapper {
  /// Converts textual status to a step index (kept original checks)
  static int statusToStepIndex(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return 7;
    if (s.contains('packing')) return 6;
    if (s.contains('demo')) return 5;
    if (s.contains('fitting')) return 4;
    if (s.contains('quality')) return 3;
    if (s.contains('color')) return 2;
    if (s.contains('raw')) return 1;
    if (s.contains('received')) return 0;

    return 0;
  }
}

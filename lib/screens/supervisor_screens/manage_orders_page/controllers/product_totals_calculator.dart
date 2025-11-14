// controllers/product_totals_calculator.dart
class ProductTotalsCalculator {
  static Map<String, int> compute(List<dynamic> products) {
    int totalProducts = products.length;
    int totalQty = 0;
    int totalFocus = 0;
    int totalTemple = 0;

    for (final p in products) {
      try {
        final qty = (p['quantity'] is int) ? p['quantity'] as int : int.tryParse('${p['quantity']}') ?? 0;
        totalQty += qty;

        final customizations = (p['customizations'] as List<dynamic>?) ?? [];
        for (final c in customizations) {
          final fq = (c['focusQty'] is int) ? c['focusQty'] as int : int.tryParse('${c['focusQty']}') ?? 0;
          final tq = (c['templeQty'] is int) ? c['templeQty'] as int : int.tryParse('${c['templeQty']}') ?? 0;
          totalFocus += fq;
          totalTemple += tq;
        }
      } catch (_) {
        // ignore malformed entries
      }
    }

    return {
      'totalProducts': totalProducts,
      'totalQty': totalQty,
      'totalFocus': totalFocus,
      'totalTemple': totalTemple,
    };
  }
}

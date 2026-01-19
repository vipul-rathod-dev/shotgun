import 'package:flutter/material.dart';
import 'product_cell_state.dart';

class FocusRowState {
  final String color;
  final Map<String, ProductCellState> products;

  final ValueNotifier<num> recTotal = ValueNotifier(0);
  final ValueNotifier<num> repTotal = ValueNotifier(0);
  final ValueNotifier<num> pendingTotal = ValueNotifier(0);

  FocusRowState({
    required this.color,
    required this.products,
  }) {
    recalc();
  }

  num get totalQty =>
      products.values.fold<num>(0, (s, c) => s + c.qty);

  void recalc() {
    num rec = 0;
    num rep = 0;

    for (final cell in products.values) {
      cell.recalc();
      rec += num.tryParse(cell.recCtrl.text) ?? 0;
      rep += num.tryParse(cell.repCtrl.text) ?? 0;
    }

    recTotal.value = rec;
    repTotal.value = rep;
    pendingTotal.value = totalQty - rec - rep;
  }

  void dispose() {
    for (final c in products.values) {
      c.dispose();
    }
    recTotal.dispose();
    repTotal.dispose();
    pendingTotal.dispose();
  }
}

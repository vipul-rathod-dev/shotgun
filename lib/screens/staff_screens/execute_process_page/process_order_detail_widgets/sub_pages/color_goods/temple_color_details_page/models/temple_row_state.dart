import 'package:flutter/material.dart';
import 'temple_product_cell_state.dart';

class TempleRowState {
  final String color;
  final Map<String, TempleProductCellState> genders;

  final ValueNotifier<num> recRTotal = ValueNotifier(0);
  final ValueNotifier<num> recLTotal = ValueNotifier(0);
  final ValueNotifier<num> repRTotal = ValueNotifier(0);
  final ValueNotifier<num> repLTotal = ValueNotifier(0);
  final ValueNotifier<num> pendingRTotal = ValueNotifier(0);
  final ValueNotifier<num> pendingLTotal = ValueNotifier(0);

  TempleRowState({
    required this.color,
    required this.genders,
  }) {
    recalc();
  }

  num get totalQty =>
      genders.values.fold<num>(0, (s, c) => s + c.qty);

  void recalc() {
    num rR = 0, rL = 0, pR = 0, pL = 0, penR = 0, penL = 0;

    for (final cell in genders.values) {
      cell.recalc();
      rR += num.tryParse(cell.recRCtrl.text) ?? 0;
      rL += num.tryParse(cell.recLCtrl.text) ?? 0;
      pR += num.tryParse(cell.repRCtrl.text) ?? 0;
      pL += num.tryParse(cell.repLCtrl.text) ?? 0;
      penR += cell.pendingR.value;
      penL += cell.pendingL.value;
    }

    recRTotal.value = rR;
    recLTotal.value = rL;
    repRTotal.value = pR;
    repLTotal.value = pL;
    pendingRTotal.value = penR;
    pendingLTotal.value = penL;
  }

  void dispose() {
    for (final c in genders.values) {
      c.dispose();
    }
    recRTotal.dispose();
    recLTotal.dispose();
    repRTotal.dispose();
    repLTotal.dispose();
    pendingRTotal.dispose();
    pendingLTotal.dispose();
  }
}

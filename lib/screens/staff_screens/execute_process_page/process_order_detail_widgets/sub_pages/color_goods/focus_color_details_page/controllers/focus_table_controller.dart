import 'package:flutter/material.dart';
import '../models/focus_row_state.dart';

class FocusTableController {
  final Map<String, FocusRowState> rows = {};

  final ValueNotifier<num> grandRec = ValueNotifier(0);
  final ValueNotifier<num> grandRep = ValueNotifier(0);
  final ValueNotifier<num> grandPending = ValueNotifier(0);

  final Map<String, ValueNotifier<num>> productRec = {};
  final Map<String, ValueNotifier<num>> productRep = {};
  final Map<String, ValueNotifier<num>> productPending = {};

  void initProducts(List<String> productNames) {
    for (final pn in productNames) {
      productRec[pn] = ValueNotifier(0);
      productRep[pn] = ValueNotifier(0);
      productPending[pn] = ValueNotifier(0);
    }
  }

  void recalcGrand() {
    num r = 0, p = 0, pen = 0;

    // reset product totals
    // for (final n in productRec.keys) {
    //   productRec[n]!.value = 0;
    //   productRep[n]!.value = 0;
    //   productPending[n]!.value = 0;
    // }

    for (final row in rows.values) {
      r += row.recTotal.value;
      p += row.repTotal.value;
      pen += row.pendingTotal.value;

      // 🔹 accumulate per-product totals
      row.products.forEach((product, cell) {
        final rec = num.tryParse(cell.recCtrl.text) ?? 0;
        final rep = num.tryParse(cell.repCtrl.text) ?? 0;

        productRec[product]!.value += rec;
        productRep[product]!.value += rep;
        productPending[product]!.value += cell.pending.value;
      });
    }

    grandRec.value = r;
    grandRep.value = p;
    grandPending.value = pen;
  }
}

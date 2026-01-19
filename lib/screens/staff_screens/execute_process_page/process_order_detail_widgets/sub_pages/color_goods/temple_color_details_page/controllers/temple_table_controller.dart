import 'package:flutter/material.dart';
import '../models/temple_row_state.dart';

class TempleTableController {
  final Map<String, TempleRowState> rows = {};

  // Per-gender totals
  final Map<String, ValueNotifier<num>> genderTotals = {};
  final Map<String, ValueNotifier<num>> genderRecR = {};
  final Map<String, ValueNotifier<num>> genderRecL = {};
  final Map<String, ValueNotifier<num>> genderRepR = {};
  final Map<String, ValueNotifier<num>> genderRepL = {};
  final Map<String, ValueNotifier<num>> genderPendingR = {};
  final Map<String, ValueNotifier<num>> genderPendingL = {};

  // Grand totals
  final ValueNotifier<num> grandRecR = ValueNotifier(0);
  final ValueNotifier<num> grandRecL = ValueNotifier(0);
  final ValueNotifier<num> grandRepR = ValueNotifier(0);
  final ValueNotifier<num> grandRepL = ValueNotifier(0);
  final ValueNotifier<num> grandPendingR = ValueNotifier(0);
  final ValueNotifier<num> grandPendingL = ValueNotifier(0);

  void initGenders(List<String> genders) {
    for (final g in genders) {
      genderTotals.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderRecR.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderRecL.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderRepR.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderRepL.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderPendingR.putIfAbsent(g, () => ValueNotifier<num>(0));
      genderPendingL.putIfAbsent(g, () => ValueNotifier<num>(0));
    }
  }

  void recalcGrand() {
    // Reset everything
    for (final g in genderTotals.keys) {
      genderTotals[g]!.value = 0;
      genderRecR[g]!.value = 0;
      genderRecL[g]!.value = 0;
      genderRepR[g]!.value = 0;
      genderRepL[g]!.value = 0;
      genderPendingR[g]!.value = 0;
      genderPendingL[g]!.value = 0;
    }

    num rR = 0, rL = 0, pR = 0, pL = 0, penR = 0, penL = 0;

    for (final row in rows.values) {
      // Row totals → grand
      rR += row.recRTotal.value;
      rL += row.recLTotal.value;
      pR += row.repRTotal.value;
      pL += row.repLTotal.value;

      // Per-gender accumulation
      row.genders.forEach((gender, cell) {
        genderTotals[gender]!.value += cell.qty;

        final recR = num.tryParse(cell.recRCtrl.text) ?? 0;
        final recL = num.tryParse(cell.recLCtrl.text) ?? 0;
        final repR = num.tryParse(cell.repRCtrl.text) ?? 0;
        final repL = num.tryParse(cell.repLCtrl.text) ?? 0;

        final pendingR = cell.pendingR.value;
        final pendingL = cell.pendingL.value;

        genderRecR[gender]!.value += recR;
        genderRecL[gender]!.value += recL;
        genderRepR[gender]!.value += repR;
        genderRepL[gender]!.value += repL;
        genderPendingR[gender]!.value += pendingR;
        genderPendingL[gender]!.value += pendingL;

        penR += pendingR;
        penL += pendingL;
      });
    }

    grandRecR.value = rR;
    grandRecL.value = rL;
    grandRepR.value = pR;
    grandRepL.value = pL;
    grandPendingR.value = penR;
    grandPendingL.value = penL;
  }
}

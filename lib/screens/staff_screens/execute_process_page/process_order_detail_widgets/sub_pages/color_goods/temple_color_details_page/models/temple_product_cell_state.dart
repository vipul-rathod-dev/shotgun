import 'package:flutter/material.dart';

class TempleProductCellState {
  final num qty;

  final TextEditingController recRCtrl;
  final TextEditingController recLCtrl;
  final TextEditingController repRCtrl;
  final TextEditingController repLCtrl;

  final ValueNotifier<num> pendingR;
  final ValueNotifier<num> pendingL;

  TempleProductCellState({
    required this.qty,
    num recR = 0,
    num recL = 0,
    num repR = 0,
    num repL = 0,
  })  : recRCtrl = TextEditingController(text: recR.toString()),
        recLCtrl = TextEditingController(text: recL.toString()),
        repRCtrl = TextEditingController(text: repR.toString()),
        repLCtrl = TextEditingController(text: repL.toString()),
        pendingR = ValueNotifier(qty - recR - repR),
        pendingL = ValueNotifier(qty - recL - repL);

  void recalc() {
    final rR = num.tryParse(recRCtrl.text) ?? 0;
    final rL = num.tryParse(recLCtrl.text) ?? 0;
    final pR = num.tryParse(repRCtrl.text) ?? 0;
    final pL = num.tryParse(repLCtrl.text) ?? 0;

    pendingR.value = qty - rR - pR;
    pendingL.value = qty - rL - pL;
  }

  void hydrate({
    required num recR,
    required num recL,
    required num repR,
    required num repL,
  }) {
    recRCtrl.text = recR.toString();
    recLCtrl.text = recL.toString();
    repRCtrl.text = repR.toString();
    repLCtrl.text = repL.toString();

    pendingR.value = qty - recR - repR;
    pendingL.value = qty - recL - repL;
  }

  void dispose() {
    recRCtrl.dispose();
    recLCtrl.dispose();
    repRCtrl.dispose();
    repLCtrl.dispose();
    pendingR.dispose();
    pendingL.dispose();
  }
}

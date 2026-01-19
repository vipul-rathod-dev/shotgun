import 'package:flutter/material.dart';

class ProductCellState {
  final num qty;

  /// Controllers
  final TextEditingController recCtrl;
  final TextEditingController repCtrl;

  /// Live pending value
  final ValueNotifier<num> pending;

  ProductCellState({
    required this.qty,
    num received = 0,
    num repairing = 0,
  })  : recCtrl = TextEditingController(text: received.toString()),
        repCtrl = TextEditingController(text: repairing.toString()),
        pending = ValueNotifier<num>(qty - received - repairing);

  void recalc() {
    final rec = num.tryParse(recCtrl.text) ?? 0;
    final rep = num.tryParse(repCtrl.text) ?? 0;
    pending.value = qty - rec - rep;
  }

  void hydrate({
    required num received,
    required num repairing,
  }) {
    recCtrl.text = received.toString();
    repCtrl.text = repairing.toString();
    pending.value = qty - received - repairing;
  }


  void dispose() {
    recCtrl.dispose();
    repCtrl.dispose();
    pending.dispose();
  }
}

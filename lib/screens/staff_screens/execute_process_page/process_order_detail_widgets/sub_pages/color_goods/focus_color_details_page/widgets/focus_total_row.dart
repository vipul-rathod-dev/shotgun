import 'package:flutter/material.dart';
import '../controllers/focus_table_controller.dart';

class FocusTotalRow {
  static DataRow build({
    required FocusTableController controller,
    required List<String> productNames,
    required num grandQty,
  }) {
    final cells = <DataCell>[
      const DataCell(Text('TOTAL')),
    ];

    for (final pn in productNames) {
    // Qty
    cells.add(
      DataCell(
        Text(
          controller.productPending.containsKey(pn)
              ? (controller.productPending[pn]!.value +
                controller.productRec[pn]!.value +
                controller.productRep[pn]!.value)
                  .toStringAsFixed(0)
              : '0',
        ),
      ),
    );

    // Rec
    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.productRec[pn]!,
          builder: (_, v, __) => Text(v.toStringAsFixed(0)),
        ),
      ),
    );

    // Rep
    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.productRep[pn]!,
          builder: (_, v, __) => Text(v.toStringAsFixed(0)),
        ),
      ),
    );

    // Pending
    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.productPending[pn]!,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: v > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );
  }



    // Total qty
    cells.add(DataCell(Text(grandQty.toStringAsFixed(0))));

    // Grand totals (LIVE)
    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.grandRec,
          builder: (_, v, __) => Text(v.toStringAsFixed(0)),
        ),
      ),
    );

    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.grandRep,
          builder: (_, v, __) => Text(v.toStringAsFixed(0)),
        ),
      ),
    );

    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: controller.grandPending,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: v > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );

    return DataRow(
      color: MaterialStateProperty.all(Colors.amber.shade200),
      cells: cells,
    );
  }
}

import 'package:flutter/material.dart';
import '../controllers/temple_table_controller.dart';

class TempleTotalRow {
  static DataRow build({
    required TempleTableController controller,
    required List<String> genders,
    required num grandQty,
  }) {
    final cells = <DataCell>[
      const DataCell(
        SizedBox(
          width: 160,
          child: Text(
            'TOTAL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    for (final g in genders) {
      cells.add(
        DataCell(
          ValueListenableBuilder<num>(
            valueListenable: controller.genderTotals[g]!,
            builder: (_, v, __) => Text(
              v.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      // RecR
      cells.add(_vn(controller.genderRecR[g]!));

      // RecL
      cells.add(_vn(controller.genderRecL[g]!));

      // RepR
      cells.add(_vn(controller.genderRepR[g]!));

      // RepL
      cells.add(_vn(controller.genderRepL[g]!));

      // PendingR
      cells.add(_vn(controller.genderPendingR[g]!, isPending: true));

      // PendingL
      cells.add(_vn(controller.genderPendingL[g]!, isPending: true));
    }

    // for (int i = 0; i < genders.length; i++) {
    //   cells.addAll(List.generate(7, (_) => const DataCell(SizedBox())));
    // }

    cells.add(DataCell(Text(grandQty.toStringAsFixed(0))));
    cells.add(_vn(controller.grandRecR));
    cells.add(_vn(controller.grandRecL));
    cells.add(_vn(controller.grandRepR));
    cells.add(_vn(controller.grandRepL));
    cells.add(_vn(controller.grandPendingR, isPending: true));
    cells.add(_vn(controller.grandPendingL, isPending: true));

    return DataRow(
      color: MaterialStateProperty.all(Colors.amber.shade200),
      cells: cells,
    );
  }

  static DataCell _vn(
    ValueNotifier<num> v, {
    bool isPending = false,
  }) =>
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: v,
          builder: (_, n, __) => Text(
            n.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPending
                  ? (n > 0 ? Colors.red : Colors.green)
                  : null,
            ),
          ),
        ),
      );
}

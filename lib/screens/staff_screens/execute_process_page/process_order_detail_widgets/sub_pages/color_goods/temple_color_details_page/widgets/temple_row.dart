import 'package:flutter/material.dart';
import '../../common_table_textfield.dart';
import '../models/temple_row_state.dart';

class TempleRow {
  static DataRow build({
    required TempleRowState row,
    required List<String> genders,
    required VoidCallback onChanged,
    required bool isEven,
  }) {
    final cells = <DataCell>[
      DataCell(
        SizedBox(
          width: 160,
          child: Text(
            row.color,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    for (final g in genders) {
      final cell = row.genders[g]!;

      cells.add(DataCell(Text(cell.qty.toStringAsFixed(0))));

      cells.add(_tf(cell.recRCtrl, onChanged, row));
      cells.add(_tf(cell.recLCtrl, onChanged, row));
      cells.add(_tf(cell.repRCtrl, onChanged, row));
      cells.add(_tf(cell.repLCtrl, onChanged, row));

      cells.add(_pending(cell.pendingR));
      cells.add(_pending(cell.pendingL));
    }

    cells.add(DataCell(Text(row.totalQty.toStringAsFixed(0))));
    cells.add(_vn(row.recRTotal));
    cells.add(_vn(row.recLTotal));
    cells.add(_vn(row.repRTotal));
    cells.add(_vn(row.repLTotal));
    cells.add(_vn(row.pendingRTotal));
    cells.add(_vn(row.pendingLTotal));

    return DataRow(
      color: MaterialStateProperty.all(
        isEven ? Colors.grey.shade200 : Colors.white,
      ),
      cells: cells,
    );
  }

  static DataCell _tf(
    TextEditingController c,
    VoidCallback onChanged,
    TempleRowState row,
  ) =>
      DataCell(
        TableTextField(
          controller: c,
          onChanged: () {
            row.recalc();
            onChanged();
          },
        ),
      );

  static DataCell _pending(ValueNotifier<num> v) =>
      DataCell(ValueListenableBuilder(
        valueListenable: v,
        builder: (_, n, __) => Text(
          n.toStringAsFixed(0),
          style: TextStyle(color: n > 0 ? Colors.red : Colors.green),
        ),
      ));

  static DataCell _vn(ValueNotifier<num> v) =>
      DataCell(ValueListenableBuilder(
        valueListenable: v,
        builder: (_, n, __) => Text(n.toStringAsFixed(0)),
      ));
}

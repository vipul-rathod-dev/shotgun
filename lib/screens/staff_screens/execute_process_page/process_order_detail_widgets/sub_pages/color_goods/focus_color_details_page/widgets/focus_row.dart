import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common_table_textfield.dart';
import '../models/focus_row_state.dart';

class FocusRow {
  static DataRow build({
    required FocusRowState row,
    required List<String> productNames,
    required VoidCallback onChanged,
    required bool isEven,
  }) {
    final cells = <DataCell>[
      // Focus Color
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

    // Product columns
    for (final pn in productNames) {
      final cell = row.products[pn]!;

      // Qty
      cells.add(
        DataCell(
          Text(
            cell.qty == 0 ? '' : cell.qty.toStringAsFixed(0),
          ),
        ),
      );

      // Received
      cells.add(
        DataCell(
          TableTextField(
            controller: cell.recCtrl,
            onChanged: () {
              row.recalc();
              onChanged();
            },
          ),
        ),
      );

      // Repairing
      cells.add(
        DataCell(
          TableTextField(
            controller: cell.repCtrl,
            onChanged: () {
              row.recalc();
              onChanged();
            },
          ),
        ),
      );

      // Pending
      cells.add(
        DataCell(
          ValueListenableBuilder<num>(
            valueListenable: cell.pending,
            builder: (_, v, __) => Text(
              v.toStringAsFixed(0),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: v > 0 ? Colors.red : Colors.green,
              ),
            ),
          ),
        ),
      );
    }

    // Row totals
    cells.add(DataCell(Text(row.totalQty.toStringAsFixed(0))));

    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: row.recTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );

    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: row.repTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );

    cells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: row.pendingTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: v > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );

    return DataRow(
      color: MaterialStateProperty.all(
        isEven ? Colors.grey.shade200 : Colors.white,
      ),
      cells: cells,
    );
  }
}

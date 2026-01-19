import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/focus_table_controller.dart';
import 'focus_row.dart';
import 'focus_total_row.dart';

class FocusTable extends StatelessWidget {
  final List<String> productNames;
  final List<String> colors;
  final Map<String, Map<String, num>> matrix;
  final FocusTableController controller;

  const FocusTable({
    super.key,
    required this.productNames,
    required this.colors,
    required this.matrix,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Build header titles
    final headerTitles = <String>[
      'Focus Color',
      for (final pn in productNames) ...[
        pn,
        'Rec',
        'Rep',
        'Pending',
      ],
      'Total',
      'Received',
      'Repairing',
      'Pending',
    ];

    final columns = headerTitles
        .map(
          (t) => DataColumn(
            label: Text(
              t,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        )
        .toList();

    // Build rows (once, no side-effects in build)
    final rows = <DataRow>[];

    for (final color in colors) {
      final rowState = controller.rows[color]!;

      rows.add(
        FocusRow.build(
          row: rowState,
          productNames: productNames,
          onChanged: controller.recalcGrand,
          isEven: rows.length.isEven,
        ),
      );
    }

    // Calculate grand quantity (static)
    final grandQty = colors.fold<num>(
      0,
      (s, c) =>
          s +
          matrix[c]!.values.fold<num>(
            0,
            (a, b) => a + b,
          ),
    );

    rows.add(
      FocusTotalRow.build(
        controller: controller,
        productNames: productNames,
        grandQty: grandQty,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOCUS COLOR SUMMARY',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: DataTable(
              headingRowColor:
                  MaterialStateProperty.all(Colors.black87),
              columns: columns,
              rows: rows,
              columnSpacing: 14,
              dataRowHeight: 40,
              headingRowHeight: 42,
            ),
          ),
        ),
      ],
    );
  }
}

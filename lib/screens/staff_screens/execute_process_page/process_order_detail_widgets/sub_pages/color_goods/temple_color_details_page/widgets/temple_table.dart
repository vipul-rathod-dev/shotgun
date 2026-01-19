import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/temple_table_controller.dart';
import 'temple_row.dart';
import 'temple_total_row.dart';

class TempleTable extends StatelessWidget {
  final List<String> genders;
  final List<String> colors;
  final Map<String, Map<String, num>> matrix;
  final TempleTableController controller;

  const TempleTable({
    super.key,
    required this.genders,
    required this.colors,
    required this.matrix,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final headers = [
      'Temple Color',
      for (final g in genders) ...[
        g,
        'Rec R',
        'Rec L',
        'Rep R',
        'Rep L',
        'Pending R',
        'Pending L',
      ],
      'Total',
      'Rec R',
      'Rec L',
      'Rep R',
      'Rep L',
      'Pending R',
      'Pending L',
    ];

    final columns = headers
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

    final rows = <DataRow>[];

    for (final color in colors) {
      rows.add(
        TempleRow.build(
          row: controller.rows[color]!,
          genders: genders,
          onChanged: controller.recalcGrand,
          isEven: rows.length.isEven,
        ),
      );
    }

    final grandQty = colors.fold<num>(
      0,
      (s, c) => s + matrix[c]!.values.fold(0, (a, b) => a + b),
    );

    rows.add(
      TempleTotalRow.build(
        controller: controller,
        genders: genders,
        grandQty: grandQty,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEMPLE COLOR SUMMARY',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        // ✅ HORIZONTAL SCROLL
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomizationTable extends StatelessWidget {
  final List customizations;
  final Color statusColor;
  final bool isDark;

  const CustomizationTable({
    super.key,
    required this.customizations,
    required this.statusColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStatePropertyAll(
          statusColor.withOpacity(isDark ? 0.2 : 0.1),
        ),
        border: TableBorder.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
        columns: [
          DataColumn(
            label: Text('Focus Color',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          DataColumn(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Focus Qty',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          DataColumn(
            label: Text('Temple Color',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          DataColumn(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Temple Qty',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
        rows: _buildRows(),
      ),
    );
  }

  List<DataRow> _buildRows() {
    final rows = <DataRow>[];

    for (int i = 0; i < customizations.length; i++) {
      final c = customizations[i];
      final isEven = i % 2 == 0;

      rows.add(
        DataRow(
          color: MaterialStatePropertyAll(
            isEven
                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade100)
                : (isDark ? Colors.grey.shade800 : Colors.white),
          ),
          cells: [
            DataCell(Text(c['focusColor'] ?? 'N/A')),
            DataCell(Align(
              alignment: Alignment.centerRight,
              child: Text('${c['focusQty'] ?? 0}'),
            )),
            DataCell(Text(c['templeColor'] ?? 'N/A')),
            DataCell(Align(
              alignment: Alignment.centerRight,
              child: Text('${c['templeQty'] ?? 0}'),
            )),
          ],
        ),
      );
    }

    if (customizations.length > 1) {
      final totalFocusQty = customizations.fold<int>(
        0,
        (sum, c) => sum + ((c['focusQty'] ?? 0) as num).toInt(),
      );

      final totalTempleQty = customizations.fold<int>(
        0,
        (sum, c) => sum + ((c['templeQty'] ?? 0) as num).toInt(),
      );

      rows.add(
        DataRow(
          color: MaterialStatePropertyAll(statusColor.withOpacity(isDark ? 0.2 : 0.1)),
          cells: [
            const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Align(
              alignment: Alignment.centerRight,
              child: Text('$totalFocusQty', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            const DataCell(Text('-')),
            DataCell(Align(
              alignment: Alignment.centerRight,
              child: Text('$totalTempleQty', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      );
    }

    return rows;
  }
}

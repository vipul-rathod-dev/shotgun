// controllers/pdf/pdf_status_mapper.dart
import 'package:pdf/pdf.dart';

class PdfStatusMapper {
  static PdfColor map(String? status) {
    if (status == null) return PdfColors.grey600;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return PdfColors.deepPurple;
    if (s.contains('packing')) return PdfColors.teal;
    if (s.contains('demo')) return PdfColors.pink;
    if (s.contains('fitting')) return PdfColors.orange;
    if (s.contains('quality')) return PdfColors.amber;
    if (s.contains('color')) return PdfColors.cyan;
    if (s.contains('raw')) return PdfColors.indigo;
    if (s.contains('received')) return PdfColors.blue;
    return PdfColors.grey;
  }
}

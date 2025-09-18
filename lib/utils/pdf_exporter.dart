import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

// Abstraksi untuk eksport PDF.
abstract class PdfExporter {
  Future<void> exportPdf(Uint8List bytes, String filename);
}

// Implementasi produksi yang memanggil printing package.
class RealPdfExporter implements PdfExporter {
  @override
  Future<void> exportPdf(Uint8List bytes, String filename) async {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }
}

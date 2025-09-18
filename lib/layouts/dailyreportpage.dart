import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/file_saver.dart';
import '../utils/pdf_exporter.dart';
import '../services/tonase_service.dart';
import '../models/tonase_model.dart';

class DailyReportPage extends StatefulWidget {
  final FileSaver? fileSaver;
  final PdfExporter? pdfExporter;

  const DailyReportPage({super.key, this.fileSaver, this.pdfExporter});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  final TonaseService _tonaseService = TonaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _rekapData = [];

  @override
  void initState() {
    super.initState();
    _loadTonaseData();
  }

  Future<void> _loadTonaseData() async {
    try {
      final allTonase = await _tonaseService.getUnsentTonase();
      final filtered = allTonase.where((t) => !t.isSended).toList();

      setState(() {
        _rekapData = _generateRekapData(filtered);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _generateRekapData(List<TonaseModel> tonaseList) {
    final areaList = _getDefaultAreaList();
    final List<Map<String, dynamic>> rekapList = [];

    for (var area in areaList) {
      final rawKode = area['kodeArea']!;
      final wilayah = area['wilayah']!;
      final kodeSet = rawKode
          .replaceAll('&', ',')
          .split(',')
          .map((k) => k.trim())
          .toSet();

      final filtered = tonaseList.where((t) {
        final areaCode = t.areaId.substring(0, 2);
        return kodeSet.contains(areaCode) && !t.isSended;
      }).toList();

      final totalKoli = filtered.fold<int>(
        0,
        (acc, item) => acc + item.totalKoli,
      );
      final totalTonase = filtered.fold<double>(
        0.0,
        (acc, item) => acc + item.totalTonase,
      );
      final customerSet = filtered.map((e) => e.custName).toSet();

      rekapList.add({
        'kodeArea': rawKode,
        'wilayah': wilayah,
        'totalKoli': totalKoli,
        'totalTonase': totalTonase,
        'jumlahToko': customerSet.length,
      });
    }

    return rekapList;
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final hari = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ][now.weekday % 7];

    final bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ][now.month - 1];

    final tanggal = "${now.day.toString().padLeft(2, '0')} $bulan ${now.year}";

    return "$hari, $tanggal";
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final jam = now.hour.toString().padLeft(2, '0');
    final menit = now.minute.toString().padLeft(2, '0');
    return "$jam:$menit";
  }

  List<Map<String, String>> _getDefaultAreaList() {
    return [
      {'kodeArea': '14 & 15', 'wilayah': 'BLORA-JEPARA'},
      {'kodeArea': '14', 'wilayah': 'JEPARA'},
      {'kodeArea': '15', 'wilayah': 'BLORA'},
      {'kodeArea': '12 & 13', 'wilayah': 'PANSEL'},
      {'kodeArea': '12', 'wilayah': 'PANSEL ATAS'},
      {'kodeArea': '13', 'wilayah': 'PANSEL BAWAH'},
      {'kodeArea': '21 & 11', 'wilayah': 'BOYOLALI-PANTURA'},
      {'kodeArea': '11', 'wilayah': 'PANTURA'},
      {'kodeArea': '21', 'wilayah': 'BOYOLALI'},
      {'kodeArea': '16 & 17', 'wilayah': 'JATIM'},
      {'kodeArea': '16', 'wilayah': 'JATIM ATAS'},
      {'kodeArea': '17', 'wilayah': 'JATIM BAWAH'},
      {'kodeArea': '18', 'wilayah': 'KLA-JOG'},
      {'kodeArea': '19', 'wilayah': 'KOTA-KOTA'},
      {'kodeArea': '20', 'wilayah': 'SKH-WNG'},
      {'kodeArea': '22', 'wilayah': 'SRA-KRA'},
      {'kodeArea': '26', 'wilayah': 'SBY'},
      {'kodeArea': '23, 30, 31', 'wilayah': 'LJ'},
      {'kodeArea': '26, 23, 30, 31', 'wilayah': 'SBY-LJ'},
    ];
  }

  void _exportData() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: Key('excel-export-button'),
              leading: const Icon(Icons.file_download),
              title: const Text('Export ke Excel'),
              onTap: () async {
                Navigator.pop(context);
                await _exportToExcel();
              },
            ),
            ListTile(
              key: Key('pdf-export-button'),
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export ke PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _exportToPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      // 1. Buat file Excel dan sheet
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Rekap Tonase'];

      // 2. Header
      sheet.appendRow([
        TextCellValue('Kode Area'),
        TextCellValue('Wilayah'),
        TextCellValue('Jumlah Toko'),
        TextCellValue('Total Koli'),
        TextCellValue('Total Tonase'),
      ]);

      // 3. Isi data
      for (var row in _rekapData) {
        sheet.appendRow([
          TextCellValue(row['kodeArea']?.toString() ?? ''),
          TextCellValue(row['wilayah']?.toString() ?? ''),
          IntCellValue(row['jumlahToko'] ?? 0),
          IntCellValue(row['totalKoli'] ?? 0),
          DoubleCellValue(row['totalTonase'] ?? 0.0),
        ]);
      }

      final bytes = excel.encode()!;
      await widget.fileSaver?.saveExcel(bytes, 'rekap_tonase$Timestamp.xlsx');
      _showMessage('File Excel berhasil disimpan');
    } catch (e) {
      _showMessage('Gagal mengexport ke Excel: $e');
    }
  }

  // Helper untuk header cell
  pw.Widget _pdfHeaderCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  // Helper untuk cell biasa
  pw.Widget _pdfCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  // Helper untuk cell tengah
  pw.Widget _pdfCenteredCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();

      // ignore: deprecated_member_use
      final headerColor = PdfColor.fromInt(Colors.teal.value);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "Report Tonase Per-Area",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      "${_getFormattedDate()}   ${_getFormattedTime()}",
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(width: 1),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(85),
                    1: const pw.FixedColumnWidth(90),
                    2: const pw.FixedColumnWidth(50),
                    3: const pw.FixedColumnWidth(50),
                    4: const pw.FixedColumnWidth(80),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: headerColor),
                      children: [
                        _pdfHeaderCell("Kode Area"),
                        _pdfHeaderCell("Wilayah"),
                        _pdfHeaderCell("Jumlah Toko"),
                        _pdfHeaderCell("Total Koli"),
                        _pdfHeaderCell("Total Tonase"),
                      ],
                    ),
                    // Data rows
                    ..._rekapData.map((row) {
                      return pw.TableRow(
                        children: [
                          _pdfCenteredCell(row['kodeArea']),
                          _pdfCell(row['wilayah']),
                          _pdfCenteredCell(row['jumlahToko'].toString()),
                          _pdfCenteredCell(row['totalKoli'].toString()),
                          _pdfCenteredCell(
                            row['totalTonase'].toStringAsFixed(2),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
      final Uint8List bytes = await pdf.save();
      await widget.pdfExporter?.exportPdf(bytes, 'rekap_tonase$Timestamp.pdf');
      _showMessage('File PDF berhasil disimpan');
    } catch (e) {
      _showMessage('Gagal mengexport ke PDF: $e');
    }
  }

  void _showMessage(
    String msg, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rekap Tonase",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Report Tonase Per-Area",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getFormattedDate(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getFormattedTime(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all<Color>(
                            Colors.teal,
                          ),
                          columns: const [
                            DataColumn(
                              label: SizedBox(
                                width: 85,
                                child: Text(
                                  "Kode Area",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 90,
                                child: Text(
                                  "Wilayah",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 50,
                                child: Text(
                                  "Jumlah Toko",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 50,
                                child: Text(
                                  "Total Koli",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 80,
                                child: Text(
                                  "Total Tonase",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: _rekapData.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Center(child: Text(row['kodeArea']))),
                                DataCell(Text(row['wilayah'])),
                                DataCell(
                                  Center(child: Text('${row['jumlahToko']}')),
                                ),
                                DataCell(
                                  Center(child: Text('${row['totalKoli']}')),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      '${row['totalTonase'].toStringAsFixed(2)}',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Export
                  ElevatedButton.icon(
                    key: Key('export-button'),
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text("Export"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

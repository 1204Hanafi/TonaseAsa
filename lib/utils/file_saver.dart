import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

// Abstraksi untuk menyimpan file Excel.
abstract class FileSaver {
  Future<void> saveExcel(List<int> bytes, String filename);
}

// Implementasi produksi yang menulis ke Download folder.
class RealFileSaver implements FileSaver {
  @override
  Future<void> saveExcel(List<int> bytes, String filename) async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      throw Exception('Izin penyimpanan ditolak');
    }
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('Tidak dapat mengakses storage');
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
  }
}

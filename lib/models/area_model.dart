import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk merepresentasikan data Area dalam aplikasi.
/// Terhubung dengan koleksi [areas] di Firestore.
class AreaModel {
  final String areaId; // ID unik area (sama dengan Firestore document ID).
  final String areaName; // Nama area (contoh: "Jawa Barat").
  final DocumentReference? reference; // Referensi ke dokumen Firestore.

  AreaModel({required this.areaId, required this.areaName, this.reference})
    : assert(areaId.isNotEmpty, 'areaId tidak boleh kosong'),
      assert(areaName.isNotEmpty, 'areaName tidak boleh kosong');

  /// Membuat [AreaModel] dari [DocumentSnapshot] Firestore.
  /// Throw [FormatException] jika parsing gagal.
  factory AreaModel.fromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      return AreaModel(
        areaId: doc.id,
        areaName: data['areaName'] as String? ?? '',
        reference: doc.reference,
      );
    } catch (e) {
      throw FormatException('Gagal parsing AreaModel dari Firestore: $e');
    }
  }

  /// Mengonversi model ke [Map] untuk disimpan di Firestore.
  Map<String, dynamic> toMap() => {'areaId': areaId, 'areaName': areaName};
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/area_model.dart';

/// Service untuk manajemen data Area (CRUD, pencarian).
/// Berinteraksi dengan koleksi [areas] di Firestore.
class AreaService {
  final FirebaseFirestore _firestore;
  late final CollectionReference areaCollection;

  AreaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    areaCollection = _firestore.collection('areas');
  }

  /// Memformat [areaId] menjadi 2 digit (contoh: "5" → "05").
  String formatAreaId(String areaId) {
    return areaId.padLeft(2, '0');
  }

  /// Mengambil semua data area.
  /// Throw [AreaException] jika gagal.
  Future<List<AreaModel>> getAreas() async {
    try {
      final snapshot = await areaCollection.get();
      return snapshot.docs.map((doc) => AreaModel.fromDocument(doc)).toList();
    } catch (e) {
      throw AreaException(
        code: 'fetch-failed',
        message: 'Gagal mengambil data: $e',
      );
    }
  }

  /// Menambahkan area baru.
  /// Throw [AreaException] jika ID/nama sudah ada.
  Future<void> addArea(AreaModel area) async {
    try {
      final formattedAreaId = formatAreaId(area.areaId);
      await _checkDuplicateAreaId(formattedAreaId);
      await _checkDuplicateAreaName(area.areaName);

      await areaCollection.doc(formattedAreaId).set({
        'areaName': area.areaName,
        'searchKeywords': [
          formattedAreaId.toLowerCase(),
          area.areaName.toLowerCase(),
        ],
      });
    } on AreaException {
      rethrow;
    } catch (e) {
      throw AreaException(code: 'add-failed', message: 'Gagal menambahkan: $e');
    }
  }

  /// Memperbarui data area.
  /// Throw [AreaException] jika area tidak ditemukan/nama sudah ada.
  Future<void> updateArea(String areaId, AreaModel area) async {
    try {
      final formattedAreaId = formatAreaId(areaId);
      final doc = await areaCollection.doc(formattedAreaId).get();
      if (!doc.exists) {
        throw AreaException(code: 'not-found', message: 'Area tidak ditemukan');
      }
      final existingNameSnapshot =
          await areaCollection
              .where('areaName', isEqualTo: area.areaName)
              .get();
      if (existingNameSnapshot.docs.isNotEmpty &&
          existingNameSnapshot.docs[0].id != formattedAreaId) {
        throw AreaException(
          code: 'duplicate-name',
          message: 'Nama sudah digunakan',
        );
      }

      await areaCollection.doc(formattedAreaId).update({
        'areaName': area.areaName,
        'searchKeywords': [
          formattedAreaId.toLowerCase(),
          area.areaName.toLowerCase(),
        ],
      });
    } on AreaException {
      rethrow;
    } catch (e) {
      throw AreaException(
        code: 'update-failed',
        message: 'Gagal memperbarui: $e',
      );
    }
  }

  /// Menghapus area berdasarkan ID.
  Future<void> deleteArea(String areaId) async {
    try {
      final formattedAreaId = formatAreaId(areaId);
      await areaCollection.doc(formattedAreaId).delete();
    } catch (e) {
      throw AreaException(
        code: 'delete-failed',
        message: 'Gagal menghapus: $e',
      );
    }
  }

  /// Pencarian area berdasarkan ID/nama (case-insensitive).
  Future<List<AreaModel>> searchAreas(String query) async {
    try {
      final formattedQuery = query.toLowerCase();
      final snapshot =
          await areaCollection
              .where('searchKeywords', arrayContains: formattedQuery)
              .get();
      return snapshot.docs.map((doc) => AreaModel.fromDocument(doc)).toList();
    } catch (e) {
      throw AreaException(code: 'search-failed', message: 'Gagal mencari: $e');
    }
  }

  // ----------------------
  // Helper Methods
  // ----------------------
  Future<void> _checkDuplicateAreaId(String areaId) async {
    final doc = await areaCollection.doc(areaId).get();
    if (doc.exists) {
      throw AreaException(code: 'duplicate-id', message: 'ID sudah digunakan');
    }
  }

  Future<void> _checkDuplicateAreaName(String areaName) async {
    final snapshot =
        await areaCollection.where('areaName', isEqualTo: areaName).get();
    if (snapshot.docs.isNotEmpty) {
      throw AreaException(code: 'duplicate-name', message: 'Nama sudah ada');
    }
  }
}

/// Exception kustom untuk error manajemen area.
class AreaException implements Exception {
  final String code;
  final String message;

  AreaException({required this.code, required this.message});
}

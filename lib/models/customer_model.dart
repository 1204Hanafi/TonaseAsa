import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk merepresentasikan data Customer dalam aplikasi.
/// Terhubung dengan koleksi [customers] di Firestore.
class CustomerModel {
  final String custId; // ID unik customer (sama dengan Firestore document ID).
  final String custName; // Nama lengkap customer.
  final String custCity; // Kota asal customer.
  final DocumentReference areaRef; // Referensi ke dokumen Area terkait.
  String areaName; // Nama area (diisi dari areaRef jika diperlukan).
  final DocumentReference? reference; // Referensi ke dokumen Firestore ini.

  CustomerModel({
    required this.custId,
    required this.custName,
    required this.custCity,
    required this.areaRef,
    this.areaName = '',
    this.reference,
  }) : assert(custId.isNotEmpty, 'custId tidak boleh kosong'),
       assert(custName.isNotEmpty, 'custName tidak boleh kosong'),
       assert(custCity.isNotEmpty, 'custCity tidak boleh kosong');

  /// Membuat [CustomerModel] dari [DocumentSnapshot] Firestore.
  /// Throw [FormatException] jika parsing gagal.
  factory CustomerModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      final data = doc.data()!;
      return CustomerModel(
        custId: doc.id,
        custName: data['custName'] as String? ?? '',
        custCity: data['custCity'] as String? ?? '',
        areaRef: data['areaId'] as DocumentReference,
        reference: doc.reference,
      );
    } catch (e) {
      throw FormatException('Gagal parsing CustomerModel dari Firestore: $e');
    }
  }

  /// Mengonversi model ke [Map] untuk disimpan di Firestore.
  Map<String, dynamic> toMap() => {
    'custName': custName,
    'custCity': custCity,
    'areaId': areaRef,
  };

  /// Membuat [CustomerModel] dari [Map] (untuk keperluan lokal/testing).
  factory CustomerModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CustomerModel(
      custId: id ?? '',
      custName: map['custName'] as String? ?? '',
      custCity: map['custCity'] as String? ?? '',
      areaRef: map['areaId'] as DocumentReference,
    );
  }
}

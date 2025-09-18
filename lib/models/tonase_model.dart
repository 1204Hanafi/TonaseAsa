import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk data tonase pengiriman, termasuk detail koli dan relasi customer.
/// Terhubung dengan koleksi [tonases] di Firestore.
class TonaseModel {
  bool isSelected; // Non-final: untuk keperluan UI (toggle selection)
  final bool isSended; // Status pengiriman
  final String tonId; // ID tonase (Firestore document ID)
  final DateTime date; // Tanggal pencatatan
  final DocumentReference customerRef; // Referensi ke customer
  final String noSj; // Nomor surat jalan
  final int totalKoli; // Jumlah total koli
  final List<double> detailTonase; // List berat per koli (kg)
  final double totalTonase; // Total berat semua koli
  String custName; // Non-final: nama customer
  String custCity; // Non-final: kota customer
  String areaId; // Non-final: ID area
  String areaName; // Non-final: nama area
  final DocumentReference? reference; // Referensi dokumen Firestore

  TonaseModel({
    this.isSelected = false,
    this.isSended = false,
    required this.tonId,
    required this.date,
    required this.customerRef,
    required this.noSj,
    required this.totalKoli,
    required this.detailTonase,
    required this.totalTonase,
    this.custName = '',
    this.custCity = '',
    this.areaId = '',
    this.areaName = '',
    this.reference,
  }) : assert(totalKoli >= 0, 'Total koli tidak boleh negatif'),
       assert(
         detailTonase.length == totalKoli,
         'Jumlah detailTonase harus sama dengan totalKoli',
       );

  /// Membuat [TonaseModel] dari [DocumentSnapshot] Firestore.
  /// Throw [FormatException] jika parsing gagal.
  factory TonaseModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data()!;
      return TonaseModel(
        tonId: doc.id,
        date: (data['date'] as Timestamp).toDate(),
        customerRef: data['custId'] as DocumentReference,
        noSj: data['noSj'] as String? ?? '',
        totalKoli: data['totalKoli'] as int? ?? 0,
        detailTonase:
            (data['detailTonase'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
        totalTonase: (data['totalTonase'] as num?)?.toDouble() ?? 0.0,
        isSended: data['isSended'] as bool? ?? false,
        reference: doc.reference,
      );
    } catch (e) {
      throw FormatException('Gagal parsing TonaseModel: $e');
    }
  }

  /// Mengonversi model ke [Map] untuk disimpan di Firestore.
  Map<String, dynamic> toMap() => {
    'date': date,
    'custId': customerRef,
    'noSj': noSj,
    'totalKoli': totalKoli,
    'detailTonase': detailTonase,
    'totalTonase': totalTonase,
    'isSended': isSended,
  };

  /// Untuk keperluan lokal/testing (tanpa reference).
  factory TonaseModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return TonaseModel(
      tonId: id ?? '',
      date: (map['date'] as Timestamp).toDate(),
      customerRef: map['custId'] as DocumentReference,
      noSj: map['noSj'] as String? ?? '',
      totalKoli: map['totalKoli'] as int? ?? 0,
      detailTonase:
          (map['detailTonase'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      totalTonase: (map['totalTonase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

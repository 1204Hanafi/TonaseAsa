import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String itemId; // ID atau kode unik item
  final String itemName; // Nama lengkap item
  final double itemWeight; // Berat per satuan dalam KG
  final String itemUnit; // Satuan (SAK, PCS, BTG, dll)
  final DocumentReference? reference;

  ItemModel({
    required this.itemId,
    required this.itemName,
    required this.itemWeight,
    required this.itemUnit,
    this.reference,
  });

  // Mengubah dokumen Firestore menjadi objek ItemModel
  factory ItemModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      itemId: doc.id,
      itemName: data['itemName'] ?? '',
      itemWeight: (data['itemWeight'] as num?)?.toDouble() ?? 0.0,
      itemUnit: data['itemUnit'] ?? '',
      reference: doc.reference,
    );
  }

  // Mengubah objek ItemModel menjadi Map untuk disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'itemWeight': itemWeight,
      'itemUnit': itemUnit,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

class ItemService {
  // Membuat referensi langsung ke koleksi 'items' di Firestore
  final CollectionReference itemCollection =
      FirebaseFirestore.instance.collection('items');

  /// Menambahkan item baru ke Firestore.
  /// ID dokumen akan menggunakan itemId dari model.
  Future<void> addItem(ItemModel item) async {
    try {
      await itemCollection.doc(item.itemId).set(item.toMap());
    } catch (e) {
      throw Exception('Gagal menambahkan item: $e');
    }
  }

  /// Mengambil semua item dari Firestore.
  Future<List<ItemModel>> getItems() async {
    try {
      final querySnapshot = await itemCollection.get();
      return querySnapshot.docs
          .map((doc) => ItemModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil data item: $e');
    }
  }

  /// Memperbarui data item yang sudah ada berdasarkan ID-nya.
  Future<void> updateItem(String itemId, ItemModel item) async {
    try {
      await itemCollection.doc(itemId).update(item.toMap());
    } catch (e) {
      throw Exception('Gagal memperbarui item: $e');
    }
  }

  /// Menghapus item dari Firestore berdasarkan ID-nya.
  Future<void> deleteItem(String itemId) async {
    try {
      await itemCollection.doc(itemId).delete();
    } catch (e) {
      throw Exception('Gagal menghapus item: $e');
    }
  }
}

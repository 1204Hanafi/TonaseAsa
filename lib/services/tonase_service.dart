import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/tonase_model.dart';
import '../models/customer_model.dart';

class TonaseService {
  final CollectionReference tonaseCollection = FirebaseFirestore.instance
      .collection('tonase');

  List<CustomerModel> customers = [];

  void setCustomer(List<CustomerModel> customers) {
    customers = customers;
  }

  /// Generate ID dengan format MMDD-XXXX berdasarkan tanggal [date]
  Future<String> generateTonId(DateTime date) async {
    String mmdd = DateFormat('MMdd').format(date);

    // Ambil semua dokumen dengan tanggal yang sama
    QuerySnapshot snapshot =
        await tonaseCollection
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day),
              ),
            )
            .where(
              'date',
              isLessThan: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day + 1),
              ),
            )
            .get();

    int currentCount = snapshot.docs.length;
    int nextNumber = currentCount + 1;
    String formattedNumber = nextNumber.toString().padLeft(4, '0');

    return '$mmdd-$formattedNumber';
  }

  /// Ambil semua data tonase
  Future<List<TonaseModel>> getUnsentTonase() async {
    try {
      final querySnapshot =
          await tonaseCollection.where('isSended', isEqualTo: false).get();
      final List<TonaseModel> tonaseList = [];

      for (var rawDoc in querySnapshot.docs) {
        try {
          final doc = rawDoc as DocumentSnapshot<Map<String, dynamic>>;
          final tonase = TonaseModel.fromDocument(doc);

          // Ambil data customer
          final customerDoc = await tonase.customerRef.get();
          if (!customerDoc.exists) continue;

          final customerData = customerDoc.data() as Map<String, dynamic>;
          tonase.custName = customerData['custName'] ?? '';
          tonase.custCity = customerData['custCity'] ?? '';

          // Ambil areaRef dari customer
          final areaRef = customerData['areaId'];
          if (areaRef is DocumentReference) {
            final areaDoc = await areaRef.get();
            tonase.areaId = areaDoc.id;
            tonase.areaName = areaDoc['areaName'] ?? '';
          } else {
            tonase.areaId = '';
            tonase.areaName = '';
          }

          tonaseList.add(tonase);
        } catch (e) {
          throw Exception("Gagal memproses satu data tonase: $e");
        }
      }

      return tonaseList;
    } catch (e) {
      throw Exception('Gagal mengambil data tonase: $e');
    }
  }

  /// Cek apakah tonId sudah ada
  Future<bool> isTonIdExists(String tonId) async {
    final docSnapshot = await tonaseCollection.doc(tonId).get();
    return docSnapshot.exists;
  }

  /// Tambah data tonase
  Future<void> addTonase(TonaseModel tonase) async {
    try {
      final generatedTonId = await generateTonId(tonase.date);

      if (await isTonIdExists(generatedTonId)) {
        throw Exception("Tonase ID '$generatedTonId' sudah digunakan");
      }

      await tonaseCollection.doc(generatedTonId).set({
        'date': tonase.date,
        'custId': tonase.customerRef,
        'noSj': tonase.noSj,
        'totalKoli': tonase.totalKoli,
        'detailTonase': tonase.detailTonase,
        'totalTonase': tonase.totalTonase,
        'isSended': false,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan tonase: $e');
    }
  }

  /// Update data tonase berdasarkan ID
  Future<void> updateTonase(String tonId, TonaseModel tonase) async {
    try {
      final docRef = tonaseCollection.doc(tonId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception("Tonase ID '$tonId' tidak ditemukan.");
      }

      final dataToUpdate = {
        'date': tonase.date,
        'custId': tonase.customerRef,
        'noSj': tonase.noSj,
        'totalKoli': tonase.totalKoli,
        'detailTonase': tonase.detailTonase,
        'totalTonase': tonase.totalTonase,
        'isSended': tonase.isSended,
      };
      await docRef.update(dataToUpdate);
    } catch (e) {
      throw Exception('Gagal mengupdate tonase: $e');
    }
  }

  /// Hapus data tonase berdasarkan ID
  Future<void> deleteTonase(String tonId) async {
    try {
      await tonaseCollection.doc(tonId).delete();
    } catch (e) {
      throw Exception('Gagal menghapus tonase: $e');
    }
  }

  Future<List<TonaseModel>> getSentTonase() async {
    try {
      final querySnapshot =
          await tonaseCollection.where('isSended', isEqualTo: true).get();
      final List<TonaseModel> tonaseList = [];

      for (var rawDoc in querySnapshot.docs) {
        try {
          final doc = rawDoc as DocumentSnapshot<Map<String, dynamic>>;
          final tonase = TonaseModel.fromDocument(doc);

          // Ambil data customer
          final customerDoc = await tonase.customerRef.get();
          if (!customerDoc.exists) continue;

          final customerData = customerDoc.data() as Map<String, dynamic>;
          tonase.custName = customerData['custName'] ?? '';
          tonase.custCity = customerData['custCity'] ?? '';

          // Ambil areaRef dari customer
          final areaRef = customerData['areaId'];
          if (areaRef is DocumentReference) {
            final areaDoc = await areaRef.get();
            tonase.areaId = areaDoc.id;
            tonase.areaName = areaDoc['areaName'] ?? '';
          } else {
            tonase.areaId = '';
            tonase.areaName = '';
          }

          tonaseList.add(tonase);
        } catch (e) {
          throw Exception("Gagal memproses satu data tonase: $e");
        }
      }

      return tonaseList;
    } catch (e) {
      throw Exception('Gagal mengambil data tonase terkirim: $e');
    }
  }
}

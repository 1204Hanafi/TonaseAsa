import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/area_model.dart';

class CustomerService {
  final CollectionReference customerCollection = FirebaseFirestore.instance
      .collection('customers');
  List<AreaModel> _areas = [];

  void setAreas(List<AreaModel> areas) {
    _areas = areas;
  }

  // Format customerId menjadi 5 digit angka
  String formatCustomerId(String customerId) {
    if (customerId.length < 5) {
      return customerId.padLeft(
        5,
        '0',
      ); // Menambahkan nol di depan hingga mencapai 5 digit
    }
    return customerId;
  }

  // Ambil List<CustomerModel>
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final querySnapshot = await customerCollection.get();
      final List<CustomerModel> customers = [];

      for (var doc in querySnapshot.docs) {
        final customer = CustomerModel.fromDocument(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
        final areaDoc = await customer.areaRef.get();
        final areaName = areaDoc['areaName'] ?? '';

        customers.add(
          CustomerModel(
            custId: customer.custId,
            custName: customer.custName,
            custCity: customer.custCity,
            areaRef: customer.areaRef,
            areaName: areaName,
            reference: customer.reference,
          ),
        );
      }
      return customers;
    } catch (e) {
      throw Exception('Gagal mengambil data customer: $e');
    }
  }

  Future<bool> isCustomerIdExists(String customerId) async {
    final formattedCustomerId = formatCustomerId(
      customerId,
    ); // Format customerId
    final docSnapshot = await customerCollection.doc(formattedCustomerId).get();
    return docSnapshot.exists;
  }

  Future<bool> isDuplicateCustomer(CustomerModel customer) async {
    final querySnapshot =
        await customerCollection
            .where('custName', isEqualTo: customer.custName)
            .where('custCity', isEqualTo: customer.custCity)
            .where('areaId', isEqualTo: customer.areaRef)
            .get();
    return querySnapshot.docs.isNotEmpty;
  }

  // Tambah customer
  Future<void> addCustomer(CustomerModel customer) async {
    try {
      final formattedCustomerId = formatCustomerId(
        customer.custId,
      ); // Format customerId

      if (await isCustomerIdExists(formattedCustomerId)) {
        throw Exception("Customer ID '$formattedCustomerId' sudah digunakan.");
      }
      if (await isDuplicateCustomer(customer)) {
        throw Exception(
          'Customer dengan nama, kota, dan area yang sama sudah ada.',
        );
      }
      await customerCollection.doc(formattedCustomerId).set({
        'custName': customer.custName,
        'custCity': customer.custCity,
        'areaId': customer.areaRef,
      });
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception:', ''));
    }
  }

  // Update customer
  Future<void> updateCustomer(String custId, CustomerModel customer) async {
    try {
      final formattedCustomerId = formatCustomerId(custId); // Format customerId

      final docSnapshot =
          await customerCollection.doc(formattedCustomerId).get();
      if (!docSnapshot.exists) {
        throw Exception(
          "Customer dengan ID '$formattedCustomerId' tidak ditemukan.",
        );
      }
      final querySnapshot =
          await customerCollection
              .where('custName', isEqualTo: customer.custName)
              .where('custCity', isEqualTo: customer.custCity)
              .where('areaId', isEqualTo: customer.areaRef)
              .get();

      if (querySnapshot.docs.isNotEmpty &&
          querySnapshot.docs[0].id != formattedCustomerId) {
        throw Exception(
          'Customer dengan nama, kota, dan area yang sama sudah ada.',
        );
      }
      await customerCollection.doc(formattedCustomerId).update({
        'custName': customer.custName,
        'custCity': customer.custCity,
        'areaId': customer.areaRef,
      });
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception:', ''));
    }
  }

  // Hapus customer
  Future<void> deleteCustomer(String custId) async {
    try {
      final formattedCustomerId = formatCustomerId(custId); // Format customerId
      await customerCollection.doc(formattedCustomerId).delete();
    } catch (e) {
      throw Exception('Gagal menghapus customer: $e');
    }
  }

  // Fungsi pencarian area berdasarkan areaId atau areaName
  Future<List<CustomerModel>> searchCustomers(String query) async {
    try {
      // Mengambil semua data area dari Firestore
      QuerySnapshot snapshot = await customerCollection.get();

      // Menggunakan regex untuk pencarian case-insensitive pada areaId dan areaName
      List<CustomerModel> customers =
          snapshot.docs
              .map(
                (doc) => CustomerModel.fromDocument(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();

      // Filter data menggunakan query, dengan case-insensitive
      final filteredCustomers =
          customers.where((customer) {
            final areaName =
                _areas
                    .firstWhere(
                      // ignore: unrelated_type_equality_checks
                      (area) => area.areaId == customer.areaRef,
                      orElse: () => AreaModel(areaId: '', areaName: ''),
                    )
                    .areaName;

            return customer.custId.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                customer.custName.toLowerCase().contains(query.toLowerCase()) ||
                customer.custCity.toLowerCase().contains(query.toLowerCase()) ||
                areaName.toLowerCase().contains(query.toLowerCase());
          }).toList();

      return filteredCustomers;
    } catch (e) {
      throw Exception("Gagal mencari customer: $e");
    }
  }

  Future<String> getAreaName(DocumentReference areaRef) async {
    try {
      final areaDoc = await areaRef.get();
      return areaDoc['areaName'] ?? ''; // Ambil nama area dari Firestore
    } catch (e) {
      throw Exception('Gagal mengambil nama area: $e');
    }
  }
}

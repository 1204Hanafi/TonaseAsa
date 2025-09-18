import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tonase_model.dart';
import '../services/tonase_service.dart';

class TonaseInputPage extends StatefulWidget {
  final TonaseModel? existingTonase;

  const TonaseInputPage({super.key, this.existingTonase});

  @override
  State<TonaseInputPage> createState() => _TonaseInputPageState();
}

class _TonaseInputPageState extends State<TonaseInputPage> {
  final TextEditingController dateController = TextEditingController();
  final TextEditingController noSjController = TextEditingController();
  final TextEditingController totalKolianController = TextEditingController();
  final TextEditingController custController = TextEditingController();
  final FocusNode custFocusNode = FocusNode();

  bool get isEditMode => widget.existingTonase != null;

  DocumentReference? selectedCustomerRef;
  Map<String, dynamic>? selectedCustomerData;
  List<Map<String, dynamic>> allCustomers = [];

  int jumlahKolian = 0;
  List<TextEditingController> tonaseControllers = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    fetchCustomers().then((_) {
      if (isEditMode) _initializeEditMode();
    });
    fetchCustomers();
  }

  void _initializeEditMode() {
    final data = widget.existingTonase!;
    selectedDate = data.date;
    dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    noSjController.text = data.noSj;
    jumlahKolian = data.totalKoli;
    totalKolianController.text = data.totalKoli.toString();

    tonaseControllers = data.detailTonase
        .map((val) => TextEditingController(text: val.toString()))
        .toList();

    selectedCustomerRef = data.customerRef;
    final customer = allCustomers.firstWhere(
      (cust) => cust['ref'].id == data.customerRef.id,
      orElse: () => {},
    );
    selectedCustomerData = customer;
    if (customer.isNotEmpty) {
      custController.text =
          '${customer['custName']} [${customer['custCity']}] - ${customer['areaId']} ${customer['areaName']}';
    }
  }

  @override
  void dispose() {
    custController.dispose();
    custFocusNode.dispose();
    noSjController.dispose();
    dateController.dispose();
    totalKolianController.dispose();
    for (final c in tonaseControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> fetchCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('customers')
        .get();
    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final areaRef = data['areaId'] as DocumentReference?;

      String areaId = '';
      String areaName = '';
      if (areaRef != null) {
        final areaDoc = await areaRef.get();
        areaId = areaRef.id;
        areaName = areaDoc.exists ? areaDoc.get('areaName') ?? '' : '';
      }

      tempList.add({
        'custId': doc.id,
        'custName': data['custName'],
        'custCity': data['custCity'],
        'areaId': areaId,
        'areaName': areaName,
        'ref': doc.reference,
      });
    }

    setState(() {
      allCustomers = tempList;
    });
  }

  void _resetForm() {
    setState(() {
      noSjController.clear();
      totalKolianController.clear();
      tonaseControllers.clear();
      jumlahKolian = 0;
      selectedCustomerRef = null;
      selectedCustomerData = null;
      custController.clear();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<void> handleSubmit() async {
    if (selectedCustomerRef == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pelanggan Tidak Ditemukan'),
          content: const Text(
            'Pelanggan belum dipilih atau tidak ditemukan. Ingin tambah pelanggan baru?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Menutup dialog
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/customer');
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tambah'),
            ),
          ],
        ),
      );
      return;
    }

    if (noSjController.text.trim().isEmpty) {
      _showMessage('No Surat Jalan tidak boleh kosong');
      return;
    }

    if (jumlahKolian == 0 || tonaseControllers.any((c) => c.text.isEmpty)) {
      _showMessage('Isi semua tonase kolian terlebih dahulu');
      return;
    }

    try {
      final tonaseList = tonaseControllers
          .map((c) => double.tryParse(c.text) ?? 0.0)
          .toList();
      final totalTonase = tonaseList.fold(0.0, (total, item) => total + item);
      final tonId = isEditMode
          ? widget.existingTonase!.tonId
          : await TonaseService().generateTonId(selectedDate);

      final tonase = TonaseModel(
        tonId: tonId,
        date: selectedDate,
        customerRef: selectedCustomerRef!,
        noSj: noSjController.text,
        totalKoli: jumlahKolian,
        detailTonase: tonaseList,
        totalTonase: totalTonase,
      );
      final service = TonaseService();
      if (widget.existingTonase != null) {
        await service.updateTonase(tonId, tonase);
      } else {
        await service.addTonase(tonase);
      }
      if (!mounted) return;
      _showMessage(
        isEditMode ? 'Data berhasil diperbarui!' : 'Data berhasil disimpan!',
      );
      if (!isEditMode) {
        _resetForm();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan: $e');
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
        title: Text(
          isEditMode ? 'Edit Tonase' : 'Tonase Input',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Pilih Tanggal',
                suffixIcon: IconButton(
                  key: Key('date-field'),
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: Key('sj-number-field'),
              controller: noSjController,
              decoration: InputDecoration(
                labelText: 'No. Surat Jalan',
                hintText: 'Contoh: 01-0001',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            RawAutocomplete<Map<String, dynamic>>(
              textEditingController: custController,
              focusNode: custFocusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return allCustomers.where((cust) {
                  final combined =
                      '${cust['custName']} ${cust['custCity']} ${cust['areaName']}'
                          .toLowerCase();
                  return combined.contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (option) =>
                  '${option['custName'] ?? ''} [${option['custCity'] ?? ''}] - ${option['areaId']} ${option['areaName'] ?? ''}',

              onSelected: (selected) {
                custController.text =
                    '${selected['custName']} [${selected['custCity']}] - ${selected['areaId']} ${selected['areaName']}';
                selectedCustomerRef = selected['ref'];
                selectedCustomerData = selected;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      key: Key('customer-field'),
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Pelanggan',
                        hintText: 'Cari pelanggan...',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        suffixIcon: const Icon(Icons.search),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          key: Key('selected-customer'),
                          title: Text(
                            '${option['custName']} [${option['custCity']}]',
                          ),
                          subtitle: Text(
                            '[${option['areaId']}]${option['areaName']}',
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: Key('koli-count-field'),
              controller: totalKolianController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Kolian',
                hintText: 'Masukkan Jumlah Kolian',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (value) {
                final int kolian = int.tryParse(value) ?? 0;
                setState(() {
                  jumlahKolian = kolian;
                  tonaseControllers = List.generate(
                    kolian,
                    (_) => TextEditingController(),
                  );
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Tonase / Koli',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(jumlahKolian, (index) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width / 2.3,
                  child: TextField(
                    key: Key('weight-field'),
                    controller: tonaseControllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${index + 1}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: Key('save-tonase-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: handleSubmit,
                child: Text(
                  isEditMode ? 'Update' : 'Simpan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

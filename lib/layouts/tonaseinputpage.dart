import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tonase_app/models/area_model.dart';
import 'package:tonase_app/models/customer_model.dart';
import 'package:tonase_app/models/item_model.dart';
import 'package:tonase_app/services/area_service.dart';
import 'package:tonase_app/services/customer_service.dart';
import 'package:tonase_app/services/item_service.dart';
import '../models/tonase_model.dart';
import '../services/tonase_service.dart';

enum JenisTimbang { am, spa, item }

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

  JenisTimbang _selectedTimbang = JenisTimbang.am;
  List<TextEditingController> keteranganControllers = [];

  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();

  final List<Map<String, dynamic>> _addedItems = [];
  double _totalItemTonase = 0.0;

  final AreaService _areaService = AreaService();
  final CustomerService _customerService = CustomerService();
  final ItemService _itemService = ItemService();
  final TonaseService _tonaseService = TonaseService();

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    fetchCustomers().then((_) {
      if (isEditMode) _initializeEditMode();
    });
  }

  void _initializeEditMode() {
    final data = widget.existingTonase!;
    selectedDate = data.date;
    dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    noSjController.text = data.noSj;
    jumlahKolian = data.totalKoli;
    totalKolianController.text = data.totalKoli.toString();

    if (data.detailTonase.isNotEmpty && data.detailTonase.first is Map) {
      setState(() {
        _selectedTimbang = JenisTimbang.spa;
      });

      tonaseControllers = data.detailTonase
          .map((item) =>
              TextEditingController(text: (item['berat'] ?? 0.0).toString()))
          .toList();
      keteranganControllers = data.detailTonase
          .map((item) => TextEditingController(text: item['keterangan'] ?? ''))
          .toList();
    } else {
      setState(() {
        _selectedTimbang = JenisTimbang.am;
      });
      tonaseControllers = data.detailTonase
          .map((val) => TextEditingController(text: val.toString()))
          .toList();
      keteranganControllers =
          List.generate(data.totalKoli, (_) => TextEditingController());
    }

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
    for (final c in keteranganControllers) {
      c.dispose();
    }
    _itemCodeController.dispose();
    _itemQtyController.dispose();
    super.dispose();
  }

  Future<void> fetchCustomers() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('customers').get();
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

    if (mounted) {
      setState(() {
        allCustomers = tempList;
      });
    }
  }

  void _resetForm() {
    setState(() {
      noSjController.clear();
      totalKolianController.clear();
      for (final controller in tonaseControllers) {
        controller.dispose();
      }
      for (final controller in keteranganControllers) {
        controller.dispose();
      }
      tonaseControllers = [];
      keteranganControllers = [];
      jumlahKolian = 0;

      _itemCodeController.clear();
      _itemQtyController.clear();
      _addedItems.clear();
      _totalItemTonase = 0.0;
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

  Future<void> _addItemToList() async {
    final itemCode = _itemCodeController.text.trim().padLeft(6, '0');
    final quantity = int.tryParse(_itemQtyController.text.trim());

    if (itemCode.isEmpty || quantity == null || quantity <= 0) {
      _showMessage('Kode Item dan Jumlah harus diisi dengan benar.');
      return;
    }

    try {
      final itemDoc = await _itemService.itemCollection.doc(itemCode).get();
      if (!itemDoc.exists) {
        _showMessage('Item dengan kode $itemCode tidak ditemukan.');
        return;
      }

      final itemData = ItemModel.fromDocument(itemDoc);

      setState(() {
        _addedItems.add({
          'itemRef': itemDoc.reference,
          'itemName': itemData.itemName,
          'itemUnit': itemData.itemUnit,
          'quantity': quantity,
          'totalWeight': quantity * itemData.itemWeight,
        });
        _calculateTotalItemTonase();
        _itemCodeController.clear();
        _itemQtyController.clear();
        FocusScope.of(context).requestFocus(FocusNode()); // Tutup keyboard
      });
    } catch (e) {
      _showMessage('Gagal mencari item: $e');
    }
  }

  void _calculateTotalItemTonase() {
    _totalItemTonase = _addedItems.fold(
        0.0, (total, item) => total + (item['totalWeight'] as double));
  }

  Future<void> _showItemSearchDialog() async {
    final selectedItem = await showDialog<ItemModel>(
      context: context,
      builder: (context) => const ItemSearchDialog(),
    );
    if (selectedItem != null) {
      _itemCodeController.text = selectedItem.itemId;
    }
  }

  Future<void> handleSubmit() async {
    if (selectedCustomerRef == null) {
      _showMessage('Pelanggan harus dipilih.');
      return;
    }
    if (noSjController.text.trim().isEmpty) {
      _showMessage('No. PK tidak boleh kosong.');
      return;
    }

    try {
      dynamic detailTonaseToSave;
      double finalTotalTonase = 0.0;
      int finalTotalKoli = 0;

      switch (_selectedTimbang) {
        case JenisTimbang.am:
        case JenisTimbang.spa:
          if (jumlahKolian == 0 ||
              tonaseControllers.any((c) => c.text.isEmpty)) {
            _showMessage('Isi semua detail tonase terlebih dahulu.');
            return;
          }
          final tonaseList = tonaseControllers
              .map((c) => double.tryParse(c.text) ?? 0.0)
              .toList();
          finalTotalTonase =
              tonaseList.fold(0.0, (total, item) => total + item);
          finalTotalKoli = jumlahKolian;

          if (_selectedTimbang == JenisTimbang.spa) {
            detailTonaseToSave = [];
            for (int i = 0; i < jumlahKolian; i++) {
              detailTonaseToSave.add({
                'berat': double.tryParse(tonaseControllers[i].text) ?? 0.0,
                'keterangan': keteranganControllers[i].text,
              });
            }
          } else {
            detailTonaseToSave = tonaseList;
          }
          break;

        case JenisTimbang.item:
          if (_addedItems.isEmpty) {
            _showMessage('Tambahkan setidaknya satu item.');
            return;
          }
          finalTotalTonase = _totalItemTonase;
          finalTotalKoli = _addedItems.length;
          detailTonaseToSave = _addedItems
              .map((item) => {
                    'itemRef': item['itemRef'],
                    'quantity': item['quantity'],
                  })
              .toList();
          break;
      }

      final tonId = isEditMode
          ? widget.existingTonase!.tonId
          : await _tonaseService.generateTonId(selectedDate);

      final tonaseData = {
        'date': selectedDate,
        'custId': selectedCustomerRef!,
        'noSj': noSjController.text,
        'totalKoli': finalTotalKoli,
        'detailTonase': detailTonaseToSave,
        'totalTonase': finalTotalTonase,
        'isSended': false,
        'jenisTimbang': _selectedTimbang.name,
      };

      if (isEditMode) {
        await _tonaseService.tonaseCollection.doc(tonId).update(tonaseData);
      } else {
        await _tonaseService.tonaseCollection.doc(tonId).set(tonaseData);
      }

      if (!mounted) return;
      _showMessage(
          isEditMode ? 'Data berhasil diperbarui!' : 'Data berhasil disimpan!');
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
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }

  Future<void> _showAddCustomerDialog() async {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    DocumentReference? areaRef;

    final newCustomerData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Customer Baru'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer ID',
                    counterText: "",
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Customer'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Kota Customer'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<AreaModel>>(
                  future: _areaService.getAreas(),
                  builder: (ctx2, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return const Text('Area tidak ditemukan');
                    }
                    final list = snap.data!;
                    return DropdownButtonFormField<DocumentReference>(
                      decoration: const InputDecoration(labelText: 'Area'),
                      items: list
                          .map((area) => DropdownMenuItem(
                                value: area.reference,
                                child:
                                    Text('[${area.areaId}] ${area.areaName}'),
                              ))
                          .toList(),
                      validator: (v) => v == null ? 'Pilih Area' : null,
                      onChanged: (v) => areaRef = v,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newCustomer = CustomerModel(
                  custId: idCtrl.text.trim().padLeft(5, '0'),
                  custName: nameCtrl.text.trim(),
                  custCity: cityCtrl.text.trim(),
                  areaRef: areaRef!,
                );

                try {
                  await _customerService.addCustomer(newCustomer);

                  final areaDoc = await newCustomer.areaRef.get();

                  if (!ctx.mounted) return;

                  final areaName = areaDoc.get('areaName') ?? '';

                  Navigator.pop(ctx, {
                    'custName': newCustomer.custName,
                    'custCity': newCustomer.custCity,
                    'areaId': newCustomer.areaRef.id,
                    'areaName': areaName,
                    'ref': _customerService.customerCollection
                        .doc(newCustomer.custId),
                  });
                } catch (e) {
                  if (!mounted) return;
                  _showMessage('Gagal menyimpan customer: $e');
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newCustomerData != null) {
      setState(() {
        custController.text =
            '${newCustomerData['custName']} [${newCustomerData['custCity']}] - ${newCustomerData['areaId']} ${newCustomerData['areaName']}';
        selectedCustomerRef = newCustomerData['ref'];
        selectedCustomerData = newCustomerData;

        allCustomers.add(newCustomerData);
      });
    }
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
                labelText: 'No. PK',
                hintText: 'Contoh: 2501.0001',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            RawAutocomplete<Map<String, dynamic>>(
              key: UniqueKey(),
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
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('customer-field'),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.teal),
                          tooltip: 'Tambah Customer Baru',
                          onPressed: _showAddCustomerDialog,
                        ),
                      ),
                    ],
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200),
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
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Jenis Penimbangan',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<JenisTimbang>(
                segments: const <ButtonSegment<JenisTimbang>>[
                  ButtonSegment(
                      value: JenisTimbang.am,
                      label: Text('AM'),
                      tooltip: 'Penimbangan Alat Mobil'),
                  ButtonSegment(
                      value: JenisTimbang.spa,
                      label: Text('SPA'),
                      tooltip: 'Penimbangan Spring'),
                  ButtonSegment(
                      value: JenisTimbang.item,
                      label: Text('ITEM'),
                      tooltip: 'Penimbangan Per Item Barang'),
                ],
                selected: {_selectedTimbang},
                onSelectionChanged: (Set<JenisTimbang> newSelection) {
                  setState(() {
                    _selectedTimbang = newSelection.first;
                    _resetForm();
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.teal,
                  selectedForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedTimbang == JenisTimbang.am ||
                _selectedTimbang == JenisTimbang.spa)
              _buildAmSpaInput(),
            if (_selectedTimbang == JenisTimbang.item) _buildItemInput(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('save-tonase-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: handleSubmit,
                child: Text(
                  isEditMode ? 'Update' : 'Simpan',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmSpaInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('koli-count-field'),
          controller: totalKolianController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah Kolian',
            hintText: 'Masukkan Jumlah Kolian',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          onChanged: (value) {
            final int kolian = int.tryParse(value) ?? 0;
            setState(() {
              jumlahKolian = kolian;
              if (tonaseControllers.length != kolian) {
                for (final c in tonaseControllers) {
                  c.dispose();
                }
                for (final c in keteranganControllers) {
                  c.dispose();
                }
                tonaseControllers =
                    List.generate(kolian, (_) => TextEditingController());
                keteranganControllers =
                    List.generate(kolian, (_) => TextEditingController());
              }
            });
          },
        ),
        const SizedBox(height: 20),
        Text(
          _selectedTimbang == JenisTimbang.spa
              ? 'Detail Ikatan Spring'
              : 'Tonase / Koli',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: jumlahKolian,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (_selectedTimbang == JenisTimbang.spa) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tonaseControllers[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Koli No.${index + 1} (kg)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: keteranganControllers[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Qty No.${index + 1} (pcs)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0))),
                    ),
                  ),
                ],
              );
            } else {
              return TextField(
                controller: tonaseControllers[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Berat Koli ${index + 1} (kg)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0))),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildItemInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _itemCodeController,
                decoration: InputDecoration(
                  labelText: 'Kode Item',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Cari Item',
                    onPressed: _showItemSearchDialog,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _itemQtyController,
                decoration: InputDecoration(
                    labelText: 'Jumlah',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0))),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.teal, size: 40),
              onPressed: _addItemToList,
              tooltip: 'Tambah Item ke Daftar',
            ),
          ],
        ),
        const Divider(height: 24),
        const Text('Daftar Item Ditambahkan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _addedItems.isEmpty
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Belum ada item yang ditambahkan.',
                        style: TextStyle(color: Colors.grey))))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedItems.length,
                itemBuilder: (context, index) {
                  final item = _addedItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      title: Text('${item['itemName']}'),
                      subtitle: Text(
                          '${item['quantity']} ${item['itemUnit']} = ${item['totalWeight']} kg'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _addedItems.removeAt(index);
                            _calculateTotalItemTonase();
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total Tonase Item: ${_totalItemTonase.toStringAsFixed(2)} kg',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class ItemSearchDialog extends StatefulWidget {
  const ItemSearchDialog({super.key});
  @override
  State<ItemSearchDialog> createState() => _ItemSearchDialogState();
}

class _ItemSearchDialogState extends State<ItemSearchDialog> {
  final ItemService _itemService = ItemService();
  List<ItemModel> _allItems = [];
  List<ItemModel> _filteredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _itemService.getItems().then((items) {
      if (mounted) {
        setState(() {
          _allItems = items;
          _filteredItems = items;
          _isLoading = false;
        });
      }
    });
  }

  void _filterItems(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        return item.itemId.contains(lowerCaseQuery) ||
            item.itemName.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari Item'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: _filterItems,
              decoration: const InputDecoration(
                hintText: 'Ketik kode atau nama item...',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(item.itemName),
                          subtitle: Text('ID: ${item.itemId}'),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

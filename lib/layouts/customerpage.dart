import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';

import '../models/customer_model.dart';
import '../models/area_model.dart';
import '../services/customer_service.dart';
import '../services/area_service.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final CustomerService _customerService = CustomerService();
  final AreaService _areaService = AreaService();

  //Data
  final List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];

  //DataTableSource
  late final CustomerDataTableSource _dataSource;

  //UI State
  bool _isLoading = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  //Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataSource = CustomerDataTableSource(
      customers: _filteredCustomers,
      onEdit: _onEdit,
      onDelete: _onDeleteConfirm,
    );
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      // 1. Panggil service secara paralel
      final results = await Future.wait([
        _customerService.getCustomers(),
        _areaService.getAreas(),
      ]);
      final customerList = results[0] as List<CustomerModel>;
      final areaList = results[1] as List<AreaModel>;

      // 2. Pastikan widget masih mounted sebelum lanjut
      if (!mounted) return;

      // 3. Buat lookup map areaRef → areaName
      final areaMap = {
        for (var area in areaList) area.reference: area.areaName,
      };

      // 4. Isi areaName untuk setiap customer
      for (var customer in customerList) {
        customer.areaName = areaMap[customer.areaRef] ?? 'Unknown';
      }

      // 5. Update state
      setState(() {
        _customers
          ..clear()
          ..addAll(customerList);
        _applyFilter('');
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal memuat: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filteredCustomers = query.isEmpty
          ? List.from(_customers)
          : _customers.where((c) {
              return c.custId.toLowerCase().contains(query) ||
                  c.custName.toLowerCase().contains(query) ||
                  c.custCity.toLowerCase().contains(query) ||
                  c.areaName.toLowerCase().contains(query);
            }).toList();
      _dataSource.updateData(_filteredCustomers);
    });
  }

  void _onSort<T extends Comparable<T>>(
    T Function(CustomerModel) getField,
    int columnIndex,
  ) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _filteredCustomers.sort((a, b) {
        final cmp = getField(a).compareTo(getField(b));
        return _sortAscending ? cmp : -cmp;
      });
      _dataSource.updateData(_filteredCustomers);
    });
  }

  Future<void> _onEdit(CustomerModel customer) async {
    await _showAddEditDialog(customer: customer);
  }

  Future<void> _onDeleteConfirm(String custId) async {
    final originalCustomer = _customers.firstWhere((c) => c.custId == custId);
    bool isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus'),
              content: const Text('Yakin ingin menghapus customer ini?'),
              actions: [
                if (!isDeleting)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                ElevatedButton(
                  key: Key('confirm-delete-button'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() => isDeleting = true);
                          Navigator.pop(ctx, true);
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        _showMessage(
          'Menghapus customer...',
          duration: const Duration(seconds: 10),
        );

        setState(() {
          _customers.removeWhere((c) => c.custId == custId);
          _applyFilter(_searchController.text);
        });

        await _customerService.deleteCustomer(custId);

        if (!mounted) return;
        _showMessage('Berhasil dihapus');
      } catch (e) {
        setState(() {
          _customers.add(originalCustomer);
        });

        if (!mounted) return;
        _showError('Gagal Hapus: ${e.toString()}');
      }
    }
  }

  Future<void> _showAddEditDialog({CustomerModel? customer}) async {
    final isEdit = customer != null;
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: customer?.custId);
    final nameCtrl = TextEditingController(text: customer?.custName);
    final cityCtrl = TextEditingController(text: customer?.custCity);
    DocumentReference? areaRef = customer?.areaRef;
    bool isSaving = false;

    final areasFuture = _areaService.getAreas();
    CustomerModel? originalCustomer;
    if (isEdit) {
      originalCustomer = _customers.firstWhere(
        (c) => c.custId == customer.custId,
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Customer' : 'Tambah Customer'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        key: Key('customer-id-field'),
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer ID',
                        ),
                        enabled: !isEdit,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: Key('customer-name-field'),
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: Key('customer-city-field'),
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer City',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<AreaModel>>(
                        future: areasFuture,
                        builder: (ctx2, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final list = snap.data!;
                          return DropdownButtonFormField<DocumentReference>(
                            key: Key('dropdown-area'),
                            initialValue: areaRef,
                            decoration: const InputDecoration(
                              labelText: 'Area',
                            ),
                            items: list
                                .map(
                                  (area) => DropdownMenuItem(
                                    key: Key('dropdown area'),
                                    value: area.reference,
                                    child: Text(area.areaName),
                                  ),
                                )
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
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                ElevatedButton(
                  key: Key('save-customer-button'),
                  onPressed: isSaving
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(ctx, true);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final cust = CustomerModel(
        custId: idCtrl.text.trim(),
        custName: nameCtrl.text.trim(),
        custCity: cityCtrl.text.trim(),
        areaRef: areaRef!,
      );
      try {
        _showMessage(
          'Memproses data customer....',
          duration: const Duration(seconds: 10),
        );

        final index = _customers.indexWhere((c) => c.custId == cust.custId);
        setState(() {
          if (index != -1) {
            // Edit existing
            _customers[index] = cust;
          } else {
            // Add new
            _customers.insert(0, cust);
          }
          _applyFilter(_searchController.text);
        });

        if (isEdit) {
          await _customerService.updateCustomer(cust.custId, cust);
        } else {
          await _customerService.addCustomer(cust);
        }

        if (!mounted) return;
        _showMessage(isEdit ? 'Berhasil diperbarui' : 'Berhasil ditambahkan');
      } catch (e) {
        setState(() {
          if (isEdit && originalCustomer != null) {
            final rollbackIndex = _customers.indexWhere(
              (c) => c.custId == cust.custId,
            );
            if (rollbackIndex != -1) {
              _customers[rollbackIndex] = originalCustomer;
            }
          } else {
            _customers.removeWhere((c) => c.custId == cust.custId);
          }
          _applyFilter(_searchController.text);
        });

        if (!mounted) return;
        _showError('Gagal Menyimpan: ${e.toString()}');
      } finally {
        isSaving = false;
      }
    }

    idCtrl.dispose();
    nameCtrl.dispose();
    cityCtrl.dispose();
  }

  Future<void> _downloadTemplate() async {
    try {
      // 1. Buat konten CSV
      final List<List<String>> csvData = [
        ['custId', 'custName', 'custCity', 'areaId'], // Header
        ['', '', '', ''], // Contoh baris kosong
      ];

      final String csvContent = const ListToCsvConverter().convert(csvData);

      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        _showMessage('Izin penyimpanan diperlukan');
        return;
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = '${directory.path}/customer_template.csv';
      final file = File(filePath);

      await file.writeAsString(csvContent);

      _showMessage('Template berhasil disimpan di:\n${file.path}');
    } catch (e) {
      _showMessage('Gagal menyimpan template: ${e.toString()}');
    }
  }

  Future<void> _importCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.isEmpty || rows.first.length != 4) {
      _showError('Format CSV Tidak Valid');
      return;
    }
    setState(() => _isLoading = true);
    try {
      //skip header
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        final area = (await _areaService.getAreas())
            .firstWhere(
              (a) => a.areaId == r[3].toString(),
              orElse: () => AreaModel(areaId: '', areaName: ''),
            )
            .reference;
        await _customerService.addCustomer(
          CustomerModel(
            custId: r[0].toString(),
            custName: r[1].toString(),
            custCity: r[2].toString(),
            areaRef: area!,
          ),
        );
      }
      if (!mounted) return;
      _showMessage('Import Berhasil');
      await _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal Import: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

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
        title: const Text(
          'Customers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download,
              semanticLabel: 'Download Template',
            ),
            onPressed: _downloadTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, semanticLabel: 'Import CSV'),
            onPressed: _importCSV,
          ),
          IconButton(
            key: Key('refresh-button'),
            icon: const Icon(Icons.refresh, semanticLabel: 'Muat Ulang'),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: _applyFilter,
              decoration: InputDecoration(
                hintText: 'Cari ID, Nama, Kota, Area...',
                prefixIcon: const Icon(Icons.search, semanticLabel: 'Cari'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, semanticLabel: 'Bersihkan'),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter('');
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: PaginatedDataTable(
                      header: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daftar Customer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            key: Key('add-customer-button'),
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Customer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      headingRowColor: WidgetStateProperty.all<Color>(
                        Colors.teal,
                      ),
                      columns: [
                        const DataColumn(
                          label: Text(
                            'No',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: const Text(
                            'ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onSort: (ci, _) => _onSort((c) => c.custId, ci),
                        ),
                        DataColumn(
                          label: const Text(
                            'Nama',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onSort: (ci, _) => _onSort((c) => c.custName, ci),
                        ),
                        DataColumn(
                          label: const Text(
                            'Kota',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onSort: (ci, _) => _onSort((c) => c.custCity, ci),
                        ),
                        DataColumn(
                          label: const Text(
                            'Area',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onSort: (ci, _) => _onSort((c) => c.areaName, ci),
                        ),
                        const DataColumn(
                          label: Text(
                            'Aksi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      source: _dataSource,
                      rowsPerPage: 10,
                      columnSpacing: 20,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      showFirstLastButtons: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomerDataTableSource extends DataTableSource {
  List<CustomerModel> customers;
  final void Function(CustomerModel) onEdit;
  final void Function(String) onDelete;

  CustomerDataTableSource({
    required this.customers,
    required this.onEdit,
    required this.onDelete,
  });

  void updateData(List<CustomerModel> newData) {
    customers = newData;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final c = customers[index];
    return DataRow(
      cells: [
        DataCell(Center(child: Text('${index + 1}'))),
        DataCell(Text(c.custId)),
        DataCell(Text(c.custName)),
        DataCell(Text(c.custCity)),
        DataCell(Text('${c.areaRef.id} - ${c.areaName}')),
        DataCell(
          Center(
            child: PopupMenuButton<String>(
              key: Key('select-action'),
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit(c);
                } else if (value == 'delete') {
                  onDelete(c.custId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  key: Key('edit-customer-button'),
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  key: Key('delete-customer-button'),
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => customers.length;

  @override
  int get selectedRowCount => 0;
}

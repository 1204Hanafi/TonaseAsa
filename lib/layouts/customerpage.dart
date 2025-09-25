import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/area_model.dart';
import '../models/customer_model.dart';
import '../services/area_service.dart';
import '../services/customer_service.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final CustomerService _customerService = CustomerService();
  final AreaService _areaService = AreaService();

  final List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];
  CustomerDataTableSource? _dataSource;

  bool _isLoading = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;

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
      final results = await Future.wait([
        _customerService.getCustomers(),
        _areaService.getAreas(),
      ]);
      final customerList = results[0] as List<CustomerModel>;
      final areaList = results[1] as List<AreaModel>;

      if (!mounted) return;

      final areaMap = {
        for (var area in areaList) area.reference: area.areaName,
      };

      for (var customer in customerList) {
        customer.areaName = areaMap[customer.areaRef] ?? 'Unknown';
      }

      setState(() {
        _customers
          ..clear()
          ..addAll(customerList);
        _applyFilter(_searchController.text);
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal memuat: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _dataSource!.updateData(_filteredCustomers);
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
      _dataSource!.updateData(_filteredCustomers);
    });
  }

  Future<void> _onEdit(CustomerModel customer) async {
    await _showAddEditDialog(customer: customer);
  }

  Future<void> _onDeleteConfirm(String custId) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Konfirmasi Hapus'),
              content: const Text('Yakin ingin menghapus customer ini?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Hapus',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));

    if (confirmed == true) {
      try {
        await _customerService.deleteCustomer(custId);
        _showMessage('Berhasil dihapus');
        await _loadCustomers();
      } catch (e) {
        _showError('Gagal Hapus: ${_getErrorMessage(e)}');
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

    final areasFuture = _areaService.getAreas();

    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(isEdit ? 'Edit Customer' : 'Tambah Customer'),
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
                        enabled: !isEdit,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Customer Name'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: cityCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Customer City'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib Diisi' : null,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<AreaModel>>(
                        future: areasFuture,
                        builder: (ctx2, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snap.hasData || snap.data!.isEmpty) {
                            return const Text('Area tidak ditemukan');
                          }
                          final list = snap.data!;
                          // Pastikan areaRef yang ada valid
                          if (areaRef != null &&
                              !list.any((a) => a.reference == areaRef)) {
                            areaRef = null;
                          }
                          return DropdownButtonFormField<DocumentReference>(
                            initialValue: areaRef,
                            decoration:
                                const InputDecoration(labelText: 'Area'),
                            items: list
                                .map((area) => DropdownMenuItem(
                                      value: area.reference,
                                      child: Text(
                                          '[${area.areaId}] ${area.areaName}'),
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
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ));

    if (saved == true) {
      final cust = CustomerModel(
        custId: idCtrl.text.trim().padLeft(5, '0'),
        custName: nameCtrl.text.trim(),
        custCity: cityCtrl.text.trim(),
        areaRef: areaRef!,
      );
      try {
        if (isEdit) {
          await _customerService.updateCustomer(cust.custId, cust);
        } else {
          await _customerService.addCustomer(cust);
        }
        await _loadCustomers();
        if (!mounted) return;
        _showMessage(isEdit ? 'Berhasil diperbarui' : 'Berhasil ditambahkan');
      } catch (e) {
        if (!mounted) return;
        _showError(
            'Gagal Menyimpan: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final List<List<String>> csvData = [
        ['custId', 'custName', 'custCity', 'areaId'],
      ];
      final String csvContent = const ListToCsvConverter().convert(csvData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

      await FileSaver.instance.saveFile(
        name: 'customer_template.csv',
        bytes: bytes,
        mimeType: MimeType.text,
      );

      _showMessage('Template berhasil diekspor.');
    } catch (e) {
      _showError('Gagal menyimpan template: ${e.toString()}');
    }
  }

  Future<void> _importCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null) {
      _showMessage('Tidak ada file yang dipilih.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uint8List? fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        throw Exception("Gagal membaca file.");
      }
      final String content = utf8.decode(fileBytes);

      final List<List<dynamic>> rows =
          const CsvToListConverter(eol: '\n').convert(content);

      if (rows.length < 2) {
        throw Exception('File CSV kosong atau hanya berisi header.');
      }

      final areas = await _areaService.getAreas();
      final areaMap = {for (var area in areas) area.areaId: area.reference};

      final batch = FirebaseFirestore.instance.batch();

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 4) continue;

        final custId = row[0].toString().trim().padLeft(5, '0');
        final custName = row[1].toString().trim();
        final custCity = row[2].toString().trim();
        final areaId = row[3].toString().trim();
        final areaRef = areaMap[areaId];

        if (custId.isNotEmpty && areaRef != null) {
          final docRef = _customerService.customerCollection.doc(custId);
          batch.set(docRef, {
            'custName': custName,
            'custCity': custCity,
            'areaId': areaRef,
          });
        }
      }

      await batch.commit();

      if (!mounted) return;
      _showMessage('${rows.length - 1} data berhasil diimpor.');
      await _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      _showError(
          'Gagal memproses file CSV: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(Object e) =>
      e is AreaException ? e.message : e.toString();

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showMessage(String msg,
          {Duration duration = const Duration(seconds: 2)}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), duration: duration));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Template',
              onPressed: _downloadTemplate),
          IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import CSV',
              onPressed: _importCSV),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: _loadCustomers),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width <= 720
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: Colors.teal,
              tooltip: 'Tambah Customer',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: _applyFilter,
              decoration: InputDecoration(
                hintText: 'Cari ID, Nama, Kota, Area...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                : _buildResponsiveDataTable(),
          )
        ],
      ),
    );
  }

  Widget _buildResponsiveDataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return _buildDesktopDataTable();
        } else {
          return _buildMobileListView();
        }
      },
    );
  }

  Widget _buildMobileListView() {
    return ListView.builder(
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final c = _filteredCustomers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.teal,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${[c.custId]} ${c.custName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context)
                              .style
                              .copyWith(color: Colors.black54),
                          children: <TextSpan>[
                            const TextSpan(
                                text: 'Kota: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '${c.custCity}\n'),
                            const TextSpan(
                                text: 'Area: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '${[c.areaRef.id]} ${c.areaName}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _onEdit(c);
                    } else if (value == 'delete') {
                      _onDeleteConfirm(c.custId);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit')
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete')
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopDataTable() {
    final minTableWidth = 900.0;
    final defaultRowsPerPage = 10;
    final availableRows = (_dataSource?.rowCount ?? 0);
    final rowsPerPage = availableRows > defaultRowsPerPage
        ? defaultRowsPerPage
        : (availableRows == 0 ? 1 : availableRows);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: PaginatedDataTable(
                header: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daftar Customer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Customer'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
                columns: [
                  _buildDataColumn('No'),
                  _buildDataColumn('ID',
                      onSort: (ci, _) => _onSort((c) => c.custId, ci)),
                  _buildDataColumn('Nama',
                      onSort: (ci, _) => _onSort((c) => c.custName, ci)),
                  _buildDataColumn('Kota',
                      onSort: (ci, _) => _onSort((c) => c.custCity, ci)),
                  _buildDataColumn('Area',
                      onSort: (ci, _) => _onSort((c) => c.areaName, ci)),
                  _buildDataColumn('Aksi'),
                ],
                source: _dataSource!,
                rowsPerPage: rowsPerPage,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                showFirstLastButtons: true,
                columnSpacing: 20,
                horizontalMargin: 16,
                headingRowColor: WidgetStateProperty.all<Color>(Colors.teal),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _buildDataColumn(String label, {Function(int, bool)? onSort}) {
    return DataColumn(
        onSort: onSort,
        label: Expanded(
            child: Center(
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        )));
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
    return DataRow(cells: [
      DataCell(Center(child: Text('${index + 1}'))),
      DataCell(Center(child: Text(c.custId))),
      DataCell(Text(c.custName)),
      DataCell(Text(c.custCity)),
      DataCell(Text('${c.areaRef.id} - ${c.areaName}')),
      DataCell(
        Center(
            child: PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit(c);
            } else if (value == 'delete') {
              onDelete(c.custId);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit')
                ])),
            PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete')
                ])),
          ],
        )),
      )
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => customers.length;
  @override
  int get selectedRowCount => 0;
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';

class ItemPage extends StatefulWidget {
  const ItemPage({super.key});

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  final ItemService _itemService = ItemService();

  final List<ItemModel> _items = [];
  List<ItemModel> _filteredItems = [];
  ItemDataTableSource? _dataSource;

  bool _isLoading = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataSource = ItemDataTableSource(
      items: _filteredItems,
      onEdit: _onEditItem,
      onDelete: _onDeleteItem,
    );
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final data = await _itemService.getItems();
      if (!mounted) return;
      _items
        ..clear()
        ..addAll(data);
      _applyFilter('');
    } catch (e) {
      _showError('Gagal memuat data: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredItems = q.isEmpty
          ? List.from(_items)
          : _items
              .where((i) =>
                  i.itemId.toLowerCase().contains(q) ||
                  i.itemName.toLowerCase().contains(q) ||
                  i.itemUnit.toLowerCase().contains(q))
              .toList();
      _dataSource!.updateData(_filteredItems);
    });
  }

  void _onSort<T extends Comparable<T>>(
    T Function(ItemModel) getField,
    int columnIndex,
  ) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _filteredItems.sort((a, b) {
        final cmp = getField(a).compareTo(getField(b));
        return _sortAscending ? cmp : -cmp;
      });
      _dataSource!.updateData(_filteredItems);
    });
  }

  Future<void> _onEditItem(ItemModel item) async {
    await _showAddEditDialog(item: item);
  }

  Future<void> _onDeleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Yakin ingin menghapus item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _itemService.deleteItem(id);
        _showMessage('Berhasil dihapus');
        await _loadItems();
      } catch (e) {
        _showError('Gagal hapus: ${_getErrorMessage(e)}');
      }
    }
  }

  Future<void> _showAddEditDialog({ItemModel? item}) async {
    final isEdit = item != null;
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: item?.itemId);
    final nameCtrl = TextEditingController(text: item?.itemName);
    final weightCtrl = TextEditingController(text: item?.itemWeight.toString());
    final unitCtrl = TextEditingController(text: item?.itemUnit);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Item' : 'Tambah Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('item-id-field'),
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item ID (6 Digit Angka)',
                  ),
                  enabled: !isEdit,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-name-field'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Item'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-weight-field'),
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'Berat (kg)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-unit-field'),
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
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
            key: const Key('save-item-button'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newItem = ItemModel(
        itemId: idCtrl.text.trim().padLeft(6, '0'),
        itemName: nameCtrl.text.trim(),
        itemWeight: double.tryParse(weightCtrl.text.trim()) ?? 0.0,
        itemUnit: unitCtrl.text.trim(),
      );
      try {
        if (isEdit) {
          await _itemService.updateItem(item.itemId, newItem);
        } else {
          await _itemService.addItem(newItem);
        }
        await _loadItems();
        if (!mounted) return;
        _showMessage(isEdit ? 'Berhasil diperbarui' : 'Berhasil ditambahkan');
      } catch (e) {
        if (!mounted) return;
        _showError('Gagal simpan: ${_getErrorMessage(e)}');
      }
    }

    idCtrl.dispose();
    nameCtrl.dispose();
    weightCtrl.dispose();
    unitCtrl.dispose();
  }

  String _getErrorMessage(Object e) => e.toString();

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _loadItems,
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width <= 720
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: Colors.teal,
              tooltip: 'Tambah Item',
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
                hintText: 'Cari ID, Nama, atau Satuan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
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
          ),
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
    if (_filteredItems.isEmpty) {
      return const Center(child: Text('Tidak ada item.'));
    }
    return ListView.builder(
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ID: ${item.itemId}'),
                      Text('Berat: ${item.itemWeight} kg | ${item.itemUnit}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _onEditItem(item);
                    } else if (value == 'delete') {
                      _onDeleteItem(item.itemId);
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
                    const Text('Daftar Item',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Item'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
                columns: [
                  _buildDataColumn('No'),
                  _buildDataColumn('ID',
                      onSort: (ci, _) => _onSort((i) => i.itemId, ci)),
                  _buildDataColumn('Nama',
                      onSort: (ci, _) => _onSort((i) => i.itemName, ci)),
                  _buildDataColumn('Berat'),
                  _buildDataColumn('Satuan',
                      onSort: (ci, _) => _onSort((i) => i.itemUnit, ci)),
                  _buildDataColumn('Aksi'),
                ],
                source: _dataSource!,
                rowsPerPage: rowsPerPage,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                showFirstLastButtons: true,
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class ItemDataTableSource extends DataTableSource {
  List<ItemModel> items;
  final void Function(ItemModel) onEdit;
  final void Function(String) onDelete;

  ItemDataTableSource({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  void updateData(List<ItemModel> newData) {
    items = newData;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final item = items[index];
    return DataRow(
      cells: [
        DataCell(Center(child: Text('${index + 1}'))),
        DataCell(Center(child: Text(item.itemId))),
        DataCell(Text(item.itemName)),
        DataCell(Center(child: Text('${item.itemWeight}'))),
        DataCell(Center(child: Text(item.itemUnit))),
        DataCell(
          Center(
            child: PopupMenuButton<String>(
              key: const Key('select-action'),
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit(item);
                } else if (value == 'delete') {
                  onDelete(item.itemId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  key: Key('edit-item-button'),
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
                  key: Key('delete-item-button'),
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
  int get rowCount => items.length;

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

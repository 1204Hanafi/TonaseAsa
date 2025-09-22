import 'package:flutter/material.dart';
import '../services/area_service.dart';
import '../models/area_model.dart';

class AreaPage extends StatefulWidget {
  const AreaPage({super.key});

  @override
  State<AreaPage> createState() => _AreaPageState();
}

class _AreaPageState extends State<AreaPage> {
  final AreaService _areaService = AreaService();

  // Data & DataSource
  final List<AreaModel> _areas = [];
  List<AreaModel> _filteredAreas = [];
  AreaDataTableSource? _dataSource;

  // State UI
  bool _isLoading = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataSource = AreaDataTableSource(
      areas: _filteredAreas,
      onEdit: _onEditArea,
      onDelete: _onDeleteArea,
    );
    _loadAreas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoading = true);
    try {
      final data = await _areaService.getAreas();
      if (!mounted) return;
      _areas
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
      _filteredAreas = q.isEmpty
          ? List.from(_areas)
          : _areas
              .where(
                (a) =>
                    a.areaId.contains(q) ||
                    a.areaName.toLowerCase().contains(q),
              )
              .toList();
      _dataSource!.updateData(_filteredAreas);
    });
  }

  void _onSort<T extends Comparable<T>>(
    T Function(AreaModel) getField,
    int columnIndex,
  ) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _filteredAreas.sort((a, b) {
        final cmp = getField(a).compareTo(getField(b));
        return _sortAscending ? cmp : -cmp;
      });
      _dataSource!.updateData(_filteredAreas);
    });
  }

  Future<void> _onEditArea(AreaModel area) async {
    await _showAddEditDialog(area: area);
  }

  void _onDeleteArea(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Yakin ingin menghapus area ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: Key('confirm-delete-button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _areaService.deleteArea(id);
        _showMessage('Berhasil dihapus');
        await _loadAreas();
      } catch (e) {
        _showError('Gagal hapus: ${_getErrorMessage(e)}');
      }
    }
  }

  Future<void> _showAddEditDialog({AreaModel? area}) async {
    final isEdit = area != null;
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: area?.areaId);
    final nameCtrl = TextEditingController(text: area?.areaName);

    // Tampilkan dialog, tanpa async di dalam builder
    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isEdit ? 'Edit Area' : 'Tambah Area'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: Key('area-id-field'),
                controller: idCtrl,
                decoration: const InputDecoration(labelText: 'ID Area'),
                enabled: !isEdit,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: Key('area-name-field'),
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Area'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: Key('save-area-button'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    // Setelah dialog ditutup:
    if (didSave == true) {
      final id = idCtrl.text.trim();
      final name = nameCtrl.text.trim();
      final newArea = AreaModel(areaId: id, areaName: name);

      try {
        if (isEdit) {
          await _areaService.updateArea(area.areaId, newArea);
        } else {
          await _areaService.addArea(newArea);
        }
        await _loadAreas();
        if (!mounted) return;
        _showMessage(isEdit ? 'Berhasil diperbarui' : 'Berhasil ditambahkan');
      } catch (e) {
        if (!mounted) return;
        _showError('Gagal simpan: ${_getErrorMessage(e)}');
      }
    }

    idCtrl.dispose();
    nameCtrl.dispose();
  }

  String _getErrorMessage(Object e) =>
      e is AreaException ? e.message : e.toString();

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        title:
            const Text('Area', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, semanticLabel: 'Muat ulang'),
            onPressed: _loadAreas,
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width <= 720
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: Colors.teal,
              tooltip: 'Tambah Area',
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
                hintText: 'Cari ID atau Nama...',
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
    return ListView.builder(
      itemCount: _filteredAreas.length,
      itemBuilder: (context, index) {
        final area = _filteredAreas[index];
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
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${[area.areaId]} ${area.areaName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ])),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _onEditArea(area);
                          } else if (value == 'delete') {
                            _onDeleteArea(area.areaId);
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
                    ])));
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
                    const Text('Daftar Area',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Area'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
                columns: [
                  _buildDataColumn('No'),
                  _buildDataColumn('ID',
                      onSort: (ci, _) => _onSort((a) => a.areaId, ci)),
                  _buildDataColumn('Nama',
                      onSort: (ci, _) => _onSort((a) => a.areaName, ci)),
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

class AreaDataTableSource extends DataTableSource {
  List<AreaModel> areas;
  final void Function(AreaModel) onEdit;
  final void Function(String) onDelete;

  AreaDataTableSource({
    required this.areas,
    required this.onEdit,
    required this.onDelete,
  });

  void updateData(List<AreaModel> newData) {
    areas = newData;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final area = areas[index];
    return DataRow(
      cells: [
        DataCell(Center(child: Text('${index + 1}'))),
        DataCell(Center(child: Text(area.areaId))),
        DataCell(Text(area.areaName)),
        DataCell(
          Center(
            child: PopupMenuButton<String>(
              key: Key('select-action'),
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit(area);
                } else if (value == 'delete') {
                  onDelete(area.areaId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  key: Key('edit-area-button'),
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
                  key: Key('delete-area-button'),
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
  int get rowCount => areas.length;

  @override
  int get selectedRowCount => 0;
}

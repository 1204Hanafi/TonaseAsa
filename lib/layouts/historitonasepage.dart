import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tonase_model.dart';
import '../services/tonase_service.dart';
import 'homepage.dart';

class HistoriTonasePage extends StatefulWidget {
  const HistoriTonasePage({super.key});

  @override
  State<HistoriTonasePage> createState() => _HistoriTonasePageState();
}

class _HistoriTonasePageState extends State<HistoriTonasePage> {
  // Controllers
  final _searchController = TextEditingController();
  final _dateRangeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // Data & Services
  HistoriDataTableSource? _dataSource;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _fetchTonase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateRangeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchTonase() async {
    setState(() => _isLoading = true);
    try {
      final data = await TonaseService().getSentTonase();
      if (!mounted) return;

      if (_dataSource == null) {
        _dataSource = HistoriDataTableSource(
          tonaseList: data,
          onViewDetail: _onViewDetails,
        );
      } else {
        _dataSource!.updateData(data);
      }

      setState(() => _isLoading = false);
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Gagal Memuat Data: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      _dateRangeController.text =
          '${DateFormat('dd/MM/yyyy').format(picked.start)} - ${DateFormat('dd/MM/yyyy').format(picked.end)}';
      _startDateController.text = DateFormat('dd/MM/yyyy').format(picked.start);
      _endDateController.text = DateFormat('dd/MM/yyyy').format(picked.end);
      _applyFilters();
    }
  }

  void _applyFilters() {
    if (_dataSource != null) {
      _dataSource!.applyFilter(
        search: _searchController.text,
        start: _startDateController.text,
        end: _endDateController.text,
      );
      // Memicu rebuild untuk memperbarui tampilan mobile
      setState(() {});
    }
  }

  void _clearFilters() {
    _dateRangeController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _searchController.clear();
    _applyFilters();
  }

  void _handleUnmark() async {
    final items = _dataSource?.getSelectedItems() ?? [];
    if (items.isEmpty) {
      _showMessage('Tidak ada data yang dipilih untuk di-Unmark');
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var item in items) {
        batch.update(
          FirebaseFirestore.instance.collection('tonase').doc(item.tonId),
          {'isSended': false},
        );
      }
      await batch.commit();

      if (!mounted) return;
      _showMessage('Berhasil Unmark Data.');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal Unmark: $e');
    }
  }

  void _onViewDetails(TonaseModel item) {
    const maxPerCol = 10;
    final List<String> list;
    if (item.detailTonase.isNotEmpty && item.detailTonase.first is Map) {
      list = item.detailTonase.asMap().entries.map((e) {
        final detailMap = e.value as Map;
        final berat = (detailMap['berat'] as num?)?.toDouble() ?? 0.0;
        final keterangan = detailMap['keterangan']?.toString() ?? '';
        return '${e.key + 1}. ${berat.toStringAsFixed(2)} kg [$keterangan pcs]';
      }).toList();
    } else {
      list = item.detailTonase.asMap().entries.map((e) {
        final berat = (e.value as num?)?.toDouble() ?? 0.0;
        return '${e.key + 1}. ${berat.toStringAsFixed(2)} kg';
      }).toList();
    }
    final cols = (list.length / maxPerCol).ceil();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detail Tonase'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLabelText('Nama Toko:', item.custName),
              _buildLabelText('Kota:', item.custCity),
              _buildLabelText('No. PK:', item.noSj),
              _buildLabelText(
                  'Total Tonase:', '${item.totalTonase.toStringAsFixed(2)} kg'),
              const SizedBox(height: 8),
              const Text('Rincian:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(cols, (col) {
                    final start = col * maxPerCol;
                    final end = (start + maxPerCol).clamp(0, list.length);
                    final slice = list.sublist(start, end);
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: slice.map((s) => Text(s)).toList(),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histori Tonase',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTonase,
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResponsiveDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          controller: _dateRangeController,
          readOnly: true,
          onTap: _selectDateRange,
          decoration: InputDecoration(
            labelText: 'Tanggal',
            hintText: 'Pilih Rentang Tanggal',
            suffixIcon: const Icon(Icons.date_range),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _handleUnmark,
                icon: const Icon(Icons.undo),
                label: const Text('Unmark'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveDataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return _buildDesktopDataTable(); // Tampilan desktop
        } else {
          return _buildMobileListView(); // Tampilan mobile
        }
      },
    );
  }

  Widget _buildMobileListView() {
    final items = _dataSource?.filteredRows ?? [];
    final areAllSelected =
        items.isNotEmpty && _dataSource?.selectedRowCount == items.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24.0,
                    width: 48.0,
                    child: Tooltip(
                      message:
                          areAllSelected ? 'Batal Pilih Semua' : 'Pilih Semua',
                      child: Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: areAllSelected,
                        onChanged: (bool? value) {
                          if (value == true) {
                            _dataSource?.selectAll();
                          } else {
                            _dataSource?.clearSelection();
                          }
                          setState(() {});
                        },
                        activeColor: Colors.teal,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Text('All',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari Toko, Kota, atau No. PK...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text("Tidak ada data untuk ditampilkan."))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _dataSource?.isSelected(item) ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      color: isSelected ? Colors.orange[300] : null,
                      child: InkWell(
                        onTap: () {
                          setState(() => _dataSource?.toggleSelection(item));
                        },
                        onLongPress: () => _onViewDetails(item),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(context)
                                            .style
                                            .copyWith(color: Colors.black),
                                        children: [
                                          TextSpan(
                                            text: item.custName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                            text: ' | ${item.custCity}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: item.isSended
                                            ? Colors.green[100]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.isSended ? 'Terkirim' : 'Belum',
                                        style: TextStyle(
                                          color: item.isSended
                                              ? Colors.green[800]
                                              : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Baris 2: Area
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context)
                                      .style
                                      .copyWith(color: Colors.black87),
                                  children: [
                                    const TextSpan(
                                        text: 'Area: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(
                                        text:
                                            '[${item.areaId}] ${item.areaName}'),
                                  ],
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context)
                                      .style
                                      .copyWith(color: Colors.black87),
                                  children: [
                                    const TextSpan(
                                        text: 'No.PK: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: '${item.noSj} | '),
                                    const TextSpan(
                                        text: 'Tgl: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(
                                        text: DateFormat('dd MMM yyyy, HH:mm')
                                            .format(item.date)),
                                  ],
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context)
                                              .style
                                              .copyWith(
                                                  fontSize: 15,
                                                  color: Colors.black),
                                          children: <TextSpan>[
                                            const TextSpan(
                                                text: 'Total Koli: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            TextSpan(text: '${item.totalKoli}'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context)
                                              .style
                                              .copyWith(
                                                  fontSize: 15,
                                                  color: Colors.black),
                                          children: <TextSpan>[
                                            const TextSpan(
                                                text: 'Total Tonase: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            TextSpan(
                                                text:
                                                    '${item.totalTonase.toStringAsFixed(2)} kg'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.visibility,
                                        size: 18, color: Colors.teal),
                                    label: const Text('Detail',
                                        style: TextStyle(color: Colors.teal)),
                                    onPressed: () => _onViewDetails(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
                      const Text('Data Riwayat Tonase',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 250,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  showCheckboxColumn: true,
                  onSelectAll: (all) {
                    if (all == null) return;
                    setState(() => all
                        ? _dataSource!.selectAll()
                        : _dataSource!.clearSelection());
                  },
                  headingRowColor: WidgetStateProperty.all<Color>(Colors.teal),
                  columns: [
                    _buildDataColumn('Tanggal'),
                    _buildDataColumn('Toko'),
                    _buildDataColumn('No. PK'),
                    _buildDataColumn('Area'),
                    _buildDataColumn('Koli', numeric: true),
                    _buildDataColumn('Tonase', numeric: true),
                    _buildDataColumn('Status'),
                    _buildDataColumn('Aksi'),
                  ],
                  source: _dataSource ??
                      HistoriDataTableSource(
                          tonaseList: [], onViewDetail: (_) {}),
                  rowsPerPage: rowsPerPage,
                  showFirstLastButtons: true,
                ),
              ),
            ));
      },
    );
  }

  DataColumn _buildDataColumn(String label, {bool numeric = false}) {
    return DataColumn(
      numeric: numeric,
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class HistoriDataTableSource extends DataTableSource {
  final DateFormat _formatter = DateFormat('dd/MM/yyyy');
  final void Function(TonaseModel) onViewDetail;
  List<TonaseModel> _all = [];
  List<TonaseModel> _filtered = [];
  final Set<TonaseModel> _selectedRows = {};

  HistoriDataTableSource({
    required List<TonaseModel> tonaseList,
    required this.onViewDetail,
  }) {
    updateData(tonaseList);
  }

  List<TonaseModel> get filteredRows => _filtered;
  bool isSelected(TonaseModel item) => _selectedRows.contains(item);

  void toggleSelection(TonaseModel item) {
    _selectedRows.contains(item)
        ? _selectedRows.remove(item)
        : _selectedRows.add(item);
    notifyListeners();
  }

  void updateData(List<TonaseModel> newList) {
    _all = newList..sort((a, b) => b.date.compareTo(a.date));
    _filtered = List.from(_all);
    notifyListeners();
  }

  void applyFilter(
      {required String search, required String start, required String end}) {
    final s = search.trim().toLowerCase();
    final hasDateFilter = start.isNotEmpty && end.isNotEmpty;
    DateTime? st, en;
    if (hasDateFilter) {
      st = _formatter.parseStrict(start);
      en = _formatter.parseStrict(end).add(const Duration(days: 1));
    }

    _filtered = _all.where((e) {
      if (hasDateFilter && (e.date.isBefore(st!) || e.date.isAfter(en!))) {
        return false;
      }
      if (s.isNotEmpty) {
        final name = e.custName.toLowerCase();
        final noSj = e.noSj.toLowerCase();
        final city = e.custCity.toLowerCase();
        if (!(name.contains(s) || noSj.contains(s) || city.contains(s))) {
          return false;
        }
      }
      return true;
    }).toList();
    notifyListeners();
  }

  void selectAll() {
    _selectedRows
      ..clear()
      ..addAll(_filtered);
    notifyListeners();
  }

  void clearSelection() {
    _selectedRows.clear();
    notifyListeners();
  }

  List<TonaseModel> getSelectedItems() => _selectedRows.toList();

  @override
  DataRow getRow(int index) {
    final e = _filtered[index];
    return DataRow(
      selected: _selectedRows.contains(e),
      onSelectChanged: (sel) {
        if (sel == null) return;
        sel ? _selectedRows.add(e) : _selectedRows.remove(e);
        notifyListeners();
      },
      cells: [
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('dd MMM yy').format(e.date)),
            Text(DateFormat('HH:mm').format(e.date),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )),
        DataCell(SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                  message: e.custName,
                  child: Text(e.custName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
              Tooltip(
                  message: e.custCity,
                  child: Text(e.custCity,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        )),
        DataCell(Center(
            child: Text(e.noSj,
                style: const TextStyle(fontWeight: FontWeight.bold)))),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.areaName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(e.areaId,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )),
        DataCell(Center(child: Text(e.totalKoli.toString()))),
        DataCell(Center(child: Text(e.totalTonase.toStringAsFixed(2)))),
        DataCell(Center(
            child: Text(e.isSended ? 'Terkirim' : 'Belum',
                style: const TextStyle(fontWeight: FontWeight.bold)))),
        DataCell(Center(
          child: TextButton.icon(
            icon: const Icon(Icons.visibility, color: Colors.green),
            label: const Text('Detail'),
            onPressed: () => onViewDetail(e),
          ),
        )),
      ],
    );
  }

  @override
  int get rowCount => _filtered.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => _selectedRows.length;
}

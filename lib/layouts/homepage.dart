import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/area_service.dart';
import '../services/tonase_service.dart';
import '../models/area_model.dart';
import '../models/tonase_model.dart';
import 'tonaseinputpage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //Controllers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dateRangeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _searchController = TextEditingController();

  //Data & Services
  final AreaService _areaService = AreaService();
  final TonaseService _tonaseService = TonaseService();
  List<AreaModel> _areas = [];
  AreaModel? _selectedArea;
  TonaseDataTableSource? _dataSource;

  //UI State
  bool _isLoadingAreas = true;
  bool _isLoadingTonase = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadAreas();
    _loadTonase();
  }

  @override
  void dispose() {
    _dateRangeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    try {
      final list = await _areaService.getAreas();
      if (!mounted) return;
      setState(() {
        _areas = [AreaModel(areaId: "all", areaName: "All Area"), ...list];
        _selectedArea = _areas.first;
        _isLoadingAreas = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingAreas = false);
      _showError('Gagal Memuat Area: $e');
    }
  }

  Future<void> _loadTonase() async {
    setState(() => _isLoadingTonase = true);
    try {
      final list = await TonaseService().getUnsentTonase();
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          _isLoadingTonase = false;
          _dataSource = TonaseDataTableSource(
            tonaseList: [],
            onEdit: _onEdit,
            onDelete: _onDeleteConfirm,
            onViewDetail: _onViewDetails,
          );
        });
        _showMessage('Data tonase belum tersedia!');
        return;
      }

      if (_dataSource == null) {
        _dataSource = TonaseDataTableSource(
          tonaseList: list,
          onEdit: _onEdit,
          onDelete: _onDeleteConfirm,
          onViewDetail: _onViewDetails,
        );
      } else {
        _dataSource!.updateData(list);
      }
      setState(() => _isLoadingTonase = false);
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() => _isLoadingTonase = false);
      _showError("Gagal memuat data tonase: $e");
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
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
        areaId: (_selectedArea?.areaId == 'all') ? '' : _selectedArea!.areaId,
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
    setState(() {
      _selectedArea = _areas.first;
    });
    _applyFilters();
  }

  void _onAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TonaseInputPage()),
    );
    await _loadTonase();
  }

  void _onEdit(TonaseModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TonaseInputPage(existingTonase: item)),
    );
    await _loadTonase();
  }

  Future<void> _onDeleteConfirm(TonaseModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _tonaseService.deleteTonase(item.tonId);
        _showMessage('Berhasil Dihapus');
        await _loadTonase();
      } catch (e) {
        _showError('Gagal Hapus Data: $e');
      }
    }
  }

  void _onViewDetails(TonaseModel item) {
    const maxPerCol = 10;
    final list = item.detailTonase
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.toStringAsFixed(2)} kg')
        .toList();
    final cols = (list.length / maxPerCol).ceil();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detail Tonase'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabelText('Nama Toko:', item.custName),
              const SizedBox(height: 2),
              _buildLabelText('Kota:', item.custCity),
              const SizedBox(height: 2),
              _buildLabelText('No. PK:', item.noSj),
              const SizedBox(height: 2),
              _buildLabelText('Total Tonase:', item.totalTonase.toString()),
              const SizedBox(height: 8),
              const Text(
                'Rincian:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
            key: const Key('close-viewDetails'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  void _handleMarkAsSend() async {
    final items = _dataSource!.getSelectedItems();
    if (items.isEmpty) {
      _showMessage('Tidak Ada Data yang dipilih.');
      return;
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var item in items) {
        batch.update(
          FirebaseFirestore.instance.collection('tonase').doc(item.tonId),
          {'isSended': true},
        );
      }
      await batch.commit();
      _showMessage('Data Berhasil di Kirim.');
      await _loadTonase();
    } catch (e) {
      _showError('Terjadi Kesalahan: $e');
    }
  }

  void _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('menu-button'),
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text(
          "TONASE",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, semanticLabel: 'Muat ulang'),
            onPressed: _loadTonase,
          ),
        ],
      ),
      drawer: _buildDrawer(user?.email),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoadingTonase
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('date-filter-field'),
          controller: _dateRangeController,
          readOnly: true,
          onTap: _selectDateRange,
          decoration: InputDecoration(
            labelText: 'Tanggal',
            hintText: 'Pilih Tanggal',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _selectDateRange,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        _isLoadingAreas
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<AreaModel>(
                key: const Key('area-dropdown-filter'),
                initialValue: _selectedArea,
                decoration: InputDecoration(
                  labelText: 'Area',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _areas
                    .map(
                      (a) => DropdownMenuItem(
                        key: const Key('select-area'),
                        value: a,
                        child: Text(a.areaName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedArea = v);
                  _applyFilters();
                },
              ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            // Gunakan Wrap agar tombol bisa turun ke bawah di layar kecil
            spacing: 8.0,
            runSpacing: 4.0,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('add-tonase-button'),
                onPressed: _onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('clear-button'),
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('mark-button'),
                onPressed: _handleMarkAsSend,
                icon: const Icon(Icons.send),
                label: const Text('Mark'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget baru untuk logika adaptif
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

  // Widget baru untuk tampilan mobile (ListView)
  Widget _buildMobileListView() {
    final items = _dataSource?.filteredRows ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: TextField(
            key: const Key('search-field-mobile'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari Toko, Kota, atau No. PK...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
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
                        color: isSelected ? Colors.teal[300] : null,
                        child: InkWell(
                          onTap: () {
                            _dataSource?.toggleSelection(item);
                            setState(() {});
                          },
                          onLongPress: () => _onViewDetails(item),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: item.custName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black),
                                      ),
                                      TextSpan(
                                        text: ' | ${item.custCity}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                      style: DefaultTextStyle.of(context)
                                          .style
                                          .copyWith(fontSize: 14),
                                      children: [
                                        const TextSpan(
                                            text: 'Area: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text:
                                                '[${item.areaId}] ${item.areaName}'),
                                      ]),
                                ),
                                RichText(
                                  text: TextSpan(
                                      style: DefaultTextStyle.of(context)
                                          .style
                                          .copyWith(fontSize: 14),
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
                                            text:
                                                DateFormat('dd MMM yyyy, HH:mm')
                                                    .format(item.date)),
                                      ]),
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
                                              style:
                                                  DefaultTextStyle.of(context)
                                                      .style
                                                      .copyWith(fontSize: 14),
                                              children: [
                                                const TextSpan(
                                                    text: 'Total Koli: ',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                TextSpan(
                                                    text: '${item.totalKoli}'),
                                              ]),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                              style:
                                                  DefaultTextStyle.of(context)
                                                      .style
                                                      .copyWith(fontSize: 14),
                                              children: [
                                                const TextSpan(
                                                    text: 'Total Tonase: ',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                TextSpan(
                                                    text:
                                                        '${item.totalTonase.toStringAsFixed(2)} kg'),
                                              ]),
                                        ),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      key: const Key('select-action'),
                                      onSelected: (value) {
                                        if (value == 'viewDetails') {
                                          _onViewDetails(item);
                                        } else if (value == 'edit') {
                                          _onEdit(item);
                                        } else if (value == 'delete') {
                                          _onDeleteConfirm(item);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          key: Key('viewDetails-button'),
                                          value: 'viewDetails',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_red_eye,
                                                  color: Colors.green),
                                              SizedBox(width: 8),
                                              Text('View Details'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          key: Key('edit-button'),
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: Colors.blue),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          key: Key('delete-button'),
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }))
      ],
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

  Widget _buildDesktopDataTable() {
    final minTableWidth = 900.0;
    final defaultRowsPerPage = 10;
    final availableRows = (_dataSource?.rowCount ?? 0);
    final rowsPerPage = availableRows > defaultRowsPerPage
        ? defaultRowsPerPage
        : (availableRows == 0 ? 1 : availableRows);

    // Menggunakan LayoutBuilder untuk mendapatkan lebar layar
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth, // Terapkan lebar responsif di sini
            child: PaginatedDataTable(
              key: const Key('home-data-table'),
              header: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Data Tonase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      key: const Key('search-field'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          key: const Key('clear-search'),
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                      onChanged: (_) => _applyFilters(),
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
                _buildDataColumn('Aksi'),
              ],
              source: _dataSource ??
                  TonaseDataTableSource(
                    tonaseList: [],
                    onEdit: _onEdit,
                    onDelete: _onDeleteConfirm,
                    onViewDetail: _onViewDetails,
                  ),
              rowsPerPage: rowsPerPage,
              showFirstLastButtons: true,
              columnSpacing: 20,
              horizontalMargin: 16,
            ),
          ),
        );
      },
    );
  }

  Drawer _buildDrawer(String? email) {
    final displayName =
        email != null && email.contains('@') ? email.split('@').first : 'Guest';
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.teal),
            currentAccountPicture:
                const CircleAvatar(child: Icon(Icons.person)),
            accountName: Text(displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(email ?? ''),
          ),
          ListTile(
            key: const Key('area-menu-button'),
            leading: const Icon(Icons.map, color: Colors.blueAccent),
            title: const Text('Data Area'),
            onTap: () => Navigator.pushNamed(context, '/area'),
          ),
          ListTile(
            key: const Key('customer-menu-button'),
            leading: const Icon(Icons.people, color: Colors.green),
            title: const Text('Data Customer'),
            onTap: () => Navigator.pushNamed(context, '/customer'),
          ),
          ListTile(
            key: const Key('rekap-menu-button'),
            leading: const Icon(Icons.insert_chart, color: Colors.amber),
            title: const Text('Rekap Harian'),
            onTap: () => Navigator.pushNamed(context, '/daily'),
          ),
          ListTile(
            key: const Key('histori-menu-button'),
            leading: const Icon(Icons.history, color: Colors.blueGrey),
            title: const Text('Riwayat Tonase'),
            onTap: () => Navigator.pushNamed(context, '/histori'),
          ),
          ListTile(
            key: const Key('logout-button'),
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => _logout(),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showMessage(String msg,
      {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }
}

class TonaseDataTableSource extends DataTableSource {
  final DateFormat _formatter = DateFormat('dd/MM/yyyy');
  final void Function(TonaseModel) onEdit;
  final void Function(TonaseModel) onDelete;
  final void Function(TonaseModel) onViewDetail;
  List<TonaseModel> _all = [];
  List<TonaseModel> _filtered = [];
  final Set<TonaseModel> _selectedRows = {};

  TonaseDataTableSource({
    required List<TonaseModel> tonaseList,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetail,
  }) {
    updateData(tonaseList);
  }

  // Getter untuk mengakses data yang sudah difilter
  List<TonaseModel> get filteredRows => _filtered;
  bool isSelected(TonaseModel item) => _selectedRows.contains(item);

  void toggleSelection(TonaseModel item) {
    if (_selectedRows.contains(item)) {
      _selectedRows.remove(item);
    } else {
      _selectedRows.add(item);
    }
    notifyListeners();
  }

  void updateData(List<TonaseModel> newList) {
    _all = newList.where((e) => !e.isSended).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _filtered = List.from(_all);
    notifyListeners();
  }

  void applyFilter({
    required String search,
    required String areaId,
    required String start,
    required String end,
  }) {
    final s = search.trim().toLowerCase();
    final hasDateFilter = start.isNotEmpty && end.isNotEmpty;
    DateTime? st, en;
    if (hasDateFilter) {
      st = _formatter.parseStrict(start);
      en = _formatter
          .parseStrict(end)
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
    }
    final hasAreaFilter = areaId.isNotEmpty;
    final hasSearch = s.isNotEmpty;
    _filtered = _all.where((e) {
      if (hasDateFilter) {
        if (e.date.isBefore(st!)) return false;
        if (e.date.isAfter(en!)) return false;
      }
      if (hasAreaFilter && e.areaId != areaId) {
        return false;
      }
      if (hasSearch) {
        final name = e.custName.toLowerCase();
        final noSj = e.noSj.toLowerCase();
        final city = e.custCity.toLowerCase();
        if (!(name.contains(s) || noSj.contains(s) || city.contains(s))) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
    final selected = _selectedRows.contains(e);

    return DataRow(
      selected: selected,
      onSelectChanged: (sel) {
        if (sel == null) return;
        sel ? _selectedRows.add(e) : _selectedRows.remove(e);
        notifyListeners();
      },
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('dd MMM yy').format(e.date)),
              Text(DateFormat('HH:mm').format(e.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: e.custName,
                  child: Text(
                    e.custName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Tooltip(
                  message: e.custCity,
                  child: Text(
                    e.custCity,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Center(
            child: Text(e.noSj,
                style: const TextStyle(fontWeight: FontWeight.bold)))),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.areaName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(e.areaId,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        DataCell(Center(child: Text(e.totalKoli.toString()))),
        DataCell(Center(child: Text(e.totalTonase.toStringAsFixed(2)))),
        DataCell(
          Center(
            child: PopupMenuButton<String>(
              key: const Key('select-action'),
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (v) {
                if (v == 'viewDetails') {
                  onViewDetail(e);
                } else if (v == 'edit') {
                  onEdit(e);
                } else if (v == 'delete') {
                  onDelete(e);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  key: Key('viewDetails-button'),
                  value: 'viewDetails',
                  child: Row(
                    children: [
                      Icon(Icons.remove_red_eye, color: Colors.green),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  key: Key('edit-button'),
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  key: Key('delete-button'),
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
  int get rowCount => _filtered.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

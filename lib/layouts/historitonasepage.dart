import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tonase_app/layouts/homepage.dart';
import 'package:tonase_app/main.dart';
import 'package:tonase_app/models/tonase_model.dart';
import 'package:tonase_app/services/tonase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoriTonasePage extends StatefulWidget {
  const HistoriTonasePage({super.key});

  @override
  State<HistoriTonasePage> createState() => _HistoriTonasePageState();
}

class _HistoriTonasePageState extends State<HistoriTonasePage> {
  final TextEditingController _searchController = TextEditingController();

  final Set<TonaseModel> _selectedRows = {};
  List<TonaseModel> _allTonase = [];
  List<TonaseModel> _filteredTonase = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTonase();
    _searchController.addListener(_applySearchFilter);
  }

  Future<void> _fetchTonase() async {
    try {
      final data = await TonaseService().getSentTonase();
      setState(() {
        _allTonase = data;
        _filteredTonase = data;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Gagal Memuat Data: $e');
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTonase = _allTonase.where((item) {
        return item.custName.toLowerCase().contains(query) ||
            item.noSj.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _handleUnmark() async {
    if (_selectedRows.isEmpty) {
      _showError('Pilih data yang akan di-Unmark');
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var item in _selectedRows) {
        batch.update(
          FirebaseFirestore.instance.collection('tonase').doc(item.tonId),
          {'isSended': false},
        );
      }
      await batch.commit();
      setState(() {
        _selectedRows.clear();
      });

      await _fetchTonase();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
      _showMessage('Berhasil Unmark Data.');
    } catch (e) {
      _showError('Gagal Unmark: $e');
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
          'Histori Tonase',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            key: Key('unmark-button'),
            icon: const Icon(Icons.undo),
            onPressed: _handleUnmark,
            tooltip: 'Batal Terkirim',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search",
                hintText: 'Cari Toko / Nomor SJ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: PaginatedDataTable(
                      key: Key('histori-data-table'),
                      showCheckboxColumn: true,
                      onSelectAll: (all) {
                        setState(() {
                          all == true
                              ? _selectedRows.addAll(_filteredTonase)
                              : _selectedRows.clear();
                        });
                      },
                      header: const Center(
                        child: Text(
                          "Daftar Riwayat Tonase",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      columnSpacing: 16,
                      headingRowColor: WidgetStateProperty.all<Color>(
                        Colors.teal,
                      ),
                      columns: const [
                        DataColumn(
                          label: SizedBox(
                            width: 60,
                            child: Text(
                              "Tanggal",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 150,
                            child: Text(
                              "Nama Toko",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Text(
                              "No. SJ",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 80,
                            child: Text(
                              "Area",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 40,
                            child: Text(
                              "Total Kolian",
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: 2,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 70,
                            child: Text(
                              "Total Tonase",
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: 2,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Text(
                              "Status",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 100,
                            child: Text(
                              "Action",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      source: _HistoriTonaseDataSource(
                        _filteredTonase,
                        _selectedRows,
                        (item, selected) {
                          setState(() {
                            selected == true
                                ? _selectedRows.add(item)
                                : _selectedRows.remove(item);
                          });
                        },
                      ),
                      rowsPerPage: 10,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _HistoriTonaseDataSource extends DataTableSource {
  final DateFormat formatter = DateFormat('dd/MM/yyyy');
  final List<TonaseModel> data;
  final Set<TonaseModel> selectedRows;
  final Function(TonaseModel, bool?) onSelectChanged;

  _HistoriTonaseDataSource(this.data, this.selectedRows, this.onSelectChanged);

  DateTime? parseDate(String date) {
    try {
      return date.isNotEmpty ? formatter.parseStrict(date) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  DataRow getRow(int index) {
    final item = data[index];
    return DataRow(
      selected: selectedRows.contains(item),
      onSelectChanged: (selected) => onSelectChanged(item, selected),
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('dd MMM yy').format(item.date)),
              Text(
                DateFormat('HH:mm').format(item.date),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
                  message: item.custName,
                  child: Text(
                    item.custName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Tooltip(
                  message: item.custCity,
                  child: Text(
                    item.custCity,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Text(item.noSj, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.areaName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                item.areaId,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        DataCell(Center(child: Text(item.totalKoli.toString()))),
        DataCell(Center(child: Text(item.totalTonase.toStringAsFixed(2)))),
        DataCell(Text(item.isSended ? 'Terkirim' : 'Belum')),
        DataCell(
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.remove_red_eye, color: Colors.green),
              label: const Text(
                'Details',
                style: TextStyle(color: Colors.black),
              ),
              onPressed: () {
                final maxItemsPerColumn = 10;
                final rincianList = List.generate(
                  item.detailTonase.length,
                  (i) =>
                      "${i + 1}. ${item.detailTonase[i].toStringAsFixed(2)} kg",
                );
                final columnCount = (rincianList.length / maxItemsPerColumn)
                    .ceil();

                showDialog(
                  context: navigatorKey.currentContext!,
                  builder: (_) {
                    return AlertDialog(
                      title: const Text("Detail Tonase"),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Nama Toko: ${item.custName}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Kota: ${item.custCity}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "No. SJ: ${item.noSj}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Total Tonase: ${item.totalTonase}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Rincian:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(columnCount, (
                                  colIndex,
                                ) {
                                  final startIndex =
                                      colIndex * maxItemsPerColumn;
                                  final endIndex =
                                      (startIndex + maxItemsPerColumn).clamp(
                                        0,
                                        rincianList.length,
                                      );
                                  final sublist = rincianList.sublist(
                                    startIndex,
                                    endIndex,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: sublist
                                          .map(
                                            (e) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
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
                          onPressed: () =>
                              Navigator.pop(navigatorKey.currentContext!),
                          child: const Text("Close"),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

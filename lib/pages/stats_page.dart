import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifier.dart';
import '../core/pos_ui.dart';
import '../services/report_service.dart';
import '../services/transaction_service.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  /// '' all, 'cash', 'qris'
  String paymentFilter = '';

  /// '' all, 'paid', 'pending', 'voided', ...
  String statusFilter = '';

  /// daily | weekly | monthly | custom
  String quickRange = 'weekly';

  final physicalCash = TextEditingController();

  // Cash Shift persistence (local) - UI convenience only, tidak mengubah logika transaksi
  bool _cashSaving = false;
  DateTime? _cashSavedAt;
  int? _cashSavedValue;
  String? _lastCashKey;

  String _cashShiftKey(DateTimeRange nr) {
    final df = DateFormat('yyyyMMdd');
    final p = paymentFilter.isEmpty ? 'all' : paymentFilter;
    final st = statusFilter.isEmpty ? 'all' : statusFilter;
    // pakai start-end biar unik sesuai range yang dipilih
    return 'cash_shift_${df.format(nr.start)}_${df.format(nr.end)}_${p}_$st';
  }

  Future<void> _loadSavedCashIfAny(String key) async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    final v = sp.getInt(key);
    final atStr = sp.getString('${key}_at');
    final at = (atStr == null) ? null : DateTime.tryParse(atStr);
    setState(() {
      _cashSavedValue = v;
      _cashSavedAt = at;
      if (v != null) physicalCash.text = v.toString();
    });
  }

  Future<void> _saveCash(String key, int value) async {
    setState(() => _cashSaving = true);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(key, value);
      await sp.setString('${key}_at', DateTime.now().toIso8601String());
      if (!mounted) return;
      setState(() {
        _cashSavedValue = value;
        _cashSavedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash shift tersimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _cashSaving = false);
    }
  }

  void _applyCashDelta(int delta) {
    final cur = int.tryParse(physicalCash.text.trim()) ?? 0;
    final next = (cur + delta);
    physicalCash.text = (next < 0 ? 0 : next).toString();
    setState(() {});
  }

  void _showCashHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cara pakai Cash Shift'),
        content: const Text(
          '1) Hitung uang cash fisik di laci.\n'
          '2) Masukkan ke kolom “Uang fisik”.\n'
          '3) Difference = Uang fisik − Cash Amount (data).\n'
          '4) Tekan Simpan agar nilai tersimpan (di device ini).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  late Future<Map<String, dynamic>> stats;

  // UI-only toggle (seperti "Show Graph" di desain)
  bool showGraph = true;

  @override
  void initState() {
    super.initState();
    stats = _loadStats(forRange: _normalizedRange(range));
  }

  @override
  void dispose() {
    physicalCash.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999, 999);

  DateTimeRange _normalizedRange(DateTimeRange r) {
    // include full last day
    return DateTimeRange(start: _startOfDay(r.start), end: _endOfDay(r.end));
  }

  DateTimeRange _dailyRange() {
    final now = DateTime.now();
    return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
  }

  DateTimeRange _weeklyRange() {
    final now = DateTime.now();
    // 7 hari termasuk hari ini
    final start = _startOfDay(now.subtract(const Duration(days: 6)));
    return DateTimeRange(start: start, end: _endOfDay(now));
  }

  DateTimeRange _monthlyRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: start, end: _endOfDay(now));
  }

  String rupiah(int v) => 'Rp ${NumberFormat('#,###', 'id_ID').format(v)}';

  // ---------- Reload (ANTI BUG: range berubah tapi data ga ikut) ----------
  void _reloadWith({
    DateTimeRange? newRange,
    String? newQuickRange,
    String? newPaymentFilter,
    String? newStatusFilter,
  }) {
    final updatedRange = _normalizedRange(newRange ?? range);

    setState(() {
      if (newRange != null) range = newRange;
      if (newQuickRange != null) quickRange = newQuickRange;
      if (newPaymentFilter != null) paymentFilter = newPaymentFilter;
      if (newStatusFilter != null) statusFilter = newStatusFilter;

      // IMPORTANT: future based on updated params
      stats = _loadStats(
        forRange: updatedRange,
        payment: (newPaymentFilter ?? paymentFilter).isEmpty
            ? null
            : (newPaymentFilter ?? paymentFilter),
        status: (newStatusFilter ?? statusFilter).isEmpty
            ? null
            : (newStatusFilter ?? statusFilter),
      );
    });
  }

  Future<void> _refresh() async {
    _reloadWith(); // reload pakai state sekarang
  }

  void applyQuickRange(String mode) {
    if (mode == 'daily') {
      _reloadWith(newRange: _dailyRange(), newQuickRange: 'daily');
    } else if (mode == 'weekly') {
      _reloadWith(newRange: _weeklyRange(), newQuickRange: 'weekly');
    } else if (mode == 'monthly') {
      _reloadWith(newRange: _monthlyRange(), newQuickRange: 'monthly');
    }
  }

  Future<void> pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: range,
    );
    if (r == null) return;
    _reloadWith(newRange: r, newQuickRange: 'custom');
  }

  // ---------- Data builder ----------
  List<_DayPoint> _buildDailySeries(
    DateTime start,
    DateTime end,
    Map<String, int> map,
  ) {
    final s = _startOfDay(start);
    final e = _startOfDay(end);
    final points = <_DayPoint>[];

    DateTime cur = s;
    while (!cur.isAfter(e)) {
      final key = DateFormat('yyyy-MM-dd').format(cur);
      points.add(_DayPoint(date: cur, value: map[key] ?? 0));
      cur = cur.add(const Duration(days: 1));
    }
    return points;
  }

  Future<Map<String, dynamic>> _loadStats({
    required DateTimeRange forRange,
    String? payment,
    String? status,
  }) async {
    final rows = await ReportService.getReport(
      from: forRange.start,
      to: forRange.end,
      paymentMethod: payment,
      status: status,
    );

    int totalTrx = 0; // paid only
    int omzet = 0; // net sales (paid only)

    int cashTrx = 0;
    int nonCashTrx = 0;

    int cashAmount = 0;
    int nonCashAmount = 0;

    int subtotalSum = 0;
    int discountSum = 0;
    int feeSum = 0;
    int otherCostSum = 0;
    int hppSum = 0;
    int grossProfitSum = 0;
    int netProfitSum = 0;

    final Map<String, int> omzetPerDay = {};
    final Map<String, _TopProduct> productAgg = {};

    for (final rr in rows) {
  final st = (rr['status'] ?? '').toString().toLowerCase();
  final isPaid = st == TransactionService.statusPaid;
  if (!isPaid) {
    // statistik uang & profit hanya dihitung dari transaksi PAID
    continue;
  }

  totalTrx++;
  final netSales = asInt(rr['net_sales'] ?? rr['total']);
  final subtotal = asInt(rr['subtotal_calc'] ?? rr['subtotal']);
  final discount = asInt(rr['discount']);
  final fee = asInt(rr['fee']);
  final other = asInt(rr['other_cost']);
  final hpp = asInt(rr['hpp']);
  final gross = asInt(rr['gross_profit']);
  final net = asInt(rr['net_profit']);

  omzet += netSales;
  subtotalSum += subtotal;
  discountSum += discount;
  feeSum += fee;
  otherCostSum += other;
  hppSum += hpp;
  grossProfitSum += gross;
  netProfitSum += net;

  final method = (rr['payment_method'] ?? '').toString().toLowerCase();
  if (method == 'cash') {
    cashTrx++;
    cashAmount += netSales;
  } else {
    nonCashTrx++;
    nonCashAmount += netSales;
  }

  final created = DateTime.tryParse((rr['created_at'] ?? '').toString());
  if (created != null) {
    final key = DateFormat('yyyy-MM-dd').format(created);
    omzetPerDay[key] = (omzetPerDay[key] ?? 0) + netSales;
  }


      // Top products (butuh join items)
      final dynamic itemsAny = rr['items'] ?? rr['transaction_items'];
      if (itemsAny is List) {
        for (final it in itemsAny) {
          if (it is! Map) continue;

          final qty = asInt(it['qty']);
          final price = asInt(it['price']);

          String name = '';
          final prodMap = it['products'];
          if (prodMap is Map && prodMap['name'] != null) {
            name = prodMap['name'].toString();
          } else if (it['product_name'] != null) {
            name = it['product_name'].toString();
          } else if (it['name'] != null) {
            name = it['name'].toString();
          }

          name = name.trim();
          if (name.isEmpty) continue;

          final addRevenue = qty * price;
          final existing = productAgg[name];
          if (existing == null) {
            productAgg[name] = _TopProduct(
              name: name,
              qty: qty,
              revenue: addRevenue,
            );
          } else {
            productAgg[name] = existing.copyWith(
              qty: existing.qty + qty,
              revenue: existing.revenue + addRevenue,
            );
          }
        }
      }
    }

    final series = _buildDailySeries(forRange.start, forRange.end, omzetPerDay);

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return {
      'range': forRange,
      'rows': rows,
      'totalTrx': totalTrx,
      'omzet': omzet,
      'grossProfitSum': grossProfitSum,
      'netProfitSum': netProfitSum,
      'cashTrx': cashTrx,
      'nonCashTrx': nonCashTrx,
      'cashAmount': cashAmount,
      'nonCashAmount': nonCashAmount,
      'series': series,
      'topProducts': topProducts.take(8).toList(),
    };
  }

  // ---------- Export ----------
  Future<void> exportPdf(List<Map<String, dynamic>> rows) async {
    try {
      final nr = _normalizedRange(range);
      final file = await ReportService.exportPdf(
        rows: rows,
        from: nr.start,
        to: nr.end,
      );
      await ReportService.shareFile(file);
    } catch (e) {
      notify(context, e.toString(), error: true);
    }
  }

Future<void> exportCsv(List<Map<String, dynamic>> rows) async {
  try {
    final file = await ReportService.exportCsv(rows: rows);
    await ReportService.shareFile(file);
  } catch (e) {
    notify(context, e.toString(), error: true);
  }
}

  Future<void> exportExcel(List<Map<String, dynamic>> rows) async {
    try {
      final nr = _normalizedRange(range);
      final file = await ReportService.exportExcel(
        rows: rows,
        from: nr.start,
        to: nr.end,
      );
      await ReportService.shareFile(file);
    } catch (e) {
      notify(context, e.toString(), error: true);
    }
  }

  Future<void> _openDownloadSheet(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      notify(context, 'Tidak ada data untuk diexport', error: true);
      return;
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.download_rounded),
                    SizedBox(width: 10),
                    Text(
                      'Download Report',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Export PDF'),
                  subtitle: const Text('Ringkasan + detail transaksi'),
                  onTap: () async {
                    Navigator.pop(context);
                    await exportPdf(rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: const Text('Export Excel'),
                  subtitle: const Text('Format spreadsheet'),
                  onTap: () async {
                    Navigator.pop(context);
                    await exportExcel(rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_rows_rounded),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Format CSV (bisa dibuka di Excel)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await exportCsv(rows);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- UI tokens ----------
  Color get _cardBorder => Colors.black.withOpacity(0.06);

  Widget _cardShell({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    String? unit,
    String? badgeText,
    Color? badgeColor,
  }) {
    return _cardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.04),
              border: Border.all(color: _cardBorder),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ],
                ),
                if (badgeText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: (badgeColor ?? Colors.blue).withOpacity(0.10),
                      border: Border.all(
                        color: (badgeColor ?? Colors.blue).withOpacity(0.20),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: (badgeColor ?? Colors.blue).withOpacity(0.95),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedRange() {
    Widget chip(String key, String label) {
      final selected = quickRange == key;
      return InkWell(
        onTap: () {
          if (key == 'custom') {
            pickRange();
          } else {
            applyQuickRange(key);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : Colors.black.withOpacity(0.75),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('daily', 'Daily'),
        chip('weekly', 'Weekly'),
        chip('monthly', 'Monthly'),
        chip('custom', 'Custom'),
      ],
    );
  }

  Widget _filterDropdowns() {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 460;

        final metode = DropdownButtonFormField<String>(
          value: paymentFilter,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Payment',
            border: const OutlineInputBorder(),
            isDense: true,
            filled: true,
            fillColor: Colors.black.withOpacity(0.02),
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('All')),
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'qris', child: Text('Non-cash (QRIS)')),
          ],
          onChanged: (v) => _reloadWith(newPaymentFilter: v ?? ''),
        );

        final status = DropdownButtonFormField<String>(
          value: statusFilter,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Status',
            border: const OutlineInputBorder(),
            isDense: true,
            filled: true,
            fillColor: Colors.black.withOpacity(0.02),
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('All')),
            DropdownMenuItem(
              value: TransactionService.statusPaid,
              child: Text('PAID'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusPending,
              child: Text('PENDING'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusVoided,
              child: Text('VOID'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusRefunded,
              child: Text('REFUND'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusCanceled,
              child: Text('CANCEL'),
            ),
          ],
          onChanged: (v) => _reloadWith(newStatusFilter: v ?? ''),
        );

        if (isNarrow) {
          return Column(children: [metode, const SizedBox(height: 12), status]);
        }

        return Row(
          children: [
            Expanded(child: metode),
            const SizedBox(width: 12),
            Expanded(child: status),
          ],
        );
      },
    );
  }

  String _bestNameFromRow(Map<String, dynamic> r) {
    final v = r['customer_name'] ?? r['customer'] ?? r['name'] ?? r['buyer_name'];
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String _bestStatusFromRow(Map<String, dynamic> r) {
    final v = r['status'] ?? r['order_status'] ?? r['payment_status'];
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '-' : s.toUpperCase();
  }

  String _bestDateFromRow(Map<String, dynamic> r) {
    final created = DateTime.tryParse((r['created_at'] ?? '').toString());
    if (created == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(created);
  }

  // ---------- Responsive Top Bar ----------
  Widget _topBar({
    required List<Map<String, dynamic>> rows,
    required String todayLabel,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final narrow = w < 420; // kunci biar gak overflow di HP kecil
        final semi = w >= 420 && w < 700;

        final downloadBtn = OutlinedButton.icon(
          onPressed: () => _openDownloadSheet(rows),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            side: BorderSide(color: _cardBorder),
            foregroundColor: Colors.black87,
          ),
        );

        final dateChip = _cardShell(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  todayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );

        final graphToggle = _cardShell(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Show Graph',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
              const SizedBox(width: 10),
              Switch.adaptive(
                value: showGraph,
                onChanged: (v) => setState(() => showGraph = v),
              ),
            ],
          ),
        );

        if (narrow) {
          // HP kecil: pecah jadi 2 baris + Wrap biar aman
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Report',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  downloadBtn,
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: min(280, w), child: dateChip),
                  graphToggle,
                ],
              ),
            ],
          );
        }

        if (semi) {
          // layar sedang: masih row tapi bagian kanan boleh wrap
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  downloadBtn,
                  SizedBox(width: 240, child: dateChip),
                  graphToggle,
                ],
              ),
            ],
          );
        }

        // Tablet / lebar: row normal
        return Row(
          children: [
            const Expanded(
              child: Text(
                'Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            downloadBtn,
            const SizedBox(width: 10),
            SizedBox(width: 260, child: dateChip),
            const SizedBox(width: 10),
            graphToggle,
          ],
        );
      },
    );
  }

  // ---------- Main UI ----------
  @override
  Widget build(BuildContext context) {
    final dfTop = DateFormat('EEE, dd MMM yyyy', 'en_US');
    final dfRange = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: PosBackground(
        child: SafeArea(
          child: PosSurface(
            padding: EdgeInsets.zero,
            child: FutureBuilder<Map<String, dynamic>>(
              future: stats,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Gagal load rekap: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: Text('Gagal load rekap'));
                }

                final s = snap.data!;

                final DateTimeRange nr = (s['range'] is DateTimeRange)
                    ? (s['range'] as DateTimeRange)
                    : _normalizedRange(range);

                final rows = (s['rows'] is List)
                    ? List<Map<String, dynamic>>.from(s['rows'] as List)
                    : <Map<String, dynamic>>[];

                final series = (s['series'] is List<_DayPoint>)
                    ? (s['series'] as List<_DayPoint>)
                    : <_DayPoint>[];

                final topProducts = (s['topProducts'] is List<_TopProduct>)
                    ? (s['topProducts'] as List<_TopProduct>)
                    : <_TopProduct>[];

                final omzet = asInt(s['omzet']);
                final totalTrx = asInt(s['totalTrx']);
                final grossProfit = asInt(s['grossProfitSum']);
                final netProfit = asInt(s['netProfitSum']);

                final cashAmount = asInt(s['cashAmount']);
                final nonCashAmount = asInt(s['nonCashAmount']);

                final phys = int.tryParse(physicalCash.text.trim()) ?? 0;
                final selisih = phys - cashAmount;

                final titleRange =
                    '${dfRange.format(nr.start)} - ${dfRange.format(nr.end)}';

                // Load saved cash shift value when range/filter changes (local device)
                final cashKey = _cashShiftKey(nr);
                if (_lastCashKey != cashKey) {
                  _lastCashKey = cashKey;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _loadSavedCashIfAny(cashKey);
                  });
                }


                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ===== Top Bar (responsive) =====
                      _topBar(
                        rows: rows,
                        todayLabel: dfTop.format(DateTime.now()),
                      ),

                      const SizedBox(height: 14),

                      // ===== Filter & Period Card =====
                      _cardShell(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Date Period',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: pickRange,
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('Pick range'),
                                ),
                                IconButton(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              titleRange,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _segmentedRange(),
                            const SizedBox(height: 14),
                            _filterDropdowns(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ===== Metrics (lebih aman di HP kecil) =====
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final isVeryNarrow = w < 360;
                          final isWide = w >= 780;
                          final gap = isWide ? 12.0 : 10.0;

                          final cards = [
  _metricCard(
    title: 'Net Sales (PAID)',
    value: rupiah(omzet),
    icon: Icons.summarize_rounded,
    unit: null,
    badgeText: null,
    badgeColor: Colors.green,
  ),
  _metricCard(
    title: 'Total Transactions (PAID)',
    value: totalTrx.toString(),
    icon: Icons.receipt_long_rounded,
    unit: 'trx',
    badgeText: null,
    badgeColor: Colors.blue,
  ),
  _metricCard(
    title: 'Gross Profit (PAID)',
    value: rupiah(grossProfit),
    icon: Icons.trending_up_rounded,
    unit: null,
    badgeText: null,
    badgeColor: Colors.green,
  ),
  _metricCard(
    title: 'Net Profit (PAID)',
    value: rupiah(netProfit),
    icon: Icons.account_balance_wallet_outlined,
    unit: null,
    badgeText: null,
    badgeColor: Colors.green,
  ),
];

                          if (isVeryNarrow) {
                            // HP kecil banget: 1 kolom
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 10),
                                cards[1],
                                const SizedBox(height: 10),
                                cards[2],
                                const SizedBox(height: 10),
                                cards[3],
                              ],
                            );
                          }

                          if (!isWide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    SizedBox(width: gap),
                                    Expanded(child: cards[1]),
                                  ],
                                ),
                                SizedBox(height: gap),
                                Row(
                                  children: [
                                    Expanded(child: cards[2]),
                                    SizedBox(width: gap),
                                    Expanded(child: cards[3]),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cards[0]),
                              SizedBox(width: gap),
                              Expanded(child: cards[1]),
                              SizedBox(width: gap),
                              Expanded(child: cards[2]),
                              SizedBox(width: gap),
                              Expanded(child: cards[3]),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // ===== Graph + Favorite Product =====
                      if (showGraph)
                        LayoutBuilder(
                          builder: (context, c) {
                            final isWide = c.maxWidth >= 900;
                            if (!isWide) {
                              return Column(
                                children: [
                                  _cardShell(
                                    child: _GraphSection(
                                      series: series,
                                      range: nr,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _cardShell(
                                    child: _FavoriteProductSection(
                                      topProducts: topProducts,
                                      rupiah: rupiah,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _cardShell(
                                    child: _GraphSection(
                                      series: series,
                                      range: nr,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: _cardShell(
                                    child: _FavoriteProductSection(
                                      topProducts: topProducts,
                                      rupiah: rupiah,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      if (showGraph) const SizedBox(height: 14),

                      // ===== Kas & Selisih =====
                      _cardShell(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Cash (Shift)',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _showCashHelp,
                                  icon: const Icon(Icons.help_outline, size: 18),
                                  label: const Text('Cara pakai'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Difference = Uang fisik − Cash Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: physicalCash,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Uang fisik (input manual)',
                                hintText: 'Misal: 250000',
                                prefixText: 'Rp ',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.02),
                                suffixIcon: IconButton(
                                  tooltip: 'Reset',
                                  onPressed: () {
                                    physicalCash.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.backspace_outlined),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),

                            // Quick input buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(10000),
                                  child: const Text('+10k'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(20000),
                                  child: const Text('+20k'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(50000),
                                  child: const Text('+50k'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(100000),
                                  child: const Text('+100k'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(200000),
                                  child: const Text('+200k'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _applyCashDelta(500000),
                                  child: const Text('+500k'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            LayoutBuilder(
                              builder: (context, c) {
                                final narrow = c.maxWidth < 520;
                                final cashCard = _metricCard(
                                  title: 'Cash Amount',
                                  value: rupiah(cashAmount),
                                  icon: Icons.payments,
                                  unit: null,
                                  badgeText: '${asInt(s['cashTrx'])} trx (data)',
                                  badgeColor: Colors.blueGrey,
                                );

                                final diffCard = _metricCard(
                                  title: 'Difference',
                                  value: rupiah(selisih),
                                  icon: Icons.compare_arrows_rounded,
                                  unit: null,
                                  badgeText: selisih == 0
                                      ? 'Pas'
                                      : (selisih < 0 ? 'Kurang' : 'Lebih'),
                                  badgeColor: selisih == 0
                                      ? Colors.green
                                      : (selisih < 0 ? Colors.orange : Colors.blue),
                                );

                                if (narrow) {
                                  return Column(
                                    children: [
                                      cashCard,
                                      const SizedBox(height: 12),
                                      diffCard,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: cashCard),
                                    const SizedBox(width: 12),
                                    Expanded(child: diffCard),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      physicalCash.text = cashAmount.toString();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.auto_fix_high),
                                    label: const Text('Auto = Cash Amount'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _cashSaving
                                        ? null
                                        : () async {
                                            final key = _cashShiftKey(nr);
                                            final v = int.tryParse(physicalCash.text.trim()) ?? 0;
                                            await _saveCash(key, v);
                                          },
                                    icon: _cashSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(_cashSaving ? 'Menyimpan...' : 'Simpan'),
                                  ),
                                ),
                              ],
                            ),
                            if (_cashSavedAt != null || _cashSavedValue != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tersimpan: ${_cashSavedValue == null ? '-' : rupiah(_cashSavedValue!)}'
                                '${_cashSavedAt == null ? '' : ' • ${DateFormat('dd MMM, HH:mm').format(_cashSavedAt!)}'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.55),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            _metricCard(
                              title: 'Non-Cash Amount',
                              value: rupiah(nonCashAmount),
                              icon: Icons.qr_code_rounded,
                              unit: null,
                              badgeText: '${asInt(s['nonCashTrx'])} trx (data)',
                              badgeColor: Colors.blueGrey,
                            ),
                          ],
                        ),
                      ),

const SizedBox(height: 14),

                      // ===== All Orders =====
                      _cardShell(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All Orders',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (rows.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'Tidak ada data untuk filter ini',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, c) {
                                  final isWide = c.maxWidth >= 820;
                                  if (isWide) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('#')),
                                          DataColumn(label: Text('Date & Time')),
                                          DataColumn(label: Text('Customer')),
                                          DataColumn(label: Text('Status')),
                                          DataColumn(label: Text('Total')),
                                        ],
                                        rows: List.generate(
                                          min(rows.length, 50),
                                          (i) {
                                            final r = rows[i];
                                            return DataRow(
                                              cells: [
                                                DataCell(Text('${i + 1}')),
                                                DataCell(
                                                    Text(_bestDateFromRow(r))),
                                                DataCell(
                                                    Text(_bestNameFromRow(r))),
                                                DataCell(Text(
                                                    _bestStatusFromRow(r))),
                                                DataCell(
                                                  Text(
                                                    rupiah(asInt(r['total'])),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: List.generate(
                                      min(rows.length, 25),
                                      (i) {
                                        final r = rows[i];
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border:
                                                Border.all(color: _cardBorder),
                                            color: Colors.white,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color:
                                                      Colors.black.withOpacity(0.04),
                                                  border: Border.all(
                                                      color: _cardBorder),
                                                ),
                                                child: Text(
                                                  '${i + 1}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _bestNameFromRow(r),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _bestDateFromRow(r),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 12,
                                                        color: Colors.black
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(999),
                                                        color: Colors.black
                                                            .withOpacity(0.03),
                                                        border: Border.all(
                                                            color: _cardBorder),
                                                      ),
                                                      child: Text(
                                                        _bestStatusFromRow(r),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                rupiah(asInt(r['total'])),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Models =================
class _DayPoint {
  final DateTime date;
  final int value;
  _DayPoint({required this.date, required this.value});
}

class _TopProduct {
  final String name;
  final int qty;
  final int revenue;

  _TopProduct({required this.name, required this.qty, required this.revenue});

  _TopProduct copyWith({String? name, int? qty, int? revenue}) {
    return _TopProduct(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      revenue: revenue ?? this.revenue,
    );
  }
}

// ================= Dashboard Sections =================
class _GraphSection extends StatefulWidget {
  final List<_DayPoint> series;
  final DateTimeRange range;

  const _GraphSection({
    required this.series,
    required this.range,
  });

  @override
  State<_GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<_GraphSection> {
  String metric = 'Total Sales Amount';

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.show_chart_rounded),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Report Graph',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                color: Colors.black.withOpacity(0.02),
              ),
              child: DropdownButton<String>(
                value: metric,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(14),
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'Total Sales Amount',
                    child: Text('Total Sales Amount'),
                  ),
                ],
                onChanged: (v) => setState(() => metric = v ?? metric),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          width: double.infinity,
          child: _AreaChart(points: widget.series),
        ),
        const SizedBox(height: 10),
        Text(
          '${df.format(widget.range.start)}  —  ${df.format(widget.range.end)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}

class _FavoriteProductSection extends StatelessWidget {
  final List<_TopProduct> topProducts;
  final String Function(int) rupiah;

  const _FavoriteProductSection({
    required this.topProducts,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Favorite Product',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Icon(Icons.search_rounded, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            color: Colors.black.withOpacity(0.02),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  'Img',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Product Name',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              Text(
                'Total Orders',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (topProducts.isEmpty)
          Text(
            'Belum ada data item produk di report.\n'
            'Kalau mau muncul, ReportService.getReport() harus join transaction_items + products(name).',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.6),
            ),
          )
        else
          ...topProducts.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      color: Colors.black.withOpacity(0.03),
                    ),
                    child: const Icon(Icons.fastfood_rounded, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rupiah(p.revenue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${p.qty} times',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ================= Area Chart =================
class _AreaChart extends StatelessWidget {
  final List<_DayPoint> points;
  const _AreaChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AreaChartPainter(
        points: points,
        dividerColor: Theme.of(context).dividerColor,
        labelStyle: (Theme.of(context).textTheme.bodySmall ??
                const TextStyle(fontSize: 11))
            .copyWith(fontSize: 10),
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<_DayPoint> points;
  final Color dividerColor;
  final TextStyle labelStyle;

  _AreaChartPainter({
    required this.points,
    required this.dividerColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 40.0;
    final rightPad = 8.0;
    final topPad = 12.0;
    final bottomPad = 22.0;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final maxVal = max(
      1,
      points.isEmpty ? 0 : points.map((e) => e.value).reduce(max),
    );

    final gridPaint = Paint()
      ..color = dividerColor.withOpacity(0.8)
      ..strokeWidth = 1;

    // horizontal grid (0%, 50%, 100%)
    for (int i = 0; i <= 2; i++) {
      final y = topPad + h * (i / 2);
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);
    }

    _drawText(canvas, _shortNum(maxVal), Offset(0, topPad - 4));
    _drawText(
      canvas,
      _shortNum((maxVal / 2).round()),
      Offset(0, topPad + h / 2 - 4),
    );

    if (points.isEmpty) {
      _drawText(canvas, 'No data', Offset(leftPad + 8, topPad + 8));
      return;
    }

    final n = points.length;
    final dx = (n <= 1) ? w : (w / (n - 1));

    // build line path
    final line = Path();
    for (int i = 0; i < n; i++) {
      final p = points[i];
      final x = leftPad + dx * i;
      final y = topPad + (h - (p.value / maxVal) * h);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        // smooth curve
        final prev = points[i - 1];
        final px = leftPad + dx * (i - 1);
        final py = topPad + (h - (prev.value / maxVal) * h);
        final cx = (px + x) / 2;
        line.cubicTo(cx, py, cx, y, x, y);
      }

      // x label (selective)
      final showLabel =
          n <= 7 || i == 0 || i == n - 1 || i == (n / 2).floor();
      if (showLabel) {
        final label = DateFormat('dd/MM').format(p.date);
        _drawText(canvas, label, Offset(x - 10, topPad + h + 4),
            style: labelStyle);
      }
    }

    // area path
    final area = Path.from(line)
      ..lineTo(leftPad + w, topPad + h)
      ..lineTo(leftPad, topPad + h)
      ..close();

    final areaPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(leftPad, topPad),
        Offset(leftPad, topPad + h),
        [
          Colors.blue.withOpacity(0.22),
          Colors.blue.withOpacity(0.02),
        ],
      );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.blue.withOpacity(0.9);

    // draw
    canvas.drawPath(area, areaPaint);
    canvas.drawPath(line, linePaint);

    // last dot
    final last = points.last;
    final lx = leftPad + dx * (n - 1);
    final ly = topPad + (h - (last.value / maxVal) * h);
    final dotFill = Paint()..color = Colors.blue.withOpacity(0.95);
    final dotBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawCircle(Offset(lx, ly), 5.2, dotFill);
    canvas.drawCircle(Offset(lx, ly), 5.2, dotBorder);
  }

  String _shortNum(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}rb';
    return v.toString();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextStyle? style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style ?? labelStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}

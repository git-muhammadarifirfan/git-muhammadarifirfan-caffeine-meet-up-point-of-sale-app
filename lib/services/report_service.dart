import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  static final _db = Supabase.instance.client;

  /// Ambil laporan transaksi (lebih lengkap + join items untuk perhitungan profit).
  /// Catatan: profit dihitung dari formula:
  /// Total bayar customer (Net Sales) = Subtotal - Diskon (atau pakai kolom `total`)
  /// Gross Profit = Net Sales - HPP
  /// Net Profit = Gross Profit - Fee - OtherCost
  static Future<List<Map<String, dynamic>>> getReport({
    required DateTime from,
    required DateTime to,
    String? paymentMethod,
    String? status,
  }) async {
    var q = _db.from('transactions').select(
          'id,user_id,subtotal,discount,fee,other_cost,total,received_amount,change_amount,payment_method,status,status_reason,created_at,order_no,customer_name,'
          'transaction_items(qty,price,buy_price,note,products(name))',
        );

    q = q.gte('created_at', from.toIso8601String());
    q = q.lte('created_at', to.toIso8601String());

    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      q = q.eq('payment_method', paymentMethod.trim());
    }
    if (status != null && status.trim().isNotEmpty) {
      q = q.eq('status', status.trim());
    }

    final res = await q.order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(res);

    final ids = rows.map((e) => e['user_id']).whereType<String>().toSet().toList();
    final names = await _fetchProfileNames(ids);

    return rows.map((t) {
      final itemsRaw = t['transaction_items'];
      final items = (itemsRaw is List)
          ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      // fallback subtotal dari items (kalau subtotal = 0 tapi items ada)
      int subtotal = _asInt(t['subtotal']);
      if (subtotal == 0 && items.isNotEmpty) {
        subtotal = items.fold<int>(
          0,
          (sum, it) => sum + (_asInt(it['price']) * _asInt(it['qty'])),
        );
      }

      final discount = _asInt(t['discount']);
      final fee = _asInt(t['fee']);
      final other = _asInt(t['other_cost']);

      // total (net sales) disimpan di kolom total, tapi tetap aman kalau belum ada
      int netSales = _asInt(t['total']);
      final computedNet = subtotal - discount;
      if (netSales == 0 && computedNet != 0) {
        netSales = computedNet < 0 ? 0 : computedNet;
      }

      final hpp = items.fold<int>(
        0,
        (sum, it) => sum + (_asInt(it['buy_price']) * _asInt(it['qty'])),
      );

      final gross = netSales - hpp;
      final net = gross - fee - other;

      final marginPct = netSales == 0 ? 0.0 : (gross / netSales) * 100.0;
      final markupPct = hpp == 0 ? 0.0 : (gross / hpp) * 100.0;

      return {
        ...t,
        'cashier_name': names[t['user_id']] ?? '-',
        // normalized items for UI
        'items': items,
        // derived numbers
        'subtotal_calc': subtotal,
        'net_sales': netSales,
        'hpp': hpp,
        'gross_profit': gross,
        'net_profit': net,
        'gross_margin_pct': marginPct,
        'markup_pct': markupPct,
      };
    }).toList();
  }

  static Future<File> exportPdf({
    required List<Map<String, dynamic>> rows,
    required DateTime from,
    required DateTime to,
    String fileNamePrefix = 'laporan_pos',
    int maxRows = 200,
  }) async {
    int totalTrx = rows.length;

    int sumSubtotal = 0;
    int sumDiscount = 0;
    int sumNetSales = 0;
    int sumFee = 0;
    int sumOther = 0;
    int sumHpp = 0;
    int sumGross = 0;
    int sumNet = 0;

    int cashSales = 0;
    int nonCashSales = 0;

    for (final r in rows) {
      sumSubtotal += _asInt(r['subtotal_calc'] ?? r['subtotal']);
      sumDiscount += _asInt(r['discount']);
      sumNetSales += _asInt(r['net_sales'] ?? r['total']);
      sumFee += _asInt(r['fee']);
      sumOther += _asInt(r['other_cost']);
      sumHpp += _asInt(r['hpp']);
      sumGross += _asInt(r['gross_profit']);
      sumNet += _asInt(r['net_profit']);

      final pm = (r['payment_method'] ?? '').toString().toLowerCase();
      if (pm == 'cash') {
        cashSales += _asInt(r['net_sales'] ?? r['total']);
      } else {
        nonCashSales += _asInt(r['net_sales'] ?? r['total']);
      }
    }

    final df = DateFormat('yyyy-MM-dd');
    final dfDT = DateFormat('yyyy-MM-dd HH:mm');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
        build: (_) {
          final limited = rows.take(maxRows).toList();

          return [
            pw.Text(
              'Laporan POS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Periode: ${df.format(from)} s/d ${df.format(to)}'),
            pw.SizedBox(height: 12),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rekap',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _kv('Total transaksi', totalTrx.toString()),
                  _kv('Subtotal', _rupiah(sumSubtotal)),
                  _kv('Diskon', _rupiah(sumDiscount)),
                  _kv('Net Sales (Total bayar)', _rupiah(sumNetSales)),
                  _kv('HPP', _rupiah(sumHpp)),
                  _kv('Gross Profit', _rupiah(sumGross)),
                  _kv('Fee', _rupiah(sumFee)),
                  _kv('Other Cost', _rupiah(sumOther)),
                  _kv('Net Profit', _rupiah(sumNet)),
                  pw.SizedBox(height: 6),
                  _kv('Cash Sales', _rupiah(cashSales)),
                  _kv('Non-cash Sales', _rupiah(nonCashSales)),
                ],
              ),
            ),

            pw.SizedBox(height: 14),
            pw.Text(
              'Detail Transaksi (max $maxRows baris)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),

            pw.Table.fromTextArray(
              headers: const [
                'Tanggal',
                'Order',
                'Kasir',
                'Metode',
                'Net Sales',
                'HPP',
                'Gross',
                'Net',
                'Status',
              ],
              data: limited.map((r) {
                final createdAt = DateTime.tryParse((r['created_at'] ?? '').toString());
                final dtStr = createdAt != null ? dfDT.format(createdAt) : '-';
                return [
                  dtStr,
                  (r['order_no'] ?? '-').toString(),
                  (r['cashier_name'] ?? '-').toString(),
                  (r['payment_method'] ?? '-').toString(),
                  _rupiah(_asInt(r['net_sales'] ?? r['total'])),
                  _rupiah(_asInt(r['hpp'])),
                  _rupiah(_asInt(r['gross_profit'])),
                  _rupiah(_asInt(r['net_profit'])),
                  (r['status'] ?? '-').toString().toUpperCase(),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final fn = "${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf";
    final file = File('${dir.path}/$fn');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static Future<File> exportExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime from,
    required DateTime to,
    String fileNamePrefix = 'laporan_transaksi',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Order No'),
      TextCellValue('Customer'),
      TextCellValue('Kasir'),
      TextCellValue('Metode'),
      TextCellValue('Status'),
      TextCellValue('Subtotal'),
      TextCellValue('Diskon'),
      TextCellValue('Net Sales'),
      TextCellValue('HPP'),
      TextCellValue('Gross Profit'),
      TextCellValue('Fee'),
      TextCellValue('Other Cost'),
      TextCellValue('Net Profit'),
      TextCellValue('Margin (%)'),
      TextCellValue('Alasan'),
    ]);

final dfDate = DateFormat('yyyy-MM-dd');
    final dfTime = DateFormat('HH:mm');

    for (final r in rows) {
      final createdAt = DateTime.tryParse((r['created_at'] ?? '').toString());
      final dateStr = createdAt != null ? dfDate.format(createdAt) : '-';
      final timeStr = createdAt != null ? dfTime.format(createdAt) : '-';

      final subtotal = _asInt(r['subtotal_calc'] ?? r['subtotal']);
      final discount = _asInt(r['discount']);
      final netSales = _asInt(r['net_sales'] ?? r['total']);
      final hpp = _asInt(r['hpp']);
      final gross = _asInt(r['gross_profit']);
      final fee = _asInt(r['fee']);
      final other = _asInt(r['other_cost']);
      final net = _asInt(r['net_profit']);
      final margin = (r['gross_margin_pct'] is num)
          ? (r['gross_margin_pct'] as num).toDouble()
          : double.tryParse((r['gross_margin_pct'] ?? '0').toString()) ?? 0.0;

      sheet.appendRow([
        TextCellValue(dateStr),
        TextCellValue(timeStr),
        TextCellValue((r['order_no'] ?? '-').toString()),
        TextCellValue((r['customer_name'] ?? '-').toString()),
        TextCellValue((r['cashier_name'] ?? '-').toString()),
        TextCellValue((r['payment_method'] ?? '-').toString()),
        TextCellValue((r['status'] ?? '-').toString().toUpperCase()),
        IntCellValue(subtotal),
        IntCellValue(discount),
        IntCellValue(netSales),
        IntCellValue(hpp),
        IntCellValue(gross),
        IntCellValue(fee),
        IntCellValue(other),
        IntCellValue(net),
        TextCellValue(margin.toStringAsFixed(2)),
        TextCellValue((r['status_reason'] ?? '').toString()),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal encode Excel');

    final dir = await getTemporaryDirectory();
    final fn = "${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";
    final file = File('${dir.path}/$fn');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> exportCsv({
    required List<Map<String, dynamic>> rows,
    String fileNamePrefix = 'laporan_transaksi',
  }) async {
    final dfDT = DateFormat('yyyy-MM-dd HH:mm');

    final header = <String>[
      'created_at',
      'order_no',
      'customer_name',
      'cashier_name',
      'payment_method',
      'status',
      'subtotal',
      'discount',
      'net_sales',
      'hpp',
      'gross_profit',
      'fee',
      'other_cost',
      'net_profit',
      'gross_margin_pct',
      'markup_pct',
      'status_reason',
    ];

    final data = <List<dynamic>>[];
    data.add(header);

    for (final r in rows) {
      final createdAt = DateTime.tryParse((r['created_at'] ?? '').toString());
      final dtStr = createdAt != null ? dfDT.format(createdAt) : (r['created_at'] ?? '').toString();

      data.add([
        dtStr,
        (r['order_no'] ?? '').toString(),
        (r['customer_name'] ?? '').toString(),
        (r['cashier_name'] ?? '').toString(),
        (r['payment_method'] ?? '').toString(),
        (r['status'] ?? '').toString(),
        _asInt(r['subtotal_calc'] ?? r['subtotal']),
        _asInt(r['discount']),
        _asInt(r['net_sales'] ?? r['total']),
        _asInt(r['hpp']),
        _asInt(r['gross_profit']),
        _asInt(r['fee']),
        _asInt(r['other_cost']),
        _asInt(r['net_profit']),
        (r['gross_margin_pct'] is num) ? (r['gross_margin_pct'] as num).toDouble().toStringAsFixed(2) : (r['gross_margin_pct'] ?? '0').toString(),
        (r['markup_pct'] is num) ? (r['markup_pct'] as num).toDouble().toStringAsFixed(2) : (r['markup_pct'] ?? '0').toString(),
        (r['status_reason'] ?? '').toString(),
      ]);
    }

    final csv = const ListToCsvConverter().convert(data);

    final dir = await getTemporaryDirectory();
    final fn = "${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";
    final file = File('${dir.path}/$fn');
    await file.writeAsString(csv, flush: true);
    return file;
  }

  static Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<Map<String, String>> _fetchProfileNames(List<String> userIds) async {
    final map = <String, String>{};
    if (userIds.isEmpty) return map;

    final ids = userIds.toSet().toList();
    for (final id in ids) {
      try {
        final res = await _db.from('profiles').select('id,name').eq('id', id).maybeSingle();
        if (res == null) {
          map[id] = '-';
        } else {
          final name = (res['name'] ?? '').toString();
          map[id] = name.isNotEmpty ? name : '-';
        }
      } catch (_) {
        map[id] = '-';
      }
    }
    return map;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _rupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(k)),
          pw.SizedBox(width: 10),
          pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bt_permission.dart';

class PrinterSettings {
  final String? name;
  final String? mac;
  final int paperMm; // 58 or 80

  const PrinterSettings({
    required this.name,
    required this.mac,
    required this.paperMm,
  });

  PrinterSettings copyWith({String? name, String? mac, int? paperMm}) {
    return PrinterSettings(
      name: name ?? this.name,
      mac: mac ?? this.mac,
      paperMm: paperMm ?? this.paperMm,
    );
  }
}

class PrinterService {
  static final _db = Supabase.instance.client;

  static const String _kMac = 'printer_mac';
  static const String _kName = 'printer_name';
  static const String _kPaper = 'printer_paper_mm';
  static const String _hrMarker = '__HR__';

  // Header struk
  static const String storeName = 'Mager Coffee Lab x Caffeine Meet Up';
  static const List<String> storeAddressLines = [
    'Caffeine Meet Up, Jl. Suronatan',
    'Baru No.3, Mergelo, Magersari,',
  ];

  static const List<String> footerLines = [
    'KRITIK DAN SARAN',
    'IG @caffeinemeetup',
    'DELIVERY ORDER CP 083836947628',
  ];

  static Future<PrinterSettings> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    final paper = sp.getInt(_kPaper) ?? 58;
    return PrinterSettings(
      name: sp.getString(_kName),
      mac: sp.getString(_kMac),
      paperMm: (paper == 80) ? 80 : 58,
    );
  }

  static Future<void> saveDevice({
    required String name,
    required String mac,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, name);
    await sp.setString(_kMac, mac);
  }

  static Future<void> clearDevice() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kName);
    await sp.remove(_kMac);
  }

  static Future<void> savePaperMm(int mm) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kPaper, (mm == 80) ? 80 : 58);
  }

  static Future<List<BluetoothInfo>> pairedDevices() async {
    final ok = await BtPermission.ensureForPairedList();
    if (!ok) {
      throw Exception(
        'Izin Bluetooth/Nearby devices belum diizinkan. Buka App Settings lalu izinkan.',
      );
    }
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> isBluetoothEnabled() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  static Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  static Future<bool> connect(String mac) async {
    final okPerm = await BtPermission.ensureForConnectAndPrint();
    if (!okPerm) {
      throw Exception(
        'Izin Bluetooth/Nearby devices belum diizinkan. Buka App Settings lalu izinkan.',
      );
    }

    // Banyak printer murah suka "nyangkut" dengan koneksi lama.
    // Jadi selalu disconnect dulu sebelum connect fresh.
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 250));

    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) return false;

    // beri waktu modul BT printer siap menerima data.
    await Future.delayed(const Duration(milliseconds: 650));
    return await PrintBluetoothThermal.connectionStatus;
  }

  static Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  /// Kirim bytes ke printer dengan cara di-chunk supaya printer 58mm murah
  /// tidak drop saat menerima data besar.
  static Future<void> _writeInChunks(
    List<int> data, {
    int chunkSize = 512,
    Duration delay = const Duration(milliseconds: 20),
  }) async {
    int off = 0;
    while (off < data.length) {
      final end = (off + chunkSize < data.length) ? off + chunkSize : data.length;
      final chunk = data.sublist(off, end); // ✅ List<int>, bukan Uint8List
      final ok = await PrintBluetoothThermal.writeBytes(chunk);
      if (!ok) throw Exception('Gagal mengirim data ke printer.');
      off = end;
      if (off < data.length) await Future.delayed(delay);
    }
  }

  /// Pastikan BT aktif + permission OK + terhubung ke printer yang tersimpan.
  /// Return settings yang dipakai.
  static Future<PrinterSettings> _ensureConnectedOrThrow() async {
    final settings = await loadSettings();
    final mac = settings.mac;
    if (mac == null || mac.trim().isEmpty) {
      throw Exception(
        'Printer belum dipilih. Buka Profile > Printer Settings.',
      );
    }

    final enabled = await isBluetoothEnabled();
    if (!enabled) throw Exception('Bluetooth belum aktif.');

    final okPerm = await BtPermission.ensureForConnectAndPrint();
    if (!okPerm) {
      throw Exception(
        'Izin Bluetooth/Nearby devices belum diizinkan. Buka App Settings lalu izinkan.',
      );
    }

    // Selalu connect fresh (hindari status "Connected" stale).
    final okConn = await connect(mac);
    if (!okConn) throw Exception('Gagal connect ke printer.');
    return settings;
  }

  /// Tombol TEST PRINT (untuk cek koneksi printer dari halaman Profile).
  static Future<void> testPrint() async {
    final settings = await _ensureConnectedOrThrow();

    final profile = await CapabilityProfile.load();
    final paper = (settings.paperMm == 80) ? PaperSize.mm80 : PaperSize.mm58;
    final gen = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(
      gen.text(
        'TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    );

    bytes.addAll(
      gen.text(
        (settings.name ?? 'Printer').toString(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    );

    final now = DateTime.now();
    final ts =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    bytes.addAll(
      gen.text(
        ts,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    );

    bytes.addAll(gen.hr(ch: '-'));
    bytes.addAll(
      gen.text(
        'Jika ini tercetak, koneksi OK.',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    );
    bytes.addAll(gen.feed(3));

    try {
      await _writeInChunks(bytes);
    } catch (_) {
      // retry sekali
      final mac = settings.mac!.trim();
      final ok2 = await connect(mac);
      if (!ok2) rethrow;
      await _writeInChunks(bytes);
    }
  }

  /// Print struk by trxId (ambil transaksi + item langsung dari database).
  static Future<void> printReceiptByTrxId({
    required String trxId,
    String? fallbackCashier,
  }) async {
    final trx = await _db
        .from('transactions')
        .select(
          'id,user_id,subtotal,discount,total,received_amount,change_amount,payment_method,status,created_at,order_no,customer_name',
        )
        .eq('id', trxId)
        .single();

    final itemsRes = await _db
        .from('transaction_items')
        .select('qty, price, buy_price, note, product_id, products(name)')
        .eq('transaction_id', trxId);

    final items = List<Map<String, dynamic>>.from(itemsRes);

    String cashier = (fallbackCashier ?? '').toString().trim();
    if (cashier.isEmpty || cashier == '-') {
      try {
        final uid = trx['user_id'];
        if (uid != null) {
          final prof = await _db.from('profiles').select('full_name').eq('id', uid).maybeSingle();
          final nm = (prof?['full_name'] ?? '').toString().trim();
          if (nm.isNotEmpty) cashier = nm;
        }
      } catch (_) {
        // ignore
      }
    }

    await printTransactionReceipt(
      trx: Map<String, dynamic>.from(trx),
      items: items,
      cashier: cashier.isEmpty ? '-' : cashier,
    );
  }

  static String _dot(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write('.');
    }
    final out = buf.toString();
    return n < 0 ? '-$out' : out;
  }

  static String rp(int n) => 'Rp ${_dot(n)}';

  static String _fmtDateTime(dynamic v) {
    if (v == null) return '';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm:$ss';
    } catch (_) {
      return v.toString();
    }
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  // =========================
  // Layout helpers (NEW)
  // =========================

  static int _maxCharsForPaper(int paperMm) => (paperMm == 80) ? 48 : 32;

  static String _collapseSpaces(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<String> _wrapText(String text, int maxChars) {
    final t = _collapseSpaces(text);
    if (t.isEmpty) return const [];
    if (t.length <= maxChars) return [t];

    final words = t.split(' ');
    final lines = <String>[];
    var current = StringBuffer();

    for (final w in words) {
      if (w.isEmpty) continue;

      // kalau ada kata super panjang, pecah paksa
      if (w.length > maxChars) {
        if (current.isNotEmpty) {
          lines.add(current.toString().trimRight());
          current = StringBuffer();
        }
        int i = 0;
        while (i < w.length) {
          final end = (i + maxChars < w.length) ? i + maxChars : w.length;
          lines.add(w.substring(i, end));
          i = end;
        }
        continue;
      }

      final next = (current.isEmpty) ? w : '${current.toString()} $w';
      if (next.length <= maxChars) {
        current.clear();
        current.write(next);
      } else {
        if (current.isNotEmpty) lines.add(current.toString().trimRight());
        current = StringBuffer()..write(w);
      }
    }

    if (current.isNotEmpty) lines.add(current.toString().trimRight());
    return lines;
  }

  static String _safeOneLine(String s, int maxChars) {
    final t = _collapseSpaces(s);
    if (t.length <= maxChars) return t;
    if (maxChars <= 1) return t.substring(0, 1);
    return '${t.substring(0, maxChars - 1)}…';
  }

  static void _addMetaLine(Generator gen, List<int> bytes, String label, String value,
      {int labelWidth = 4}) {
    // Format: "Key : Value" (lebih kebaca di struk)
    final l = label.trim();
    final v = value.trim();
    if (v.isEmpty) return;
    bytes.addAll(
      gen.text(
        '${l.padRight(labelWidth)}: $v',
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
  }

  static void _addAmountRow(Generator gen, List<int> bytes, String label, String value,
      {bool bold = false}) {
    bytes.addAll(
      gen.row([
        PosColumn(
          text: label,
          width: 7,
          styles: PosStyles(align: PosAlign.left, bold: bold),
        ),
        PosColumn(
          text: value,
          width: 5,
          styles: PosStyles(align: PosAlign.right, bold: bold),
        ),
      ]),
    );
  }

  /// Print struk transaksi.
  /// - panggil hanya untuk transaksi status == 'paid'
  /// - items hasil dari TransactionService.getTransactionItems
  static Future<void> printTransactionReceipt({
    required Map<String, dynamic> trx,
    required List<Map<String, dynamic>> items,
    String? cashier,
  }) async {
    final settings = await _ensureConnectedOrThrow();
    final mac = settings.mac!.trim();

    final profile = await CapabilityProfile.load();
    final paper = (settings.paperMm == 80) ? PaperSize.mm80 : PaperSize.mm58;
    final gen = Generator(paper, profile);

    final maxChars = _maxCharsForPaper(settings.paperMm);

    final bytes = <int>[];

    // ========= HEADER =========
    bytes.addAll(
      gen.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    );

    // Alamat (lebih rapi, tanpa line kosong aneh)
    for (final line in storeAddressLines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t == _hrMarker) continue; // marker hanya buat pemisah, kita kontrol sendiri
      bytes.addAll(gen.text(t, styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.hr(ch: '-'));

    bytes.addAll(
      gen.text(
        'STRUK PEMBAYARAN',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(gen.hr(ch: '-'));

    // ========= META =========
    final dt = _fmtDateTime(trx['created_at']);
    final kasir = (cashier ?? '').trim().isEmpty ? '-' : cashier!.trim();

    final orderNo = trx['order_no'];
    final orderText = (orderNo != null)
        ? '#${orderNo.toString().padLeft(3, '0')}'
        : '-';

    final customer = (trx['customer_name'] ?? '').toString().trim();

    _addMetaLine(gen, bytes, 'Waktu', dt, labelWidth: 5);
    _addMetaLine(gen, bytes, 'Order', orderText, labelWidth: 5);
    _addMetaLine(gen, bytes, 'Kasir', kasir, labelWidth: 5);
    if (customer.isNotEmpty) _addMetaLine(gen, bytes, 'Cust', customer, labelWidth: 5);

    bytes.addAll(gen.hr(ch: '-'));

    // ========= ITEMS =========
    // Header kolom kecil (biar kebaca, tapi tidak makan tempat)
    bytes.addAll(
      gen.row([
        PosColumn(
          text: 'Item',
          width: 7,
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 5,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(gen.hr(ch: '-'));

    int idx = 0;
    for (final it in items) {
      idx++;
      final prod = it['products'];
      final rawName = (prod is Map ? (prod['name'] ?? '') : (it['name'] ?? '')).toString();
      final name = _collapseSpaces(rawName.isEmpty ? '-' : rawName);

      final qty = _asInt(it['qty']);
      final price = _asInt(it['price']);
      final lineTotal = price * qty;

      // Nama item: wrap + numbering
      final prefix = '$idx. ';
      final nameMax = (maxChars - prefix.length).clamp(8, maxChars);
      final nameLines = _wrapText(name, nameMax);

      if (nameLines.isEmpty) {
        bytes.addAll(gen.text('$prefix-', styles: const PosStyles(bold: true)));
      } else {
        // line 1: "1. Nama..."
        bytes.addAll(
          gen.text(
            '$prefix${nameLines.first}',
            styles: const PosStyles(bold: true, align: PosAlign.left),
          ),
        );
        // line berikutnya: indent
        for (int i = 1; i < nameLines.length; i++) {
          bytes.addAll(gen.text('   ${nameLines[i]}'));
        }
      }

      // Detail qty x harga + total kanan (lebih rapi)
      final leftDetail = _safeOneLine('$qty x ${rp(price)}', maxChars);
      bytes.addAll(
        gen.row([
          PosColumn(
            text: leftDetail,
            width: 7,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: rp(lineTotal),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );

      // Note (jika ada)
      final note = (it['note'] ?? '').toString().trim();
      if (note.isNotEmpty) {
        final noteLines = _wrapText(note, (maxChars - 4).clamp(10, maxChars));
        for (final nl in noteLines) {
          bytes.addAll(gen.text('   • $nl'));
        }
      }

      // Spasi tipis antar item
      bytes.addAll(gen.feed(1));
    }

    // ========= SUMMARY =========
    bytes.addAll(gen.hr(ch: '-'));

    final subtotal = _asInt(trx['subtotal']);
    final discount = _asInt(trx['discount']);
    final total = _asInt(trx['total']);
    final payment = (trx['payment_method'] ?? '').toString().trim();
    final received = _asInt(trx['received_amount']);
    final change = _asInt(trx['change_amount']);

    _addAmountRow(gen, bytes, 'Sub Total', rp(subtotal));
    if (discount > 0) _addAmountRow(gen, bytes, 'Diskon', '-${rp(discount)}');

    bytes.addAll(gen.hr(ch: '='));
    _addAmountRow(gen, bytes, 'TOTAL', rp(total), bold: true);
    bytes.addAll(gen.hr(ch: '='));

    final payLabel = payment.isEmpty ? 'METODE' : 'METODE';
    _addMetaLine(
      gen,
      bytes,
      payLabel,
      payment.isEmpty ? '-' : payment.toUpperCase(),
      labelWidth: 6,
    );

    if (payment.toLowerCase() == 'cash') {
      _addAmountRow(gen, bytes, 'Bayar', rp(received));
      _addAmountRow(gen, bytes, 'Kembali', rp(change));
    } else {
      // Non-cash biasanya bayar pas total
      _addAmountRow(gen, bytes, 'Dibayar', rp(total));
    }

    bytes.addAll(gen.feed(1));

    // ========= FOOTER =========
    bytes.addAll(
      gen.text(
        'Terima kasih 🙏',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(gen.feed(1));

    for (final line in footerLines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      bytes.addAll(
        gen.text(
          t,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes.addAll(gen.feed(2));
    // Banyak printer murah tidak punya cutter, jadi jangan cut.

    try {
      await _writeInChunks(bytes);
    } catch (_) {
      // Retry sekali: reconnect lalu kirim ulang.
      final ok2 = await connect(mac);
      if (!ok2) rethrow;
      await _writeInChunks(bytes);
    }
  }
}

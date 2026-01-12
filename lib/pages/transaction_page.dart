import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notifier.dart';
import '../services/transaction_service.dart';
import '../services/printer_service.dart';
import '../core/pos_ui.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late Future<List<Map<String, dynamic>>> transactions;

  // ===== Filters (UI) =====
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _range;
  String _statusFilter = 'all'; // all | pending | paid | voided | refunded | canceled

  @override
  void initState() {
    super.initState();
    transactions = TransactionService.getTransactions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      transactions = TransactionService.getTransactions(
        from: _range?.start,
        to: _range?.end,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
    });
  }

  // ===== Status UI =====
  Color _statusColor(String s) {
    switch (s) {
      case TransactionService.statusPaid:
        return const Color(0xFF16A34A);
      case TransactionService.statusPending:
        return const Color(0xFF2563EB);
      case TransactionService.statusVoided:
        return const Color(0xFFF59E0B);
      case TransactionService.statusRefunded:
        return const Color(0xFFEF4444);
      case TransactionService.statusCanceled:
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF334155);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case TransactionService.statusPaid:
        return Icons.check_circle_rounded;
      case TransactionService.statusPending:
        return Icons.hourglass_bottom_rounded;
      case TransactionService.statusVoided:
        return Icons.block_rounded;
      case TransactionService.statusRefunded:
        return Icons.keyboard_return_rounded;
      case TransactionService.statusCanceled:
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case TransactionService.statusPaid:
        return 'Paid';
      case TransactionService.statusPending:
        return 'Pending';
      case TransactionService.statusVoided:
        return 'Voided';
      case TransactionService.statusRefunded:
        return 'Refunded';
      case TransactionService.statusCanceled:
        return 'Canceled';
      default:
        return s;
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    // penting: jangan pakai postFrame biar nggak nyangkut context saat sheet/dialog ditutup
    notify(context, msg, error: error);
  }

  // ===== Dialog helpers =====
  Future<String?> _askReason({
    required String title,
    required String hint,
  }) async {
    final ctrl = TextEditingController();
    String? errorText;

    final res = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final v = ctrl.text.trim();
              if (v.isEmpty) {
                setLocal(() => errorText = 'Tidak boleh kosong');
                // optional: toast juga (biar jelas)
                _toast('Alasan tidak boleh kosong', error: true);
                return;
              }
              Navigator.pop(dialogCtx, v);
            }

            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setLocal(() => errorText = null);
                  }
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
    return res;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String okText = 'Ya',
    String cancelText = 'Tidak',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ===== Layout helpers =====
  bool _isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 900;

  String _money(num v) => 'Rp ${NumberFormat('#,###', 'id_ID').format(v.toInt())}';


  // ===== Safe parsers (anti-crash) =====
  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    if (raw is int) {
      // unix ms atau s (heuristik)
      if (raw > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) {
      final v = raw.toInt();
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }

    final s = raw.toString().trim();
    final dt = DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T'));
    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _productNameFrom(dynamic productsField) {
    if (productsField is Map) {
      final name = productsField['name'];
      return (name == null || name.toString().trim().isEmpty) ? '-' : name.toString();
    }
    if (productsField is List && productsField.isNotEmpty) {
      final first = productsField.first;
      if (first is Map) {
        final name = first['name'];
        return (name == null || name.toString().trim().isEmpty) ? '-' : name.toString();
      }
    }
    return '-';
  }


  Widget _statusPill(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _chipButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosTokens.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: PosTokens.text),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: PosTokens.text,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final init = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
    );

    if (picked == null) return;
    setState(() => _range = picked);
    reload();
  }

  

Future<int?> _askCashReceived({required int total}) async {
  final ctrl = TextEditingController();
  String? err;
  int preview = 0;

  final res = await showDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          void recompute() {
            final v = int.tryParse(ctrl.text.trim()) ?? 0;
            setLocal(() {
              preview = v;
              err = null;
            });
          }

          void submit() {
            final v = int.tryParse(ctrl.text.trim()) ?? 0;
            if (v < total) {
              setLocal(() => err = 'Uang diterima kurang dari total');
              return;
            }
            Navigator.pop(dialogCtx, v);
          }

          return AlertDialog(
            title: const Text('Pembayaran Cash'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: ${_money(total)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Uang diterima',
                    hintText: 'Contoh: 50000',
                    errorText: err,
                  ),
                  onChanged: (_) => recompute(),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kembalian: ${_money((preview - total) < 0 ? 0 : (preview - total))}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );

  ctrl.dispose();
  return res;
}

// ===== Actions sheet =====
  Widget _buildActionButtons({
  required BuildContext sheetCtx,
  required Map<String, dynamic> trx,
  required List<Map<String, dynamic>> items,
  required String userId,
  required String status,
}) {
  final trxId = trx['id'].toString();
  final isPending = status == TransactionService.statusPending;
  final isPaid = status == TransactionService.statusPaid;
  final isFinal = !isPending && !isPaid;

  // guard biar user gak bisa spam klik & biar async gak nabrak context disposed
  final busy = ValueNotifier<bool>(false);

  void closeSheetSafely() {
    // jangan pernah pakai Navigator.of(sheetCtx) tanpa cek mounted
    if (!mounted) return;
    if (!sheetCtx.mounted) return;

    final nav = Navigator.maybeOf(sheetCtx);
    if (nav != null && nav.canPop()) nav.pop();
  }

  Future<void> runGuarded(Future<void> Function() job) async {
    if (busy.value) return;
    busy.value = true;
    try {
      await job();
    } catch (e, st) {
      // biar keliatan root errornya di console (penting buat debugging)
      debugPrint('ACTION ERROR: $e');
      debugPrintStack(stackTrace: st);

      if (mounted) _toast(e.toString(), error: true);
    } finally {
      if (busy.hasListeners) busy.value = false;
    }
  }

  if (isFinal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF6F8FC),
        border: Border.all(color: PosTokens.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Status sudah final. Tidak bisa diubah lagi.')),
        ],
      ),
    );
  }

  return ValueListenableBuilder<bool>(
    valueListenable: busy,
    builder: (_, isBusy, __) {
      Future<void> runPaid() async => runGuarded(() async {
            final ok = await _confirm(
              title: 'Konfirmasi',
              message: 'Set transaksi ini jadi PAID?\nStok akan berkurang.',
              okText: 'Ya, PAID',
            );
            if (!ok) return;
            if (!mounted) return;

            final pay = (trx['payment_method'] ?? '').toString().toLowerCase();
            final totalPay = _toNum(trx['total']).toInt();

            if (pay == 'cash') {
              final received = await _askCashReceived(total: totalPay);
              if (received == null) return;
              final change = (received - totalPay);
              await TransactionService.markAsPaid(
                trxId: trxId,
                userId: userId,
                receivedAmount: received,
                changeAmount: change < 0 ? 0 : change,
              );
            } else {
              await TransactionService.markAsPaid(trxId: trxId, userId: userId);
            }
            if (!mounted) return;

            _toast('Status jadi PAID');
            closeSheetSafely();
            reload();
          });

      Future<void> runVoid({required String title}) async => runGuarded(() async {
            final reason = await _askReason(
              title: title,
              hint: 'Contoh: salah input / customer batal',
            );
            if (reason == null) return;
            if (!mounted) return;

            final ok = await _confirm(
              title: 'Konfirmasi',
              message: 'Yakin VOID transaksi ini?',
              okText: 'Ya, VOID',
            );
            if (!ok) return;
            if (!mounted) return;

            await TransactionService.voidTransaction(
              trxId: trxId,
              userId: userId,
              reason: reason,
            );
            if (!mounted) return;

            _toast(isPaid ? 'Transaksi VOIDED (stok balik)' : 'Transaksi VOIDED');
            closeSheetSafely();
            reload();
          });

      Future<void> runRefund() async => runGuarded(() async {
            final reason = await _askReason(
              title: 'Refund Transaksi',
              hint: 'Contoh: uang dikembalikan',
            );
            if (reason == null) return;
            if (!mounted) return;

            final ok = await _confirm(
              title: 'Konfirmasi',
              message: 'Yakin REFUND transaksi ini?',
              okText: 'Ya, REFUND',
            );
            if (!ok) return;
            if (!mounted) return;

            await TransactionService.refundTransaction(
              trxId: trxId,
              userId: userId,
              reason: reason,
            );
            if (!mounted) return;

            _toast('Transaksi REFUNDED (stok balik)');
            closeSheetSafely();
            reload();
          });

      Future<void> runCancel({required String title}) async => runGuarded(() async {
            final reason = await _askReason(
              title: title,
              hint: 'Contoh: customer batal / nominal salah',
            );
            if (reason == null) return;
            if (!mounted) return;

            final ok = await _confirm(
              title: 'Konfirmasi',
              message: 'Yakin CANCEL transaksi ini?',
              okText: 'Ya, CANCEL',
            );
            if (!ok) return;
            if (!mounted) return;

            await TransactionService.cancelTransaction(
              trxId: trxId,
              userId: userId,
              reason: reason,
            );
            if (!mounted) return;

            _toast('Transaksi CANCELED');
            closeSheetSafely();
            reload();
          });

      Future<void> runPrint() async => runGuarded(() async {
            // ✅ Ambil data terbaru langsung dari database biar struk selalu valid
            // (dan menghindari data UI yang mungkin stale).
            await PrinterService.printReceiptByTrxId(
              trxId: trx['id'].toString(),
              fallbackCashier: (trx['cashier_name'] ?? '-').toString(),
            );
            if (!mounted) return;
            _toast('Struk terkirim ke printer');
          });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),

          if (isPending)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: isBusy ? null : runPaid,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(isBusy ? 'Processing...' : 'Mark as PAID'),
              ),
            ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => runVoid(
                            title: isPending ? 'Void Transaksi (Pending)' : 'Void Transaksi',
                          ),
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Void'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => runCancel(
                            title: isPaid ? 'Cancel Transaksi (Paid)' : 'Cancel Transaksi',
                          ),
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),

          if (isPaid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: isBusy ? null : runPrint,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print Struk'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : runRefund,
                icon: const Icon(Icons.keyboard_return_rounded),
                label: const Text('Refund'),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            isPending
                ? '• PAID: stok berkurang\n• VOID/CANCEL: transaksi dibatalkan'
                : '• VOID/REFUND/CANCEL: stok akan kembali',
            style: const TextStyle(
              fontSize: 12,
              color: PosTokens.subtext,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    },
  );
}

  // ===== Detail Drawer (tablet) / BottomSheet (mobile) =====
  void openDetail(Map<String, dynamic> trx) {
    final isTablet = _isTablet(context);
    if (isTablet) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _detailCard(ctx, trx),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _detailCard(sheetCtx, trx),
            ),
          );
        },
      );
    }
  }

  Widget _detailCard(BuildContext sheetCtx, Map<String, dynamic> trx) {
    final date = _parseDate(trx['created_at']);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final status = (trx['status'] ?? TransactionService.statusPending).toString();
    final reason = (trx['status_reason'] ?? '').toString();
    final user = Supabase.instance.client.auth.currentUser;

    final orderNo = (trx['order_no'] ?? 0);
    final customerName = (trx['customer_name'] ?? '').toString();

    final headerOrderText = (orderNo is int && orderNo > 0)
        ? '#${orderNo.toString().padLeft(3, '0')}'
        : (orderNo.toString().isNotEmpty ? '#${orderNo.toString()}' : '-');

    return PosSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7FF),
                border: Border(
                  bottom: BorderSide(color: PosTokens.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PosTokens.border),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: PosTokens.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction Detail',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: PosTokens.text,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$headerOrderText • ${customerName.isEmpty ? '-' : customerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: PosTokens.subtext,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(status),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(sheetCtx).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: TransactionService.getTransactionItems(trx['id'].toString()),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 340,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return SizedBox(
                        height: 340,
                        child: Center(child: Text('Error items: ${snap.error}')),
                      );
                    }

                    final items = snap.data ?? [];

                    Widget infoRow(IconData icon, String label, String value) {
                      return Row(
                        children: [
                          Icon(icon, size: 18, color: PosTokens.text),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 105,
                            child: Text(
                              label,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              value,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.text),
                            ),
                          ),
                        ],
                      );
                    }

                    final total = (trx['total'] ?? 0) is num ? (trx['total'] as num) : num.tryParse('${trx['total']}') ?? 0;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PosTokens.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                infoRow(Icons.calendar_month_rounded, 'Date', df.format(date)),
                                const SizedBox(height: 8),
                                infoRow(Icons.person_rounded, 'Cashier', (trx['cashier_name'] ?? '-').toString()),
                                const SizedBox(height: 8),
                                infoRow(Icons.payments_rounded, 'Payment', (trx['payment_method'] ?? '-').toString()),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F8FC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: PosTokens.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.summarize_rounded, size: 18, color: PosTokens.text),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Total',
                                        style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _money(total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: PosTokens.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),


const SizedBox(height: 10),
// Profit breakdown
Builder(
  builder: (_) {
    final subtotal = _toNum(trx['subtotal']).toInt();
    final discount = _toNum(trx['discount']).toInt();
    final fee = _toNum(trx['fee']).toInt();
    final other = _toNum(trx['other_cost']).toInt();
    final totalPay = _toNum(trx['total']).toInt();

    int hpp = 0;
    for (final it in items) {
      final qty = _toNum(it['qty']).toInt();
      final buy = _toNum(it['buy_price']).toInt();
      hpp += (buy * qty);
    }

    final gross = totalPay - hpp;
    final net = gross - fee - other;
    final margin = totalPay == 0 ? 0.0 : (gross / totalPay) * 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profit', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
              Text(_money(subtotal), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          if (discount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('Diskon', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
                Text('-${_money(discount)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('HPP', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
              Text(_money(hpp), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Gross Profit', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text))),
              Text(_money(gross), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('Fee', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
              Text('-${_money(fee)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('Other Cost', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
              Text('-${_money(other)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text))),
              Text(_money(net), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Margin kotor: ${margin.toStringAsFixed(2)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext)),
          if ((trx['payment_method'] ?? '').toString().toLowerCase() == 'cash' &&
              status == TransactionService.statusPaid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('Uang diterima', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
                Text(_money(_toNum(trx['received_amount']).toInt()), style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('Kembalian', style: TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext))),
                Text(_money(_toNum(trx['change_amount']).toInt()), style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ],
      ),
    );
  },
),
                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: const Color(0xFFFFF7ED),
                                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.55)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Reason: $reason',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C2D12)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Actions
                          if (user != null) ...[
                            _buildActionButtons(
                              sheetCtx: sheetCtx,
                              trx: trx,
                              items: items,
                              userId: user.id,
                              status: status,
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFFF6F8FC),
                                border: Border.all(color: PosTokens.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Login diperlukan untuk mengubah status transaksi.',
                                      style: TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Items
                          const Text('Items', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text)),
                          const SizedBox(height: 8),

                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Tidak ada item', style: TextStyle(color: PosTokens.subtext, fontWeight: FontWeight.w700)),
                            )
                          else
                            ...items.map((i) {
                              final product = i['products'] as Map<String, dynamic>?;
                              final name = product?['name']?.toString() ?? '-';
                              final qty = (i['qty'] ?? 0);
                              final price = (i['price'] ?? 0);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: PosTokens.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: PosTokens.border),
                                      ),
                                      child: const Icon(Icons.local_cafe_rounded, color: PosTokens.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Qty: ${qty.toInt()} • Rp ${price.toInt()}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Top filter bar =====
  Widget _filterBar() {
    final df = DateFormat('dd MMM yyyy');
    final rangeText = _range == null ? 'Date Range' : '${df.format(_range!.start)} - ${df.format(_range!.end)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: 320,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PosTokens.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: PosTokens.subtext),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search order / customer / payment...',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, color: PosTokens.subtext),
                    ),
                ],
              ),
            ),
          ),

          // Date range
          _chipButton(
            icon: Icons.calendar_month_rounded,
            label: rangeText,
            onTap: _pickDateRange,
          ),

          // Status filter
          SizedBox(
            height: 44,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PosTokens.border),
                ),
                child: DropdownButton<String>(
                  value: _statusFilter,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'voided', child: Text('Voided')),
                    DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                    DropdownMenuItem(value: 'canceled', child: Text('Canceled')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                    reload();
                  },
                ),
              ),
            ),
          ),

          // Refresh
          _chipButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onTap: reload,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> data) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return data;

    bool hit(Map<String, dynamic> t) {
      final orderNo = (t['order_no'] ?? '').toString().toLowerCase();
      final cust = (t['customer_name'] ?? '').toString().toLowerCase();
      final pay = (t['payment_method'] ?? '').toString().toLowerCase();
      final status = (t['status'] ?? '').toString().toLowerCase();
      final total = (t['total'] ?? '').toString().toLowerCase();
      return orderNo.contains(q) || cust.contains(q) || pay.contains(q) || status.contains(q) || total.contains(q);
    }

    return data.where(hit).toList();
  }

  Widget _tableHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTokens.border),
      ),
      child: const Row(
        children: [
          SizedBox(width: 72, child: Text('Order', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          SizedBox(width: 140, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          Expanded(child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          SizedBox(width: 140, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          SizedBox(width: 120, child: Text('Payment', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
          SizedBox(width: 90, child: Text('Detail', style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext))),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> t) {
    final date = _parseDate(t['created_at']);
    final df = DateFormat('dd/MM/yyyy • HH:mm');

    final status = (t['status'] ?? TransactionService.statusPending).toString();
    final color = _statusColor(status);

    final orderNoRaw = (t['order_no'] ?? 0);
    final orderText = (orderNoRaw is int && orderNoRaw > 0)
        ? '#${orderNoRaw.toString().padLeft(3, '0')}'
        : (orderNoRaw.toString().isEmpty ? '-' : '#${orderNoRaw.toString()}');

    final customer = (t['customer_name'] ?? '-').toString();
    final total = (t['total'] ?? 0);
    final payment = (t['payment_method'] ?? '-').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => openDetail(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PosTokens.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      orderText,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Text(
                df.format(date),
                style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext),
              ),
            ),
            Expanded(
              child: Text(
                customer.isEmpty ? '-' : customer,
                style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 110, child: Align(alignment: Alignment.centerLeft, child: _statusPill(status))),
            SizedBox(
              width: 140,
              child: Text(
                _money(total is num ? total : num.tryParse('$total') ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                payment.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.subtext),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 90,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => openDetail(t),
                  child: const Text('Detail'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Mobile cards =====
  Widget _mobileCard(Map<String, dynamic> t) {
    final date = _parseDate(t['created_at']);
    final df = DateFormat('dd/MM/yyyy • HH:mm');

    final status = (t['status'] ?? TransactionService.statusPending).toString();
    final color = _statusColor(status);

    final orderNoRaw = (t['order_no'] ?? 0);
    final orderText = (orderNoRaw is int && orderNoRaw > 0)
        ? '#${orderNoRaw.toString().padLeft(3, '0')}'
        : (orderNoRaw.toString().isEmpty ? '-' : '#${orderNoRaw.toString()}');

    final customer = (t['customer_name'] ?? '-').toString();
    final total = (t['total'] ?? 0);
    final payment = (t['payment_method'] ?? '-').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => openDetail(t),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PosTokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 70,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$orderText • ${customer.isEmpty ? '-' : customer}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: PosTokens.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusPill(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${df.format(date)} • ${payment.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: PosTokens.subtext, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(total is num ? total : num.tryParse('$total') ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Page =====
  @override
  Widget build(BuildContext context) {
    final isTablet = _isTablet(context);

    return Scaffold(
      body: PosBackground(
        child: SafeArea(
          child: PosSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PosHeaderBar(title: 'Activity', crumb: 'Order History'),
                const SizedBox(height: 12),

                _filterBar(),
                const SizedBox(height: 12),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => reload(),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: transactions,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snap.hasError) {
                          return ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(child: Text('Error: ${snap.error}')),
                            ],
                          );
                        }

                        final raw = snap.data ?? [];
                        final data = _applySearch(raw);

                        if (data.isEmpty) {
                          return ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Tidak ada transaksi yang cocok')),
                            ],
                          );
                        }

                        if (isTablet) {
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: data.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              if (i == 0) return _tableHeaderRow();
                              return _tableRow(data[i - 1]);
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _mobileCard(data[i]),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
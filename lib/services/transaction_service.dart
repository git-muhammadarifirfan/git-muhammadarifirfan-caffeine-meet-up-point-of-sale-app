import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
  static final _db = Supabase.instance.client;

  /// Status transaksi
  static const String statusPending = 'pending';
  static const String statusPaid = 'paid';
  static const String statusVoided = 'voided';
  static const String statusRefunded = 'refunded';
  static const String statusCanceled = 'canceled';

  /// ========== CREATE TRANSACTION ==========
  /// Default: buat transaksi PENDING dulu (stok belum berkurang)
  static Future<String> createPendingTransaction({
    required String userId,
    required int subtotal,
    int discount = 0,
    int fee = 0,
    int otherCost = 0,
    required int total,
    required String payment, // cash/qris
    required List<Map<String, dynamic>> items,

    // ✅ baru (sesuai schema DB kamu)
    required int orderNo,
    required String customerName,
  }) async {
    final trx = await _db
        .from('transactions')
        .insert({
          'user_id': userId,
          'subtotal': subtotal,
          'discount': discount,
          'fee': fee,
          'other_cost': otherCost,
          'total': total,
          'received_amount': 0,
          'change_amount': 0,
          'payment_method': payment,
          'status': statusPending,

          // ✅ masuk DB
          'order_no': orderNo,
          'customer_name': customerName.trim(),
        })
        .select()
        .single();

    final trxId = trx['id'] as String;

    await _db.from('transaction_items').insert(
          items
              .map(
                (i) => {
                  'transaction_id': trxId,
                  'product_id': i['id'],
                  'price': i['price'],
                  'buy_price': i['buy_price'] ?? 0,
                  'qty': i['qty'],
                  'note': i['note'],
                },
              )
              .toList(),
        );

    await _insertLog(
      transactionId: trxId,
      userId: userId,
      action: 'create',
      reason: null,
    );

    return trxId;
  }

  /// Shortcut lama (kalau masih kepakai): langsung create PAID
  static Future<void> createTransaction({
    required String userId,
    required int total,
    required String payment,
    required List<Map<String, dynamic>> items,

    // ✅ baru (biar konsisten)
    required int orderNo,
    required String customerName,
  }) async {
    final trxId = await createPendingTransaction(
      userId: userId,
      subtotal: total,
      discount: 0,
      fee: 0,
      otherCost: 0,
      total: total,
      payment: payment,
      items: items,
      orderNo: orderNo,
      customerName: customerName,
    );

    // langsung jadi PAID (stok berkurang)
    await markAsPaid(trxId: trxId, userId: userId);
  }

  /// ========== GET LIST ==========
  /// Tanpa join profiles (biar aman)
  static Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    var q = _db.from('transactions').select(
          // ✅ tambahin order_no & customer_name
          'id,user_id,subtotal,discount,fee,other_cost,total,received_amount,change_amount,payment_method,status,status_reason,created_at,order_no,customer_name',
        );

    if (from != null) q = q.gte('created_at', from.toIso8601String());
    if (to != null) q = q.lte('created_at', to.toIso8601String());
    if (status != null && status.isNotEmpty) q = q.eq('status', status);

    final res = await q.order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(res);

    final ids = rows
        .map((e) => e['user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final names = await _fetchProfileNames(ids);

    return rows
        .map((t) => {...t, 'cashier_name': names[t['user_id']] ?? '-'})
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getTransactionItems(
    String trxId,
  ) async {
    final res = await _db
        .from('transaction_items')
        .select('qty, price, buy_price, note, product_id, products(name)')
        .eq('transaction_id', trxId);

    return List<Map<String, dynamic>>.from(res);
  }


  /// Ambil item buat kebutuhan stok saja (lebih ringan & aman, tanpa embed join)
  static Future<List<Map<String, dynamic>>> getTransactionStockItems(
    String trxId,
  ) async {
    final res = await _db
        .from('transaction_items')
        .select('qty, product_id')
        .eq('transaction_id', trxId);

    return List<Map<String, dynamic>>.from(res);
  }


  /// ========== STATUS CHANGES ==========
  static Future<void> markAsPaid({
    required String trxId,
    required String userId,
    int receivedAmount = 0,
    int changeAmount = 0,
  }) async {
    await _changeStatus(
      trxId: trxId,
      userId: userId,
      nextStatus: statusPaid,
      reason: null,
      receivedAmount: receivedAmount,
      changeAmount: changeAmount,
    );
  }

  static Future<void> voidTransaction({
    required String trxId,
    required String userId,
    required String reason,
  }) async {
    await _changeStatus(
      trxId: trxId,
      userId: userId,
      nextStatus: statusVoided,
      reason: reason,
    );
  }

  static Future<void> refundTransaction({
    required String trxId,
    required String userId,
    required String reason,
  }) async {
    await _changeStatus(
      trxId: trxId,
      userId: userId,
      nextStatus: statusRefunded,
      reason: reason,
    );
  }

  static Future<void> cancelTransaction({
    required String trxId,
    required String userId,
    required String reason,
  }) async {
    await _changeStatus(
      trxId: trxId,
      userId: userId,
      nextStatus: statusCanceled,
      reason: reason,
    );
  }

  /// Rule stok:
  /// - pending -> paid : stok dikurangi
  /// - paid -> (void/refund/cancel) : stok dibalikin
  /// - pending -> canceled : stok tidak berubah
  static Future<void> _changeStatus({
    required String trxId,
    required String userId,
    required String nextStatus,
    String? reason,
    int? receivedAmount,
    int? changeAmount,
  }) async {
    // alasan wajib untuk void/refund/cancel
    final needReason =
        nextStatus == statusVoided ||
        nextStatus == statusRefunded ||
        nextStatus == statusCanceled;

    if (needReason && (reason == null || reason.trim().isEmpty)) {
      throw 'Alasan wajib diisi';
    }

    final trx = await _db
        .from('transactions')
        .select('id,status')
        .eq('id', trxId)
        .single();

    final prevStatus = (trx['status'] ?? statusPending).toString();

    if (prevStatus == nextStatus) return;

    // final state
    final isFinal =
        prevStatus == statusVoided ||
        prevStatus == statusRefunded ||
        prevStatus == statusCanceled;

    if (isFinal) {
      throw 'Transaksi sudah ${prevStatus.toUpperCase()}';
    }

    // Update status
    final update = <String, dynamic>{
  'status': nextStatus,
  'status_reason': (reason ?? '').trim(),
  'updated_at': DateTime.now().toIso8601String(),
};

// simpan uang diterima & kembalian ketika jadi PAID (khusus cash)
if (nextStatus == statusPaid) {
  update['received_amount'] = receivedAmount ?? 0;
  update['change_amount'] = changeAmount ?? 0;
}

await _db.from('transactions').update(update).eq('id', trxId);

    // Handle stock transitions
    if (prevStatus == statusPending && nextStatus == statusPaid) {
      // kurangi stok
      final items = await getTransactionStockItems(trxId);
      for (final i in items) {
        final qty = (i['qty'] as num).toInt();
        final productId = (i['product_id']).toString();
        if (qty <= 0) continue;

        await _db.rpc(
          'adjust_stock',
          params: {'p_product_id': productId, 'p_delta': -qty},
        );
      }
    }

    if (prevStatus == statusPaid &&
        (nextStatus == statusVoided ||
            nextStatus == statusRefunded ||
            nextStatus == statusCanceled)) {
      // balikin stok
      final items = await getTransactionStockItems(trxId);
      for (final i in items) {
        final qty = (i['qty'] as num).toInt();
        final productId = (i['product_id']).toString();
        if (qty <= 0) continue;

        await _db.rpc(
          'adjust_stock',
          params: {'p_product_id': productId, 'p_delta': qty},
        );
      }
    }

    // Log
    await _insertLog(
      transactionId: trxId,
      userId: userId,
      action: nextStatus == statusPaid
          ? 'paid'
          : nextStatus == statusVoided
              ? 'void'
              : nextStatus == statusRefunded
                  ? 'refund'
                  : 'cancel',
      reason: (reason ?? '').trim().isEmpty ? null : reason!.trim(),
    );
  }

  static Future<void> _insertLog({
    required String transactionId,
    required String userId,
    required String action,
    String? reason,
  }) async {
    await _db.from('transaction_logs').insert({
      'transaction_id': transactionId,
      'user_id': userId,
      'action': action,
      'reason': reason,
    });
  }

  // ===== helpers =====
  /// tanpa in_ (kompatibilitas aman)
  static Future<Map<String, String>> _fetchProfileNames(
    List<String> userIds,
  ) async {
    final map = <String, String>{};
    if (userIds.isEmpty) return map;

    final ids = userIds.toSet().toList();

    for (final id in ids) {
      try {
        final res = await _db
            .from('profiles')
            .select('id,name')
            .eq('id', id)
            .maybeSingle();

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
}

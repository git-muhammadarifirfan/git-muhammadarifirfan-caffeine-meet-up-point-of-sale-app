import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import '../../services/product_service.dart';
import '../../core/notifier.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

enum _LayoutMode { phone, tablet, wide }

class _KasirPageState extends State<KasirPage> {
  // ====== DATA / STATE (LOGIC TETAP) ======
  final List<CartItem> cart = [];

  // Search UI state
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Customer
  final TextEditingController _customerCtrl = TextEditingController();

  // Payment UI state
  String _paymentUi = 'qris'; // qris | cash | transfer | ewallet | other

  // Cache products
  late Future<List<Map<String, dynamic>>> _productsFuture;

  // Order number (urut dari DB)
  int _orderNumber = 0;
  bool _loadingOrderNo = false;

  int get total => cart.fold(0, (s, i) => s + i.subtotal);

  // ====== STYLE TOKENS ======
  static const _radius = 20.0;
  static const _fieldRadius = 14.0;

  Color get _bg1 => const Color(0xFFF7FAFF);
  Color get _bg2 => const Color(0xFFEAF2FF);
  Color get _surface => Colors.white;
  Color get _stroke => const Color(0xFFE8EEF7);
  Color get _primary => const Color(0xFF2F6BFF);
  Color get _text => const Color(0xFF0F172A);
  Color get _muted => const Color(0xFF64748B);
  Color get _fieldFill => const Color(0xFFF6F8FC);

  // ====== PAYMENT NORMALIZER (FIX BUG PAYMENT DB) ======
  static const Set<String> _paymentKeys = {
    'qris',
    'cash',
    'transfer',
    'ewallet',
    'other',
  };

  String _normalizePayment(String v) {
    final x = (v).trim().toLowerCase();
    return _paymentKeys.contains(x) ? x : 'other';
  }

  // ====== FORMATTERS (Rp 10.000) ======
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _dot(int n) {
    final neg = n < 0;
    final s = n.abs().toString();
    final rev = s.split('').reversed.join();
    final parts = <String>[];
    for (int i = 0; i < rev.length; i += 3) {
      parts.add(rev.substring(i, math.min(i + 3, rev.length)));
    }
    final out = parts
        .map((c) => c.split('').reversed.join())
        .toList()
        .reversed
        .join('.');
    return neg ? '-$out' : out;
  }

  String _rp(dynamic v) => 'Rp ${_dot(_toInt(v))}';

  @override
  void initState() {
    super.initState();
    _productsFuture = getProducts();

    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });

    _initOrderNumber();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  // ====== GET PRODUCTS ======
  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await ProductService.getProducts();
    return (res).cast<Map<String, dynamic>>();
  }

  // ====== ORDER NUMBER: ambil MAX(order_no)+1 ======
  Future<void> _initOrderNumber() async {
    try {
      if (!mounted) return;
      setState(() => _loadingOrderNo = true);

      final sb = Supabase.instance.client;

      final dynamic row = await sb
          .from('transactions')
          .select('order_no')
          .order('order_no', ascending: false)
          .limit(1)
          .maybeSingle();

      final last = (row == null) ? 0 : (row['order_no'] ?? 0);
      final int lastInt =
          last is int ? last : (int.tryParse(last.toString()) ?? 0);
      final next = lastInt + 1;

      if (!mounted) return;
      setState(() {
        _orderNumber = next;
        _loadingOrderNo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orderNumber = 1;
        _loadingOrderNo = false;
      });
      debugPrint('LOAD ORDER NO ERROR => $e');
    }
  }

  Future<void> _refreshOrderNumber() async {
    await _initOrderNumber();
  }

  // ====== CART OPS ======
  void addToCart(Map p) {
    final stockEnabled = (p['stock_enabled'] ?? true) == true;
    final stock = (p['stock'] ?? 0) is int
        ? p['stock'] as int
        : int.tryParse(p['stock'].toString()) ?? 0;

    if (stockEnabled && stock <= 0) {
      notify(context, 'Stok habis', error: true);
      return;
    }

    final id = p['id'];
    final i = cart.indexWhere((e) => e.id == id);

    setState(() {
      if (i >= 0) {
        cart[i].qty++;
      } else {
        cart.add(CartItem(id: id, name: p['name'], price: (p['price'] as num).toInt(), buyPrice: (p['buy_price'] ?? 0) is num ? (p['buy_price'] as num).toInt() : int.tryParse("${p['buy_price']}") ?? 0, qty: 1));
      }
    });

    notify(context, 'Produk ditambahkan');
  }

  void inc(CartItem c) => setState(() => c.qty++);
  void dec(CartItem c) {
    setState(() {
      if (c.qty > 1) {
        c.qty--;
      } else {
        cart.remove(c);
      }
    });
  }

  void removeItem(CartItem c) => setState(() => cart.remove(c));

  List<Map<String, dynamic>> cartItems() {
    return cart.map((c) => {'id': c.id, 'price': c.price, 'buy_price': c.buyPrice, 'qty': c.qty}).toList();
  }

  /// ✅ FIX: iPad portrait jangan masuk wide split
  _LayoutMode _layoutMode(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final shortest = mq.size.shortestSide;

    final isTablet = shortest >= 600;

    // Wide split cuma kalau bener2 lebar (desktop / landscape tablet besar)
    if (w >= 1024) return _LayoutMode.wide;

    if (isTablet) return _LayoutMode.tablet;
    return _LayoutMode.phone;
  }

  double _gridRatio(int crossAxis) {
    if (crossAxis >= 4) return 0.92;
    if (crossAxis == 3) return 0.98;
    return 1.05;
  }

  String _payLabel(String v) {
    switch (_normalizePayment(v)) {
      case 'cash':
        return 'CASH';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'TRANSFER';
      case 'ewallet':
        return 'E-WALLET';
      default:
        return 'OTHER';
    }
  }

  InputDecoration _modalFieldDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: _primary),
      ),
    );
  }

  // ====== CUSTOM ORDER DB HELPERS ======
  Future<Map<String, dynamic>> _createCustomProductInDb({
    required String name,
    required int price,
  }) async {
    final sb = Supabase.instance.client;
    final inserted = await sb
        .from('products')
        .insert({
          'name': name,
          'price': price,
          'buy_price': 0,
          'image_url': null,
          'is_active': true,
          'stock': 0,
          'stock_enabled': false,
          'category_id': null,
        })
        .select()
        .single();

    // ✅ FIX CRASH: jangan pakai arrow assignment yang return Future di setState
    if (mounted) {
      setState(() {
        _productsFuture = getProducts();
      });
    }

    return Map<String, dynamic>.from(inserted);
  }

  Future<String> _createTransactionDirect({
    required String userId,
    required int subtotal,
    required int discount,
    required int fee,
    required int otherCost,
    required int total, // Total bayar customer = subtotal - diskon
    required String payment,
    required List<Map<String, dynamic>> items,
    required int orderNo,
    required String customerName,
    String? note,
  }) async {
    final sb = Supabase.instance.client;

    final trx = await sb
        .from('transactions')
        .insert({
          'user_id': userId,
          'subtotal': subtotal,
          'discount': discount,
          'fee': fee,
          'other_cost': otherCost,
          'total': total,
          'payment_method': _normalizePayment(payment),
          'status': 'pending',
          'customer_name': customerName,
          'order_no': orderNo,
          'received_amount': 0,
          'change_amount': 0,
        })
        .select('id')
        .single();

    final trxId = trx['id'] as String;

    final rows = items
        .map(
          (it) => {
            'transaction_id': trxId,
            'product_id': it['id'],
            'price': it['price'],
            'buy_price': (it['buy_price'] ?? 0),
            'qty': it['qty'],
            'note': note,
          },
        )
        .toList();

    if (rows.isNotEmpty) {
      await sb.from('transaction_items').insert(rows);
    }

    return trxId;
  }

  // ====== STOCK DECREASE (biar fitur normal order tetap lengkap walau tanpa clamp payment) ======
  Future<void> _decreaseStockIfEnabled(List<Map<String, dynamic>> items) async {
    final sb = Supabase.instance.client;

    for (final it in items) {
      final pid = it['id'];
      final qty = _toInt(it['qty']);
      if (pid == null || qty <= 0) continue;

      final dynamic p = await sb
          .from('products')
          .select('id, stock, stock_enabled')
          .eq('id', pid)
          .maybeSingle();

      if (p == null) continue;

      final enabled = (p['stock_enabled'] ?? true) == true;
      if (!enabled) continue;

      final cur = _toInt(p['stock']);
      final next = (cur - qty) < 0 ? 0 : (cur - qty);

      await sb.from('products').update({'stock': next}).eq('id', pid);
    }
  }

  // ====== BUILD ======
  @override
  Widget build(BuildContext context) {
    final mode = _layoutMode(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bg1,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg1, _bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: switch (mode) {
                  _LayoutMode.wide => Row(
                      children: [
                        Expanded(
                          child: _posSurface(
                            child: Column(
                              children: [
                                _headerLeft(compact: false),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: _buildProductArea(crossAxis: 4),
                                ),
                                const SizedBox(height: 10),
                                _trackOrderStrip(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 430,
                          child: _posSurface(child: _buildCartPanel()),
                        ),
                      ],
                    ),
                  _LayoutMode.tablet => _buildTabletPortrait(),
                  _LayoutMode.phone => _buildPhone(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====== PHONE ======
  Widget _buildPhone() {
    return Stack(
      children: [
        _posSurface(
          child: Column(
            children: [
              _headerLeft(compact: true),
              const SizedBox(height: 10),
              Expanded(
                child: _buildProductArea(crossAxis: 2),
              ),
              // ✅ ruang aman biar grid gak ketutup bar
              SizedBox(height: _mobileCartBarHeight(context) + 10),
            ],
          ),
        ),
        _mobileCartBar(),
      ],
    );
  }

  // ====== TABLET PORTRAIT ======
  Widget _buildTabletPortrait() {
    return LayoutBuilder(
      builder: (context, c) {
        final maxH = c.maxHeight;
        const gap = 12.0;

        double topH = maxH * 0.56;
        double bottomH = maxH - topH - gap;

        topH = math.max(320.0, topH);
        bottomH = math.max(260.0, bottomH);

        final need = topH + bottomH + gap;
        if (need > maxH) {
          final scale = (maxH - gap) / (topH + bottomH);
          topH *= scale;
          bottomH *= scale;
        }

        return Column(
          children: [
            SizedBox(
              height: topH,
              child: _posSurface(
                child: Column(
                  children: [
                    _headerLeft(compact: false),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildProductArea(crossAxis: 3),
                    ),
                    const SizedBox(height: 10),
                    _trackOrderStrip(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: gap),
            SizedBox(
              height: bottomH,
              child: _posSurface(child: _buildCartPanel()),
            ),
          ],
        );
      },
    );
  }

  // ====== SHELL / SURFACE ======
  Widget _posSurface({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: child,
      ),
    );
  }

  // ====== HEADER (LEFT) ======
  Widget _headerLeft({required bool compact}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          _iconChip(Icons.menu_rounded),
          const SizedBox(width: 10),
          if (!compact) ...[
            _chip(icon: Icons.calendar_month_outlined, label: 'Wed, 29 May 2024'),
            const SizedBox(width: 8),
            _chip(icon: Icons.access_time_rounded, label: '07:59 AM'),
            const Spacer(),
            _chip(
              icon: Icons.circle,
              label: 'Open Order',
              iconColor: const Color(0xFF16A34A),
            ),
            const SizedBox(width: 8),
            _iconChip(Icons.power_settings_new_rounded),
          ] else ...[
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: const Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text(
                      'Open Order',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.power_settings_new_rounded, color: _muted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon) {
    return Container(
      height: 40,
      width: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _text),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? _primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _text,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // ====== LEFT CONTENT ======
  Widget _buildProductArea({required int crossAxis}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final all = (snap.data ?? []);
        final active = all.where((p) => p['is_active'] == true).toList();

        final filtered = _query.isEmpty
            ? active
            : active.where((p) {
                final name = (p['name'] ?? '').toString().toLowerCase();
                final price = (p['price'] ?? '').toString().toLowerCase();
                return name.contains(_query) || price.contains(_query);
              }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                height: 86,
                child: Row(
                  children: [
                    Expanded(
                      child: _categoryCard(
                        title: 'All Menu',
                        subtitle: '${filtered.length} items',
                        selected: true,
                        icon: Icons.layers_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _customOrderBtn(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _stroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search something sweet on your mind...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        onPressed: () => _searchCtrl.clear(),
                        icon: Icon(Icons.close_rounded, color: _muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: _gridRatio(crossAxis),
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _productCard(filtered[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _customOrderBtn() {
    return SizedBox(
      height: 86,
      width: 160,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openCustomOrderModalFull,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _stroke),
                ),
                child: Icon(Icons.add_rounded, color: _primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Order',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  // ====== CUSTOM ORDER (FULL FORM) ======
  void _openCustomOrderModalFull() {
    final mode = _layoutMode(context);

    final customerCtrl = TextEditingController(text: _customerCtrl.text.trim());
    String payment = _normalizePayment(_paymentUi);
    final noteCtrl = TextEditingController();

    final discountCtrl = TextEditingController(text: '0');
    final feeCtrl = TextEditingController(text: '0');
    final otherCostCtrl = TextEditingController(text: '0');

    final List<_CustomLine> lines = [_CustomLine()];
    bool submitting = false;

    Future<void> submit(StateSetter setModal, BuildContext ctx) async {
      if (submitting) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        notify(context, 'User belum login', error: true);
        return;
      }

      final customerName = customerCtrl.text.trim();
      if (customerName.isEmpty) {
        notify(context, 'Nama customer wajib diisi', error: true);
        return;
      }

      final cleaned = <_CustomLineData>[];
      for (final l in lines) {
        final name = l.nameCtrl.text.trim();
        final price = int.tryParse(l.priceCtrl.text.trim()) ?? 0;
        final qty = int.tryParse(l.qtyCtrl.text.trim()) ?? 0;

        if (name.isEmpty && price == 0 && qty == 0) continue;

        if (name.isEmpty) {
          notify(context, 'Nama item wajib diisi', error: true);
          return;
        }
        if (price <= 0) {
          notify(context, 'Harga harus > 0', error: true);
          return;
        }
        if (qty <= 0) {
          notify(context, 'Qty minimal 1', error: true);
          return;
        }

        cleaned.add(_CustomLineData(name: name, price: price, qty: qty));
      }

      if (cleaned.isEmpty) {
        notify(context, 'Minimal 1 item diisi', error: true);
        return;
      }

      if (_orderNumber <= 0) {
        await _initOrderNumber();
      }

      try {
        setModal(() => submitting = true);

        final createdItems = <Map<String, dynamic>>[];
        int grandTotal = 0;

        for (final item in cleaned) {
          final inserted = await _createCustomProductInDb(
            name: item.name,
            price: item.price,
          );
          final pid = inserted['id'];
          grandTotal += item.price * item.qty;

          createdItems.add({'id': pid, 'price': item.price, 'buy_price': 0, 'qty': item.qty});
        }

        final normalizedPayment = _normalizePayment(payment);

        final subtotal = grandTotal;

        final discount = math.max(0, math.min(subtotal, int.tryParse(discountCtrl.text.trim()) ?? 0));
        final fee = math.max(0, int.tryParse(feeCtrl.text.trim()) ?? 0);
        final otherCost = math.max(0, int.tryParse(otherCostCtrl.text.trim()) ?? 0);
        final totalPay = math.max(0, subtotal - discount);

        await _createTransactionDirect(
          userId: user.id,
          subtotal: subtotal,
          discount: discount,
          fee: fee,
          otherCost: otherCost,
          total: totalPay,
          payment: normalizedPayment,
          items: createdItems,
          orderNo: _orderNumber,
          customerName: customerName,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );

        if (mounted) {
          setState(() {
            _customerCtrl.text = customerName;
            _paymentUi = normalizedPayment;
          });
        }

        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        notify(context, 'Custom order dibuat (PENDING)');
        await _refreshOrderNumber();
      } catch (e) {
        notify(context, 'Gagal buat custom order: $e', error: true);
      } finally {
        if (ctx.mounted) setModal(() => submitting = false);
      }
    }

    Widget content(
      BuildContext ctx,
      StateSetter setModal,
      ScrollController scrollCtrl,
    ) {
      void addLine() => setModal(() => lines.add(_CustomLine()));
      void removeLine(int i) {
        if (lines.length == 1) return;
        setModal(() {
          final l = lines.removeAt(i);
          l.dispose();
        });
      }

      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Row(
              children: [
                Text(
                  'Custom Order',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: customerCtrl,
              textInputAction: TextInputAction.next,
              decoration: _modalFieldDecoration(
                label: 'Nama Customer',
                hint: 'Misal: Arif',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: payment,
              decoration: _modalFieldDecoration(label: 'Metode Pembayaran'),
              items: const [
                DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setModal(() => payment = _normalizePayment(v ?? 'cash')),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Item',
                style: TextStyle(color: _text, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(lines.length, (i) {
              final line = lines[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: line.nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _modalFieldDecoration(
                          label: 'Nama item ${i + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: line.priceCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setModal(() {}),
                        decoration: _modalFieldDecoration(label: 'Harga'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: TextField(
                        controller: line.qtyCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setModal(() {}),
                        decoration: _modalFieldDecoration(label: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Hapus item',
                      onPressed: () => removeLine(i),
                      icon: Icon(Icons.delete_outline_rounded, color: _muted),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah item'),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: _modalFieldDecoration(
                label: 'Catatan',
                hint: 'Contoh: no sugar, extra ice, dll',
              ),
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                int subtotal = 0;
                for (final l in lines) {
                  final p = int.tryParse(l.priceCtrl.text.trim()) ?? 0;
                  final q = int.tryParse(l.qtyCtrl.text.trim()) ?? 0;
                  if (p > 0 && q > 0) subtotal += p * q;
                }
                final discount = math.max(0, math.min(subtotal, int.tryParse(discountCtrl.text.trim()) ?? 0));
                final fee = math.max(0, int.tryParse(feeCtrl.text.trim()) ?? 0);
                final otherCost = math.max(0, int.tryParse(otherCostCtrl.text.trim()) ?? 0);
                final totalPay = math.max(0, subtotal - discount);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      _line('Subtotal', _rp(subtotal)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _modalFieldDecoration(label: 'Diskon (Rp)', hint: '0'),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _modalFieldDecoration(label: 'Fee (Rp)', hint: '0'),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: otherCostCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _modalFieldDecoration(label: 'Other Cost (Rp)', hint: '0'),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      _line('Total bayar customer', _rp(totalPay)),
                    ],
                  ),
                );
              },
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: submitting ? null : () => submit(setModal, ctx),
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Buat Custom Order (Pending)',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    void cleanup() {
      customerCtrl.dispose();
      noteCtrl.dispose();
      discountCtrl.dispose();
      feeCtrl.dispose();
      otherCostCtrl.dispose();
      for (final l in lines) {
        l.dispose();
      }
    }

    if (mode != _LayoutMode.phone) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'custom_order',
        barrierColor: Colors.black.withOpacity(0.25),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) {
          final w = MediaQuery.of(context).size.width;
          final panelW = math.min(560.0, w * 0.65);

          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelW,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                  ),
                  border: Border.all(color: _stroke),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 22,
                      offset: Offset(-8, 0),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: StatefulBuilder(
                    builder: (ctx, setModal) {
                      return PrimaryScrollController(
                        controller: ScrollController(),
                        child: Builder(
                          builder: (ctx2) {
                            final ctrl = PrimaryScrollController.of(ctx2);
                            return content(ctx, setModal, ctrl);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, anim, __, child) {
          final tween =
              Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
          return SlideTransition(
            position: tween.animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          );
        },
      ).then((_) => cleanup());
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: _surface,
        builder: (_) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.92,
                minChildSize: 0.60,
                maxChildSize: 0.98,
                builder: (ctx2, scrollCtrl) {
                  return SafeArea(child: content(ctx, setModal, scrollCtrl));
                },
              );
            },
          );
        },
      ).then((_) => cleanup());
    }
  }

  Widget _categoryCard({
    required String title,
    required String subtitle,
    required bool selected,
    required IconData icon,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? _primary : _stroke),
        boxShadow: selected
            ? const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Color(0x22000000),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Colors.white.withOpacity(0.22) : _stroke,
              ),
            ),
            child: Icon(icon, color: selected ? Colors.white : _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected ? Colors.white.withOpacity(0.85) : _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ product card anti-overflow + Rp formatter
  Widget _productCard(Map<String, dynamic> p) {
    final String name = (p['name'] ?? '-').toString();
    final int priceInt = _toInt(p['price']);
    final String? imageUrl = p['image_url']?.toString();
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    final stockEnabled = (p['stock_enabled'] ?? true) == true;
    final stock = _toInt(p['stock']);
    final bool out = stockEnabled && stock <= 0;

    const imgRadius = 16.0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => addToCart(p),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imgRadius),
                    child: Container(
                      color: _fieldFill,
                      child: hasImage
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.local_cafe_rounded, size: 30),
                              ),
                              loadingBuilder: (c, child, loading) {
                                if (loading == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(Icons.local_cafe_rounded, size: 30),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _rp(priceInt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                if (out)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Text(
                      'HABIS',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      stockEnabled ? 'Stok: $stock' : 'Stok: ∞',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackOrderStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Track Order →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== CART PANEL ======
  Widget _buildCartPanel() {
    final orderText = _loadingOrderNo
        ? '...'
        : (_orderNumber <= 0 ? '#001' : '#${_orderNumber.toString().padLeft(3, '0')}');

    return LayoutBuilder(
      builder: (context, constraints) {
        final kb = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: kb > 0 ? 8 : 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _stroke),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: _primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Customer's Order",
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Order Number: $orderText",
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _initOrderNumber,
                      child: _iconMini(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _customerCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Nama Customer',
                    hintText: 'Misal: Arif',
                    filled: true,
                    fillColor: _fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_fieldRadius),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_fieldRadius),
                      borderSide: BorderSide(color: _stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_fieldRadius),
                      borderSide: BorderSide(color: _primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: _stroke),
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: Text(
                          'No Item Selected',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (_, i) => _cartItemTile(cart[i]),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: cart.length,
                      ),
              ),
              Divider(height: 1, color: _stroke),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + (kb > 0 ? 8 : 0)),
                child: Column(
                  children: [
                    _line('Subtotal', _rp(total)),
                    const SizedBox(height: 6),
                    _line('Discount', _rp(0)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('TOTAL', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        Text(_rp(total), style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        _payPill(_payLabel(_paymentUi)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: cart.isEmpty ? null : _openOrderConfirmation,
                        child: const Text(
                          'Place Order',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconMini(IconData icon) {
    return Container(
      height: 40,
      width: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _text, size: 18),
    );
  }

  Widget _cartItemTile(CartItem c) {
    final int price = _toInt(c.price);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 62,
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Icon(Icons.local_cafe_rounded, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _rp(price),
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _qtyBtn(Icons.remove_rounded, onTap: () => dec(c)),
              const SizedBox(width: 8),
              Text('${c.qty}', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              _qtyBtn(Icons.add_rounded, onTap: () => inc(c)),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Hapus',
                onPressed: () => removeItem(c),
                icon: Icon(Icons.delete_outline_rounded, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        child: Icon(icon, size: 18, color: _text),
      ),
    );
  }

  Widget _line(String left, String right) {
    return Row(
      children: [
        Text(left, style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(right, style: TextStyle(color: _muted, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _payPill(String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _openPaymentPicker,
      child: Container(
        height: 44,
        width: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _primary),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(color: _primary, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  void _openPaymentPicker() {
    final items = const [
      ('qris', 'QRIS'),
      ('cash', 'Cash'),
      ('transfer', 'Transfer'),
      ('ewallet', 'E-Wallet'),
      ('other', 'Other'),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Pilih Metode Pembayaran',
                      style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...items.map((e) {
                  final key = _normalizePayment(e.$1);
                  final title = e.$2;
                  final selected = _normalizePayment(_paymentUi) == key;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: selected ? _primary : _muted,
                    ),
                    title: Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w800, color: _text),
                    ),
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _paymentUi = key;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====== MOBILE CART BAR ======
  double _mobileCartBarHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    if (h < 520) return 82;
    return 90;
  }

  Widget _mobileCartBar() {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: kb > 0 ? kb + 12 : 12,
      child: SizedBox(
        height: _mobileCartBarHeight(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _stroke),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 10),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cart.isEmpty
                      ? 'Cart kosong'
                      : 'Cart: ${cart.length} item • ${_rp(total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: cart.isEmpty ? null : openCartMobile,
                icon: const Icon(Icons.shopping_cart_rounded),
                label: const Text('Open Cart'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openCartMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            void incModal(CartItem c) {
              setModal(() => c.qty++);
              setState(() {});
            }

            void decModal(CartItem c) {
              setModal(() {
                if (c.qty > 1) {
                  c.qty--;
                } else {
                  cart.remove(c);
                }
              });
              setState(() {});
            }

            void deleteModal(CartItem c) {
              setModal(() => cart.remove(c));
              setState(() {});
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final h = MediaQuery.of(context).size.height;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  height: math.min(h * 0.90, h - 40),
                  child: _posSurface(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                'Cart',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _customerCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Nama customer...',
                              prefixIcon: const Icon(Icons.person_rounded),
                              filled: true,
                              fillColor: _fieldFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _stroke),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: _stroke),
                        Expanded(
                          child: cart.isEmpty
                              ? Center(
                                  child: Text(
                                    'Cart kosong',
                                    style: TextStyle(
                                      color: _muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemBuilder: (_, i) {
                                    final c = cart[i];
                                    final price = _toInt(c.price);
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _stroke),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: _text,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_rp(price)} x ${c.qty}',
                                                  style: TextStyle(
                                                    color: _muted,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Hapus',
                                            onPressed: () => deleteModal(c),
                                            icon: const Icon(Icons.delete_outline_rounded),
                                          ),
                                          _qtyBtn(Icons.remove_rounded, onTap: () => decModal(c)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${c.qty}',
                                            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(width: 8),
                                          _qtyBtn(Icons.add_rounded, onTap: () => incModal(c)),
                                        ],
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemCount: cart.length,
                                ),
                        ),
                        Divider(height: 1, color: _stroke),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _line('TOTAL', _rp(total)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Spacer(),
                                  _payPill(_payLabel(_paymentUi)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: cart.isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          _openOrderConfirmation();
                                        },
                                  child: const Text(
                                    'Place Order',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ====== ORDER CONFIRMATION ======
  void _openOrderConfirmation() {
    final mode = _layoutMode(context);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      notify(context, 'User belum login', error: true);
      return;
    }

    final customerName = _customerCtrl.text.trim();
    if (customerName.isEmpty) {
      notify(context, 'Nama customer wajib diisi', error: true);
      return;
    }

    final orderNoText = _loadingOrderNo
        ? '...'
        : '#${(_orderNumber <= 0 ? 1 : _orderNumber).toString().padLeft(3, '0')}';

    // Profit fields per transaksi (diskon/fee/other cost)
    final discountCtrl = TextEditingController(text: '0');
    final feeCtrl = TextEditingController(text: '0');
    final otherCostCtrl = TextEditingController(text: '0');

    bool submitting = false;

    Future<void> confirmAndSubmit(StateSetter setModal, BuildContext ctx) async {
      if (submitting) return;

      if (_orderNumber <= 0) await _initOrderNumber();

      try {
        setModal(() => submitting = true);

        final payment = _normalizePayment(_paymentUi);

        // ✅ FIX PAYMENT BUG: selalu simpan value payment yg dipilih (qris/cash/transfer/ewallet/other)
        // + tetap update stock seperti biasanya
        final subtotal = total;
        final discount = math.max(0, math.min(subtotal, int.tryParse(discountCtrl.text.trim()) ?? 0));
        final fee = math.max(0, int.tryParse(feeCtrl.text.trim()) ?? 0);
        final otherCost = math.max(0, int.tryParse(otherCostCtrl.text.trim()) ?? 0);
        final totalPay = math.max(0, subtotal - discount);

        await _createTransactionDirect(
          userId: user.id,
          subtotal: subtotal,
          discount: discount,
          fee: fee,
          otherCost: otherCost,
          total: totalPay,
          payment: payment,
          items: cartItems(),
          orderNo: _orderNumber,
          customerName: customerName,
        );

        if (!mounted) return;
        if (Navigator.canPop(ctx)) Navigator.pop(ctx);

        notify(context, 'Transaksi dibuat (PENDING)');
        setState(() => cart.clear());
        await _refreshOrderNumber();
      } catch (e) {
        debugPrint('CONFIRM ORDER ERROR => $e');
        notify(context, 'Gagal membuat transaksi: $e', error: true);
      } finally {
        if (ctx.mounted) setModal(() => submitting = false);
      }
    }

    Widget content(BuildContext ctx, StateSetter setModal, ScrollController sc) {
      final pay = _payLabel(_paymentUi);

      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: ListView(
          controller: sc,
          children: [
            Row(
              children: [
                Text(
                  'Order Confirmation',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(customerName, style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Order No', style: TextStyle(color: _muted, fontWeight: FontWeight.w700))),
                      Text(orderNoText, style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Payment', style: TextStyle(color: _muted, fontWeight: FontWeight.w700))),
                      Text(pay, style: TextStyle(color: _primary, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Order Items', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...cart.map((c) {
              final price = _toInt(c.price);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_rp(price)} x ${c.qty}',
                            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(_rp(c.subtotal), style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            }),
            Builder(
              builder: (context) {
                final subtotal = total;
                final discount = math.max(0, math.min(subtotal, int.tryParse(discountCtrl.text.trim()) ?? 0));
                final fee = math.max(0, int.tryParse(feeCtrl.text.trim()) ?? 0);
                final otherCost = math.max(0, int.tryParse(otherCostCtrl.text.trim()) ?? 0);
                final totalPay = math.max(0, subtotal - discount);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      _line('Subtotal', _rp(subtotal)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Diskon (Rp)',
                          hintText: '0',
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fee (Rp)',
                          hintText: '0',
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: otherCostCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Other Cost (Rp)',
                          hintText: '0',
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 10),
                      _line('Total bayar customer', _rp(totalPay)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('TOTAL', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text(_rp(totalPay), style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Gross Profit = (Subtotal - Diskon) - HPP\nNet Profit = Gross Profit - Fee - OtherCost',
                          style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: submitting ? null : () => confirmAndSubmit(setModal, ctx),
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm Order',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    if (mode != _LayoutMode.phone) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'order_confirm',
        barrierColor: Colors.black.withOpacity(0.25),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) {
          final w = MediaQuery.of(context).size.width;
          final panelW = math.min(560.0, w * 0.65);

          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelW,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                  ),
                  border: Border.all(color: _stroke),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 22,
                      offset: Offset(-8, 0),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: StatefulBuilder(
                    builder: (ctx, setModal) {
                      return PrimaryScrollController(
                        controller: ScrollController(),
                        child: Builder(
                          builder: (ctx2) {
                            final ctrl = PrimaryScrollController.of(ctx2);
                            return content(ctx, setModal, ctrl);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, anim, __, child) {
          final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
          return SlideTransition(
            position: tween.animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: _surface,
        builder: (_) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.92,
                minChildSize: 0.60,
                maxChildSize: 0.98,
                builder: (ctx2, scrollCtrl) {
                  return SafeArea(child: content(ctx, setModal, scrollCtrl));
                },
              );
            },
          );
        },
      );
    }
  }
}

// ====== helper classes for custom order dynamic lines ======
class _CustomLine {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _CustomLineData {
  final String name;
  final int price;
  final int qty;

  _CustomLineData({required this.name, required this.price, required this.qty});
}

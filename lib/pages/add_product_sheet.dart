import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/notifier.dart';
import '../core/pos_ui.dart';
import '../services/categorie_service.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';

class AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? product;

  const AddProductSheet({
    super.key,
    required this.onSaved,
    this.product,
  });

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final price = TextEditingController();
  final buyPrice = TextEditingController(text: '0');
  final stock = TextEditingController(text: '0');

  bool loading = false;

  /// IMPORTANT: null berarti "belum dipilih"
  String? categoryId;

  File? _pickedImage;
  String? _existingImageUrl;

  bool stockEnabled = true;

  late Future<List<Map<String, dynamic>>> categories;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    categories = CategoryService.getCategories();

    if (widget.product != null) {
      final p = widget.product!;
      name.text = (p['name'] ?? '').toString();
      price.text = (p['price'] ?? '').toString();
      buyPrice.text = (p['buy_price'] ?? 0).toString();
      stock.text = (p['stock'] ?? 0).toString();

      // ✅ FIX: jangan pernah set '' karena bikin dropdown crash
      final rawCat = p['category_id'];
      final catStr = rawCat == null ? '' : rawCat.toString().trim();
      categoryId = catStr.isEmpty ? null : catStr;

      _existingImageUrl = (p['image_url'] ?? '').toString();
      stockEnabled = (p['stock_enabled'] ?? true) == true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    buyPrice.dispose();
    stock.dispose();
    super.dispose();
  }

  String? _req(String? v, String msg) {
    if ((v ?? '').trim().isEmpty) return msg;
    return null;
  }

  String? _priceValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Harga wajib diisi';
    final n = int.tryParse(s);
    if (n == null) return 'Harga harus angka';
    if (n < 0) return 'Harga tidak valid';
    return null;
  }

  String? _buyPriceValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // boleh kosong => dianggap 0
    final n = int.tryParse(s);
    if (n == null) return 'Harga beli harus angka';
    if (n < 0) return 'Harga beli tidak valid';
    return null;
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (x == null) return;

    setState(() => _pickedImage = File(x.path));
  }

  Widget _imageBox() {
    return InkWell(
      onTap: pickImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: PosTokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: _pickedImage != null
                  ? Image.file(_pickedImage!, fit: BoxFit.cover)
                  : (_existingImageUrl != null &&
                          _existingImageUrl!.trim().isNotEmpty)
                      ? Image.network(
                          _existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PosTokens.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 18, color: PosTokens.text),
                    SizedBox(width: 8),
                    Text(
                      'Pilih Foto',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: PosTokens.text,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Text(
        'Tap untuk pilih foto produk',
        style: TextStyle(
          color: PosTokens.subtext,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// ✅ ini kunci anti crash:
  /// kalau categoryId tidak ada di list items => return null
  String? _safeCategoryValue(List<Map<String, dynamic>> cats) {
    if (categoryId == null) return null;
    final exists = cats.any((c) => c['id'].toString() == categoryId);
    return exists ? categoryId : null;
  }

  Future<void> save() async {
    if (loading) return;

    // Form validation
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (categoryId == null) {
      notify(context, 'Kategori wajib dipilih', error: true);
      return;
    }

    final priceVal = int.tryParse(price.text.trim());
    final buyVal = int.tryParse(buyPrice.text.trim()) ?? 0;
    if (priceVal == null) {
      notify(context, 'Harga harus angka', error: true);
      return;
    }

    final stockVal = int.tryParse(stock.text.trim()) ?? 0;

    setState(() => loading = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_pickedImage != null) {
        imageUrl = await StorageService.uploadProductImage(_pickedImage!);
      }

      if (!isEdit) {
        await ProductService.addProduct(
          name: name.text.trim(),
          price: priceVal,
          buyPrice: buyVal,
          categoryId: categoryId!,
          imageUrl: imageUrl,
          stock: stockVal,
          stockEnabled: stockEnabled,
        );
      } else {
        await ProductService.updateProduct(
          id: widget.product!['id'].toString(),
          name: name.text.trim(),
          price: priceVal,
          buyPrice: buyVal,
          categoryId: categoryId!,
          imageUrl: imageUrl,
          isActive: (widget.product!['is_active'] ?? true) == true,
          stock: stockVal,
          stockEnabled: stockEnabled,
        );
      }

      notify(context, 'Produk tersimpan');
      widget.onSaved();
    } catch (e) {
      notify(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.60,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: PosTokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: PosTokens.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // ===== HEADER =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PosTokens.border),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                          color: PosTokens.text,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Produk' : 'Tambah Produk',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: PosTokens.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Data rapi = kasir & report makin enak.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: PosTokens.subtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: PosTokens.border),

                // ===== BODY =====
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _SectionCard(
                            title: 'Foto Produk',
                            child: _imageBox(),
                          ),
                          const SizedBox(height: 12),

                          _SectionCard(
                            title: 'Info Produk',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: name,
                                  validator: (v) =>
                                      _req(v, 'Nama produk wajib diisi'),
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Produk',
                                    hintText: 'Misal: Americano',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: buyPrice,
                                  validator: _buyPriceValidator,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Harga Beli / HPP (Rp)',
                                    hintText: 'Misal: 15000',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: price,
                                  validator: _priceValidator,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Harga Jual (Rp)',
                                    hintText: 'Misal: 20000',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          _SectionCard(
                            title: 'Kategori',
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: categories,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                }

                                final data = snap.data ?? [];

                                // ✅ value aman: harus ada di items
                                final safeValue = _safeCategoryValue(data);

                                return DropdownButtonFormField<String>(
                                  value: safeValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori',
                                    hintText: 'Pilih kategori',
                                  ),
                                  items: data
                                      .map(
                                        (c) => DropdownMenuItem<String>(
                                          value: c['id'].toString(),
                                          child: Text(
                                            (c['name'] ?? '-').toString(),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => categoryId = v),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          _SectionCard(
                            title: 'Stok',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: stock,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Stok (angka)',
                                    hintText: 'Misal: 10',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Stok Aktif',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: const Text(
                                    'Kalau OFF, stok tidak berkurang saat transaksi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: PosTokens.subtext,
                                    ),
                                  ),
                                  value: stockEnabled,
                                  onChanged: (v) =>
                                      setState(() => stockEnabled = v),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===== FOOTER CTA =====
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: PosTokens.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              loading ? null : () => Navigator.pop(context),
                          child: const Text('BATAL'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading ? null : save,
                          child: Text(loading ? 'MENYIMPAN...' : 'SIMPAN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: PosTokens.text,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

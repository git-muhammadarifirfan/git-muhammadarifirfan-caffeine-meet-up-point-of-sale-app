import 'package:flutter/material.dart';
import 'package:pos_coffeeshop_ayudian/core/notifier.dart';
import '../../services/product_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final name = TextEditingController();
  final price = TextEditingController();

  bool loading = false;

  void submit() async {
    if (name.text.isEmpty || price.text.isEmpty) {
      notify(context, 'Semua field wajib diisi', error: true);
      return;
    }

    final parsedPrice = int.tryParse(price.text);
    if (parsedPrice == null) {
      notify(context, 'Harga harus angka', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await ProductService.addProduct(
        name: name.text,
        price: parsedPrice,
        categoryId: 'TEMP', // ganti dropdown nanti
      );

      notify(context, 'Produk berhasil ditambahkan');
      Navigator.pop(context);
    } catch (e) {
      notify(context, 'Gagal menambah produk', error: true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Produk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama Produk'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

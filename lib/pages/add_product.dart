import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../core/notifier.dart';
import 'add_product_sheet.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Future<List<Map<String, dynamic>>> products;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    products = ProductService.getProducts();
  }

  void openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProductSheet(
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: openAdd)],
      ),
      body: FutureBuilder(
        future: products,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;
          if (data.isEmpty) {
            return const Center(child: Text('Belum ada produk'));
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              return ListTile(
                leading: p['image_url'] != null
                    ? Image.network(p['image_url'], width: 50)
                    : const Icon(Icons.coffee),
                title: Text(p['name']),
                subtitle: Text('${p['categories']['name']} • Rp ${p['price']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: p['is_active'],
                      onChanged: (v) async {
                        await ProductService.toggleActive(p['id'], v);
                        setState(load);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await ProductService.deleteProduct(p['id']);
                        notify(context, 'Produk dihapus');
                        setState(load);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

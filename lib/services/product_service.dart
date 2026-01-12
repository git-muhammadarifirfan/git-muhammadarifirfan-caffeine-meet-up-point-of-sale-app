import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await _db
        .from('products')
        .select('*, categories(name)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addProduct({
    required String name,
    required int price,
    int buyPrice = 0,
    required String categoryId,
    String? imageUrl,
    int stock = 0,
    bool stockEnabled = true,
  }) async {
    await _db.from('products').insert({
      'name': name,
      'price': price,
      'buy_price': buyPrice,
      'category_id': categoryId,
      'image_url': imageUrl,
      'is_active': true,
      'stock': stock,
      'stock_enabled': stockEnabled,
    });
  }

  static Future<void> updateProduct({
    required String id,
    required String name,
    required int price,
    int buyPrice = 0,
    required String categoryId,
    String? imageUrl,
    required bool isActive,
    required int stock,
    required bool stockEnabled,
  }) async {
    await _db
        .from('products')
        .update({
          'name': name,
          'price': price,
      'buy_price': buyPrice,
          'category_id': categoryId,
          'image_url': imageUrl,
          'is_active': isActive,
          'stock': stock,
          'stock_enabled': stockEnabled,
        })
        .eq('id', id);
  }

  static Future<void> deleteProduct(String id) async {
    await _db.from('products').delete().eq('id', id);
  }

  static Future<void> toggleActive(String id, bool value) async {
    await _db.from('products').update({'is_active': value}).eq('id', id);
  }

  static Future<void> toggleStockEnabled(String id, bool value) async {
    await _db.from('products').update({'stock_enabled': value}).eq('id', id);
  }

  /// Update stok manual (angka saja).
  /// delta: + untuk tambah stok, - untuk kurang stok
  static Future<void> adjustStock({
    required String productId,
    required int delta,
  }) async {
    // Pakai RPC biar update stok atomic dan aman untuk concurrency
    await _db.rpc(
      'adjust_stock',
      params: {'p_product_id': productId, 'p_delta': delta},
    );
  }

  static Future<void> setStock({
    required String productId,
    required int stock,
  }) async {
    await _db.from('products').update({'stock': stock}).eq('id', productId);
  }
}

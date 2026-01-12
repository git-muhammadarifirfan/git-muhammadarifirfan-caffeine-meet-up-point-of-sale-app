import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await _db.from('categories').select().order('name');

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addCategory(String name) async {
    await _db.from('categories').insert({'name': name});
  }

  static Future<void> updateCategory(String id, String name) async {
    await _db.from('categories').update({'name': name}).eq('id', id);
  }

  static Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }
}

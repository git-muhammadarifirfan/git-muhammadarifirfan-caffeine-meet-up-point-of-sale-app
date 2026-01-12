import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final _supabase = Supabase.instance.client;

  // Pastikan sama persis dengan nama bucket di Supabase Storage
  static const String bucketName = 'product-images';

  static Future<String> uploadProductImage(File file) async {
    final bytes = await file.readAsBytes();

    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // public url
      final url = _supabase.storage.from(bucketName).getPublicUrl(fileName);
      return url;
    } on StorageException catch (e) {
      // Ini biar error kebaca jelas
      throw Exception('Storage error: ${e.message}');
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }
}

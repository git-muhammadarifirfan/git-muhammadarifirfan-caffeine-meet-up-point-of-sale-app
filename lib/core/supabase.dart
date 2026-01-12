import 'package:supabase_flutter/supabase_flutter.dart';

class Supa {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://kbbkxavelmpnfqfdoclh.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtiYmt4YXZlbG1wbmZxZmRvY2xoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MDk5NDgsImV4cCI6MjA4MTI4NTk0OH0.I1wQc1R2GHJK0FmPcAvOUKT9Ik8zsEJ1aL_pG_vzbXQ',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

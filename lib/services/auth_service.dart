import '../core/supabase.dart';
import '../core/session.dart';

class AuthService {
  static Future<void> loadProfile() async {
    final user = Supa.client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await Supa.client
          .from('profiles')
          .select('id, role, name')
          .eq('id', user.id)
          .single();

      Session.userId = user.id;
      Session.role = res['role'] ?? 'kasir';
      Session.name = res['name'] ?? user.email ?? '';
    } catch (e) {
      // fallback kalau profile belum kebentuk
      Session.userId = user.id;
      Session.role = 'kasir';
      Session.name = user.email ?? '';
    }
  }
}

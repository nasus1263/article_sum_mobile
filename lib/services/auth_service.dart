import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

/// Local wrapper — named AppUser to avoid colliding with supabase's own
/// exported `AuthUser` type.
class AppUser {
  final String id;
  final String? email;

  const AppUser({required this.id, this.email});

  static AppUser? fromSupabaseUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);
}

/// Email/password auth against the shared Supabase client — mirrors
/// electron/db.js's signUp/signIn/signOut/getUser/onAuthStateChange.
class AuthService {
  static Future<AppUser?> getUser() async {
    final client = await SupabaseClientProvider.getClient();
    return AppUser.fromSupabaseUser(client.auth.currentUser);
  }

  static Future<AppUser?> signUp(String email, String password) async {
    final client = await SupabaseClientProvider.getClient();
    final res = await client.auth.signUp(email: email, password: password);
    return AppUser.fromSupabaseUser(res.user);
  }

  static Future<AppUser?> signIn(String email, String password) async {
    final client = await SupabaseClientProvider.getClient();
    final res = await client.auth.signInWithPassword(email: email, password: password);
    return AppUser.fromSupabaseUser(res.user);
  }

  static Future<void> signOut() async {
    final client = await SupabaseClientProvider.getClient();
    await client.auth.signOut();
  }
}

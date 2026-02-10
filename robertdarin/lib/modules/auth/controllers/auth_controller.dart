import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/api_service.dart';

class AuthController {
  final SupabaseClient client = ApiService.client;

  Future<bool> signup(String email, String password) async {
    final response = await client.auth.signUp(email: email, password: password);
    return response.user != null;
  }

  Future<bool> login(String email, String password) async {
    final response = await client.auth.signInWithPassword(email: email, password: password);
    return response.user != null;
  }

  Future<void> logout() async {
    await client.auth.signOut();
  }
}

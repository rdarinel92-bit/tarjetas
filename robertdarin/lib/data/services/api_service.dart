import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class ApiService {
  // Usar el cliente centralizado de AppSupabase
  static SupabaseClient get client => AppSupabase.client;
}

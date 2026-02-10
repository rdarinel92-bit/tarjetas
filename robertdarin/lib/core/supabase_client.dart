import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// CLIENTE SUPABASE - Robert Darin Fintech V10.28
/// Inicialización segura con manejo de errores
/// ═══════════════════════════════════════════════════════════════════════════════
class AppSupabase {
  static bool _initialized = false;
  
  /// Inicializa la conexión a Supabase con manejo de errores
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      await Supabase.initialize(
        url: 'https://qtfsxfvxqiihnofrpmmu.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0ZnN4ZnZ4cWlpaG5vZnJwbW11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczMjU5MDIsImV4cCI6MjA4MjkwMTkwMn0.D4LrG8FlnqfK0Zhi2Ex0z2UGeoVSr6u1XR2jnxis9Bg',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _initialized = true;
      debugPrint('✅ Supabase inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando Supabase: $e');
      rethrow; // Re-lanzar para que la app maneje el error
    }
  }

  /// Verifica si Supabase está inicializado
  static bool get isInitialized => _initialized;

  /// Cliente de Supabase
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Usuario actualmente autenticado (o null)
  static User? get currentUser => client.auth.currentUser;
  
  /// Verifica si hay un usuario autenticado
  static bool get isAuthenticated => currentUser != null;
  
  /// Stream de cambios de estado de autenticación
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}

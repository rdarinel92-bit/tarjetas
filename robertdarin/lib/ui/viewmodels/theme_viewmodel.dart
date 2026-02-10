import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/supabase_client.dart';

/// ViewModel para gestionar el tema global de la aplicación
/// Soporta temas: oscuro, azul, verde, púrpura (personalizables desde Centro de Control)
class ThemeViewModel extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  
  String _currentTheme = 'oscuro';
  Map<String, dynamic>? _temaActivo;
  bool _loading = true;

  String get currentTheme => _currentTheme;
  Map<String, dynamic>? get temaActivo => _temaActivo;
  bool get isLoading => _loading;

  // Colores base por tema
  static final Map<String, ThemeColors> _themePalettes = {
    'oscuro': ThemeColors(
      background: const Color(0xFF0D0D14),
      surface: const Color(0xFF1E293B),
      primary: Colors.cyanAccent,
      secondary: Colors.blueAccent,
      accent: Colors.orangeAccent,
    ),
    'azul': ThemeColors(
      background: const Color(0xFF0A1628),
      surface: const Color(0xFF1A2744),
      primary: Colors.blueAccent,
      secondary: Colors.indigoAccent,
      accent: Colors.lightBlueAccent,
    ),
    'verde': ThemeColors(
      background: const Color(0xFF0A1A14),
      surface: const Color(0xFF1A3028),
      primary: Colors.tealAccent,
      secondary: Colors.greenAccent,
      accent: Colors.limeAccent,
    ),
    'purpura': ThemeColors(
      background: const Color(0xFF14101A),
      surface: const Color(0xFF281E3C),
      primary: Colors.purpleAccent,
      secondary: Colors.deepPurpleAccent,
      accent: Colors.pinkAccent,
    ),
  };

  ThemeColors get colors => _themePalettes[_currentTheme] ?? _themePalettes['oscuro']!;

  ThemeViewModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _loading = true;
    notifyListeners();

    try {
      // Primero intentar cargar de SharedPreferences (local)
      final prefs = await SharedPreferences.getInstance();
      final localTheme = prefs.getString(_themeKey);
      
      if (localTheme != null && _themePalettes.containsKey(localTheme)) {
        _currentTheme = localTheme;
      }

      // Luego intentar cargar tema activo de Supabase
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        // Cargar preferencia del usuario (si la tabla existe)
        try {
          final userPrefs = await AppSupabase.client
              .from('preferencias_usuario')
              .select('tema')
              .eq('usuario_id', user.id)
              .maybeSingle();
          
          if (userPrefs != null && userPrefs['tema'] != null) {
            _currentTheme = userPrefs['tema'];
            await prefs.setString(_themeKey, _currentTheme);
          }
        } catch (e) {
          // La tabla puede no existir - usar SharedPreferences como fallback
          debugPrint('Preferencias de usuario no disponibles, usando local');
        }

        // También cargar tema activo global (configurado por superadmin)
        try {
          final temaActivo = await AppSupabase.client
              .from('temas_app')
              .select()
              .eq('activo', true)
              .maybeSingle();
          
          if (temaActivo != null) {
            _temaActivo = temaActivo;
          }
        } catch (e) {
          debugPrint('Temas no disponibles: $e');
        }
      }
    } catch (e) {
      debugPrint('Error cargando tema: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    if (!_themePalettes.containsKey(theme)) return;
    
    _currentTheme = theme;
    notifyListeners();

    try {
      // Guardar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);

      // Guardar en Supabase si hay usuario logueado (si la tabla existe)
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        try {
          await AppSupabase.client.from('preferencias_usuario').upsert({
            'usuario_id': user.id,
            'tema': theme,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'usuario_id');
        } catch (e) {
          // La tabla puede no existir - solo usar SharedPreferences
          debugPrint('No se pudo guardar tema en servidor: $e');
        }
      }
    } catch (e) {
      debugPrint('Error guardando tema: $e');
    }
  }

  ThemeData buildTheme() {
    final themeColors = colors;
    
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: themeColors.background,
      primaryColor: themeColors.primary,
      colorScheme: ColorScheme.dark(
        primary: themeColors.primary,
        secondary: themeColors.secondary,
        surface: themeColors.surface,
        // ignore: deprecated_member_use
        background: themeColors.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColors.primary),
        titleTextStyle: TextStyle(
          color: themeColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: themeColors.primary,
        foregroundColor: themeColors.background,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColors.primary,
          foregroundColor: themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: themeColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColors.primary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColors.primary),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: themeColors.surface,
        selectedItemColor: themeColors.primary,
        unselectedItemColor: Colors.white54,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: themeColors.surface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeColors.primary;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeColors.primary.withValues(alpha: 0.3);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
    );
  }

  // Método para refrescar tema desde servidor
  Future<void> refreshFromServer() async {
    await _loadTheme();
  }

  // Obtener todos los temas disponibles
  List<String> get availableThemes => _themePalettes.keys.toList();

  // Obtener nombre legible del tema
  String getThemeName(String themeId) {
    switch (themeId) {
      case 'oscuro': return 'Oscuro Elegante';
      case 'azul': return 'Azul Noche';
      case 'verde': return 'Verde Bosque';
      case 'purpura': return 'Púrpura Místico';
      default: return themeId;
    }
  }

  // Obtener icono del tema
  IconData getThemeIcon(String themeId) {
    switch (themeId) {
      case 'oscuro': return Icons.dark_mode;
      case 'azul': return Icons.nights_stay;
      case 'verde': return Icons.park;
      case 'purpura': return Icons.auto_awesome;
      default: return Icons.palette;
    }
  }
}

/// Clase para almacenar los colores de un tema
class ThemeColors {
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color accent;

  ThemeColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

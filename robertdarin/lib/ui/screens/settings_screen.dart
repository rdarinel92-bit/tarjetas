// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../security/pin_lock_service.dart';

enum _PinVerifyResult { ok, reset, cancel }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefPushKey = 'pref_notificaciones_push';
  static const String _prefEmailKey = 'pref_notificaciones_email';
  static const String _prefSoundKey = 'pref_sonidos_app';
  static const String _prefVibrationKey = 'pref_vibracion';
  static const String _prefThemeKey = 'app_theme';

  String? _userRole;
  String _userName = '';
  String _userEmail = '';
  bool _loading = true;
  
  // Preferencias
  bool _notificacionesPush = true;
  bool _notificacionesEmail = false;
  bool _sonidosApp = true;
  bool _vibracion = true;
  String _temaSeleccionado = 'oscuro';
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _pinSet = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final localPrefs = await SharedPreferences.getInstance();
    _loadLocalPrefs(localPrefs);

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final role = await authVm.obtenerRol();
    final user = authVm.usuarioActual;
    
    // Cargar preferencias del usuario
    if (user != null) {
      try {
        final prefs = await AppSupabase.client
            .from('preferencias_usuario')
            .select()
            .eq('usuario_id', user.id)
            .maybeSingle();
        
        if (prefs != null) {
          _notificacionesPush = prefs['notificaciones_push'] ?? true;
          _notificacionesEmail = prefs['notificaciones_email'] ?? false;
          _sonidosApp = prefs['sonidos_app'] ?? true;
          _vibracion = prefs['vibracion'] ?? true;
          _temaSeleccionado = prefs['tema'] ?? 'oscuro';
          await _persistLocalPrefs(prefsInstance: localPrefs);
        }
      } catch (e) {
        debugPrint('Error cargando preferencias: $e');
      }
    }

    // Seguridad local (PIN/biometria)
    if (user != null) {
      try {
        _pinSet = await PinLockService.instance.isPinSet(user.id);
        _bioEnabled = await PinLockService.instance.isBiometricEnabled(user.id);
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        _bioAvailable = supported && canCheck;
      } catch (e) {
        debugPrint('Error cargando seguridad local: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _userRole = role;
        _userName = user?.userMetadata?['full_name'] ?? 
                    user?.email?.split('@').first ?? 'Usuario';
        _userEmail = user?.email ?? '';
        _loading = false;
      });
    }
  }

  void _loadLocalPrefs(SharedPreferences prefs) {
    _notificacionesPush = prefs.getBool(_prefPushKey) ?? _notificacionesPush;
    _notificacionesEmail = prefs.getBool(_prefEmailKey) ?? _notificacionesEmail;
    _sonidosApp = prefs.getBool(_prefSoundKey) ?? _sonidosApp;
    _vibracion = prefs.getBool(_prefVibrationKey) ?? _vibracion;
    _temaSeleccionado = prefs.getString(_prefThemeKey) ?? _temaSeleccionado;
  }

  Future<void> _persistLocalPrefs({SharedPreferences? prefsInstance}) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    await prefs.setBool(_prefPushKey, _notificacionesPush);
    await prefs.setBool(_prefEmailKey, _notificacionesEmail);
    await prefs.setBool(_prefSoundKey, _sonidosApp);
    await prefs.setBool(_prefVibrationKey, _vibracion);
    await prefs.setString(_prefThemeKey, _temaSeleccionado);
  }

  Future<void> _guardarPreferencia(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final user = AppSupabase.client.auth.currentUser;
    await _guardarPreferenciaLocal(prefs, key, value);
    if (user == null) return;
    
    try {
      await AppSupabase.client.from('preferencias_usuario').upsert({
        'usuario_id': user.id,
        key: value,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error guardando preferencia: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo guardar en servidor. Se mantendra local."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _guardarPreferenciaLocal(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    switch (key) {
      case 'notificaciones_push':
        await prefs.setBool(_prefPushKey, value == true);
        _notificacionesPush = value == true;
        break;
      case 'notificaciones_email':
        await prefs.setBool(_prefEmailKey, value == true);
        _notificacionesEmail = value == true;
        break;
      case 'sonidos_app':
        await prefs.setBool(_prefSoundKey, value == true);
        _sonidosApp = value == true;
        break;
      case 'vibracion':
        await prefs.setBool(_prefVibrationKey, value == true);
        _vibracion = value == true;
        break;
      case 'tema':
        await prefs.setString(_prefThemeKey, value?.toString() ?? 'oscuro');
        _temaSeleccionado = value?.toString() ?? 'oscuro';
        break;
      default:
        break;
    }
  }

  bool get isSuperAdmin => _userRole == 'superadmin';
  bool get isAdmin => _userRole == 'admin' || isSuperAdmin;
  bool get isOperador => _userRole == 'operador' || isAdmin;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumScaffold(
        title: "Ajustes",
        body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      );
    }

    return PremiumScaffold(
      title: "Ajustes",
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === TARJETA DE PERFIL ===
            _buildProfileCard(),
            const SizedBox(height: 25),

            // === SECCIÓN: CUENTA Y PERFIL (TODOS) ===
            _buildSectionTitle("Cuenta y Perfil", Colors.blueAccent, Icons.person),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _buildSettingItem(
                    Icons.person_outline, 
                    "Mi Perfil", 
                    "Editar nombre y foto",
                    () => _editarPerfil(),
                  ),
                  _buildSettingItem(
                    Icons.lock_outline, 
                    "Seguridad", 
                    "Cambiar contraseña",
                    () => _cambiarPassword(),
                  ),
                  _buildSettingItem(
                    Icons.phone_android, 
                    "Dispositivos", 
                    "Sesiones activas",
                    () => _verDispositivos(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // === SECCIÓN: NOTIFICACIONES ===
            _buildSectionTitle("Notificaciones", Colors.orangeAccent, Icons.notifications),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _buildSwitchItem(
                    Icons.notifications_active,
                    "Notificaciones Push",
                    "Recibir alertas en tiempo real",
                    _notificacionesPush,
                    (v) {
                      setState(() => _notificacionesPush = v);
                      _guardarPreferencia('notificaciones_push', v);
                    },
                  ),
                  _buildSwitchItem(
                    Icons.email_outlined,
                    "Notificaciones Email",
                    "Recibir resúmenes por correo",
                    _notificacionesEmail,
                    (v) {
                      setState(() => _notificacionesEmail = v);
                      _guardarPreferencia('notificaciones_email', v);
                    },
                  ),
                  _buildSwitchItem(
                    Icons.volume_up,
                    "Sonidos",
                    "Sonidos de la app",
                    _sonidosApp,
                    (v) {
                      setState(() => _sonidosApp = v);
                      _guardarPreferencia('sonidos_app', v);
                    },
                  ),
                  _buildSwitchItem(
                    Icons.vibration,
                    "Vibración",
                    "Vibrar con notificaciones",
                    _vibracion,
                    (v) {
                      setState(() => _vibracion = v);
                      _guardarPreferencia('vibracion', v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // === SECCIÓN: APARIENCIA ===
            _buildSectionTitle("Apariencia", Colors.purpleAccent, Icons.palette),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _buildThemeSelector(),
                ],
              ),
            ),

            // === SECCIÓN: OPERACIONES (OPERADOR+) ===
            if (isOperador) ...[
              const SizedBox(height: 25),
              _buildSectionTitle("Operaciones", Colors.greenAccent, Icons.work),
              const SizedBox(height: 10),
              PremiumCard(
                child: Column(
                  children: [
                    _buildSettingItem(
                      Icons.payment, 
                      "Registrar Cobro", 
                      "Cobrar préstamo o tanda",
                      () => Navigator.pushNamed(context, AppRoutes.registrarCobro),
                    ),
                    if (isAdmin)
                      _buildSettingItem(
                        Icons.pending_actions, 
                        "Cobros Pendientes", 
                        "Confirmar transferencias",
                        () => Navigator.pushNamed(context, AppRoutes.cobrosPendientes),
                      ),
                  ],
                ),
              ),
            ],

            // === SECCIÓN: ADMINISTRACIÓN (ADMIN+) ===
            if (isAdmin) ...[
              const SizedBox(height: 25),
              _buildSectionTitle("Administración", Colors.tealAccent, Icons.admin_panel_settings),
              const SizedBox(height: 10),
              PremiumCard(
                child: Column(
                  children: [
                    _buildSettingItem(
                      Icons.account_balance, 
                      "Métodos de Pago", 
                      "Configurar bancos y QR",
                      () => Navigator.pushNamed(context, AppRoutes.configurarMetodosPago),
                    ),
                    _buildSettingItem(
                      Icons.security, 
                      "Roles y Permisos", 
                      "Gestionar accesos",
                      () => Navigator.pushNamed(context, AppRoutes.roles),
                    ),
                    _buildSettingItem(
                      Icons.history, 
                      "Auditoría", 
                      "Historial de actividad",
                      () => Navigator.pushNamed(context, AppRoutes.auditoria),
                    ),
                  ],
                ),
              ),
            ],

            // === SECCIÓN: CENTRO DE CONTROL (SUPERADMIN) ===
            if (isSuperAdmin) ...[
              const SizedBox(height: 25),
              _buildSectionTitle("Centro de Control", Colors.cyanAccent, Icons.settings_suggest),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.cyanAccent.withOpacity(0.15),
                      Colors.purpleAccent.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _buildSettingItem(
                      Icons.dashboard_customize, 
                      "Control Total", 
                      "Temas, fondos, promociones",
                      () => Navigator.pushNamed(context, AppRoutes.controlCenter),
                      highlight: true,
                    ),
                    _buildSettingItem(
                      Icons.campaign, 
                      "Notificaciones Masivas", 
                      "Enviar a todos los usuarios",
                      () => Navigator.pushNamed(context, AppRoutes.controlCenter),
                    ),
                    _buildSettingItem(
                      Icons.backup, 
                      "Backup Manual", 
                      "Crear copia de seguridad",
                      () => _crearBackup(),
                    ),
                    _buildSettingItem(
                      Icons.system_update, 
                      "Modo Mantenimiento", 
                      "Activar/desactivar",
                      () => _toggleMantenimiento(),
                    ),
                  ],
                ),
              ),
            ],

            // === SECCIÓN: SOPORTE (TODOS) ===
            const SizedBox(height: 25),
            _buildSectionTitle("Soporte", Colors.white54, Icons.help),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _buildSettingItem(
                    Icons.help_outline, 
                    "Centro de Ayuda", 
                    "Preguntas frecuentes",
                    () => _mostrarAyuda(),
                  ),
                  _buildSettingItem(
                    Icons.chat_bubble_outline, 
                    "Contactar Soporte", 
                    "Abrir chat de soporte",
                    () => Navigator.pushNamed(context, AppRoutes.chat),
                  ),
                  _buildSettingItem(
                    Icons.gavel, 
                    "Información Legal", 
                    "Términos, privacidad y licencia",
                    () => Navigator.pushNamed(context, AppRoutes.informacionLegal),
                  ),
                  _buildSettingItem(
                    Icons.info_outline, 
                    "Acerca de", 
                    "Uniko v10.51",
                    () => _mostrarAcercaDe(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Botón de cerrar sesión
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmarCerrarSesion(),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            _getRolColor().withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getRolColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: _getRolColor(),
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRolColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRolLabel(),
                    style: TextStyle(
                      color: _getRolColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: _getRolColor()),
            onPressed: () => _editarPerfil(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, VoidCallback onTap, {bool highlight = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: highlight ? Colors.cyanAccent : Colors.white70, size: 22),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: value ? Colors.greenAccent : Colors.white54, size: 22),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.greenAccent,
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themeVm = Provider.of<ThemeViewModel>(context);
    final selectedTheme = themeVm.currentTheme;
    final temas = [
      {'id': 'oscuro', 'nombre': 'Oscuro', 'icon': Icons.dark_mode, 'color': Colors.blueGrey},
      {'id': 'azul', 'nombre': 'Azul Noche', 'icon': Icons.nights_stay, 'color': Colors.indigo},
      {'id': 'verde', 'nombre': 'Verde Bosque', 'icon': Icons.park, 'color': Colors.teal},
      {'id': 'purpura', 'nombre': 'Púrpura', 'icon': Icons.auto_awesome, 'color': Colors.deepPurple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Tema de la App",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: temas.map((tema) {
            final isSelected = selectedTheme == tema['id'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _temaSeleccionado = tema['id'] as String);
                // Aplicar tema globalmente
                themeVm.setTheme(tema['id'] as String);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✨ Tema "${tema['nombre']}" aplicado'),
                    backgroundColor: tema['color'] as Color,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected 
                      ? LinearGradient(colors: [(tema['color'] as Color).withOpacity(0.3), (tema['color'] as Color).withOpacity(0.1)])
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tema['color'] as Color : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tema['icon'] as IconData, color: tema['color'] as Color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tema['nombre'] as String,
                      style: TextStyle(
                        color: isSelected ? tema['color'] as Color : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, color: tema['color'] as Color, size: 16),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getRolColor() {
    switch (_userRole) {
      case 'superadmin': return Colors.deepOrangeAccent;
      case 'admin': return Colors.orangeAccent;
      case 'operador': return Colors.blueAccent;
      case 'cliente': return Colors.greenAccent;
      default: return Colors.blueAccent;
    }
  }

  String _getRolLabel() {
    switch (_userRole) {
      case 'superadmin': return '👑 SUPERADMIN';
      case 'admin': return '⚡ ADMIN';
      case 'operador': return '📋 OPERADOR';
      case 'cliente': return '👤 CLIENTE';
      default: return _userRole?.toUpperCase() ?? 'USUARIO';
    }
  }

  // === ACCIONES ===
  
  void _editarPerfil() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _buildEditProfileSheet(),
    );
  }

  Widget _buildEditProfileSheet() {
    final nombreCtrl = TextEditingController(text: _userName);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Editar Perfil",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nombreCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Nombre completo",
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un nombre valido'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                try {
                  await AppSupabase.client.auth.updateUser(
                    UserAttributes(data: {'full_name': nombre}),
                  );
                  final user = AppSupabase.client.auth.currentUser;
                  if (user != null) {
                    try {
                      await AppSupabase.client.from('usuarios').update({
                        'nombre_completo': nombre,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', user.id);
                    } catch (_) {}
                  }
                  setState(() => _userName = nombre);
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Guardar Cambios"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _cambiarPassword() async {
    final email = _userEmail.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay email disponible.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Cambiar Contrasena", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: "Contrasena actual",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: "Nueva contrasena",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirmar contrasena",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final current = currentCtrl.text.trim();
                final newPass = newCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (current.isEmpty) {
                  setDialogState(() => error = "Ingresa tu contrasena actual");
                  return;
                }
                if (newPass.length < 6) {
                  setDialogState(() => error = "Minimo 6 caracteres");
                  return;
                }
                if (newPass != confirm) {
                  setDialogState(() => error = "Las contrasenas no coinciden");
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );

    final currentPassword = currentCtrl.text;
    final newPassword = newCtrl.text;
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      ),
    );

    try {
      final res = await AppSupabase.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (res.user == null) {
        throw const AuthException("Credenciales invalidas");
      }
      await AppSupabase.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Contrasena actualizada"),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cambiarPin() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) return;

    if (_pinSet) {
      final result = await _verificarPinDialog(user.id);
      if (result == _PinVerifyResult.cancel) return;
      if (result == _PinVerifyResult.reset) {
        final resetOk = await _resetPinWithPassword(user.id);
        if (!resetOk) return;
      }
    }

    final newPin = await _solicitarNuevoPin();
    if (newPin == null) return;

    try {
      await PinLockService.instance.savePin(
        user.id,
        newPin,
        biometricsEnabled: _bioEnabled,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo guardar el PIN. Intenta de nuevo."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _pinSet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN actualizado'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _eliminarPin() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null || !_pinSet) return;

    final result = await _verificarPinDialog(user.id);
    if (result == _PinVerifyResult.cancel) return;

    if (result == _PinVerifyResult.reset) {
      final resetOk = await _resetPinWithPassword(user.id);
      if (!resetOk) return;
    } else {
      await PinLockService.instance.clearPin(user.id);
      if (mounted) {
        setState(() {
          _pinSet = false;
          _bioEnabled = false;
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PIN eliminado. Se solicitara configurar uno nuevo."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<_PinVerifyResult> _verificarPinDialog(String userId) async {
    final pinCtrl = TextEditingController();
    String? error;
    final result = await showDialog<_PinVerifyResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Verificar PIN", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ingresa tu PIN actual para continuar.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: "PIN",
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _PinVerifyResult.cancel),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _PinVerifyResult.reset),
              child: const Text("Recuperar con contraseña"),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                if (pin.length < 4 || pin.length > 6) {
                  setDialogState(() => error = "PIN inválido");
                  return;
                }
                final ok = await PinLockService.instance.verifyPin(userId, pin);
                if (ok) {
                  if (context.mounted) {
                    Navigator.pop(context, _PinVerifyResult.ok);
                  }
                } else {
                  setDialogState(() => error = "PIN incorrecto");
                }
              },
              child: const Text("Verificar"),
            ),
          ],
        ),
      ),
    );
    pinCtrl.dispose();
    return result ?? _PinVerifyResult.cancel;
  }

  Future<String?> _solicitarNuevoPin() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Nuevo PIN", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: "PIN"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: "Confirmar PIN"),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (pin.length < 4 || pin.length > 6) {
                  setDialogState(() => error = "PIN inválido");
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => error = "Los PIN no coinciden");
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
    final result = ok == true ? pinCtrl.text.trim() : null;
    pinCtrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  Future<bool> _resetPinWithPassword(String userId) async {
    if (_userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay correo para reautenticar"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final passCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Reautenticar", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Contraseña"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Verificar"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      passCtrl.dispose();
      return false;
    }

    try {
      final res = await AppSupabase.client.auth.signInWithPassword(
        email: _userEmail,
        password: passCtrl.text,
      );
      if (res.user == null) throw const AuthException("Credenciales inválidas");

      await PinLockService.instance.clearPin(userId);
      if (mounted) {
        setState(() {
          _pinSet = false;
          _bioEnabled = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PIN restablecido. Configura uno nuevo."),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      passCtrl.dispose();
    }
  }

  Future<void> _toggleBiometria(bool value) async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) return;
    if (!_pinSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Configura un PIN primero"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!value) {
      await PinLockService.instance.setBiometricEnabled(user.id, false);
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: "Activar biometría",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return;
      await PinLockService.instance.setBiometricEnabled(user.id, true);
      if (mounted) setState(() => _bioEnabled = true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Biometría no disponible"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _verDispositivos() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Obtener información de la sesión actual
      final session = AppSupabase.client.auth.currentSession;
      final user = AppSupabase.client.auth.currentUser;
      
      if (mounted) Navigator.pop(context);
      
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text("Sesión Activa", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              
              // Dispositivo actual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smartphone, color: Colors.greenAccent, size: 20),
                        SizedBox(width: 8),
                        Text("Este dispositivo", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        Spacer(),
                        Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSessionInfo("Usuario", user?.email ?? 'N/A'),
                    _buildSessionInfo("ID Sesión", session?.accessToken.substring(0, 20) ?? 'N/A'),
                    _buildSessionInfo("Expira", session?.expiresAt != null 
                        ? DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000).toString().substring(0, 16)
                        : 'N/A'),
                    _buildSessionInfo("Último acceso", user?.lastSignInAt?.substring(0, 16) ?? 'N/A'),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botón cerrar otras sesiones
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await AppSupabase.client.auth
                          .signOut(scope: SignOutScope.others);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("✅ Se cerraron las otras sesiones activas"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.orangeAccent),
                  label: const Text("Cerrar otras sesiones", style: TextStyle(color: Colors.orangeAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
  
  Widget _buildSessionInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _crearBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("💾 Crear Backup", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Esto registrará un punto de respaldo del sistema con la fecha y hora actual.\n\n¿Continuar?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Crear Backup", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    // Mostrar loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text("Creando backup..."),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 5),
      ),
    );
    
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      final ahora = DateTime.now();

      final resultado = await AppSupabase.client.rpc(
        'crear_backup_completo',
        params: {
          'p_notas': 'Backup manual desde Ajustes por $_userName',
        },
      );

      final List<Map<String, dynamic>> filas = (resultado as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final totalTablas = filas.length;
      final totalRegistros = filas.fold<int>(
        0,
        (s, r) => s + ((r['registros'] ?? 0) as int),
      );

      // Registrar backup en auditoría
      await AppSupabase.client.from('auditoria').insert({
        'accion': 'BACKUP_MANUAL',
        'tabla_afectada': 'sistema',
        'descripcion': 'Backup manual creado desde Ajustes por $_userName',
        'usuario_id': userId,
        'metadata': {
          'fecha': ahora.toIso8601String(),
          'tipo': 'manual',
          'origen': 'settings_screen',
          'usuario_email': _userEmail,
          'tablas_respaldadas': filas.map((r) => r['tabla']).toList(),
          'registros_totales': totalRegistros,
        },
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Backup OK ($totalTablas tablas, $totalRegistros registros) - ${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleMantenimiento() async {
    // Primero obtener estado actual
    bool estadoActual = false;
    try {
      final config = await AppSupabase.client
          .from('configuracion_global')
          .select('modo_mantenimiento, id')
          .maybeSingle();
      estadoActual = config?['modo_mantenimiento'] == true;
    } catch (e) {
      debugPrint('Error obteniendo estado: $e');
    }
    
    final nuevoEstado = !estadoActual;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              nuevoEstado ? Icons.engineering : Icons.check_circle,
              color: nuevoEstado ? Colors.orangeAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 10),
            const Text("Modo Mantenimiento", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nuevoEstado 
                  ? "¿Activar modo mantenimiento?\n\nLos usuarios verán un mensaje y no podrán operar."
                  : "¿Desactivar modo mantenimiento?\n\nLos usuarios podrán usar la app normalmente.",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (nuevoEstado ? Colors.orangeAccent : Colors.greenAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    "Estado actual: ",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    estadoActual ? "EN MANTENIMIENTO" : "OPERATIVO",
                    style: TextStyle(
                      color: estadoActual ? Colors.orangeAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado ? Colors.orangeAccent : Colors.greenAccent,
            ),
            child: Text(
              nuevoEstado ? "Activar" : "Desactivar",
              style: TextStyle(color: nuevoEstado ? Colors.black : Colors.black),
            ),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // Actualizar en la base de datos
      await AppSupabase.client.from('configuracion_global').update({
        'modo_mantenimiento': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
      }).neq('id', '00000000-0000-0000-0000-000000000000'); // Actualiza todos los registros
      
      // Registrar en auditoría
      await AppSupabase.client.from('auditoria').insert({
        'accion': nuevoEstado ? 'ACTIVAR_MANTENIMIENTO' : 'DESACTIVAR_MANTENIMIENTO',
        'tabla_afectada': 'configuracion_global',
        'descripcion': 'Modo mantenimiento ${nuevoEstado ? "activado" : "desactivado"} por $_userName',
        'usuario_id': AppSupabase.client.auth.currentUser?.id,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nuevoEstado ? Icons.engineering : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(nuevoEstado 
                    ? "🔧 Modo mantenimiento ACTIVADO" 
                    : "✅ Sistema OPERATIVO"),
              ],
            ),
            backgroundColor: nuevoEstado ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarAyuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Centro de Ayuda", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildHelpItem("¿Cómo registro un pago?", "Ve a Cobros > Registrar Cobro"),
            _buildHelpItem("¿Cómo creo una tanda?", "Ve a Tandas > Nueva Tanda"),
            _buildHelpItem("¿Cómo agrego un cliente?", "Ve a Clientes > botón +"),
            _buildHelpItem("¿Cómo veo mis préstamos?", "Ve a la sección Préstamos"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String pregunta, String respuesta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(respuesta, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  void _mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: "Uniko",
      applicationVersion: "v10.51",
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00D9FF).withOpacity(0.3),
              const Color(0xFF8B5CF6).withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.business_center, color: Color(0xFF00D9FF), size: 40),
      ),
      children: const [
        Text("Sistema Multi-Negocio integral para gestión de préstamos, tandas, servicios y comercio."),
        SizedBox(height: 10),
        Text("© 2026 Robert-Darin • Todos los derechos reservados", 
             style: TextStyle(fontSize: 12, color: Colors.grey)),
        SizedBox(height: 5),
        Text("Desarrollado en México 🇲🇽", 
             style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
        content: const Text("¿Estás seguro que deseas cerrar sesión?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthViewModel>(context, listen: false).cerrarSesion(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Cerrar Sesión"),
          ),
        ],
      ),
    );
  }
}

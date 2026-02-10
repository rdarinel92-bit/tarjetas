import 'package:flutter/foundation.dart';
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/app_routes.dart';
import '../../services/tarjetas_chat_realtime_service.dart'; // V10.54 Chat Realtime
import '../../services/push_notification_service.dart'; // V10.56 FCM Token

class AuthViewModel extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  static const Set<String> _ownerEmails = {
    'rdarinel992@gmail.com',
  };
  bool _cargando = false;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;

  User? get usuarioActual => _supabase.auth.currentUser;

  bool _esOwnerEmail(String? email) {
    if (email == null) {
      debugPrint('⚠️ _esOwnerEmail: email es null');
      return false;
    }
    final emailLower = email.toLowerCase().trim();
    final esOwner = _ownerEmails.contains(emailLower);
    debugPrint('🔍 _esOwnerEmail: "$email" → lower="$emailLower" → esOwner=$esOwner');
    debugPrint('🔍 _ownerEmails contiene: $_ownerEmails');
    return esOwner;
  }

  Future<void> iniciarSesion(
      String email, String password, BuildContext context) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _asegurarPerfilUsuario(response.user!);
        
        // V10.54 - Iniciar servicio de chat en tiempo real
        try {
          await TarjetasChatRealtimeService().inicializar();
        } catch (e) {
          debugPrint('⚠️ Error iniciando chat realtime: $e');
        }
        
        // V10.56 - Guardar FCM token para push notifications
        try {
          await PushNotificationService().guardarTokenUsuario(response.user!.id);
        } catch (e) {
          debugPrint('⚠️ Error guardando FCM token: $e');
        }
        
        await navegarSegunRol(context);
      }
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _asegurarPerfilUsuario(User user) async {
    try {
      // 1. Upsert en tabla usuarios
      await _supabase.from('usuarios').upsert({
        'id': user.id,
        'email': user.email,
        'nombre_completo':
            user.userMetadata?['full_name'] ?? 'Super Administrador',
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // 2. Asegurar rol superadmin para el dueño (correo autorizado)
      // Nota: Mantener lista corta y controlada.
      if (_esOwnerEmail(user.email)) {
        await _asegurarRolSuperadmin(user.id);
      }
    } catch (e) {
      debugPrint('Aviso: Perfil usuario error: $e');
    }
  }
  
  /// V10.35 - Asegura que el superadmin tenga su rol en usuarios_roles
  Future<void> _asegurarRolSuperadmin(String userId) async {
    try {
      // Obtener ID del rol superadmin
      final rolRes = await _supabase
          .from('roles')
          .select('id')
          .eq('nombre', 'superadmin')
          .maybeSingle();
      
      if (rolRes == null) {
        debugPrint('Aviso: No se encontró rol superadmin');
        return;
      }
      
      final rolId = rolRes['id'];
      
      // Verificar si ya tiene el rol asignado
      final existeRol = await _supabase
          .from('usuarios_roles')
          .select('id')
          .eq('usuario_id', userId)
          .eq('rol_id', rolId)
          .maybeSingle();
      
      if (existeRol == null) {
        // Insertar el rol
        await _supabase.from('usuarios_roles').insert({
          'usuario_id': userId,
          'rol_id': rolId,
        });
        debugPrint('✅ Rol superadmin asignado en usuarios_roles');
      }
    } catch (e) {
      debugPrint('Aviso: Error asegurando rol superadmin: $e');
    }
  }

  Future<String> obtenerRol() async {
    final user = usuarioActual;
    if (user == null) {
      debugPrint('⚠️ obtenerRol: user es NULL, retornando cliente');
      return 'cliente';
    }

    debugPrint('🔍 obtenerRol: email="${user.email}", id="${user.id}"');

    // Owner fijo (asegura acceso aunque falte rol en BD)
    if (_esOwnerEmail(user.email)) {
      debugPrint('✅ obtenerRol: Email es owner → superadmin');
      return 'superadmin';
    }
    
    debugPrint('⚠️ obtenerRol: Email NO está en _ownerEmails, verificando BD...');

    // Prioridad superadmin si ya tiene rol asignado
    try {
      final esSuperadmin = await _supabase.rpc(
        'usuario_tiene_rol',
        params: {'rol_nombre': 'superadmin'},
      );
      if (esSuperadmin == true) {
        return 'superadmin';
      }
    } catch (e) {
      debugPrint('Aviso: Error verificando superadmin: $e');
    }

    try {
      // Primero verificar si es un colaborador
      final colaboradorRes = await _supabase
          .from('v_colaboradores_completos')
          .select('id, tipo_codigo, estado')
          .eq('auth_uid', user.id)
          .eq('estado', 'activo')
          .maybeSingle();

      if (colaboradorRes != null) {
        final tipoCodigo = colaboradorRes['tipo_codigo']?.toString();
        if (tipoCodigo != null && tipoCodigo.isNotEmpty) {
          return 'colaborador_$tipoCodigo';
        }
        return 'colaborador';
      }

      // Verificar si es una vendedora NICE & BELLA
      final vendedoraNiceRes = await _supabase
          .from('nice_vendedoras')
          .select('id, activo')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (vendedoraNiceRes != null) {
        return 'vendedora_nice';
      }

      // Verificar también por email para vendedoras NICE
      final vendedoraNiceByEmail = await _supabase
          .from('nice_vendedoras')
          .select('id, activo')
          .eq('email', user.email ?? '')
          .eq('activo', true)
          .maybeSingle();

      if (vendedoraNiceByEmail != null) {
        // Vincular auth_uid
        await _supabase
            .from('nice_vendedoras')
            .update({'auth_uid': user.id})
            .eq('id', vendedoraNiceByEmail['id']);
        return 'vendedora_nice';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR TÉCNICO DE CLIMAS
      // ════════════════════════════════════════════════════════════════════
      final tecnicoClimasRes = await _supabase
          .from('climas_tecnicos')
          .select('id, activo')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (tecnicoClimasRes != null) {
        return 'tecnico_climas';
      }

      // Verificar por email
      final tecnicoClimasByEmail = await _supabase
          .from('climas_tecnicos')
          .select('id, activo')
          .eq('email', user.email ?? '')
          .eq('activo', true)
          .maybeSingle();

      if (tecnicoClimasByEmail != null) {
        await _supabase
            .from('climas_tecnicos')
            .update({'auth_uid': user.id})
            .eq('id', tecnicoClimasByEmail['id']);
        return 'tecnico_climas';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR REPARTIDOR DE PURIFICADORA
      // ════════════════════════════════════════════════════════════════════
      final repartidorRes = await _supabase
          .from('purificadora_repartidores')
          .select('id, activo')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (repartidorRes != null) {
        return 'repartidor_purificadora';
      }

      // Verificar por email
      final repartidorByEmail = await _supabase
          .from('purificadora_repartidores')
          .select('id, activo')
          .eq('email', user.email ?? '')
          .eq('activo', true)
          .maybeSingle();

      if (repartidorByEmail != null) {
        await _supabase
            .from('purificadora_repartidores')
            .update({'auth_uid': user.id})
            .eq('id', repartidorByEmail['id']);
        return 'repartidor_purificadora';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR CLIENTE DE MÓDULO (CLIMAS, PURIFICADORA)
      // ════════════════════════════════════════════════════════════════════
      final clienteModuloRes = await _supabase
          .from('clientes_modulo')
          .select('id, modulo, activo')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (clienteModuloRes != null) {
        return 'cliente_${clienteModuloRes['modulo']}';
      }

      // Verificar cliente CLIMAS por email
      final clienteClimasRes = await _supabase
          .from('climas_clientes')
          .select('id')
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (clienteClimasRes != null) {
        // Verificar o crear vínculo en clientes_modulo
        await _supabase
            .from('climas_clientes')
            .update({'auth_uid': user.id})
            .eq('id', clienteClimasRes['id']);
        return 'cliente_climas';
      }

      // Verificar cliente PURIFICADORA por email
      final clientePurificadoraRes = await _supabase
          .from('purificadora_clientes')
          .select('id')
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (clientePurificadoraRes != null) {
        await _supabase
            .from('purificadora_clientes')
            .update({'auth_uid': user.id})
            .eq('id', clientePurificadoraRes['id']);
        return 'cliente_purificadora';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR CLIENTE DE VENTAS/CATÁLOGO V10.22
      // ════════════════════════════════════════════════════════════════════
      final clienteVentasRes = await _supabase
          .from('ventas_clientes')
          .select('id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteVentasRes != null) {
        return 'cliente_ventas';
      }

      // Verificar por email
      final clienteVentasByEmail = await _supabase
          .from('ventas_clientes')
          .select('id')
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (clienteVentasByEmail != null) {
        await _supabase
            .from('ventas_clientes')
            .update({'auth_uid': user.id})
            .eq('id', clienteVentasByEmail['id']);
        return 'cliente_ventas';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR CLIENTE DE NICE JOYERÍA V10.22
      // ════════════════════════════════════════════════════════════════════
      final clienteNiceRes = await _supabase
          .from('nice_clientes')
          .select('id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteNiceRes != null) {
        return 'cliente_nice';
      }

      // Verificar por email
      final clienteNiceByEmail = await _supabase
          .from('nice_clientes')
          .select('id')
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (clienteNiceByEmail != null) {
        await _supabase
            .from('nice_clientes')
            .update({'auth_uid': user.id})
            .eq('id', clienteNiceByEmail['id']);
        return 'cliente_nice';
      }

      // ════════════════════════════════════════════════════════════════════
      // VERIFICAR VENDEDOR DE VENTAS/CATÁLOGO
      // ════════════════════════════════════════════════════════════════════
      final vendedorVentasRes = await _supabase
          .from('ventas_vendedores')
          .select('id, activo')
          .eq('auth_uid', user.id)
          .eq('activo', true)
          .maybeSingle();

      if (vendedorVentasRes != null) {
        return 'vendedor_ventas';
      }

      // Verificar por email
      final vendedorVentasByEmail = await _supabase
          .from('ventas_vendedores')
          .select('id, activo')
          .eq('email', user.email ?? '')
          .eq('activo', true)
          .maybeSingle();

      if (vendedorVentasByEmail != null) {
        await _supabase
            .from('ventas_vendedores')
            .update({'auth_uid': user.id})
            .eq('id', vendedorVentasByEmail['id']);
        return 'vendedor_ventas';
      }

      // Si no es colaborador, vendedora, técnico, repartidor ni cliente módulo, buscar rol normal
      final res = await _supabase
          .from('usuarios_roles')
          .select('roles(nombre)')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (res != null && res['roles'] != null) {
        return res['roles']['nombre']?.toString() ?? 'cliente';
      }
      return 'cliente';
    } catch (e) {
      debugPrint('Error al obtener rol: $e');
      return 'cliente';
    }
  }

  Future<void> navegarSegunRol(BuildContext context) async {
    final rol = await obtenerRol();
    String ruta;

    debugPrint('Navegando con rol real detectado: $rol');

    // Verificar si es colaborador
    if (rol.startsWith('colaborador_')) {
      ruta = AppRoutes.dashboardColaborador;
    } else if (rol.startsWith('cliente_')) {
      // Clientes de módulos específicos
      switch (rol) {
        case 'cliente_climas':
          ruta = AppRoutes.dashboardClienteClimas;
          break;
        case 'cliente_purificadora':
          ruta = AppRoutes.dashboardClientePurificadora;
          break;
        case 'cliente_ventas':
          ruta = AppRoutes.dashboardClienteVentas;
          break;
        case 'cliente_nice':
          ruta = AppRoutes.dashboardClienteNice;
          break;
        default:
          ruta = AppRoutes.dashboardCliente;
      }
    } else {
      switch (rol) {
        case 'superadmin':
          ruta = AppRoutes.dashboardSuperadmin;
          break;
        case 'admin':
          ruta = AppRoutes.dashboardAdmin;
          break;
        case 'operador':
          ruta = AppRoutes.dashboardOperador;
          break;
        case 'contador':
          ruta = AppRoutes.dashboardAdmin; // Usa AppShell con acceso a Contabilidad
          break;
        case 'recursos_humanos':
          ruta = AppRoutes.dashboardAdmin; // Usa AppShell con acceso a RRHH
          break;
        case 'aval':
          ruta = AppRoutes.dashboardAval;
          break;
        case 'vendedora_nice':
          ruta = AppRoutes.dashboardVendedoraNice;
          break;
        case 'tecnico_climas':
          ruta = AppRoutes.dashboardTecnicoClimas;
          break;
        case 'repartidor_purificadora':
          ruta = AppRoutes.dashboardRepartidorPurificadora;
          break;
        case 'vendedor_ventas':
          ruta = AppRoutes.dashboardVendedorVentas;
          break;
        case 'cliente':
        default:
          ruta = AppRoutes.dashboardCliente;
      }
    }

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, ruta);
    }
  }

  Future<void> cerrarSesion(BuildContext context) async {
    // Mostrar pantalla de cierre de sesión elegante
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPantallaCerrandoSesion(),
    );

    // Esperar un momento para mostrar la animación
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // V10.54 - Detener servicio de chat en tiempo real
      await TarjetasChatRealtimeService().detenerEscucha();
      
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión en Supabase: $e');
    }

    if (context.mounted) {
      // Limpia todo el historial de navegación y vuelve al login
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  Widget _buildPantallaCerrandoSesion() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Círculo de progreso
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.cyanAccent.withOpacity(0.8),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.logout,
                    color: Colors.cyanAccent,
                    size: 30,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Cerrando sesión...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Guardando cambios",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 30),
            // Barra de progreso lineal
            SizedBox(
              width: 200,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1400),
                builder: (context, value, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.cyanAccent.withOpacity(0.8),
                      ),
                      minHeight: 6,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

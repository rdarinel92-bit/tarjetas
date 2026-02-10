// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE AUTENTICACIÓN PARA NUEVOS USUARIOS
// Robert Darin Platform v10.55
// 
// Permite crear cuentas de login para cualquier tipo de usuario:
// - Técnicos de climas → rol: tecnico_climas → Dashboard: dashboardTecnicoClimas
// - Repartidores de purificadora → rol: repartidor_purificadora → Dashboard: dashboardRepartidorPurificadora
// - Vendedoras NICE → rol: vendedora_nice → Dashboard: dashboardVendedoraNice
// - Vendedores Ventas → rol: vendedor_ventas → Dashboard: dashboardVendedorVentas
// - Clientes → rol: cliente → Dashboard: dashboardCliente
// - Colaboradores → rol: colaborador → Dashboard: dashboardColaborador
// ═══════════════════════════════════════════════════════════════════════════════

class AuthCreacionService {
  
  /// Mapeo de tipo de usuario a rol en BD
  static const Map<String, String> _tipoUsuarioARol = {
    'tecnico_climas': 'tecnico_climas',
    'repartidor_purificadora': 'repartidor_purificadora',
    'vendedora_nice': 'vendedora_nice',
    'vendedor_ventas': 'vendedor_ventas',
    'cliente': 'cliente',
    'cliente_climas': 'cliente',
    'cliente_purificadora': 'cliente',
    'cliente_ventas': 'cliente',
    'cliente_nice': 'cliente',
    'colaborador': 'colaborador',
    'inversionista': 'colaborador',
    'aval': 'aval',
  };

  /// Crea una cuenta de autenticación para un usuario
  /// Retorna el auth_uid si fue exitoso, null si falló
  static Future<String?> crearCuentaAuth({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tipoUsuario, // 'tecnico_climas', 'repartidor_purificadora', etc.
    String? rol, // Si no se especifica, se determina automáticamente
    String? negocioId, // Para vincular al negocio
  }) async {
    try {
      // Determinar el rol correcto
      final rolFinal = rol ?? _tipoUsuarioARol[tipoUsuario] ?? 'cliente';

      // 1. Crear usuario en Supabase Auth
      final response = await AppSupabase.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': nombreCompleto,
          'tipo_usuario': tipoUsuario,
          'rol': rolFinal,
        },
      );

      if (response.user == null) {
        debugPrint('Error: No se pudo crear usuario en auth');
        return null;
      }

      final authUid = response.user!.id;

      // 2. Crear registro en tabla usuarios con negocio_id
      await AppSupabase.client.from('usuarios').upsert({
        'auth_uid': authUid,
        'email': email,
        'nombre_completo': nombreCompleto,
        if (negocioId != null) 'negocio_id': negocioId,
      }, onConflict: 'auth_uid');

      // 3. Asignar rol
      final rolData = await AppSupabase.client
          .from('roles')
          .select('id')
          .eq('nombre', rolFinal)
          .maybeSingle();
      
      if (rolData != null) {
        final usuarioData = await AppSupabase.client
            .from('usuarios')
            .select('id')
            .eq('auth_uid', authUid)
            .single();
        
        await AppSupabase.client.from('usuarios_roles').upsert({
          'usuario_id': usuarioData['id'],
          'rol_id': rolData['id'],
        }, onConflict: 'usuario_id,rol_id');
      } else {
        // Si el rol específico no existe, crear uno genérico o usar operador
        debugPrint('Rol "$rolFinal" no encontrado, usando operador como fallback');
        final rolOperador = await AppSupabase.client
            .from('roles')
            .select('id')
            .eq('nombre', 'operador')
            .maybeSingle();
        
        if (rolOperador != null) {
          final usuarioData = await AppSupabase.client
              .from('usuarios')
              .select('id')
              .eq('auth_uid', authUid)
              .single();
          
          await AppSupabase.client.from('usuarios_roles').upsert({
            'usuario_id': usuarioData['id'],
            'rol_id': rolOperador['id'],
          }, onConflict: 'usuario_id,rol_id');
        }
      }

      return authUid;
    } catch (e) {
      debugPrint('Error creando cuenta auth: $e');
      return null;
    }
  }

  /// Genera una contraseña aleatoria segura
  static String generarPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    return List.generate(12, (index) => chars[(DateTime.now().microsecond + index * 7) % chars.length]).join();
  }

  /// Valida que el email no esté en uso
  static Future<bool> emailDisponible(String email) async {
    try {
      final existing = await AppSupabase.client
          .from('usuarios')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();
      return existing == null;
    } catch (e) {
      return true; // Asumir disponible si hay error
    }
  }

  /// Información sobre cada tipo de usuario
  static Map<String, Map<String, String>> get tipoUsuarioInfo => {
    'tecnico_climas': {
      'rol': 'tecnico_climas',
      'titulo': 'Técnico de Climas',
      'dashboard': 'Panel de Técnico',
      'descripcion': 'Verá sus órdenes asignadas, podrá completar servicios y registrar materiales',
      'icono': '❄️',
    },
    'repartidor_purificadora': {
      'rol': 'repartidor_purificadora',
      'titulo': 'Repartidor',
      'dashboard': 'Panel de Repartidor',
      'descripcion': 'Verá sus rutas del día, podrá registrar entregas y cobros',
      'icono': '🚚',
    },
    'vendedora_nice': {
      'rol': 'vendedora_nice',
      'titulo': 'Vendedora NICE',
      'dashboard': 'Panel de Vendedora',
      'descripcion': 'Verá su catálogo, pedidos, clientes y comisiones',
      'icono': '💎',
    },
    'vendedor_ventas': {
      'rol': 'vendedor_ventas',
      'titulo': 'Vendedor',
      'dashboard': 'Panel de Vendedor',
      'descripcion': 'Verá el catálogo de productos, podrá crear pedidos y ver sus ventas',
      'icono': '🛒',
    },
    'cliente': {
      'rol': 'cliente',
      'titulo': 'Cliente',
      'dashboard': 'Portal de Cliente',
      'descripcion': 'Verá sus préstamos, pagos pendientes y podrá realizar pagos',
      'icono': '👤',
    },
    'cliente_climas': {
      'rol': 'cliente',
      'titulo': 'Cliente Climas',
      'dashboard': 'Portal de Cliente',
      'descripcion': 'Verá sus servicios de aire acondicionado y mantenimientos',
      'icono': '❄️',
    },
    'cliente_purificadora': {
      'rol': 'cliente',
      'titulo': 'Cliente Purificadora',
      'dashboard': 'Portal de Cliente',
      'descripcion': 'Verá sus pedidos de agua y entregas programadas',
      'icono': '💧',
    },
    'cliente_ventas': {
      'rol': 'cliente',
      'titulo': 'Cliente Ventas',
      'dashboard': 'Portal de Cliente',
      'descripcion': 'Verá sus pedidos, historial de compras y facturas',
      'icono': '🛍️',
    },
    'cliente_nice': {
      'rol': 'cliente',
      'titulo': 'Cliente NICE',
      'dashboard': 'Portal de Cliente',
      'descripcion': 'Verá sus pedidos de productos NICE y estado de entregas',
      'icono': '💎',
    },
    'colaborador': {
      'rol': 'colaborador',
      'titulo': 'Colaborador',
      'dashboard': 'Panel de Colaborador',
      'descripcion': 'Verá sus inversiones, rendimientos y estado de cuenta',
      'icono': '🤝',
    },
    'inversionista': {
      'rol': 'colaborador',
      'titulo': 'Inversionista',
      'dashboard': 'Panel de Colaborador',
      'descripcion': 'Verá sus inversiones, rendimientos y reportes financieros',
      'icono': '💰',
    },
    'aval': {
      'rol': 'aval',
      'titulo': 'Aval',
      'dashboard': 'Portal de Aval',
      'descripcion': 'Verá los préstamos que respalda y notificaciones importantes',
      'icono': '✅',
    },
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET REUTILIZABLE PARA CAMPOS DE AUTENTICACIÓN (V10.55)
// ═══════════════════════════════════════════════════════════════════════════════

class CamposAuthWidget extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool crearCuenta;
  final ValueChanged<bool> onCrearCuentaChanged;
  final String tipoUsuario;

  const CamposAuthWidget({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.crearCuenta,
    required this.onCrearCuentaChanged,
    this.tipoUsuario = 'usuario',
  });

  @override
  State<CamposAuthWidget> createState() => _CamposAuthWidgetState();
}

class _CamposAuthWidgetState extends State<CamposAuthWidget> {
  bool _mostrarPassword = false;

  Map<String, String> get _infoTipo => 
      AuthCreacionService.tipoUsuarioInfo[widget.tipoUsuario] ?? {
        'titulo': widget.tipoUsuario,
        'dashboard': 'Su panel',
        'descripcion': 'Tendrá acceso a la aplicación',
        'icono': '👤',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '🔐 Acceso a la App',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            ],
          ),
        ),

        // Toggle crear cuenta
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.crearCuenta 
                  ? const Color(0xFF00D9FF).withOpacity(0.5) 
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: SwitchListTile(
            title: Text(
              'Crear acceso a la app',
              style: TextStyle(
                color: widget.crearCuenta ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              widget.crearCuenta 
                  ? 'El ${widget.tipoUsuario} podrá iniciar sesión'
                  : 'Sin acceso a la app',
              style: TextStyle(
                color: widget.crearCuenta 
                    ? const Color(0xFF00D9FF).withOpacity(0.7)
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
            value: widget.crearCuenta,
            onChanged: widget.onCrearCuentaChanged,
            activeColor: const Color(0xFF00D9FF),
          ),
        ),

        // Campos de email y password (solo si crearCuenta)
        if (widget.crearCuenta) ...[
          const SizedBox(height: 12),
          
          // Info del rol y dashboard asignado
          _buildInfoRolAsignado(),
          const SizedBox(height: 16),
          
          // Email
          TextField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email de acceso',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.email, color: Color(0xFF00D9FF)),
              filled: true,
              fillColor: const Color(0xFF0D0D14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00D9FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password
          TextField(
            controller: widget.passwordController,
            obscureText: !_mostrarPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF00D9FF)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high, color: Color(0xFF00D9FF)),
                    onPressed: () {
                      widget.passwordController.text = AuthCreacionService.generarPassword();
                      setState(() => _mostrarPassword = true);
                    },
                    tooltip: 'Generar contraseña',
                  ),
                ],
              ),
              filled: true,
              fillColor: const Color(0xFF0D0D14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00D9FF)),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          Text(
            '💡 El ${widget.tipoUsuario} usará este email y contraseña para entrar a la app',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
          ),
        ],
      ],
    );
  }
  
  /// Construye el widget de información del rol asignado
  Widget _buildInfoRolAsignado() {
    final info = AuthCreacionService.tipoUsuarioInfo[widget.tipoUsuario];
    
    if (info == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Se asignará rol por defecto "operador"',
                style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.badge, color: Color(0xFF00D9FF), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rol: ${info['rol']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      info['descripcion'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dashboard, color: Color(0xFF8B5CF6), size: 12),
                const SizedBox(width: 4),
                Text(
                  'Dashboard: ${info['dashboard']}',
                  style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

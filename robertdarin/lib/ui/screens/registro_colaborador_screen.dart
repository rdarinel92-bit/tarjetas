/// ═══════════════════════════════════════════════════════════════════════════════
/// REGISTRO DE COLABORADOR - Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Permite a los colaboradores crear su cuenta usando el código de invitación
/// ═══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

class RegistroColaboradorScreen extends StatefulWidget {
  final String? codigoInvitacion; // Puede venir por deep link
  
  const RegistroColaboradorScreen({super.key, this.codigoInvitacion});

  @override
  State<RegistroColaboradorScreen> createState() => _RegistroColaboradorScreenState();
}

class _RegistroColaboradorScreenState extends State<RegistroColaboradorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _codigoValidado = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  
  // Datos del colaborador (después de validar código)
  Map<String, dynamic>? _invitacion;
  Map<String, dynamic>? _colaborador;
  Map<String, dynamic>? _tipoColaborador;

  @override
  void initState() {
    super.initState();
    if (widget.codigoInvitacion != null) {
      _codigoController.text = widget.codigoInvitacion!;
      _validarCodigo();
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validarCodigo() async {
    final codigo = _codigoController.text.trim().toUpperCase();
    if (codigo.isEmpty || codigo.length < 6) {
      setState(() => _error = 'Ingresa un código válido');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Buscar invitación por código
      final invRes = await AppSupabase.client
          .from('colaborador_invitaciones')
          .select('''
            *,
            colaborador:colaborador_creado_id(*)
          ''')
          .eq('codigo_invitacion', codigo)
          .maybeSingle();

      if (invRes == null) {
        setState(() {
          _error = 'Código de invitación no encontrado';
          _isLoading = false;
        });
        return;
      }

      if (invRes['estado'] != 'pendiente') {
        setState(() {
          _error = 'Este código ya fue utilizado o expiró';
          _isLoading = false;
        });
        return;
      }

      // Verificar si expiró
      if (invRes['fecha_expiracion'] != null) {
        final expira = DateTime.parse(invRes['fecha_expiracion']);
        if (DateTime.now().isAfter(expira)) {
          setState(() {
            _error = 'Este código ha expirado. Solicita uno nuevo.';
            _isLoading = false;
          });
          return;
        }
      }

      _invitacion = invRes;
      
      // Obtener datos del colaborador
      if (invRes['colaborador'] != null) {
        _colaborador = invRes['colaborador'];
        _emailController.text = _colaborador!['email'] ?? invRes['email'] ?? '';
      } else {
        _emailController.text = invRes['email'] ?? '';
      }

      // Obtener tipo de colaborador
      if (invRes['tipo_id'] != null) {
        final tipoRes = await AppSupabase.client
            .from('colaborador_tipos')
            .select()
            .eq('id', invRes['tipo_id'])
            .single();
        _tipoColaborador = tipoRes;
      }

      setState(() {
        _codigoValidado = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al validar código: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmarPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Crear usuario en Supabase Auth
      final authRes = await AppSupabase.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _colaborador?['nombre'] ?? _invitacion?['nombre'] ?? 'Colaborador',
          'es_colaborador': true,
        },
      );

      if (authRes.user == null) {
        setState(() {
          _error = 'No se pudo crear la cuenta. Intenta con otro email.';
          _isLoading = false;
        });
        return;
      }

      final authUid = authRes.user!.id;

      // Actualizar colaborador con auth_uid
      if (_colaborador != null) {
        await AppSupabase.client
            .from('colaboradores')
            .update({
              'auth_uid': authUid,
              'tiene_cuenta': true,
              'estado': 'activo',
            })
            .eq('id', _colaborador!['id']);
      } else {
        // Crear colaborador si no existía
        await AppSupabase.client.from('colaboradores').insert({
          'negocio_id': _invitacion!['negocio_id'],
          'tipo_id': _invitacion!['tipo_id'],
          'nombre': _invitacion!['nombre'] ?? 'Colaborador',
          'email': _emailController.text.trim(),
          'auth_uid': authUid,
          'tiene_cuenta': true,
          'estado': 'activo',
        });
      }

      // Marcar invitación como aceptada
      await AppSupabase.client
          .from('colaborador_invitaciones')
          .update({
            'estado': 'aceptada',
            'fecha_respuesta': DateTime.now().toIso8601String(),
          })
          .eq('id', _invitacion!['id']);

      // Mostrar éxito y redirigir
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                const Text('¡Cuenta Creada!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Bienvenido ${_colaborador?['nombre'] ?? 'Colaborador'}!',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_tipoColaborador != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rol: ${_tipoColaborador!['nombre']}',
                      style: const TextStyle(color: Color(0xFF3B82F6)),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Tu cuenta ha sido creada y vinculada exitosamente. Ahora puedes iniciar sesión.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.dashboardColaborador);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Ir a Mi Panel'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('already registered')) {
        errorMsg = 'Este email ya está registrado. Intenta iniciar sesión.';
      }
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Logo y título
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF3B82F6).withOpacity(0.3), const Color(0xFF8B5CF6).withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF3B82F6), size: 50),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Registro de Colaborador',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _codigoValidado 
                    ? 'Crea tu cuenta para acceder al sistema'
                    : 'Ingresa tu código de invitación',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                ),
              
              // Paso 1: Validar código
              if (!_codigoValidado) ...[
                _buildCodigoInput(),
              ],
              
              // Paso 2: Crear cuenta
              if (_codigoValidado) ...[
                _buildInfoColaborador(),
                const SizedBox(height: 24),
                _buildFormularioCuenta(),
              ],
              
              const SizedBox(height: 24),
              
              // Link a login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.white54)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Iniciar Sesión', style: TextStyle(color: Color(0xFF3B82F6))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodigoInput() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.vpn_key, color: Color(0xFFFBBF24), size: 40),
              const SizedBox(height: 16),
              const Text(
                'Código de Invitación',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'El administrador del negocio te compartió un código de 8 caracteres',
                style: TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
                  filled: true,
                  fillColor: Colors.black26,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFBBF24)),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _validarCodigo,
            icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward),
            label: Text(_isLoading ? 'Validando...' : 'Validar Código'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColaborador() {
    Color tipoColor = const Color(0xFF3B82F6);
    IconData tipoIcon = Icons.person;
    
    if (_tipoColaborador != null) {
      switch (_tipoColaborador!['codigo']) {
        case 'co_superadmin':
          tipoColor = const Color(0xFFEF4444);
          tipoIcon = Icons.admin_panel_settings;
          break;
        case 'socio_operativo':
          tipoColor = const Color(0xFF8B5CF6);
          tipoIcon = Icons.handshake;
          break;
        case 'socio_inversionista':
          tipoColor = const Color(0xFF10B981);
          tipoIcon = Icons.trending_up;
          break;
        case 'contador':
          tipoColor = const Color(0xFF3B82F6);
          tipoIcon = Icons.calculate;
          break;
        case 'asesor':
          tipoColor = const Color(0xFFFBBF24);
          tipoIcon = Icons.support_agent;
          break;
        case 'facturador':
          tipoColor = const Color(0xFF06B6D4);
          tipoIcon = Icons.receipt_long;
          break;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tipoColor.withOpacity(0.3), tipoColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tipoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tipoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tipoIcon, color: tipoColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _colaborador?['nombre'] ?? _invitacion?['nombre'] ?? 'Colaborador',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: tipoColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _tipoColaborador?['nombre'] ?? 'Colaborador',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildFormularioCuenta() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crea tu cuenta',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF3B82F6)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu email';
              if (!v.contains('@')) return 'Email no válido';
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3B82F6)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa una contraseña';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Confirmar password
          TextFormField(
            controller: _confirmarPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3B82F6)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirma tu contraseña';
              if (v != _passwordController.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _crearCuenta,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add),
              label: Text(_isLoading ? 'Creando cuenta...' : 'Crear mi Cuenta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

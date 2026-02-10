// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class EmpleadoFormScreen extends StatefulWidget {
  const EmpleadoFormScreen({super.key});

  @override
  State<EmpleadoFormScreen> createState() => _EmpleadoFormScreenState();
}

class _EmpleadoFormScreenState extends State<EmpleadoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Datos Personales y Acceso
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  
  // Datos Laborales
  final _puestoController = TextEditingController();
  final _salarioController = TextEditingController();
  final _comisionController = TextEditingController(text: '0');
  
  String? _rolSeleccionado;
  String? _sucursalSeleccionada;
  String _tipoComision = 'ninguna'; // ninguna, al_liquidar, proporcional, primer_pago
  List<dynamic> _sucursales = [];
  List<dynamic> _roles = [];
  List<dynamic> _permisosDelRol = []; // Permisos cargados de la BD
  bool _loading = false;
  bool _cargandoPermisos = false;
  int _currentStep = 0;

  // Iconos y descripciones amigables para permisos
  final Map<String, Map<String, dynamic>> _permisosInfo = {
    // Permisos generales
    'ver_dashboard': {'icono': '📊', 'nombre': 'Ver Dashboard', 'color': Colors.blueAccent},
    'gestionar_clientes': {'icono': '👥', 'nombre': 'Gestionar Clientes', 'color': Colors.tealAccent},
    'gestionar_prestamos': {'icono': '💰', 'nombre': 'Gestionar Préstamos', 'color': Colors.greenAccent},
    'gestionar_tandas': {'icono': '🔄', 'nombre': 'Gestionar Tandas', 'color': Colors.purpleAccent},
    'gestionar_avales': {'icono': '🤝', 'nombre': 'Gestionar Avales', 'color': Colors.orangeAccent},
    'gestionar_pagos': {'icono': '💵', 'nombre': 'Gestionar Pagos', 'color': Colors.green},
    'gestionar_empleados': {'icono': '👨‍💼', 'nombre': 'Gestionar Empleados', 'color': Colors.cyan},
    'ver_reportes': {'icono': '📈', 'nombre': 'Ver Reportes', 'color': Colors.amber},
    'ver_auditoria': {'icono': '🔍', 'nombre': 'Ver Auditoría', 'color': Colors.grey},
    'gestionar_usuarios': {'icono': '🔐', 'nombre': 'Gestionar Usuarios', 'color': Colors.redAccent},
    'gestionar_roles': {'icono': '⚙️', 'nombre': 'Gestionar Roles', 'color': Colors.deepOrange},
    'gestionar_sucursales': {'icono': '🏪', 'nombre': 'Gestionar Sucursales', 'color': Colors.indigo},
    'configuracion_global': {'icono': '🛠️', 'nombre': 'Configuración Global', 'color': Colors.pink},
    'acceso_control_center': {'icono': '🎛️', 'nombre': 'Control Center', 'color': Colors.red},
    
    // Permisos del módulo CLIMAS
    'ver_climas_dashboard': {'icono': '❄️', 'nombre': 'Ver Dashboard Climas', 'color': Colors.lightBlue},
    'gestionar_climas_ordenes': {'icono': '📋', 'nombre': 'Gestionar Órdenes Climas', 'color': Colors.blue},
    'gestionar_climas_equipos': {'icono': '🌡️', 'nombre': 'Gestionar Equipos AC', 'color': Colors.cyan},
    'gestionar_climas_clientes': {'icono': '👤', 'nombre': 'Clientes Climas', 'color': Colors.teal},
    'gestionar_climas_tecnicos': {'icono': '🔧', 'nombre': 'Gestionar Técnicos', 'color': Colors.blueGrey},
    
    // Permisos de Técnico Climas
    'climas_tecnico_ver_ordenes': {'icono': '📝', 'nombre': 'Ver Órdenes Asignadas', 'color': Colors.lightBlue},
    'climas_tecnico_ejecutar_ordenes': {'icono': '✅', 'nombre': 'Ejecutar Órdenes', 'color': Colors.green},
    'climas_tecnico_checklist': {'icono': '☑️', 'nombre': 'Completar Checklists', 'color': Colors.teal},
    'climas_tecnico_fotos': {'icono': '📸', 'nombre': 'Subir Fotos', 'color': Colors.purple},
    'climas_tecnico_firmas': {'icono': '✍️', 'nombre': 'Capturar Firmas', 'color': Colors.indigo},
    'climas_tecnico_materiales': {'icono': '🔩', 'nombre': 'Registrar Materiales', 'color': Colors.brown},
    'climas_tecnico_ver_comisiones': {'icono': '💲', 'nombre': 'Ver Mis Comisiones', 'color': Colors.amber},
    
    // Permisos de Cliente Climas
    'climas_cliente_solicitar': {'icono': '📞', 'nombre': 'Solicitar Servicios', 'color': Colors.green},
    'climas_cliente_ver_equipos': {'icono': '🏠', 'nombre': 'Ver Mis Equipos', 'color': Colors.blue},
    'climas_cliente_ver_historial': {'icono': '📜', 'nombre': 'Ver Historial', 'color': Colors.grey},
    'climas_cliente_ver_garantias': {'icono': '🛡️', 'nombre': 'Ver Garantías', 'color': Colors.orange},
    'climas_cliente_mensajes': {'icono': '💬', 'nombre': 'Mensajes', 'color': Colors.teal},
    'climas_cliente_calificar': {'icono': '⭐', 'nombre': 'Calificar Servicios', 'color': Colors.yellow},
    
    // Permisos Admin Climas
    'climas_admin_configuracion': {'icono': '⚙️', 'nombre': 'Config. Climas', 'color': Colors.blueGrey},
    'climas_admin_reportes': {'icono': '📊', 'nombre': 'Reportes Climas', 'color': Colors.deepPurple},
    'climas_admin_zonas': {'icono': '🗺️', 'nombre': 'Gestionar Zonas', 'color': Colors.green},
    'climas_admin_precios': {'icono': '💵', 'nombre': 'Config. Precios', 'color': Colors.amber},
    'climas_admin_comisiones': {'icono': '💰', 'nombre': 'Gestionar Comisiones', 'color': Colors.orange},
    'climas_admin_productos': {'icono': '📦', 'nombre': 'Inventario/Productos', 'color': Colors.brown},
    'climas_admin_calendario': {'icono': '📅', 'nombre': 'Calendario', 'color': Colors.red},
    
    // Permisos módulo PURIFICADORA
    'ver_purificadora_dashboard': {'icono': '💧', 'nombre': 'Dashboard Purificadora', 'color': Colors.lightBlue},
    'gestionar_purificadora_rutas': {'icono': '🚚', 'nombre': 'Gestionar Rutas', 'color': Colors.blue},
    'gestionar_purificadora_clientes': {'icono': '👥', 'nombre': 'Clientes Agua', 'color': Colors.cyan},
    'gestionar_purificadora_pedidos': {'icono': '📦', 'nombre': 'Gestionar Pedidos Agua', 'color': Colors.teal},
    'purificadora_repartidor_ver_rutas': {'icono': '🗺️', 'nombre': 'Ver Rutas Asignadas', 'color': Colors.blue},
    'purificadora_repartidor_entregas': {'icono': '✅', 'nombre': 'Registrar Entregas', 'color': Colors.green},
    'purificadora_cliente_pedir': {'icono': '📞', 'nombre': 'Solicitar Agua', 'color': Colors.lightBlue},
    'purificadora_cliente_historial': {'icono': '📜', 'nombre': 'Historial Pedidos', 'color': Colors.grey},
    
    // Permisos módulo VENTAS/NICE
    'ver_ventas_dashboard': {'icono': '🛒', 'nombre': 'Dashboard Ventas', 'color': Colors.purple},
    'gestionar_ventas_productos': {'icono': '📦', 'nombre': 'Gestionar Productos', 'color': Colors.deepPurple},
    'gestionar_ventas_pedidos': {'icono': '🛍️', 'nombre': 'Gestionar Pedidos', 'color': Colors.pink},
    'gestionar_ventas_clientes': {'icono': '👥', 'nombre': 'Clientes Ventas', 'color': Colors.pinkAccent},
    'vendedor_ver_catalogo': {'icono': '📚', 'nombre': 'Ver Catálogo', 'color': Colors.purple},
    'vendedor_crear_pedidos': {'icono': '🛒', 'nombre': 'Crear Pedidos', 'color': Colors.deepPurple},
    'vendedor_ver_comisiones': {'icono': '💲', 'nombre': 'Ver Comisiones', 'color': Colors.amber},
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _puestoController.dispose();
    _salarioController.dispose();
    _comisionController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final sucursalesRes = await AppSupabase.client.from('sucursales').select();
      final rolesRes = await AppSupabase.client.from('roles').select().neq('nombre', 'superadmin');
      
      setState(() {
        _sucursales = sucursalesRes;
        _roles = rolesRes;
        if (_sucursales.isNotEmpty) _sucursalSeleccionada = _sucursales[0]['id'];
        if (_roles.isNotEmpty) {
          _rolSeleccionado = _roles[0]['id'];
          _cargarPermisosDelRol(_rolSeleccionado!);
        }
      });
    } catch (e) {
      debugPrint("Error cargando datos: $e");
    }
  }

  Future<void> _cargarPermisosDelRol(String rolId) async {
    setState(() => _cargandoPermisos = true);
    try {
      // Cargar permisos asignados a este rol desde la BD
      final permisosRes = await AppSupabase.client
          .from('roles_permisos')
          .select('permiso_id, permisos(clave_permiso, descripcion)')
          .eq('rol_id', rolId);
      
      setState(() {
        _permisosDelRol = List<Map<String, dynamic>>.from(permisosRes);
      });
    } catch (e) {
      debugPrint("Error cargando permisos: $e");
      setState(() => _permisosDelRol = []);
    }
    setState(() => _cargandoPermisos = false);
  }

  Future<void> _guardarEmpleado() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rolSeleccionado == null || _sucursalSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona rol y sucursal'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _loading = true);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final rolNombre = _roles.firstWhere((r) => r['id'] == _rolSeleccionado)['nombre'];
    
    try {
      // 1. CREAR CREDENCIALES EN SUPABASE AUTH (usando Admin invite o signUp)
      // Guardar sesión actual del admin
      final currentSession = AppSupabase.client.auth.currentSession;
      
      final authResponse = await AppSupabase.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre_completo': _nombreController.text.trim(),
          'rol': rolNombre,
        },
      );
      
      if (authResponse.user == null) {
        throw Exception('No se pudo crear la cuenta de autenticación');
      }
      
      final authUserId = authResponse.user!.id;
      
      // Restaurar sesión del admin si cambió
      if (currentSession != null && AppSupabase.client.auth.currentUser?.id != currentSession.user.id) {
        await AppSupabase.client.auth.setSession(currentSession.refreshToken!);
      }
      
      // 2. Usar función RPC para crear el empleado (bypass RLS)
      final resultado = await AppSupabase.client.rpc('crear_empleado_completo', params: {
        'p_auth_user_id': authUserId,
        'p_email': email,
        'p_nombre_completo': _nombreController.text.trim(),
        'p_telefono': _telefonoController.text.trim(),
        'p_puesto': _puestoController.text.trim(),
        'p_salario': double.tryParse(_salarioController.text) ?? 0,
        'p_sucursal_id': _sucursalSeleccionada,
        'p_rol_id': _rolSeleccionado,
        'p_comision_porcentaje': double.tryParse(_comisionController.text) ?? 0,
        'p_comision_tipo': _tipoComision,
      });

      if (resultado is Map && resultado['success'] == true) {
        if (mounted) {
          _mostrarResumenCreacion();
        }
      } else {
        final errorMsg = resultado is Map ? resultado['error'] : 'Error desconocido';
        throw Exception(errorMsg);
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('already registered') || errorMsg.contains('already exists')) {
        errorMsg = 'Este email ya está registrado en el sistema';
      } else if (errorMsg.contains('No tienes permisos')) {
        errorMsg = 'No tienes permisos para crear empleados. Verifica tu rol.';
      }
      debugPrint('Error creando empleado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarResumenCreacion() {
    final rolNombre = _roles.firstWhere((r) => r['id'] == _rolSeleccionado)['nombre'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text("Empleado Creado"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Credenciales de acceso:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.person, "Nombre", _nombreController.text),
            _buildInfoRow(Icons.email, "Email", _emailController.text),
            _buildInfoRow(Icons.lock, "Contraseña", _passwordController.text),
            _buildInfoRow(Icons.badge, "Rol", rolNombre.toUpperCase()),
            const Divider(),
            const Text("⚠️ El empleado deberá cambiar la contraseña en su primer acceso.", 
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text("ENTENDIDO"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Alta de Personal",
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _guardarEmpleado();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: _loading && _currentStep == 2
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentStep == 2 ? 'CREAR EMPLEADO' : 'SIGUIENTE'),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 10),
                    TextButton(onPressed: details.onStepCancel, child: const Text('ATRÁS')),
                  ],
                ],
              ),
            );
          },
          steps: [
            // PASO 1: Datos personales
            Step(
              title: const Text("Datos Personales", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Información básica del empleado"),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: PremiumCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre Completo *', prefixIcon: Icon(Icons.person)),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Corporativo *', prefixIcon: Icon(Icons.email)),
                      validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email válido requerido' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña Temporal *', 
                        helperText: 'El empleado deberá cambiarla al entrar',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                  ],
                ),
              ),
            ),

            // PASO 2: Rol y Permisos
            Step(
              title: const Text("Rol y Permisos", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Qué puede hacer en el sistema"),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _rolSeleccionado,
                      items: _roles.map((r) => DropdownMenuItem(
                        value: r['id'].toString(), 
                        child: Row(
                          children: [
                            Icon(
                              r['nombre'] == 'admin' ? Icons.admin_panel_settings :
                              r['nombre'] == 'operador' ? Icons.badge :
                              r['nombre'] == 'cliente' ? Icons.person : Icons.shield,
                              size: 20,
                              color: r['nombre'] == 'admin' ? Colors.orangeAccent :
                                     r['nombre'] == 'operador' ? Colors.blueAccent : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Text(r['nombre'].toString().toUpperCase()),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _rolSeleccionado = v);
                        if (v != null) _cargarPermisosDelRol(v);
                      },
                      decoration: const InputDecoration(labelText: 'Rol en el Sistema *', prefixIcon: Icon(Icons.admin_panel_settings)),
                    ),
                    const SizedBox(height: 20),
                    
                    // Descripción del rol
                    if (_rolSeleccionado != null)
                      _buildDescripcionRol(),
                    
                    const SizedBox(height: 15),
                    const Text("Permisos incluidos:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    if (_cargandoPermisos)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                    else if (_permisosDelRol.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Este rol no tiene permisos configurados en la base de datos. Contacta al administrador.',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._buildPermisosPreview(),
                  ],
                ),
              ),
            ),

            // PASO 3: Asignación Laboral
            Step(
              title: const Text("Asignación Laboral", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Puesto, sucursal y salario"),
              isActive: _currentStep >= 2,
              content: PremiumCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _sucursalSeleccionada,
                      items: _sucursales.map((s) => DropdownMenuItem(
                        value: s['id'].toString(), 
                        child: Text(s['nombre']),
                      )).toList(),
                      onChanged: (v) => setState(() => _sucursalSeleccionada = v),
                      decoration: const InputDecoration(labelText: 'Sucursal Asignada *', prefixIcon: Icon(Icons.store)),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _puestoController,
                      decoration: const InputDecoration(labelText: 'Título del Puesto', prefixIcon: Icon(Icons.work)),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _salarioController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Salario Mensual', prefixIcon: Icon(Icons.monetization_on)),
                    ),
                    
                    const SizedBox(height: 25),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    
                    // === SECCIÓN DE COMISIONES ===
                    Row(
                      children: [
                        const Icon(Icons.percent, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Sistema de Comisiones",
                          style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Configura si este empleado recibe comisiones por préstamos",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 15),
                    
                    // Porcentaje de comisión
                    TextFormField(
                      controller: _comisionController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Porcentaje de Comisión (%)',
                        prefixIcon: Icon(Icons.attach_money),
                        helperText: 'Ej: 30 = 30% de las ganancias del préstamo',
                      ),
                      onChanged: (v) {
                        final valor = int.tryParse(v) ?? 0;
                        if (valor > 0 && _tipoComision == 'ninguna') {
                          setState(() => _tipoComision = 'al_liquidar');
                        } else if (valor == 0) {
                          setState(() => _tipoComision = 'ninguna');
                        }
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Tipo de pago de comisión
                    const Text("¿Cuándo se paga la comisión?", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    
                    _buildComisionOption(
                      'ninguna',
                      'Sin comisión',
                      'El empleado no recibe comisiones por préstamos',
                      Icons.money_off,
                      Colors.grey,
                    ),
                    _buildComisionOption(
                      'al_liquidar',
                      'Al liquidar préstamo',
                      'Recibe la comisión completa cuando el cliente termina de pagar',
                      Icons.check_circle,
                      Colors.greenAccent,
                    ),
                    _buildComisionOption(
                      'proporcional',
                      'Proporcional por pago',
                      'Recibe parte de la comisión con cada cuota que pague el cliente',
                      Icons.pie_chart,
                      Colors.blueAccent,
                    ),
                    _buildComisionOption(
                      'primer_pago',
                      'Al primer pago',
                      'Recibe la comisión completa cuando el cliente hace el primer pago',
                      Icons.flash_on,
                      Colors.orangeAccent,
                    ),
                    
                    // Ejemplo de cálculo
                    if (_tipoComision != 'ninguna' && (int.tryParse(_comisionController.text) ?? 0) > 0)
                      _buildEjemploComision(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComisionOption(String tipo, String titulo, String descripcion, IconData icon, Color color) {
    final isSelected = _tipoComision == tipo;
    final comision = int.tryParse(_comisionController.text) ?? 0;
    final isDisabled = tipo != 'ninguna' && comision == 0;
    
    return GestureDetector(
      onTap: isDisabled ? null : () => setState(() => _tipoComision = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? color : Colors.white38, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: isDisabled ? Colors.white38 : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    descripcion,
                    style: TextStyle(color: isDisabled ? Colors.white24 : Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEjemploComision() {
    final comision = int.tryParse(_comisionController.text) ?? 0;
    const montoEjemplo = 10000.0;
    const interesEjemplo = 10.0;
    final ganancia = montoEjemplo * interesEjemplo / 100;
    final comisionMonto = ganancia * comision / 100;
    
    String descripcionPago = '';
    switch (_tipoComision) {
      case 'al_liquidar':
        descripcionPago = 'Recibe \$${comisionMonto.toStringAsFixed(0)} cuando el cliente termine de pagar todo el préstamo';
        break;
      case 'proporcional':
        descripcionPago = 'Recibe ~\$${(comisionMonto / 10).toStringAsFixed(0)} por cada cuota (si son 10 cuotas)';
        break;
      case 'primer_pago':
        descripcionPago = 'Recibe \$${comisionMonto.toStringAsFixed(0)} cuando el cliente pague la primera cuota';
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, color: Colors.blueAccent, size: 16),
              SizedBox(width: 6),
              Text("Ejemplo de cálculo:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text("Préstamo: \$${montoEjemplo.toStringAsFixed(0)} al $interesEjemplo% de interés", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text("Ganancia total: \$${ganancia.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text("Comisión del empleado ($comision%): \$${comisionMonto.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Text(descripcionPago, style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  List<Widget> _buildPermisosPreview() {
    // Usar permisos reales cargados de la BD
    return _permisosDelRol.map((p) {
      final permisoData = p['permisos'];
      final clavePermiso = permisoData?['clave_permiso'] ?? 'desconocido';
      final info = _permisosInfo[clavePermiso] ?? {
        'icono': '✅',
        'nombre': clavePermiso.replaceAll('_', ' ').toUpperCase(),
        'color': Colors.greenAccent,
      };
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (info['color'] as Color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(info['icono'], style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                info['nombre'],
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDescripcionRol() {
    // V10.50 - Fix: usar cast seguro en lugar de orElse null
    final rol = _roles.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r?['id'] == _rolSeleccionado, 
      orElse: () => null,
    );
    if (rol == null) return const SizedBox.shrink();
    
    final nombre = rol['nombre'] ?? '';
    String descripcion = rol['descripcion'] ?? '';
    Color color;
    IconData icono;
    
    switch (nombre) {
      case 'admin':
        color = Colors.orangeAccent;
        icono = Icons.admin_panel_settings;
        if (descripcion.isEmpty) descripcion = 'Acceso completo a operaciones del negocio, reportes y gestión de personal';
        break;
      case 'operador':
        color = Colors.blueAccent;
        icono = Icons.badge;
        if (descripcion.isEmpty) descripcion = 'Funciones operativas diarias: cobranza, registro de pagos, atención a clientes';
        break;
      case 'cliente':
        color = Colors.grey;
        icono = Icons.person;
        if (descripcion.isEmpty) descripcion = 'Acceso solo a visualizar su propia información';
        break;
      default:
        color = Colors.teal;
        icono = Icons.shield;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

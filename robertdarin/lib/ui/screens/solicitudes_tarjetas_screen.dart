import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

/// Pantalla para ver las solicitudes recibidas desde las tarjetas QR
class SolicitudesTarjetasScreen extends StatefulWidget {
  const SolicitudesTarjetasScreen({super.key});

  @override
  State<SolicitudesTarjetasScreen> createState() => _SolicitudesTarjetasScreenState();
}

class _SolicitudesTarjetasScreenState extends State<SolicitudesTarjetasScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _solicitudes = [];
  String _filtroEstado = 'todas';
  String _filtroModulo = 'todos';
  late TabController _tabController;
  
  final List<String> _estados = ['todas', 'pendiente', 'contactada', 'convertida', 'rechazada'];
  final List<String> _modulos = ['todos', 'climas', 'prestamos', 'tandas', 'cobranza', 'servicios'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarSolicitudes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarSolicitudes() async {
    try {
      setState(() => _isLoading = true);
      
      // Cargar de tarjetas_servicio_solicitudes (formulario web)
      var query = AppSupabase.client
          .from('tarjetas_servicio_solicitudes')
          .select()
          .order('created_at', ascending: false);
      
      final res = await query;
      
      if (mounted) {
        setState(() {
          _solicitudes = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando solicitudes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _solicitudesFiltradas {
    return _solicitudes.where((s) {
      final estadoOk = _filtroEstado == 'todas' || s['estado'] == _filtroEstado;
      final moduloOk = _filtroModulo == 'todos' || 
          (s['tarjetas_servicio']?['modulo'] ?? s['modulo']) == _filtroModulo;
      return estadoOk && moduloOk;
    }).toList();
  }

  int get _pendientes => _solicitudes.where((s) => s['estado'] == 'pendiente').length;
  int get _contactadas => _solicitudes.where((s) => s['estado'] == 'contactada').length;
  int get _convertidas => _solicitudes.where((s) => s['estado'] == 'convertida').length;

  Future<void> _cambiarEstado(Map<String, dynamic> solicitud, String nuevoEstado) async {
    try {
      await AppSupabase.client
          .from('tarjetas_servicio_solicitudes')
          .update({
            'estado': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', solicitud['id']);
      
      _cargarSolicitudes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado a: $nuevoEstado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error actualizando estado: $e');
    }
  }

  void _llamar(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final url = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _abrirWhatsApp(String? telefono, String? nombre) async {
    if (telefono == null || telefono.isEmpty) return;
    final numero = telefono.startsWith('52') ? telefono : '52$telefono';
    final mensaje = Uri.encodeComponent(
      'Hola ${nombre ?? ''}, gracias por tu interés. Te contactamos respecto a tu solicitud.',
    );
    final url = Uri.parse('https://wa.me/$numero?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // CONVERTIR A CLIENTE - Crear cliente desde solicitud QR
  // ═══════════════════════════════════════════════════════════════════════════════

  Future<void> _convertirACliente(Map<String, dynamic> solicitud) async {
    final tarjeta = solicitud['tarjetas_servicio'] as Map<String, dynamic>?;
    final modulo = (tarjeta?['modulo'] ?? solicitud['modulo'] ?? 'general').toString().toLowerCase();
    
    // Controladores para el formulario
    final nombreCtrl = TextEditingController(text: solicitud['nombre'] ?? '');
    final telefonoCtrl = TextEditingController(text: (solicitud['telefono'] ?? '').replaceAll('+52', ''));
    final emailCtrl = TextEditingController(text: solicitud['email'] ?? '');
    final direccionCtrl = TextEditingController();
    bool crearAcceso = (solicitud['email'] ?? '').toString().isNotEmpty;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convertir a Cliente', 
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                    Text('Módulo: ', 
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getModuloColor(modulo).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_getModuloIcon(modulo)),
                    const SizedBox(width: 4),
                    Text(_capitalize(modulo), 
                      style: TextStyle(color: _getModuloColor(modulo), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput('Nombre completo *', nombreCtrl, Icons.person),
                const SizedBox(height: 12),
                _buildDialogInput('Teléfono *', telefonoCtrl, Icons.phone, 
                  keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogInput('Email', emailCtrl, Icons.email, 
                  keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildDialogInput('Dirección', direccionCtrl, Icons.location_on),
                const SizedBox(height: 16),
                
                // Opción crear acceso
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: crearAcceso,
                        activeColor: const Color(0xFF10B981),
                        onChanged: emailCtrl.text.isNotEmpty 
                          ? (v) => setDialogState(() => crearAcceso = v ?? false)
                          : null,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crear acceso a la app',
                              style: TextStyle(
                                color: emailCtrl.text.isNotEmpty ? Colors.white : Colors.white38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              emailCtrl.text.isNotEmpty 
                                ? 'El cliente podrá ingresar con su email'
                                : 'Requiere email para crear acceso',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info del módulo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getModuloColor(modulo).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getModuloColor(modulo).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _getModuloColor(modulo), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getModuloDescripcion(modulo),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty || telefonoCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre y teléfono son obligatorios')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'nombre': nombreCtrl.text.trim(),
                  'telefono': telefonoCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'direccion': direccionCtrl.text.trim(),
                  'crearAcceso': crearAcceso && emailCtrl.text.trim().isNotEmpty,
                  'modulo': modulo,
                });
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Crear Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
    
    if (result == null) return;
    
    // Crear el cliente
    await _crearClienteDesdeFormulario(solicitud, result);
  }

  Future<void> _crearClienteDesdeFormulario(
    Map<String, dynamic> solicitud, 
    Map<String, dynamic> datos
  ) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
      
      final tarjeta = solicitud['tarjetas_servicio'] as Map<String, dynamic>?;
      final negocioId = tarjeta?['negocio_id'] ?? solicitud['negocio_id'];
      String? usuarioId;
      
      // Si crear acceso, primero crear usuario auth
      if (datos['crearAcceso'] == true && datos['email'].toString().isNotEmpty) {
        try {
          final password = 'Cliente${DateTime.now().year}${DateTime.now().millisecondsSinceEpoch % 1000}';
          // Usar signUp con password temporal (el admin puede resetear después)
          final authResponse = await AppSupabase.client.auth.signUp(
            email: datos['email'],
            password: password,
            data: {'nombre': datos['nombre'], 'rol': 'cliente'},
          );
          
          if (authResponse.user != null) {
            usuarioId = authResponse.user!.id;
            
            // Crear perfil en usuarios
            await AppSupabase.client.from('usuarios').upsert({
              'id': usuarioId,
              'email': datos['email'],
              'nombre_completo': datos['nombre'],
              'telefono': '+52${datos['telefono']}',
            });
            
            // Asignar rol cliente
            final rolCliente = await AppSupabase.client
                .from('roles')
                .select('id')
                .eq('nombre', 'cliente')
                .maybeSingle();
            
            if (rolCliente != null && usuarioId != null) {
              await AppSupabase.client.from('usuarios_roles').insert({
                'usuario_id': usuarioId,
                'rol_id': rolCliente['id'],
              });
            }
          }
        } catch (authError) {
          debugPrint('Error creando auth: $authError');
          // Continuar sin crear usuario auth
        }
      }
      
      // Insertar cliente
      final clienteData = {
        'nombre': datos['nombre'],
        'telefono': '+52${datos['telefono']}',
        'email': datos['email'].toString().isNotEmpty ? datos['email'] : null,
        'direccion': datos['direccion'].toString().isNotEmpty ? datos['direccion'] : null,
        'negocio_id': negocioId,
        'usuario_id': usuarioId,
        'activo': true,
        'origen': 'tarjeta_qr',
        'notas': 'Convertido desde solicitud QR - Módulo: ${datos['modulo']} - Servicio: ${solicitud['servicio_interes'] ?? 'N/A'}',
      };
      
      final clienteRes = await AppSupabase.client
          .from('clientes')
          .insert(clienteData)
          .select()
          .single();
      
      // Actualizar solicitud como convertida
      await AppSupabase.client
          .from('tarjetas_servicio_solicitudes')
          .update({
            'estado': 'atendido',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', solicitud['id']);
      
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      
      // Mostrar éxito y preguntar siguiente acción
      if (mounted) {
        _mostrarExitoYSiguienteAccion(clienteRes, datos['modulo'], solicitud);
      }
      
      // Recargar solicitudes
      _cargarSolicitudes();
      
    } catch (e) {
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      
      debugPrint('Error creando cliente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear cliente: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _mostrarExitoYSiguienteAccion(
    Map<String, dynamic> cliente, 
    String modulo, 
    Map<String, dynamic> solicitud
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('¡Cliente Creado!', 
                style: TextStyle(color: Color(0xFF10B981), fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cliente['nombre'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              cliente['telefono'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '¿Qué deseas hacer ahora?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            
            // Acciones según módulo
            _buildAccionModulo(modulo, cliente, solicitud),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionModulo(String modulo, Map<String, dynamic> cliente, Map<String, dynamic> solicitud) {
    final acciones = <Widget>[];
    
    // Acción ver cliente siempre disponible
    acciones.add(_buildAccionButton(
      icon: Icons.person,
      label: 'Ver Cliente',
      color: const Color(0xFF8B5CF6),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.clientes);
      },
    ));
    
    // Acciones específicas por módulo
    switch (modulo) {
      case 'prestamos':
      case 'finanzas':
        acciones.insert(0, _buildAccionButton(
          icon: Icons.attach_money,
          label: 'Crear Préstamo',
          color: const Color(0xFF10B981),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(
              context, 
              AppRoutes.prestamos,
              arguments: {'clienteId': cliente['id']},
            );
          },
        ));
        break;
        
      case 'tandas':
        acciones.insert(0, _buildAccionButton(
          icon: Icons.group_add,
          label: 'Agregar a Tanda',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.tandas);
          },
        ));
        break;
        
      case 'climas':
        acciones.insert(0, _buildAccionButton(
          icon: Icons.ac_unit,
          label: 'Crear Orden de Servicio',
          color: const Color(0xFF3B82F6),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.climasOrdenNueva);
          },
        ));
        break;
        
      case 'cobranza':
        acciones.insert(0, _buildAccionButton(
          icon: Icons.receipt_long,
          label: 'Registrar Cobro',
          color: const Color(0xFF00D9FF),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.cobrosPendientes);
          },
        ));
        break;
    }
    
    // WhatsApp para confirmar
    acciones.add(_buildAccionButton(
      icon: Icons.chat,
      label: 'WhatsApp',
      color: const Color(0xFF25D366),
      onTap: () {
        Navigator.pop(context);
        _abrirWhatsApp(cliente['telefono'], cliente['nombre']);
      },
    ));
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: acciones,
    );
  }

  Widget _buildAccionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInput(String label, TextEditingController controller, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String _getModuloDescripcion(String modulo) {
    switch (modulo) {
      case 'prestamos':
      case 'finanzas':
        return 'El cliente podrá solicitar préstamos y ver su estado de cuenta desde la app.';
      case 'tandas':
        return 'El cliente podrá participar en tandas y ver sus pagos pendientes.';
      case 'climas':
        return 'El cliente tendrá acceso a solicitar servicios de aire acondicionado.';
      case 'cobranza':
        return 'El cliente podrá ver sus deudas y realizar pagos.';
      default:
        return 'El cliente tendrá acceso básico a la plataforma según los permisos asignados.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Solicitudes QR',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarSolicitudes,
        ),
      ],
      body: Column(
        children: [
          // Stats Cards
          _buildStatsCards(),
          
          // Filtros
          _buildFiltros(),
          
          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _solicitudesFiltradas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarSolicitudes,
                        color: const Color(0xFFD4AF37),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _solicitudesFiltradas.length,
                          itemBuilder: (context, index) {
                            return _buildSolicitudCard(_solicitudesFiltradas[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Pendientes', _pendientes, const Color(0xFFFBBF24), Icons.schedule),
          const SizedBox(width: 12),
          _buildStatCard('Contactadas', _contactadas, const Color(0xFF00D9FF), Icons.call),
          const SizedBox(width: 12),
          _buildStatCard('Convertidas', _convertidas, const Color(0xFF10B981), Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filtroEstado,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _estados.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e == 'todas' ? 'Todos los estados' : _capitalize(e)),
                  )).toList(),
                  onChanged: (v) => setState(() => _filtroEstado = v ?? 'todas'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filtroModulo,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _modulos.map((m) => DropdownMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Text(_getModuloIcon(m), style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(m == 'todos' ? 'Todos' : _capitalize(m)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _filtroModulo = v ?? 'todos'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(Map<String, dynamic> solicitud) {
    final tarjeta = solicitud['tarjetas_servicio'] as Map<String, dynamic>?;
    final estado = solicitud['estado'] ?? 'pendiente';
    final modulo = tarjeta?['modulo'] ?? solicitud['modulo'] ?? 'general';
    final createdAt = DateTime.tryParse(solicitud['created_at'] ?? '') ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getEstadoColor(estado).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header con estado y módulo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getEstadoColor(estado).withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getModuloColor(modulo).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getModuloIcon(modulo),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solicitud['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tarjeta?['nombre_negocio'] ?? _capitalize(modulo),
                        style: TextStyle(
                          color: _getModuloColor(modulo),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildEstadoChip(estado),
              ],
            ),
          ),
          
          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildInfoRow(Icons.phone, solicitud['telefono'] ?? 'Sin teléfono'),
                if (solicitud['email'] != null)
                  _buildInfoRow(Icons.email, solicitud['email']),
                if (solicitud['servicio_interes'] != null)
                  _buildInfoRow(Icons.star, solicitud['servicio_interes']),
                if (solicitud['mensaje'] != null && solicitud['mensaje'].toString().isNotEmpty)
                  _buildInfoRow(Icons.message, solicitud['mensaje'], isMessage: true),
                _buildInfoRow(Icons.access_time, _formatFecha(createdAt)),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Acciones
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              children: [
                // Fila 1: Llamar, WhatsApp, Estado
                Row(
                  children: [
                    // Llamar
                    _buildActionButton(
                      icon: Icons.call,
                      label: 'Llamar',
                      color: const Color(0xFF00D9FF),
                      onTap: () => _llamar(solicitud['telefono']),
                    ),
                    const SizedBox(width: 8),
                    // WhatsApp
                    _buildActionButton(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _abrirWhatsApp(solicitud['telefono'], solicitud['nombre']),
                    ),
                    const SizedBox(width: 8),
                    // Cambiar estado
                    Expanded(
                      child: PopupMenuButton<String>(
                        color: const Color(0xFF16213E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, size: 16, color: Color(0xFFD4AF37)),
                              SizedBox(width: 6),
                              Text('Estado', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          _buildPopupItem('pendiente', 'Pendiente', Icons.schedule, const Color(0xFFFBBF24)),
                          _buildPopupItem('contactada', 'Contactada', Icons.call, const Color(0xFF00D9FF)),
                          _buildPopupItem('convertida', 'Convertida', Icons.check_circle, const Color(0xFF10B981)),
                          _buildPopupItem('rechazada', 'Rechazada', Icons.cancel, const Color(0xFFEF4444)),
                        ],
                        onSelected: (nuevoEstado) => _cambiarEstado(solicitud, nuevoEstado),
                      ),
                    ),
                  ],
                ),
                
                // Fila 2: Botón Convertir a Cliente (solo si no está convertida)
                if (estado != 'convertida') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _convertirACliente(solicitud),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Convertir a Cliente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isMessage = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: isMessage ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMessage ? Colors.white70 : Colors.white,
                fontSize: 13,
                fontStyle: isMessage ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: isMessage ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    final color = _getEstadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _capitalize(estado),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin solicitudes',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las solicitudes de tus tarjetas QR\naparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return const Color(0xFFFBBF24);
      case 'contactada':
        return const Color(0xFF00D9FF);
      case 'convertida':
        return const Color(0xFF10B981);
      case 'rechazada':
        return const Color(0xFFEF4444);
      default:
        return Colors.white60;
    }
  }

  Color _getModuloColor(String modulo) {
    switch (modulo.toLowerCase()) {
      case 'climas':
        return const Color(0xFF3B82F6);
      case 'prestamos':
        return const Color(0xFF10B981);
      case 'tandas':
        return const Color(0xFF8B5CF6);
      case 'cobranza':
        return const Color(0xFF00D9FF);
      case 'finanzas':
        return const Color(0xFFD4AF37);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  String _getModuloIcon(String modulo) {
    switch (modulo.toLowerCase()) {
      case 'climas':
        return '❄️';
      case 'prestamos':
        return '🏦';
      case 'tandas':
        return '👥';
      case 'cobranza':
        return '📋';
      case 'finanzas':
        return '💰';
      case 'servicios':
        return '🔧';
      case 'todos':
        return '📁';
      default:
        return '💼';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatFecha(DateTime fecha) {
    final now = DateTime.now();
    final diff = now.difference(fecha);
    
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} horas';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}

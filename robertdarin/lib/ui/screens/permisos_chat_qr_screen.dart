/// ══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE PERMISOS CHAT QR - Robert Darin Fintech V10.56
/// ══════════════════════════════════════════════════════════════════════════════
/// Permite asignar/quitar permisos de notificaciones de chat QR a empleados
/// por negocio. Los empleados con este permiso recibirán notificaciones
/// cuando los clientes escriban desde el QR web.
/// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class PermisosChatQRScreen extends StatefulWidget {
  final String? negocioId;
  final String? negocioNombre;
  
  const PermisosChatQRScreen({
    super.key,
    this.negocioId,
    this.negocioNombre,
  });

  @override
  State<PermisosChatQRScreen> createState() => _PermisosChatQRScreenState();
}

class _PermisosChatQRScreenState extends State<PermisosChatQRScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _negocios = [];
  List<Map<String, dynamic>> _empleados = [];
  String? _negocioSeleccionado;
  String _negocioNombre = '';

  @override
  void initState() {
    super.initState();
    if (widget.negocioId != null) {
      _negocioSeleccionado = widget.negocioId;
      _negocioNombre = widget.negocioNombre ?? 'Negocio';
      _cargarEmpleados();
    } else {
      _cargarNegocios();
    }
  }

  Future<void> _cargarNegocios() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('negocios')
          .select('id, nombre')
          .eq('activo', true)
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _negocios = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando negocios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEmpleados() async {
    if (_negocioSeleccionado == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Obtener empleados asignados al negocio
      final res = await AppSupabase.client
          .from('empleados_negocios')
          .select('''
            id,
            empleado_id,
            negocio_id,
            auth_uid,
            rol_modulo,
            es_administrador,
            permisos_especificos,
            activo,
            empleados!inner(
              id,
              nombre,
              puesto,
              telefono,
              usuarios!empleados_usuario_id_fkey(
                nombre_completo,
                email
              )
            )
          ''')
          .eq('negocio_id', _negocioSeleccionado!)
          .eq('activo', true)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _empleados = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando empleados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePermisoChatQR(Map<String, dynamic> empleadoNegocio) async {
    final id = empleadoNegocio['id'];
    final permisosActuales = empleadoNegocio['permisos_especificos'] ?? {};
    final chatQRActivo = permisosActuales['chat_qr'] == true;
    
    try {
      // Actualizar permisos
      final nuevosPermisos = Map<String, dynamic>.from(permisosActuales);
      nuevosPermisos['chat_qr'] = !chatQRActivo;
      nuevosPermisos['recibir_notificaciones_qr'] = !chatQRActivo;
      
      await AppSupabase.client
          .from('empleados_negocios')
          .update({'permisos_especificos': nuevosPermisos})
          .eq('id', id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatQRActivo 
                ? '🔕 Permiso de Chat QR desactivado' 
                : '🔔 Permiso de Chat QR activado'),
            backgroundColor: chatQRActivo ? Colors.orange : Colors.green,
          ),
        );
        _cargarEmpleados();
      }
    } catch (e) {
      debugPrint('Error actualizando permiso: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleEsAdministrador(Map<String, dynamic> empleadoNegocio) async {
    final id = empleadoNegocio['id'];
    final esAdmin = empleadoNegocio['es_administrador'] == true;
    
    try {
      await AppSupabase.client
          .from('empleados_negocios')
          .update({'es_administrador': !esAdmin})
          .eq('id', id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esAdmin 
                ? '👤 Ya no es administrador del negocio' 
                : '👑 Ahora es administrador del negocio'),
            backgroundColor: esAdmin ? Colors.orange : Colors.green,
          ),
        );
        _cargarEmpleados();
      }
    } catch (e) {
      debugPrint('Error actualizando admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🔐 Permisos Chat QR',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_negocioSeleccionado == null) {
      return _buildSelectorNegocios();
    }
    return _buildListaEmpleados();
  }

  Widget _buildSelectorNegocios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Selecciona un negocio:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _negocios.length,
            itemBuilder: (context, index) {
              final negocio = _negocios[index];
              return Card(
                color: const Color(0xFF1A1A2E),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00D9FF).withOpacity(0.2),
                    child: const Icon(Icons.business, color: Color(0xFF00D9FF)),
                  ),
                  title: Text(
                    negocio['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    setState(() {
                      _negocioSeleccionado = negocio['id'];
                      _negocioNombre = negocio['nombre'] ?? '';
                    });
                    _cargarEmpleados();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2, color: Color(0xFF00D9FF), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permisos de Chat QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Los empleados con este permiso recibirán notificaciones '
            'cuando un cliente escriba desde el código QR de las tarjetas web.\n\n'
            '• 👑 Administradores: reciben TODAS las notificaciones\n'
            '• 💬 Chat QR: recibe notificaciones del chat web',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaEmpleados() {
    return Column(
      children: [
        // Header con botón de regreso
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _negocioSeleccionado = null;
                    _empleados = [];
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _negocioNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_empleados.length} empleados asignados',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00D9FF)),
                onPressed: _cargarEmpleados,
              ),
            ],
          ),
        ),
        
        // Lista de empleados
        Expanded(
          child: _empleados.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _empleados.length,
                  itemBuilder: (context, index) => _buildEmpleadoCard(_empleados[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay empleados asignados\na este negocio',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Asignar empleados'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpleadoCard(Map<String, dynamic> empleadoNegocio) {
    final empleado = empleadoNegocio['empleados'] ?? {};
    final usuario = empleado['usuarios'] ?? {};
    final nombre = usuario['nombre_completo'] ?? empleado['nombre'] ?? 'Sin nombre';
    final email = usuario['email'] ?? '';
    final puesto = empleado['puesto'] ?? empleadoNegocio['rol_modulo'] ?? 'Sin puesto';
    final esAdmin = empleadoNegocio['es_administrador'] == true;
    final permisos = empleadoNegocio['permisos_especificos'] ?? {};
    final chatQRActivo = permisos['chat_qr'] == true;
    
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esAdmin 
              ? const Color(0xFFFFD700).withOpacity(0.3) 
              : Colors.transparent,
          width: esAdmin ? 2 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del empleado
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: esAdmin 
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : const Color(0xFF8B5CF6).withOpacity(0.2),
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: esAdmin ? const Color(0xFFFFD700) : const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (esAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Text(
                        puesto,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(color: Colors.white12, height: 24),
            
            // Switches de permisos
            _buildPermisoSwitch(
              icon: Icons.admin_panel_settings,
              titulo: 'Administrador del Negocio',
              descripcion: 'Acceso completo y todas las notificaciones',
              activo: esAdmin,
              onChanged: () => _toggleEsAdministrador(empleadoNegocio),
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(height: 12),
            _buildPermisoSwitch(
              icon: Icons.qr_code_2,
              titulo: 'Notificaciones Chat QR',
              descripcion: 'Recibe mensajes de clientes desde el QR web',
              activo: chatQRActivo || esAdmin, // Si es admin, siempre activo
              onChanged: esAdmin ? null : () => _togglePermisoChatQR(empleadoNegocio),
              color: const Color(0xFF00D9FF),
              disabled: esAdmin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermisoSwitch({
    required IconData icon,
    required String titulo,
    required String descripcion,
    required bool activo,
    required VoidCallback? onChanged,
    required Color color,
    bool disabled = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(activo ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color.withOpacity(activo ? 1 : 0.5), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: Colors.white.withOpacity(activo ? 1 : 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                disabled ? 'Incluido como administrador' : descripcion,
                style: TextStyle(
                  color: Colors.white.withOpacity(disabled ? 0.3 : 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: activo,
          onChanged: disabled ? null : (_) => onChanged?.call(),
          activeColor: color,
          activeTrackColor: color.withOpacity(0.3),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withOpacity(0.3),
        ),
      ],
    );
  }
}

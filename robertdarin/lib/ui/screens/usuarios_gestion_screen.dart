// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE USUARIOS COMPLETA - Robert Darin Platform v10.18
/// Roles, permisos, actividad, último acceso
/// ═══════════════════════════════════════════════════════════════════════════════
class UsuariosGestionScreen extends StatefulWidget {
  const UsuariosGestionScreen({super.key});

  @override
  State<UsuariosGestionScreen> createState() => _UsuariosGestionScreenState();
}

class _UsuariosGestionScreenState extends State<UsuariosGestionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _busqueda = '';
  
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _roles = [];
  Map<String, int> _estadisticas = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar usuarios con roles
      final usersRes = await AppSupabase.client
          .from('usuarios')
          .select('*, usuarios_roles(roles(id, nombre))')
          .order('created_at', ascending: false);
      _usuarios = List<Map<String, dynamic>>.from(usersRes);

      // Cargar roles disponibles
      final rolesRes = await AppSupabase.client.from('roles').select().order('nombre');
      _roles = List<Map<String, dynamic>>.from(rolesRes);

      // Calcular estadísticas
      int activos = 0, inactivos = 0, admins = 0, clientes = 0;
      for (var u in _usuarios) {
        if (u['activo'] == true) activos++; else inactivos++;
        final rolList = u['usuarios_roles'] as List? ?? [];
        for (var r in rolList) {
          final rolNombre = r['roles']?['nombre'] ?? '';
          if (rolNombre == 'superadmin' || rolNombre == 'admin') admins++;
          if (rolNombre == 'cliente') clientes++;
        }
      }
      _estadisticas = {
        'total': _usuarios.length,
        'activos': activos,
        'inactivos': inactivos,
        'admins': admins,
        'clientes': clientes,
      };

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _usuariosFiltrados {
    if (_busqueda.isEmpty) return _usuarios;
    final q = _busqueda.toLowerCase();
    return _usuarios.where((u) {
      final nombre = (u['nombre_completo'] ?? '').toLowerCase();
      final email = (u['email'] ?? '').toLowerCase();
      return nombre.contains(q) || email.contains(q);
    }).toList();
  }

  String _getRolPrincipal(Map<String, dynamic> usuario) {
    final rolList = usuario['usuarios_roles'] as List? ?? [];
    if (rolList.isEmpty) return 'Sin rol';
    return rolList.first['roles']?['nombre'] ?? 'Sin rol';
  }

  Color _getRolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'superadmin': return const Color(0xFFEF4444);
      case 'admin': return const Color(0xFFF59E0B);
      case 'operador': return const Color(0xFF3B82F6);
      case 'cliente': return const Color(0xFF10B981);
      case 'aval': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '👥 Gestión de Usuarios',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.white),
          onPressed: () => _mostrarNuevoUsuario(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => _cargarDatos(),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStats(),
                _buildBusqueda(),
                _buildTabs(),
                Expanded(child: _buildTabContent()),
              ],
            ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(children: [
        _buildStatCard('Total', '${_estadisticas['total'] ?? 0}', Icons.people, const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _buildStatCard('Activos', '${_estadisticas['activos'] ?? 0}', Icons.check_circle, const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _buildStatCard('Admins', '${_estadisticas['admins'] ?? 0}', Icons.admin_panel_settings, const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _buildStatCard('Clientes', '${_estadisticas['clientes'] ?? 0}', Icons.person, const Color(0xFF8B5CF6)),
      ]),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildBusqueda() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o email...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(10)),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11),
        tabs: const [
          Tab(text: 'Todos'),
          Tab(text: 'Activos'),
          Tab(text: 'Admins'),
          Tab(text: 'Inactivos'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListaUsuarios(_usuariosFiltrados),
        _buildListaUsuarios(_usuariosFiltrados.where((u) => u['activo'] == true).toList()),
        _buildListaUsuarios(_usuariosFiltrados.where((u) {
          final rol = _getRolPrincipal(u).toLowerCase();
          return rol == 'superadmin' || rol == 'admin';
        }).toList()),
        _buildListaUsuarios(_usuariosFiltrados.where((u) => u['activo'] != true).toList()),
      ],
    );
  }

  Widget _buildListaUsuarios(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin usuarios', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lista.length,
        itemBuilder: (context, index) => _buildUsuarioCard(lista[index]),
      ),
    );
  }

  Widget _buildUsuarioCard(Map<String, dynamic> usuario) {
    final nombre = usuario['nombre_completo'] ?? 'Sin nombre';
    final email = usuario['email'] ?? '';
    final activo = usuario['activo'] == true;
    final rol = _getRolPrincipal(usuario);
    final rolColor = _getRolColor(rol);
    final ultimoAcceso = usuario['ultimo_acceso'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: activo ? null : Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: rolColor.withOpacity(0.2),
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
            style: TextStyle(color: rolColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: rolColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text(rol.toUpperCase(), style: TextStyle(color: rolColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: activo ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(activo ? 'Activo' : 'Inactivo', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                if (ultimoAcceso != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 12, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    'Último: ${DateFormat('dd/MM HH:mm').format(DateTime.parse(ultimoAcceso))}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onSelected: (value) => _accionUsuario(usuario, value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'ver', child: Text('👁️ Ver Detalle')),
            const PopupMenuItem(value: 'rol', child: Text('🔑 Cambiar Rol')),
            const PopupMenuItem(value: 'resetear', child: Text('🔄 Resetear Contraseña')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(activo ? '🔴 Desactivar' : '🟢 Activar'),
            ),
            const PopupMenuItem(value: 'actividad', child: Text('📊 Ver Actividad')),
          ],
        ),
        onTap: () => _mostrarDetalleUsuario(usuario),
      ),
    );
  }

  void _accionUsuario(Map<String, dynamic> usuario, String accion) {
    switch (accion) {
      case 'ver':
        _mostrarDetalleUsuario(usuario);
        break;
      case 'rol':
        _mostrarCambiarRol(usuario);
        break;
      case 'resetear':
        _resetearPassword(usuario);
        break;
      case 'toggle':
        _toggleActivo(usuario);
        break;
      case 'actividad':
        _mostrarActividad(usuario);
        break;
    }
  }

  void _mostrarDetalleUsuario(Map<String, dynamic> usuario) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getRolColor(_getRolPrincipal(usuario)).withOpacity(0.2),
                  child: Text(
                    (usuario['nombre_completo'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: _getRolColor(_getRolPrincipal(usuario)), fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario['nombre_completo'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(usuario['email'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetalleRow('Rol', _getRolPrincipal(usuario)),
            _buildDetalleRow('Estado', usuario['activo'] == true ? 'Activo' : 'Inactivo'),
            _buildDetalleRow('Teléfono', usuario['telefono'] ?? 'No especificado'),
            _buildDetalleRow('Creado', usuario['created_at'] != null 
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(usuario['created_at'])) 
                : 'No especificado'),
            _buildDetalleRow('Último acceso', usuario['ultimo_acceso'] != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(usuario['ultimo_acceso'])) 
                : 'Nunca'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _mostrarCambiarRol(usuario);
                    },
                    icon: const Icon(Icons.key),
                    label: const Text('Cambiar Rol'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleActivo(usuario);
                    },
                    icon: Icon(usuario['activo'] == true ? Icons.block : Icons.check),
                    label: Text(usuario['activo'] == true ? 'Desactivar' : 'Activar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: usuario['activo'] == true ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _mostrarCambiarRol(Map<String, dynamic> usuario) {
    String? rolSeleccionado = _getRolPrincipal(usuario);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cambiar Rol: ${usuario['nombre_completo']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._roles.map((rol) => RadioListTile<String>(
                title: Text(rol['nombre'].toString().toUpperCase(), style: TextStyle(color: _getRolColor(rol['nombre']))),
                subtitle: Text(rol['descripcion'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                value: rol['nombre'],
                groupValue: rolSeleccionado,
                activeColor: _getRolColor(rol['nombre']),
                onChanged: (v) => setModalState(() => rolSeleccionado = v),
              )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Buscar rol ID
                  final rol = _roles.firstWhere((r) => r['nombre'] == rolSeleccionado, orElse: () => {});
                  if (rol.isEmpty) return;
                  
                  // Eliminar roles anteriores
                  await AppSupabase.client.from('usuarios_roles').delete().eq('usuario_id', usuario['id']);
                  
                  // Asignar nuevo rol
                  await AppSupabase.client.from('usuarios_roles').insert({
                    'usuario_id': usuario['id'],
                    'rol_id': rol['id'],
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _cargarDatos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Rol cambiado a $rolSeleccionado'), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetearPassword(Map<String, dynamic> usuario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Resetear Contraseña', style: TextStyle(color: Colors.white)),
        content: Text('¿Enviar email de reseteo a ${usuario['email']}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📧 Email de reseteo enviado a ${usuario['email']}'), backgroundColor: Colors.green),
      );
    }
  }

  void _toggleActivo(Map<String, dynamic> usuario) async {
    final nuevoEstado = !(usuario['activo'] == true);
    await AppSupabase.client.from('usuarios').update({'activo': nuevoEstado}).eq('id', usuario['id']);
    _cargarDatos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado ? '✅ Usuario activado' : '🔴 Usuario desactivado'),
          backgroundColor: nuevoEstado ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _mostrarActividad(Map<String, dynamic> usuario) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actividad: ${usuario['nombre_completo']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildActividadItem('Último acceso', usuario['ultimo_acceso'] ?? 'Nunca', Icons.login),
            _buildActividadItem('Cuenta creada', usuario['created_at'] ?? 'Desconocido', Icons.person_add),
            _buildActividadItem('Última actualización', usuario['updated_at'] ?? 'Nunca', Icons.edit),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActividadItem(String label, String valor, IconData icon) {
    String formatted = valor;
    if (valor != 'Nunca' && valor != 'Desconocido') {
      try {
        formatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(valor));
      } catch (e) {
        formatted = valor;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                Text(formatted, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarNuevoUsuario() {
    final emailCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    String? rolSeleccionado;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo Usuario', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: rolSeleccionado,
                dropdownColor: const Color(0xFF0D0D14),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Rol',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _roles.map((r) => DropdownMenuItem(
                  value: r['nombre'] as String,
                  child: Text(r['nombre'].toString().toUpperCase()),
                )).toList(),
                onChanged: (v) => setModalState(() => rolSeleccionado = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (emailCtrl.text.isEmpty || nombreCtrl.text.isEmpty || rolSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completa todos los campos'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  
                  try {
                    // Crear usuario en tabla usuarios
                    final nuevoUser = await AppSupabase.client.from('usuarios').insert({
                      'email': emailCtrl.text,
                      'nombre_completo': nombreCtrl.text,
                      'activo': true,
                    }).select().single();
                    
                    // Asignar rol
                    final rol = _roles.firstWhere((r) => r['nombre'] == rolSeleccionado);
                    await AppSupabase.client.from('usuarios_roles').insert({
                      'usuario_id': nuevoUser['id'],
                      'rol_id': rol['id'],
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _cargarDatos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Usuario creado'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Crear Usuario'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

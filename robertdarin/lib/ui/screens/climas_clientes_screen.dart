// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_models.dart';
import '../../services/auth_creacion_service.dart'; // V10.22 Auth para clientes

/// ═══════════════════════════════════════════════════════════════════════════════
/// CLIENTES DEL MÓDULO CLIMAS - CRUD Completo
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasClientesScreen extends StatefulWidget {
  const ClimasClientesScreen({super.key});
  @override
  State<ClimasClientesScreen> createState() => _ClimasClientesScreenState();
}

class _ClimasClientesScreenState extends State<ClimasClientesScreen> {
  bool _isLoading = true;
  List<ClimasClienteModel> _clientes = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final res = await AppSupabase.client
          .from('climas_clientes')
          .select()
          .order('nombre');
      if (mounted) {
        setState(() {
          _clientes = (res as List).map((e) => ClimasClienteModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ClimasClienteModel> get _clientesFiltrados {
    if (_searchQuery.isEmpty) return _clientes;
    final q = _searchQuery.toLowerCase();
    return _clientes.where((c) =>
        c.nombre.toLowerCase().contains(q) ||
        (c.telefono?.toLowerCase().contains(q) ?? false) ||
        (c.email?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Clientes Climas',
      body: Column(
        children: [
          _buildBusqueda(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clientesFiltrados.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _cargarClientes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clientesFiltrados.length,
                          itemBuilder: (context, index) => _buildClienteCard(_clientesFiltrados[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF00B4D8),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBusqueda() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar cliente...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00B4D8)),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No hay clientes registrados' : 'Sin resultados',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _mostrarFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(ClimasClienteModel cliente) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cliente.activo ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00B4D8).withOpacity(0.2),
          child: Text(
            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cliente.nombre,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cliente.tipoCliente == 'empresa'
                    ? const Color(0xFF8B5CF6).withOpacity(0.2)
                    : const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cliente.tipoCliente == 'empresa' ? 'Empresa' : 'Particular',
                style: TextStyle(
                  color: cliente.tipoCliente == 'empresa' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (cliente.telefono != null)
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(cliente.telefono!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            if (cliente.email != null)
              Row(
                children: [
                  Icon(Icons.email, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(cliente.email!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            if (cliente.direccion != null)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cliente.direccion!,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
          color: const Color(0xFF1A1A2E),
          onSelected: (value) {
            if (value == 'edit') _mostrarFormulario(cliente: cliente);
            if (value == 'delete') _confirmarEliminar(cliente);
            if (value == 'toggle') _toggleActivo(cliente);
            if (value == 'detalle') Navigator.pushNamed(context, AppRoutes.climasClienteDetalle, arguments: cliente.id);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'detalle', child: Text('Ver Detalle', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
            PopupMenuItem(
              value: 'toggle',
              child: Text(cliente.activo ? 'Desactivar' : 'Activar', style: const TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => Navigator.pushNamed(context, AppRoutes.climasClienteDetalle, arguments: cliente.id),
      ),
    );
  }

  Future<void> _mostrarFormulario({ClimasClienteModel? cliente}) async {
    final nombreController = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoController = TextEditingController(text: cliente?.telefono ?? '');
    final emailController = TextEditingController(text: cliente?.email ?? '');
    final direccionController = TextEditingController(text: cliente?.direccion ?? '');
    final rfcController = TextEditingController(text: cliente?.rfc ?? '');
    final passwordController = TextEditingController(); // V10.22 Auth
    String tipoCliente = cliente?.tipoCliente ?? 'particular';
    bool crearCuenta = false; // V10.22
    bool guardando = false; // V10.22

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            cliente == null ? 'Nuevo Cliente' : 'Editar Cliente',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nombreController, 'Nombre *', Icons.person),
                const SizedBox(height: 12),
                _buildTextField(telefonoController, 'Teléfono', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(direccionController, 'Dirección', Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField(rfcController, 'RFC (opcional)', Icons.badge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTipoBtn('Particular', tipoCliente == 'particular', () {
                        setDialogState(() => tipoCliente = 'particular');
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTipoBtn('Empresa', tipoCliente == 'empresa', () {
                        setDialogState(() => tipoCliente = 'empresa');
                      }),
                    ),
                  ],
                ),
                // V10.22: Sección de acceso a la app (solo para nuevos)
                if (cliente == null) ...[
                  CamposAuthWidget(
                    emailController: emailController,
                    passwordController: passwordController,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setDialogState(() => crearCuenta = v),
                    tipoUsuario: 'cliente_climas',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: guardando ? null : () async {
                if (nombreController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                
                // V10.22: Validar si se va a crear cuenta
                if (crearCuenta && cliente == null) {
                  if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un email válido'), backgroundColor: Colors.orange));
                    return;
                  }
                  if (passwordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange));
                    return;
                  }
                }
                
                setDialogState(() => guardando = true);
                
                String? authUid;
                
                // V10.22: Crear cuenta de auth si se solicitó
                if (crearCuenta && cliente == null) {
                  authUid = await AuthCreacionService.crearCuentaAuth(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    nombreCompleto: nombreController.text.trim(),
                    tipoUsuario: 'cliente_climas',
                    rol: 'cliente',
                  );
                  
                  if (authUid == null) {
                    setDialogState(() => guardando = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al crear cuenta. El email puede estar en uso.'), backgroundColor: Colors.red),
                      );
                    }
                    return;
                  }
                }
                
                final data = {
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim().isEmpty ? null : telefonoController.text.trim(),
                  'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  'direccion': direccionController.text.trim().isEmpty ? null : direccionController.text.trim(),
                  'rfc': rfcController.text.trim().isEmpty ? null : rfcController.text.trim(),
                  'tipo_cliente': tipoCliente,
                  if (crearCuenta && authUid != null) 'auth_uid': authUid, // V10.22
                };

                try {
                  if (cliente == null) {
                    await AppSupabase.client.from('climas_clientes').insert(data);
                  } else {
                    await AppSupabase.client.from('climas_clientes').update(data).eq('id', cliente.id);
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setDialogState(() => guardando = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)),
              child: guardando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(cliente == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _cargarClientes();
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF00B4D8)),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTipoBtn(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00B4D8).withOpacity(0.2) : const Color(0xFF0D0D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF00B4D8) : Colors.transparent),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: selected ? const Color(0xFF00B4D8) : Colors.white54)),
        ),
      ),
    );
  }

  Future<void> _toggleActivo(ClimasClienteModel cliente) async {
    try {
      await AppSupabase.client
          .from('climas_clientes')
          .update({'activo': !cliente.activo})
          .eq('id', cliente.id);
      _cargarClientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmarEliminar(ClimasClienteModel cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${cliente.nombre}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AppSupabase.client.from('climas_clientes').delete().eq('id', cliente.id);
        _cargarClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

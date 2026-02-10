// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/purificadora_models.dart';
import '../../services/auth_creacion_service.dart'; // V10.22 Auth para clientes

/// ═══════════════════════════════════════════════════════════════════════════════
/// CLIENTES DEL MÓDULO PURIFICADORA - CRUD Completo
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraClientesScreen extends StatefulWidget {
  const PurificadoraClientesScreen({super.key});
  @override
  State<PurificadoraClientesScreen> createState() => _PurificadoraClientesScreenState();
}

class _PurificadoraClientesScreenState extends State<PurificadoraClientesScreen> {
  bool _isLoading = true;
  List<PurificadoraClienteModel> _clientes = [];
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
          .from('purificadora_clientes')
          .select()
          .order('nombre');
      if (mounted) {
        setState(() {
          _clientes = (res as List).map((e) => PurificadoraClienteModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<PurificadoraClienteModel> get _clientesFiltrados {
    if (_searchQuery.isEmpty) return _clientes;
    final q = _searchQuery.toLowerCase();
    return _clientes.where((c) =>
        c.nombre.toLowerCase().contains(q) ||
        c.direccion.toLowerCase().contains(q) ||
        (c.colonia?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Clientes Purificadora',
      body: Column(
        children: [
          _buildBusqueda(),
          _buildResumen(),
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
        backgroundColor: const Color(0xFF06B6D4),
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
          hintText: 'Buscar cliente o dirección...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF06B6D4)),
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

  Widget _buildResumen() {
    final totalGarrafones = _clientes.fold(0, (sum, c) => sum + c.garrafonesEnPrestamo);
    final conSaldo = _clientes.where((c) => c.saldoPendiente > 0).length;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Clientes', '${_clientes.length}', const Color(0xFF06B6D4)),
          _buildMiniStat('Garrafones', '$totalGarrafones', const Color(0xFF22C55E)),
          _buildMiniStat('Con Saldo', '$conSaldo', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
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
        ],
      ),
    );
  }

  Widget _buildClienteCard(PurificadoraClienteModel cliente) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cliente.saldoPendiente > 0
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF06B6D4), size: 20),
              Text(
                '${cliente.garrafonesEnPrestamo}',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getColorTipo(cliente.tipoCliente).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cliente.tipoDisplay,
                style: TextStyle(color: _getColorTipo(cliente.tipoCliente), fontSize: 9),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    cliente.direccion,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (cliente.colonia != null) ...[
              const SizedBox(height: 2),
              Text(
                'Col. ${cliente.colonia}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (cliente.telefono != null) ...[
                  Icon(Icons.phone, size: 12, color: Colors.white.withOpacity(0.4)),
                  Text(' ${cliente.telefono}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.4)),
                Text(
                  ' ${cliente.frecuenciaEntrega}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (cliente.saldoPendiente > 0)
              Text(
                '\$${cliente.saldoPendiente.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5), size: 20),
              color: const Color(0xFF1A1A2E),
              onSelected: (value) {
                if (value == 'edit') _mostrarFormulario(cliente: cliente);
                if (value == 'delete') _confirmarEliminar(cliente);
                if (value == 'detail') {
                  Navigator.pushNamed(context, '/purificadora/cliente/detalle', arguments: cliente.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.visibility, color: Color(0xFF06B6D4), size: 18), SizedBox(width: 8), Text('Ver Detalle', style: TextStyle(color: Colors.white))])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Color(0xFF22C55E), size: 18), SizedBox(width: 8), Text('Editar', style: TextStyle(color: Colors.white))])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Color(0xFFEF4444), size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.pushNamed(context, '/purificadora/cliente/detalle', arguments: cliente.id),
      ),
    );
  }

  Color _getColorTipo(String tipo) {
    switch (tipo) {
      case 'casa': return const Color(0xFF10B981);
      case 'negocio': return const Color(0xFF8B5CF6);
      case 'oficina': return const Color(0xFF06B6D4);
      case 'escuela': return const Color(0xFFF59E0B);
      case 'restaurante': return const Color(0xFFEC4899);
      default: return Colors.white54;
    }
  }

  Future<void> _mostrarFormulario({PurificadoraClienteModel? cliente}) async {
    final nombreController = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoController = TextEditingController(text: cliente?.telefono ?? '');
    final direccionController = TextEditingController(text: cliente?.direccion ?? '');
    final coloniaController = TextEditingController(text: cliente?.colonia ?? '');
    final referenciasController = TextEditingController(text: cliente?.referencias ?? '');
    final garrafonesController = TextEditingController(text: cliente?.garrafonesEnPrestamo.toString() ?? '0');
    final emailController = TextEditingController(); // V10.22 Auth
    final passwordController = TextEditingController(); // V10.22 Auth
    String tipoCliente = cliente?.tipoCliente ?? 'casa';
    String frecuencia = cliente?.frecuenciaEntrega ?? 'semanal';
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(nombreController, 'Nombre *', Icons.person),
                const SizedBox(height: 12),
                _buildTextField(telefonoController, 'Teléfono', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(direccionController, 'Dirección *', Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField(coloniaController, 'Colonia', Icons.map),
                const SizedBox(height: 12),
                _buildTextField(referenciasController, 'Referencias', Icons.info_outline),
                const SizedBox(height: 12),
                _buildTextField(garrafonesController, 'Garrafones en préstamo', Icons.water_drop, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                const Text('Tipo de Cliente', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('🏠 Casa', tipoCliente == 'casa', () => setDialogState(() => tipoCliente = 'casa')),
                    _buildChip('🏪 Negocio', tipoCliente == 'negocio', () => setDialogState(() => tipoCliente = 'negocio')),
                    _buildChip('🏢 Oficina', tipoCliente == 'oficina', () => setDialogState(() => tipoCliente = 'oficina')),
                    _buildChip('🏫 Escuela', tipoCliente == 'escuela', () => setDialogState(() => tipoCliente = 'escuela')),
                    _buildChip('🍽️ Restaurant', tipoCliente == 'restaurante', () => setDialogState(() => tipoCliente = 'restaurante')),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Frecuencia de Entrega', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildFreqBtn('Diaria', frecuencia == 'diaria', () => setDialogState(() => frecuencia = 'diaria'))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFreqBtn('Semanal', frecuencia == 'semanal', () => setDialogState(() => frecuencia = 'semanal'))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFreqBtn('Quincenal', frecuencia == 'quincenal', () => setDialogState(() => frecuencia = 'quincenal'))),
                  ],
                ),
                // V10.22: Sección de acceso a la app (solo para nuevos)
                if (cliente == null) ...[
                  CamposAuthWidget(
                    emailController: emailController,
                    passwordController: passwordController,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setDialogState(() => crearCuenta = v),
                    tipoUsuario: 'cliente_purificadora',
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
                if (nombreController.text.trim().isEmpty || direccionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre y dirección son obligatorios')),
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
                    tipoUsuario: 'cliente_purificadora',
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
                  'direccion': direccionController.text.trim(),
                  'colonia': coloniaController.text.trim().isEmpty ? null : coloniaController.text.trim(),
                  'referencias': referenciasController.text.trim().isEmpty ? null : referenciasController.text.trim(),
                  'garrafones_en_prestamo': int.tryParse(garrafonesController.text) ?? 0,
                  'tipo_cliente': tipoCliente,
                  'frecuencia_entrega': frecuencia,
                  if (crearCuenta && emailController.text.isNotEmpty) 'email': emailController.text.trim(), // V10.22
                  if (crearCuenta && authUid != null) 'auth_uid': authUid, // V10.22
                };

                try {
                  if (cliente == null) {
                    await AppSupabase.client.from('purificadora_clientes').insert(data);
                  } else {
                    await AppSupabase.client.from('purificadora_clientes').update(data).eq('id', cliente.id);
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setDialogState(() => guardando = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
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
        prefixIcon: Icon(icon, color: const Color(0xFF06B6D4)),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF0D0D14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF06B6D4) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFF06B6D4) : Colors.white54, fontSize: 12)),
      ),
    );
  }

  Widget _buildFreqBtn(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF0D0D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF06B6D4) : Colors.transparent),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: selected ? const Color(0xFF06B6D4) : Colors.white54, fontSize: 11)),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(PurificadoraClienteModel cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${cliente.nombre}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
        await AppSupabase.client.from('purificadora_clientes').delete().eq('id', cliente.id);
        _cargarClientes();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

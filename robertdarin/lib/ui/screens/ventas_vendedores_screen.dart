// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/ventas_models.dart';
import '../../services/auth_creacion_service.dart'; // V10.22 Auth

/// ═══════════════════════════════════════════════════════════════════════════════
/// VENDEDORES DEL MÓDULO VENTAS - CRUD Completo V10.22
/// Con capacidad de crear acceso a la app
/// ═══════════════════════════════════════════════════════════════════════════════
class VentasVendedoresScreen extends StatefulWidget {
  const VentasVendedoresScreen({super.key});
  @override
  State<VentasVendedoresScreen> createState() => _VentasVendedoresScreenState();
}

class _VentasVendedoresScreenState extends State<VentasVendedoresScreen> {
  bool _isLoading = true;
  List<VentasVendedorModel> _vendedores = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarVendedores();
  }

  Future<void> _cargarVendedores() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_vendedores')
          .select()
          .order('nombre');
      if (mounted) {
        setState(() {
          _vendedores = (res as List).map((e) => VentasVendedorModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<VentasVendedorModel> get _vendedoresFiltrados {
    if (_searchQuery.isEmpty) return _vendedores;
    final q = _searchQuery.toLowerCase();
    return _vendedores.where((v) =>
        v.nombre.toLowerCase().contains(q) ||
        (v.telefono?.toLowerCase().contains(q) ?? false) ||
        (v.email?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Vendedores',
      body: Column(
        children: [
          _buildBusqueda(),
          _buildResumen(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vendedoresFiltrados.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _cargarVendedores,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _vendedoresFiltrados.length,
                          itemBuilder: (context, index) => _buildVendedorCard(_vendedoresFiltrados[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF22C55E),
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
          hintText: 'Buscar vendedor...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF22C55E)),
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
    final activos = _vendedores.where((v) => v.activo).length;
    final totalVentas = _vendedores.fold(0.0, (sum, v) => sum + v.ventasMes);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF22C55E).withOpacity(0.2), const Color(0xFF10B981).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumenItem('$activos', 'Activos', Icons.badge),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildResumenItem('\$${totalVentas.toStringAsFixed(0)}', 'Ventas Mes', Icons.trending_up),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildResumenItem('${_vendedores.length}', 'Total', Icons.people),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String valor, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF22C55E), size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No hay vendedores', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Vendedor'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
          ),
        ],
      ),
    );
  }

  Widget _buildVendedorCard(VentasVendedorModel vendedor) {
    final progreso = vendedor.cumplimientoMeta;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: vendedor.activo ? null : Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: vendedor.activo ? const Color(0xFF22C55E).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          child: Icon(Icons.badge, color: vendedor.activo ? const Color(0xFF22C55E) : Colors.grey),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                vendedor.nombre,
                style: TextStyle(
                  color: vendedor.activo ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!vendedor.activo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Inactivo', style: TextStyle(color: Colors.red, fontSize: 10)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (vendedor.telefono != null)
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(vendedor.telefono!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ventas: \$${vendedor.ventasMes.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (progreso / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(progreso >= 100 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B)),
                      ),
                      Text('${progreso.toStringAsFixed(0)}% de meta', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${vendedor.comisionPorcentaje.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                    Text('Comisión', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
          color: const Color(0xFF1A1A2E),
          onSelected: (value) {
            if (value == 'edit') _mostrarFormulario(vendedor: vendedor);
            if (value == 'delete') _confirmarEliminar(vendedor);
            if (value == 'toggle') _toggleActivo(vendedor);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Color(0xFF22C55E), size: 18), SizedBox(width: 8), Text('Editar', style: TextStyle(color: Colors.white))])),
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(vendedor.activo ? Icons.block : Icons.check_circle, color: vendedor.activo ? Colors.orange : const Color(0xFF22C55E), size: 18),
                const SizedBox(width: 8),
                Text(vendedor.activo ? 'Desactivar' : 'Activar', style: const TextStyle(color: Colors.white)),
              ]),
            ),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Color(0xFFEF4444), size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActivo(VentasVendedorModel vendedor) async {
    try {
      await AppSupabase.client
          .from('ventas_vendedores')
          .update({'activo': !vendedor.activo})
          .eq('id', vendedor.id);
      _cargarVendedores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarFormulario({VentasVendedorModel? vendedor}) async {
    final nombreController = TextEditingController(text: vendedor?.nombre ?? '');
    final telefonoController = TextEditingController(text: vendedor?.telefono ?? '');
    final emailController = TextEditingController(text: vendedor?.email ?? '');
    final metaController = TextEditingController(text: vendedor?.metaMensual.toString() ?? '0');
    final comisionController = TextEditingController(text: vendedor?.comisionPorcentaje.toString() ?? '10');
    final passwordController = TextEditingController(); // V10.22
    bool crearCuenta = false; // V10.22
    bool guardando = false; // V10.22

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            vendedor == null ? 'Nuevo Vendedor' : 'Editar Vendedor',
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
                _buildTextField(metaController, 'Meta mensual \$', Icons.flag, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(comisionController, 'Comisión %', Icons.percent, keyboardType: TextInputType.number),
                // V10.22: Sección de acceso a la app (solo para nuevos)
                if (vendedor == null) ...[
                  CamposAuthWidget(
                    emailController: emailController,
                    passwordController: passwordController,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setDialogState(() => crearCuenta = v),
                    tipoUsuario: 'vendedor_ventas',
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
                if (crearCuenta && vendedor == null) {
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
                
                // V10.55: Crear cuenta de auth si se solicitó
                if (crearCuenta && vendedor == null) {
                  authUid = await AuthCreacionService.crearCuentaAuth(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    nombreCompleto: nombreController.text.trim(),
                    tipoUsuario: 'vendedor_ventas',
                    // Rol específico para vendedores → ve dashboardVendedorVentas
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
                  'meta_mensual': double.tryParse(metaController.text) ?? 0,
                  'comision_porcentaje': double.tryParse(comisionController.text) ?? 10,
                  if (crearCuenta && authUid != null) 'auth_uid': authUid, // V10.22
                };

                try {
                  if (vendedor == null) {
                    await AppSupabase.client.from('ventas_vendedores').insert(data);
                  } else {
                    await AppSupabase.client.from('ventas_vendedores').update(data).eq('id', vendedor.id);
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setDialogState(() => guardando = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              child: guardando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(vendedor == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _cargarVendedores();
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF22C55E)),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _confirmarEliminar(VentasVendedorModel vendedor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${vendedor.nombre}?', style: const TextStyle(color: Colors.white70)),
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
        await AppSupabase.client.from('ventas_vendedores').delete().eq('id', vendedor.id);
        _cargarVendedores();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

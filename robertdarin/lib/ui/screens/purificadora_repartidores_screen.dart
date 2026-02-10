// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/auth_creacion_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE REPARTIDORES PURIFICADORA - Robert Darin Platform v10.22
/// CRUD completo: Crear, listar, editar, activar/desactivar repartidores
/// Con opción de crear cuenta de acceso para la app
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraRepartidoresScreen extends StatefulWidget {
  const PurificadoraRepartidoresScreen({super.key});

  @override
  State<PurificadoraRepartidoresScreen> createState() => _PurificadoraRepartidoresScreenState();
}

class _PurificadoraRepartidoresScreenState extends State<PurificadoraRepartidoresScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _repartidores = [];
  bool _mostrarInactivos = false;

  @override
  void initState() {
    super.initState();
    _cargarRepartidores();
  }

  Future<void> _cargarRepartidores() async {
    try {
      var query = AppSupabase.client.from('purificadora_repartidores').select();
      if (!_mostrarInactivos) query = query.eq('activo', true);
      final res = await query.order('nombre');
      if (mounted) setState(() { _repartidores = List<Map<String, dynamic>>.from(res); _isLoading = false; });
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🚚 Repartidores',
      actions: [
        IconButton(
          icon: Icon(_mostrarInactivos ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: () { setState(() => _mostrarInactivos = !_mostrarInactivos); _cargarRepartidores(); },
          tooltip: _mostrarInactivos ? 'Ocultar inactivos' : 'Mostrar inactivos',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLista(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF00BCD4),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Repartidor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLista() {
    if (_repartidores.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin repartidores registrados', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarRepartidores,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _repartidores.length,
        itemBuilder: (context, index) => _buildRepartidorCard(_repartidores[index]),
      ),
    );
  }

  Widget _buildRepartidorCard(Map<String, dynamic> repartidor) {
    final activo = repartidor['activo'] ?? true;
    final zona = repartidor['zona'] ?? 'Sin zona';
    final tieneAuth = repartidor['auth_uid'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activo ? const Color(0xFF00BCD4).withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: activo ? const Color(0xFF00BCD4).withOpacity(0.2) : Colors.red.withOpacity(0.2),
              child: Icon(Icons.local_shipping, color: activo ? const Color(0xFF00BCD4) : Colors.red),
            ),
            if (tieneAuth)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(repartidor['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (!activo) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('INACTIVO', style: TextStyle(color: Colors.red, fontSize: 10)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📱 ${repartidor['telefono'] ?? 'Sin teléfono'}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
            Text('📍 $zona', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
            if (tieneAuth)
              Text('✅ Tiene acceso a la app', style: TextStyle(color: Colors.green.withOpacity(0.7), fontSize: 11)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF0D0D14),
          onSelected: (v) => _handleAccion(v, repartidor),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'editar', child: Text('✏️ Editar', style: TextStyle(color: Colors.white))),
            PopupMenuItem(
              value: 'toggle',
              child: Text(activo ? '🚫 Desactivar' : '✅ Activar', style: const TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(value: 'ver_entregas', child: Text('📦 Ver Entregas', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _handleAccion(String accion, Map<String, dynamic> repartidor) async {
    switch (accion) {
      case 'editar':
        _mostrarFormulario(repartidor: repartidor);
        break;
      case 'toggle':
        await AppSupabase.client.from('purificadora_repartidores').update({'activo': !(repartidor['activo'] ?? true)}).eq('id', repartidor['id']);
        _cargarRepartidores();
        break;
      case 'ver_entregas':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ver entregas de ${repartidor['nombre']}'), backgroundColor: Colors.blue),
        );
        break;
    }
  }

  void _mostrarFormulario({Map<String, dynamic>? repartidor}) {
    final esEdicion = repartidor != null;
    final nombreCtrl = TextEditingController(text: repartidor?['nombre'] ?? '');
    final telefonoCtrl = TextEditingController(text: repartidor?['telefono'] ?? '');
    final zonaCtrl = TextEditingController(text: repartidor?['zona'] ?? '');
    final vehiculoCtrl = TextEditingController(text: repartidor?['vehiculo'] ?? '');
    final notasCtrl = TextEditingController(text: repartidor?['notas'] ?? '');
    
    // V10.22: Campos para crear cuenta de acceso
    final emailCtrl = TextEditingController(text: repartidor?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    bool crearCuenta = false;
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(esEdicion ? 'Editar Repartidor' : 'Nuevo Repartidor', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                TextField(
                  controller: nombreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Nombre completo'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Teléfono'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: zonaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Zona de reparto'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: vehiculoCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Vehículo (ej: Camioneta blanca)'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notasCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Notas adicionales'),
                ),
                
                // V10.22: Sección de acceso a la app (solo para nuevos)
                if (!esEdicion) ...[
                  CamposAuthWidget(
                    emailController: emailCtrl,
                    passwordController: passwordCtrl,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setModalState(() => crearCuenta = v),
                    tipoUsuario: 'repartidor_purificadora',
                  ),
                ],
                
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: guardando ? null : () async {
                    if (nombreCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre'), backgroundColor: Colors.orange));
                      return;
                    }

                    // Validar email si se va a crear cuenta
                    if (crearCuenta && !esEdicion) {
                      if (emailCtrl.text.trim().isEmpty || !emailCtrl.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un email válido'), backgroundColor: Colors.orange));
                        return;
                      }
                      if (passwordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange));
                        return;
                      }
                    }

                    setModalState(() => guardando = true);

                    String? authUid;
                    
                    // Crear cuenta de auth si se solicitó
                    if (crearCuenta && !esEdicion) {
                      authUid = await AuthCreacionService.crearCuentaAuth(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        nombreCompleto: nombreCtrl.text.trim(),
                        tipoUsuario: 'repartidor_purificadora',
                        // Rol específico para repartidores → ve dashboardRepartidorPurificadora
                      );
                      
                      if (authUid == null) {
                        setModalState(() => guardando = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al crear cuenta. El email puede estar en uso.'), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }
                    }

                    final data = {
                      'nombre': nombreCtrl.text.trim(),
                      'telefono': telefonoCtrl.text.trim(),
                      'zona': zonaCtrl.text.trim(),
                      'vehiculo': vehiculoCtrl.text.trim(),
                      'notas': notasCtrl.text.trim(),
                      'activo': true,
                      if (crearCuenta && authUid != null) 'auth_uid': authUid,
                      if (crearCuenta) 'email': emailCtrl.text.trim(),
                    };

                    if (esEdicion) {
                      await AppSupabase.client.from('purificadora_repartidores').update(data).eq('id', repartidor['id']);
                    } else {
                      await AppSupabase.client.from('purificadora_repartidores').insert(data);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _cargarRepartidores();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(esEdicion 
                            ? '✅ Repartidor actualizado' 
                            : crearCuenta 
                              ? '✅ Repartidor creado con acceso a la app'
                              : '✅ Repartidor creado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), minimumSize: const Size(double.infinity, 50)),
                  child: guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(esEdicion ? 'Guardar Cambios' : 'Crear Repartidor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF0D0D14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

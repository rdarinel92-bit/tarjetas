// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../data/models/aval_model.dart';
import '../../core/supabase_client.dart';
import '../../services/auth_creacion_service.dart';
import '../viewmodels/negocio_activo_provider.dart';

class AvalesScreen extends StatefulWidget {
  const AvalesScreen({super.key});

  @override
  State<AvalesScreen> createState() => _AvalesScreenState();
}

class _AvalesScreenState extends State<AvalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AvalModel> _avales = [];
  List<dynamic> _prestamosConAval = [];
  bool _cargando = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // V10.55: Obtener negocio activo para filtrar
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      // Cargar avales
      var queryAvales = AppSupabase.client
          .from('avales')
          .select('*, clientes(nombre_completo)');
      
      if (negocioId != null) {
        queryAvales = queryAvales.eq('negocio_id', negocioId);
      }
      
      final avalesRes = await queryAvales.order('nombre');
      
      // Cargar préstamos con avales para estadísticas
      var queryPrestamos = AppSupabase.client
          .from('prestamos')
          .select('id, aval_id, monto, estado')
          .not('aval_id', 'is', null);
      
      if (negocioId != null) {
        queryPrestamos = queryPrestamos.eq('negocio_id', negocioId);
      }
      
      final prestamosRes = await queryPrestamos;

      setState(() {
        _avales = (avalesRes as List).map((e) => AvalModel.fromMap(e)).toList();
        _prestamosConAval = prestamosRes;
      });
    } catch (e) {
      debugPrint("Error cargando avales: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  List<AvalModel> get _avalesFiltrados {
    if (_filtro.isEmpty) return _avales;
    return _avales.where((a) =>
        a.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
        a.email.toLowerCase().contains(_filtro.toLowerCase()) ||
        a.telefono.contains(_filtro)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Gestión de Avales",
      body: Column(
        children: [
          // ESTADÍSTICAS RÁPIDAS
          _buildEstadisticas(),
          const SizedBox(height: 15),
          
          // BUSCADOR
          TextField(
            decoration: InputDecoration(
              hintText: "Buscar por nombre, email o teléfono...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _filtro = v),
          ),
          const SizedBox(height: 15),
          
          // TABS
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Todos los Avales"),
              Tab(text: "Crear Acceso"),
            ],
          ),
          const SizedBox(height: 10),
          
          // CONTENIDO
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaAvales(),
                _buildCrearAcceso(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        onPressed: () => _mostrarFormularioAval(),
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }

  Widget _buildEstadisticas() {
    final totalAvales = _avales.length;
    final avalesConAcceso = _avales.where((a) => a.usuarioId != null).length;
    final prestamosActivos = _prestamosConAval.where((p) => p['estado'] == 'activo').length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Total Avales", totalAvales.toString(), Icons.people, Colors.blueAccent)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard("Con Acceso App", avalesConAcceso.toString(), Icons.phone_android, Colors.greenAccent)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard("Garantizando", prestamosActivos.toString(), Icons.handshake, Colors.orangeAccent)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildListaAvales() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final avales = _avalesFiltrados;

    if (avales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 15),
            const Text("No hay avales registrados", style: TextStyle(color: Colors.white38)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioAval(),
              icon: const Icon(Icons.add),
              label: const Text("Registrar Primer Aval"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        itemCount: avales.length,
        itemBuilder: (context, index) => _buildAvalCard(avales[index]),
      ),
    );
  }

  Widget _buildAvalCard(AvalModel aval) {
    final tieneAcceso = aval.usuarioId != null && aval.usuarioId!.isNotEmpty;
    final prestamosDeEsteAval = _prestamosConAval.where((p) => p['aval_id'] == aval.id).toList();

    return PremiumCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                  child: Text(aval.nombre.isNotEmpty ? aval.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ),
                if (tieneAcceso)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E1E2C), width: 2),
                      ),
                      child: const Icon(Icons.check, size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: Text(aval.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aval.telefono, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text("Relación: ${aval.relacion}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white38),
              onSelected: (v) => _accionAval(v, aval),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'ver', child: Text('Ver Detalle')),
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                if (!tieneAcceso)
                  const PopupMenuItem(value: 'acceso', child: Text('Crear Acceso App')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          if (prestamosDeEsteAval.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.handshake, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text("Garantiza ${prestamosDeEsteAval.length} préstamo(s)", 
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrearAcceso() {
    final avalesSinAcceso = _avales.where((a) => a.usuarioId == null || a.usuarioId!.isEmpty).toList();

    if (avalesSinAcceso.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.greenAccent),
            SizedBox(height: 15),
            Text("Todos los avales tienen acceso a la App", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(15),
          child: Text(
            "Los avales con acceso podrán:\n• Ver el estado de los préstamos que garantizan\n• Recibir notificaciones de pagos pendientes\n• Subir documentos de identificación",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        ...avalesSinAcceso.map((aval) => ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.white12,
            child: Icon(Icons.person_off, color: Colors.white38),
          ),
          title: Text(aval.nombre, style: const TextStyle(color: Colors.white)),
          subtitle: Text(aval.email.isNotEmpty ? aval.email : aval.telefono, 
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: ElevatedButton(
            onPressed: () => _crearAccesoParaAval(aval),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Dar Acceso", style: TextStyle(color: Colors.black, fontSize: 12)),
          ),
        )),
      ],
    );
  }

  void _accionAval(String accion, AvalModel aval) {
    switch (accion) {
      case 'ver':
        _mostrarDetalleAval(aval);
        break;
      case 'editar':
        _mostrarFormularioAval(aval: aval);
        break;
      case 'acceso':
        _crearAccesoParaAval(aval);
        break;
      case 'eliminar':
        _confirmarEliminar(aval);
        break;
    }
  }

  void _mostrarDetalleAval(AvalModel aval) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                  child: Text(aval.nombre[0].toUpperCase(),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(aval.nombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(aval.relacion, style: const TextStyle(color: Colors.orangeAccent)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _buildDetalleRow(Icons.email, "Email", aval.email.isNotEmpty ? aval.email : "No registrado"),
            _buildDetalleRow(Icons.phone, "Teléfono", aval.telefono),
            _buildDetalleRow(Icons.home, "Dirección", aval.direccion.isNotEmpty ? aval.direccion : "No registrada"),
            _buildDetalleRow(Icons.badge, "Identificación", aval.identificacion ?? "No registrada"),
            _buildDetalleRow(Icons.phone_android, "Acceso App", aval.usuarioId != null ? "✅ Activo" : "❌ Sin acceso"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white38),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(color: Colors.white54)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  /// Genera una contraseña segura de 8 caracteres
  String _generarPasswordSeguro() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _mostrarFormularioAval({AvalModel? aval}) {
    final esEdicion = aval != null;
    final nombreCtrl = TextEditingController(text: aval?.nombre ?? '');
    final emailCtrl = TextEditingController(text: aval?.email ?? '');
    final telefonoCtrl = TextEditingController(text: aval?.telefono ?? '');
    final direccionCtrl = TextEditingController(text: aval?.direccion ?? '');
    final relacionCtrl = TextEditingController(text: aval?.relacion ?? '');
    final identificacionCtrl = TextEditingController(text: aval?.identificacion ?? '');
    String? clienteSeleccionado = aval?.clienteId;
    bool crearAccesoInmediato = false; // Nueva opción
    final passwordCtrl = TextEditingController(text: _generarPasswordSeguro());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(esEdicion ? "Editar Aval" : "Nuevo Aval", 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Completo *")),
              const SizedBox(height: 10),
              TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: "Teléfono *"), keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email"), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              TextField(controller: direccionCtrl, decoration: const InputDecoration(labelText: "Dirección")),
              const SizedBox(height: 10),
              TextField(controller: relacionCtrl, decoration: const InputDecoration(labelText: "Relación con cliente", hintText: "Ej: Hermano, Padre, Amigo")),
              const SizedBox(height: 10),
              TextField(controller: identificacionCtrl, decoration: const InputDecoration(labelText: "# Identificación (INE/CURP)")),
              const SizedBox(height: 10),
              // Selector de cliente
              FutureBuilder(
                future: AppSupabase.client.from('clientes').select('id, nombre_completo'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final clientes = snapshot.data as List;
                  return DropdownButtonFormField<String>(
                    value: clienteSeleccionado,
                    items: clientes.map((c) => DropdownMenuItem(
                      value: c['id'].toString(), 
                      child: Text(c['nombre_completo'] ?? 'Sin nombre'),
                    )).toList(),
                    onChanged: (v) => clienteSeleccionado = v,
                    decoration: const InputDecoration(labelText: "Cliente que avala *"),
                  );
                },
              ),
              // NUEVO: Opción de crear acceso inmediato
              if (!esEdicion) ...[
                const SizedBox(height: 15),
                StatefulBuilder(
                  builder: (context, setLocalState) => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Crear acceso a la App", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("El aval podrá ver los préstamos que garantiza", 
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                        value: crearAccesoInmediato,
                        activeColor: Colors.greenAccent,
                        onChanged: (v) => setLocalState(() => crearAccesoInmediato = v),
                      ),
                      if (crearAccesoInmediato) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordCtrl,
                          decoration: InputDecoration(
                            labelText: "Contraseña temporal",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.orangeAccent),
                              onPressed: () => setLocalState(() => passwordCtrl.text = _generarPasswordSeguro()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text("⚠️ Requiere email válido para crear cuenta", 
                          style: TextStyle(color: Colors.orange, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nombreCtrl.text.isEmpty || telefonoCtrl.text.isEmpty || clienteSeleccionado == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Completa los campos requeridos"), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final email = emailCtrl.text.trim();
                        final telefono = telefonoCtrl.text.trim();
                        
                        // Validar email si se va a crear acceso
                        if (crearAccesoInmediato && (email.isEmpty || !email.contains('@'))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Se requiere email válido para crear acceso"), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final data = {
                          'nombre': nombreCtrl.text.trim(),
                          'email': email,
                          'telefono': telefono,
                          'direccion': direccionCtrl.text.trim(),
                          'relacion': relacionCtrl.text.trim(),
                          'identificacion': identificacionCtrl.text.trim(),
                          'cliente_id': clienteSeleccionado,
                        };

                        try {
                          if (esEdicion) {
                            await AppSupabase.client.from('avales').update(data).eq('id', aval.id);
                            Navigator.pop(context);
                            _cargarDatos();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Aval actualizado"), backgroundColor: Colors.green),
                            );
                          } else {
                            // Crear aval
                            String? usuarioId;
                            
                            if (crearAccesoInmediato) {
                              // V10.55: Usar AuthCreacionService para crear cuenta
                              final password = passwordCtrl.text.trim();
                              usuarioId = await AuthCreacionService.crearCuentaAuth(
                                email: email,
                                password: password,
                                nombreCompleto: nombreCtrl.text.trim(),
                                tipoUsuario: 'aval',
                              );
                              
                              if (usuarioId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error al crear cuenta. El email puede estar en uso.'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                            }
                            
                            // Insertar aval con o sin usuario_id
                            data['usuario_id'] = usuarioId;
                            await AppSupabase.client.from('avales').insert(data);
                            
                            Navigator.pop(context);
                            _cargarDatos();
                            
                            if (crearAccesoInmediato && usuarioId != null) {
                              _mostrarCredencialesCreadas(email, passwordCtrl.text.trim(), telefono, nombreCtrl.text.trim());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Aval registrado"), backgroundColor: Colors.green),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                      child: Text(esEdicion ? "Guardar" : "Registrar", style: const TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _crearAccesoParaAval(AvalModel aval) async {
    // Validar que tenga email válido
    if (aval.email.isEmpty || !aval.email.contains('@')) {
      // Pedir email si no tiene
      final emailCtrl = TextEditingController();
      final nuevoEmail = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("Email requerido"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${aval.nombre} no tiene email registrado.", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 15),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email del aval"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
              child: const Text("Continuar"),
            ),
          ],
        ),
      );
      
      if (nuevoEmail == null || nuevoEmail.isEmpty || !nuevoEmail.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Se requiere un email válido"), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      
      // Actualizar email del aval
      await AppSupabase.client.from('avales').update({'email': nuevoEmail}).eq('id', aval.id);
      aval = AvalModel(
        id: aval.id, nombre: aval.nombre, email: nuevoEmail, telefono: aval.telefono,
        direccion: aval.direccion, relacion: aval.relacion, clienteId: aval.clienteId,
        identificacion: aval.identificacion, usuarioId: aval.usuarioId,
      );
    }

    final passwordCtrl = TextEditingController(text: _generarPasswordSeguro());
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.greenAccent),
              const SizedBox(width: 10),
              const Text("Crear Acceso"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aval.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(aval.email, style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordCtrl,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.orangeAccent),
                    onPressed: () => setDialogState(() => passwordCtrl.text = _generarPasswordSeguro()),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "El aval podrá:\n• Ver préstamos que garantiza\n• Recibir alertas de pagos\n• Subir documentos",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              icon: const Icon(Icons.check, color: Colors.black, size: 18),
              label: const Text("Crear Acceso", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // V10.55: Usar AuthCreacionService para crear cuenta
      final password = passwordCtrl.text.trim();
      final usuarioId = await AuthCreacionService.crearCuentaAuth(
        email: aval.email,
        password: password,
        nombreCompleto: aval.nombre,
        tipoUsuario: 'aval',
      );

      if (usuarioId == null) {
        throw Exception('No se pudo crear la cuenta de usuario');
      }

      // Actualizar aval con el usuario_id
      await AppSupabase.client.from('avales').update({
        'usuario_id': usuarioId,
      }).eq('id', aval.id);

      if (mounted) Navigator.pop(context); // Cerrar loading
      _cargarDatos();

      if (mounted) {
        _mostrarCredencialesCreadas(aval.email, password, aval.telefono, aval.nombre);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Muestra las credenciales creadas con opciones para copiar y enviar por WhatsApp
  void _mostrarCredencialesCreadas(String email, String password, String telefono, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.greenAccent),
            ),
            const SizedBox(width: 10),
            const Text("¡Acceso Creado!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CREDENCIALES", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(child: Text(email, style: const TextStyle(color: Colors.white))),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Colors.orangeAccent),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: email));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Email copiado"), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(child: Text(password, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Colors.orangeAccent),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Contraseña copiada"), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // Botón de WhatsApp
            if (telefono.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _enviarCredencialesPorWhatsApp(nombre, email, password, telefono),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  label: const Text("Enviar por WhatsApp", style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: "Email: $email\nContraseña: $password"));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Credenciales copiadas al portapapeles")),
              );
            },
            child: const Text("Copiar Todo"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  /// Envía las credenciales por WhatsApp
  Future<void> _enviarCredencialesPorWhatsApp(String nombre, String email, String password, String telefono) async {
    final mensaje = '''🔐 *Acceso a Robert Darin App*

Hola $nombre, te compartimos tus credenciales de acceso:

📧 *Email:* $email
🔑 *Contraseña:* $password

Con esta cuenta podrás:
✅ Ver los préstamos que garantizas
✅ Recibir alertas de pagos
✅ Subir tus documentos

📲 Descarga la app y accede con estos datos.''';

    final tel = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUrl = 'https://wa.me/52$tel?text=${Uri.encodeComponent(mensaje)}';
    
    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No se pudo abrir WhatsApp');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al abrir WhatsApp: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarEliminar(AvalModel aval) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("¿Eliminar aval?"),
        content: Text("Se eliminará permanentemente a ${aval.nombre}.\n\nSi tiene préstamos asociados, estos quedarán sin aval."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppSupabase.client.from('avales').delete().eq('id', aval.id);
        _cargarDatos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aval eliminado"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

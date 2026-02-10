// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/purificadora_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DETALLE COMPLETO DE CLIENTE PURIFICADORA - 6 Tabs
/// Entregas, Garrafones, Pagos, Contactos, Documentos, Notas
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraClienteDetalleScreen extends StatefulWidget {
  final String clienteId;
  const PurificadoraClienteDetalleScreen({super.key, required this.clienteId});
  @override
  State<PurificadoraClienteDetalleScreen> createState() => _PurificadoraClienteDetalleScreenState();
}

class _PurificadoraClienteDetalleScreenState extends State<PurificadoraClienteDetalleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  PurificadoraClienteModel? _cliente;
  
  // Datos de las tabs
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _garrafonesHistorial = [];
  List<Map<String, dynamic>> _pagos = [];
  List<Map<String, dynamic>> _contactos = [];
  List<Map<String, dynamic>> _documentos = [];
  List<Map<String, dynamic>> _notas = [];

  // Stats
  int _totalEntregas = 0;
  int _totalGarrafonesEntregados = 0;
  double _totalPagado = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarCliente(),
      _cargarEntregas(),
      _cargarGarrafonesHistorial(),
      _cargarPagos(),
      _cargarContactos(),
      _cargarDocumentos(),
      _cargarNotas(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarCliente() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_clientes')
          .select()
          .eq('id', widget.clienteId)
          .single();
      if (mounted) {
        setState(() => _cliente = PurificadoraClienteModel.fromMap(res));
      }
    } catch (e) {
      debugPrint('Error cargando cliente: $e');
    }
  }

  Future<void> _cargarEntregas() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_entregas')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('fecha', ascending: false);
      if (mounted) {
        final lista = res as List;
        int totalGarrafones = 0;
        for (var e in lista) {
          totalGarrafones += (e['garrafones_entregados'] ?? 0) as int;
        }
        setState(() {
          _entregas = List<Map<String, dynamic>>.from(lista);
          _totalEntregas = lista.length;
          _totalGarrafonesEntregados = totalGarrafones;
        });
      }
    } catch (e) {
      debugPrint('Error entregas: $e');
    }
  }

  Future<void> _cargarGarrafonesHistorial() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_garrafones_historial')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() => _garrafonesHistorial = List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('Error garrafones: $e');
    }
  }

  Future<void> _cargarPagos() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_pagos')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('fecha', ascending: false);
      if (mounted) {
        final lista = res as List;
        double total = 0;
        for (var p in lista) {
          total += (p['monto'] ?? 0).toDouble();
        }
        setState(() {
          _pagos = List<Map<String, dynamic>>.from(lista);
          _totalPagado = total;
        });
      }
    } catch (e) {
      debugPrint('Error pagos: $e');
    }
  }

  Future<void> _cargarContactos() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_cliente_contactos')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('es_principal', ascending: false);
      if (mounted) {
        setState(() => _contactos = List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('Error contactos: $e');
    }
  }

  Future<void> _cargarDocumentos() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_cliente_documentos')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _documentos = List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('Error documentos: $e');
    }
  }

  Future<void> _cargarNotas() async {
    try {
      final res = await AppSupabase.client
          .from('purificadora_cliente_notas')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _notas = List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('Error notas: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES RÁPIDAS
  // ═══════════════════════════════════════════════════════════════════════════

  void _editarCliente() async {
    if (_cliente == null) return;
    
    final nombreController = TextEditingController(text: _cliente!.nombre);
    final telefonoController = TextEditingController(text: _cliente!.telefono);
    final direccionController = TextEditingController(text: _cliente!.direccion);
    final coloniaController = TextEditingController(text: _cliente!.colonia ?? '');
    final referenciasController = TextEditingController(text: _cliente!.referencias ?? '');
    final notasController = TextEditingController(text: _cliente!.notas ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Editar Cliente', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Teléfono', labelStyle: TextStyle(color: Colors.white54)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: direccionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Dirección', labelStyle: TextStyle(color: Colors.white54)),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: coloniaController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Colonia', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenciasController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Referencias', labelStyle: TextStyle(color: Colors.white54)),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notas', labelStyle: TextStyle(color: Colors.white54)),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await AppSupabase.client.from('purificadora_clientes').update({
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'direccion': direccionController.text.trim(),
                  'colonia': coloniaController.text.trim(),
                  'referencias': referenciasController.text.trim(),
                  'notas': notasController.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', widget.clienteId);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      _cargarCliente();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cliente actualizado'), backgroundColor: Colors.green));
      }
    }
  }

  void _llamar() async {
    if (_cliente?.telefono == null) return;
    final uri = Uri.parse('tel:${_cliente!.telefono}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _whatsapp() async {
    final numero = _cliente?.whatsapp ?? _cliente?.telefono;
    if (numero == null) return;
    final uri = Uri.parse('https://wa.me/52$numero');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _abrirMapa() async {
    if (_cliente?.coordenadas != null) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_cliente!.coordenadas}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final query = Uri.encodeComponent('${_cliente!.direccion}, ${_cliente!.colonia ?? ""}');
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return PremiumScaffold(
        title: 'Cargando...',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cliente == null) {
      return PremiumScaffold(
        title: 'Error',
        body: const Center(child: Text('Cliente no encontrado', style: TextStyle(color: Colors.white))),
      );
    }

    return PremiumScaffold(
      title: _cliente!.nombre,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: _editarCliente,
          tooltip: 'Editar Cliente',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1A1A2E),
          onSelected: (value) {
            switch (value) {
              case 'llamar': _llamar(); break;
              case 'whatsapp': _whatsapp(); break;
              case 'mapa': _abrirMapa(); break;
              case 'entrega': _registrarEntregaRapida(); break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'llamar', child: Row(children: [Icon(Icons.phone, color: Color(0xFF22C55E), size: 20), SizedBox(width: 12), Text('Llamar', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'whatsapp', child: Row(children: [Icon(Icons.chat, color: Color(0xFF25D366), size: 20), SizedBox(width: 12), Text('WhatsApp', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'mapa', child: Row(children: [Icon(Icons.map, color: Color(0xFF06B6D4), size: 20), SizedBox(width: 12), Text('Ver en Mapa', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'entrega', child: Row(children: [Icon(Icons.local_shipping, color: Color(0xFF8B5CF6), size: 20), SizedBox(width: 12), Text('Registrar Entrega', style: TextStyle(color: Colors.white))])),
          ],
        ),
      ],
      body: Column(
        children: [
          _buildHeader(),
          _buildStats(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _accionPorTab,
        backgroundColor: const Color(0xFF06B6D4),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  _cliente!.nombre.isNotEmpty ? _cliente!.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_cliente!.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_cliente!.codigoCliente != null)
                      Text('Código: ${_cliente!.codigoCliente}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_cliente!.tipoDisplay, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('${_cliente!.direccion}${_cliente!.colonia != null ? ', ${_cliente!.colonia}' : ''}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13))),
            ],
          ),
          if (_cliente!.referencias != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.6), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(_cliente!.referencias!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (_cliente!.telefono != null) ...[
                Icon(Icons.phone, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Text(_cliente!.telefono!, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                const SizedBox(width: 16),
              ],
              Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8), size: 14),
              const SizedBox(width: 4),
              Text(_cliente!.frecuenciaEntrega.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ],
          ),
          if (_cliente!.diasEntrega.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _cliente!.diasEntrega.map((dia) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(dia, style: const TextStyle(color: Colors.white, fontSize: 11)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Entregas', '$_totalEntregas', const Color(0xFF06B6D4)),
          _buildStatItem('Garrafones', '$_totalGarrafonesEntregados', const Color(0xFF22C55E)),
          _buildStatItem('En Préstamo', '${_cliente!.garrafonesEnPrestamo}', const Color(0xFFFBBF24)),
          _buildStatItem('Saldo', '\$${_cliente!.saldoPendiente.toStringAsFixed(0)}', _cliente!.saldoPendiente > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF06B6D4),
        labelColor: const Color(0xFF06B6D4),
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(icon: Icon(Icons.local_shipping, size: 20), text: 'Entregas'),
          Tab(icon: Icon(Icons.water_drop, size: 20), text: 'Garrafones'),
          Tab(icon: Icon(Icons.payments, size: 20), text: 'Pagos'),
          Tab(icon: Icon(Icons.people, size: 20), text: 'Contactos'),
          Tab(icon: Icon(Icons.folder, size: 20), text: 'Documentos'),
          Tab(icon: Icon(Icons.note, size: 20), text: 'Notas'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTabEntregas(),
        _buildTabGarrafones(),
        _buildTabPagos(),
        _buildTabContactos(),
        _buildTabDocumentos(),
        _buildTabNotas(),
      ],
    );
  }

  void _accionPorTab() {
    switch (_tabController.index) {
      case 0: _registrarEntregaRapida(); break;
      case 1: _registrarMovimientoGarrafon(); break;
      case 2: _registrarPago(); break;
      case 3: _nuevoContacto(); break;
      case 4: _nuevoDocumento(); break;
      case 5: _nuevaNota(); break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: ENTREGAS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabEntregas() {
    if (_entregas.isEmpty) {
      return _buildEmptyTab('Sin entregas', Icons.local_shipping_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entregas.length,
      itemBuilder: (context, index) {
        final entrega = _entregas[index];
        final garrafones = entrega['garrafones_entregados'] ?? 0;
        final vacios = entrega['garrafones_recogidos'] ?? 0;
        final monto = (entrega['monto_cobrado'] ?? 0).toDouble();
        final fecha = entrega['fecha'] ?? '';
        final estado = entrega['estado'] ?? 'completada';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Color(0xFF06B6D4), size: 20),
                      const SizedBox(width: 8),
                      Text('$garrafones llenos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  _buildEstadoEntrega(estado),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$vacios vacíos recogidos', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
              if (monto > 0) ...[
                const SizedBox(height: 4),
                Text('Cobrado: \$${monto.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoEntrega(String estado) {
    Color color;
    String texto;
    switch (estado) {
      case 'pendiente': color = const Color(0xFFFBBF24); texto = 'Pendiente'; break;
      case 'en_ruta': color = const Color(0xFF06B6D4); texto = 'En Ruta'; break;
      case 'completada': color = const Color(0xFF22C55E); texto = 'Completada'; break;
      case 'no_entregada': color = const Color(0xFFEF4444); texto = 'No Entregada'; break;
      default: color = Colors.grey; texto = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _registrarEntregaRapida() {
    final garrafonesController = TextEditingController(text: '1');
    final vaciosController = TextEditingController(text: '1');
    final montoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar Entrega', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildTextField(garrafonesController, 'Garrafones Llenos', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(vaciosController, 'Vacíos Recogidos', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(montoController, 'Monto Cobrado (opcional)', keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await AppSupabase.client.from('purificadora_entregas').insert({
                      'cliente_id': widget.clienteId,
                      'garrafones_entregados': int.tryParse(garrafonesController.text) ?? 0,
                      'garrafones_recogidos': int.tryParse(vaciosController.text) ?? 0,
                      'monto_cobrado': double.tryParse(montoController.text) ?? 0,
                      'fecha': DateTime.now().toIso8601String().substring(0, 10),
                      'estado': 'completada',
                    });
                    Navigator.pop(context);
                    _cargarEntregas();
                  } catch (e) {
                    debugPrint('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: GARRAFONES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabGarrafones() {
    return Column(
      children: [
        // Resumen de garrafones
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('En Préstamo', style: TextStyle(color: Colors.white70)),
                  Text('${_cliente!.garrafonesEnPrestamo}', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 24)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Máximo Permitido', style: TextStyle(color: Colors.white70)),
                  Text('${_cliente!.garrafonesMaximo}', style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disponibles para Entregar', style: TextStyle(color: Colors.white70)),
                  Text('${_cliente!.garrafonesMaximo - _cliente!.garrafonesEnPrestamo}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        // Historial
        Expanded(
          child: _garrafonesHistorial.isEmpty
              ? _buildEmptyTab('Sin movimientos de garrafones', Icons.water_drop_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _garrafonesHistorial.length,
                  itemBuilder: (context, index) {
                    final mov = _garrafonesHistorial[index];
                    final tipo = mov['tipo'] ?? 'entrega';
                    final cantidad = mov['cantidad'] ?? 0;
                    final esEntrega = tipo == 'entrega' || tipo == 'prestamo';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(esEntrega ? Icons.arrow_forward : Icons.arrow_back, color: esEntrega ? const Color(0xFFFBBF24) : const Color(0xFF22C55E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(esEntrega ? 'Entregados' : 'Devueltos', style: const TextStyle(color: Colors.white)),
                                Text(mov['fecha'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('${esEntrega ? '+' : '-'}$cantidad', style: TextStyle(color: esEntrega ? const Color(0xFFFBBF24) : const Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _registrarMovimientoGarrafon() {
    final cantidadController = TextEditingController(text: '1');
    String tipo = 'devolucion';

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
              const Text('Movimiento de Garrafones', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => tipo = 'devolucion'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tipo == 'devolucion' ? const Color(0xFF22C55E).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tipo == 'devolucion' ? const Color(0xFF22C55E) : Colors.white24),
                        ),
                        child: Text('Devolución', textAlign: TextAlign.center, style: TextStyle(color: tipo == 'devolucion' ? const Color(0xFF22C55E) : Colors.white70)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => tipo = 'prestamo'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tipo == 'prestamo' ? const Color(0xFFFBBF24).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tipo == 'prestamo' ? const Color(0xFFFBBF24) : Colors.white24),
                        ),
                        child: Text('Préstamo Extra', textAlign: TextAlign.center, style: TextStyle(color: tipo == 'prestamo' ? const Color(0xFFFBBF24) : Colors.white70)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(cantidadController, 'Cantidad', keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await AppSupabase.client.from('purificadora_garrafones_historial').insert({
                        'cliente_id': widget.clienteId,
                        'tipo': tipo,
                        'cantidad': int.tryParse(cantidadController.text) ?? 1,
                        'fecha': DateTime.now().toIso8601String().substring(0, 10),
                      });
                      Navigator.pop(context);
                      _cargarGarrafonesHistorial();
                      _cargarCliente();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: PAGOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabPagos() {
    return Column(
      children: [
        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Saldo Pendiente', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('\$${_cliente!.saldoPendiente.toStringAsFixed(2)}', style: TextStyle(color: _cliente!.saldoPendiente > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Column(
                children: [
                  const Text('Total Pagado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('\$${_totalPagado.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ],
          ),
        ),
        // Lista de pagos
        Expanded(
          child: _pagos.isEmpty
              ? _buildEmptyTab('Sin pagos registrados', Icons.payments_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pagos.length,
                  itemBuilder: (context, index) {
                    final pago = _pagos[index];
                    final monto = (pago['monto'] ?? 0).toDouble();
                    final metodo = pago['metodo_pago'] ?? 'efectivo';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Icon(_getIconoMetodoPago(metodo), color: const Color(0xFF22C55E), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pago['concepto'] ?? 'Pago', style: const TextStyle(color: Colors.white)),
                                Text('${pago['fecha'] ?? ''} • ${metodo.toUpperCase()}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getIconoMetodoPago(String metodo) {
    switch (metodo) {
      case 'efectivo': return Icons.payments;
      case 'tarjeta': return Icons.credit_card;
      case 'transferencia': return Icons.account_balance;
      default: return Icons.payment;
    }
  }

  void _registrarPago() {
    final montoController = TextEditingController();
    final conceptoController = TextEditingController();
    String metodo = 'efectivo';

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
              const Text('Registrar Pago', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(montoController, 'Monto', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField(conceptoController, 'Concepto (opcional)'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodo,
                dropdownColor: const Color(0xFF0D0D14),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Método de Pago',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                ],
                onChanged: (v) => setModalState(() => metodo = v ?? 'efectivo'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (montoController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('purificadora_pagos').insert({
                        'cliente_id': widget.clienteId,
                        'monto': double.parse(montoController.text),
                        'concepto': conceptoController.text.isEmpty ? 'Pago de agua' : conceptoController.text,
                        'metodo_pago': metodo,
                        'fecha': DateTime.now().toIso8601String().substring(0, 10),
                      });
                      Navigator.pop(context);
                      _cargarPagos();
                      _cargarCliente();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: CONTACTOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabContactos() {
    if (_contactos.isEmpty) {
      return _buildEmptyTab('Sin contactos adicionales', Icons.people_outline);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contactos.length,
      itemBuilder: (context, index) {
        final contacto = _contactos[index];
        final esPrincipal = contacto['es_principal'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: esPrincipal ? Border.all(color: const Color(0xFF06B6D4).withOpacity(0.5)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
                    child: Text((contacto['nombre'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF06B6D4))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(contacto['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            if (esPrincipal) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        if (contacto['parentesco'] != null)
                          Text(contacto['parentesco'], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                      ],
                    ),
                  ),
                  if (contacto['telefono'] != null)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Color(0xFF22C55E), size: 20),
                      onPressed: () async {
                        final uri = Uri.parse('tel:${contacto['telefono']}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _nuevoContacto() {
    final nombreController = TextEditingController();
    final parentescoController = TextEditingController();
    final telefonoController = TextEditingController();
    bool esPrincipal = false;

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
              const Text('Nuevo Contacto', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(nombreController, 'Nombre *'),
              const SizedBox(height: 12),
              _buildTextField(parentescoController, 'Parentesco (ej: Esposa, Hijo)'),
              const SizedBox(height: 12),
              _buildTextField(telefonoController, 'Teléfono', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: esPrincipal,
                onChanged: (v) => setModalState(() => esPrincipal = v ?? false),
                title: const Text('Contacto Principal', style: TextStyle(color: Colors.white)),
                activeColor: const Color(0xFF06B6D4),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nombreController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('purificadora_cliente_contactos').insert({
                        'cliente_id': widget.clienteId,
                        'nombre': nombreController.text,
                        'parentesco': parentescoController.text.isEmpty ? null : parentescoController.text,
                        'telefono': telefonoController.text.isEmpty ? null : telefonoController.text,
                        'es_principal': esPrincipal,
                      });
                      Navigator.pop(context);
                      _cargarContactos();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: DOCUMENTOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabDocumentos() {
    if (_documentos.isEmpty) {
      return _buildEmptyTab('Sin documentos', Icons.folder_open);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documentos.length,
      itemBuilder: (context, index) {
        final doc = _documentos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.insert_drive_file, color: Color(0xFF06B6D4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['nombre'] ?? 'Documento', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text((doc['tipo'] ?? 'otro').toUpperCase(), style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nuevoDocumento() {
    final nombreController = TextEditingController();
    String tipo = 'otro';

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
              const Text('Nuevo Documento', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(nombreController, 'Nombre del documento *'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipo,
                dropdownColor: const Color(0xFF0D0D14),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'contrato', child: Text('Contrato')),
                  DropdownMenuItem(value: 'identificacion', child: Text('Identificación')),
                  DropdownMenuItem(value: 'comprobante', child: Text('Comprobante')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                ],
                onChanged: (v) => setModalState(() => tipo = v ?? 'otro'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nombreController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('purificadora_cliente_documentos').insert({
                        'cliente_id': widget.clienteId,
                        'nombre': nombreController.text,
                        'tipo': tipo,
                      });
                      Navigator.pop(context);
                      _cargarDocumentos();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: NOTAS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabNotas() {
    if (_notas.isEmpty) {
      return _buildEmptyTab('Sin notas', Icons.note_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notas.length,
      itemBuilder: (context, index) {
        final nota = _notas[index];
        final fecha = nota['created_at'] != null
            ? DateTime.parse(nota['created_at']).toString().substring(0, 16)
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(nota['autor'] ?? 'Sistema', style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(nota['contenido'] ?? '', style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      },
    );
  }

  void _nuevaNota() {
    final contenidoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nueva Nota', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: contenidoController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe tu nota aquí...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (contenidoController.text.isEmpty) return;
                  try {
                    await AppSupabase.client.from('purificadora_cliente_notas').insert({
                      'cliente_id': widget.clienteId,
                      'contenido': contenidoController.text,
                      'autor': 'Usuario',
                    });
                    Navigator.pop(context);
                    _cargarNotas();
                  } catch (e) {
                    debugPrint('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyTab(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

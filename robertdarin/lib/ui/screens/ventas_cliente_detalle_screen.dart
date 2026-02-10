// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/ventas_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DETALLE COMPLETO DE CLIENTE VENTAS - 6 Tabs
/// Pedidos, Créditos, Contactos, Documentos, Notas, Cotizaciones
/// ═══════════════════════════════════════════════════════════════════════════════
class VentasClienteDetalleScreen extends StatefulWidget {
  final String clienteId;
  const VentasClienteDetalleScreen({super.key, required this.clienteId});
  @override
  State<VentasClienteDetalleScreen> createState() => _VentasClienteDetalleScreenState();
}

class _VentasClienteDetalleScreenState extends State<VentasClienteDetalleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  VentasClienteModel? _cliente;
  
  // Datos de las tabs
  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _creditos = [];
  List<Map<String, dynamic>> _contactos = [];
  List<Map<String, dynamic>> _documentos = [];
  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _cotizaciones = [];

  // Stats
  int _totalPedidos = 0;
  double _totalComprado = 0;
  int _totalCotizaciones = 0;

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
      _cargarPedidos(),
      _cargarCreditos(),
      _cargarContactos(),
      _cargarDocumentos(),
      _cargarNotas(),
      _cargarCotizaciones(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarCliente() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_clientes')
          .select()
          .eq('id', widget.clienteId)
          .single();
      if (mounted) {
        setState(() => _cliente = VentasClienteModel.fromMap(res));
      }
    } catch (e) {
      debugPrint('Error cargando cliente: $e');
    }
  }

  Future<void> _cargarPedidos() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_pedidos')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('created_at', ascending: false);
      if (mounted) {
        final lista = res as List;
        double total = 0;
        for (var p in lista) {
          total += (p['total'] ?? 0).toDouble();
        }
        setState(() {
          _pedidos = List<Map<String, dynamic>>.from(lista);
          _totalPedidos = lista.length;
          _totalComprado = total;
        });
      }
    } catch (e) {
      debugPrint('Error pedidos: $e');
    }
  }

  Future<void> _cargarCreditos() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_cliente_creditos')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() => _creditos = List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('Error créditos: $e');
    }
  }

  Future<void> _cargarContactos() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_cliente_contactos')
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
          .from('ventas_cliente_documentos')
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
          .from('ventas_cliente_notas')
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

  Future<void> _cargarCotizaciones() async {
    try {
      final res = await AppSupabase.client
          .from('ventas_cotizaciones')
          .select()
          .eq('cliente_id', widget.clienteId)
          .order('created_at', ascending: false);
      if (mounted) {
        final lista = res as List;
        setState(() {
          _cotizaciones = List<Map<String, dynamic>>.from(lista);
          _totalCotizaciones = lista.length;
        });
      }
    } catch (e) {
      debugPrint('Error cotizaciones: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES RÁPIDAS
  // ═══════════════════════════════════════════════════════════════════════════

  void _editarCliente() async {
    if (_cliente == null) return;
    
    final nombreController = TextEditingController(text: _cliente!.nombre);
    final telefonoController = TextEditingController(text: _cliente!.telefono);
    final emailController = TextEditingController(text: _cliente!.email ?? '');
    final direccionController = TextEditingController(text: _cliente!.direccion ?? '');
    final ciudadController = TextEditingController(text: _cliente!.ciudad ?? '');
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
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white54)),
                keyboardType: TextInputType.emailAddress,
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
                controller: ciudadController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Ciudad', labelStyle: TextStyle(color: Colors.white54)),
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
                await AppSupabase.client.from('ventas_clientes').update({
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  'direccion': direccionController.text.trim(),
                  'ciudad': ciudadController.text.trim(),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
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

  void _email() async {
    if (_cliente?.email == null) return;
    final uri = Uri.parse('mailto:${_cliente!.email}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _abrirMapa() async {
    if (_cliente?.direccion == null) return;
    final query = Uri.encodeComponent('${_cliente!.direccion}, ${_cliente!.ciudad ?? ""}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              case 'email': _email(); break;
              case 'mapa': _abrirMapa(); break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'llamar', child: Row(children: [Icon(Icons.phone, color: Color(0xFF22C55E), size: 20), SizedBox(width: 12), Text('Llamar', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'whatsapp', child: Row(children: [Icon(Icons.chat, color: Color(0xFF25D366), size: 20), SizedBox(width: 12), Text('WhatsApp', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'email', child: Row(children: [Icon(Icons.email, color: Color(0xFF8B5CF6), size: 20), SizedBox(width: 12), Text('Email', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'mapa', child: Row(children: [Icon(Icons.map, color: Color(0xFF06B6D4), size: 20), SizedBox(width: 12), Text('Ver en Mapa', style: TextStyle(color: Colors.white))])),
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
        backgroundColor: const Color(0xFF8B5CF6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)]),
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
                      child: Text(_cliente!.tipo.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cliente!.direccion != null)
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('${_cliente!.direccion}${_cliente!.ciudad != null ? ', ${_cliente!.ciudad}' : ''}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13))),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_cliente!.telefono != null) ...[
                Icon(Icons.phone, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Text(_cliente!.telefono!, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                const SizedBox(width: 16),
              ],
              if (_cliente!.email != null) ...[
                Icon(Icons.email, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(_cliente!.email!, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ],
          ),
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
          _buildStatItem('Pedidos', '$_totalPedidos', const Color(0xFF8B5CF6)),
          _buildStatItem('Comprado', '\$${_totalComprado.toStringAsFixed(0)}', const Color(0xFF22C55E)),
          _buildStatItem('Saldo', '\$${_cliente!.saldoPendiente.toStringAsFixed(0)}', _cliente!.saldoPendiente > 0 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4)),
          _buildStatItem('Cotizaciones', '$_totalCotizaciones', const Color(0xFFFBBF24)),
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
        indicatorColor: const Color(0xFF8B5CF6),
        labelColor: const Color(0xFF8B5CF6),
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(icon: Icon(Icons.shopping_cart, size: 20), text: 'Pedidos'),
          Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'Créditos'),
          Tab(icon: Icon(Icons.people, size: 20), text: 'Contactos'),
          Tab(icon: Icon(Icons.folder, size: 20), text: 'Documentos'),
          Tab(icon: Icon(Icons.note, size: 20), text: 'Notas'),
          Tab(icon: Icon(Icons.request_quote, size: 20), text: 'Cotizaciones'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTabPedidos(),
        _buildTabCreditos(),
        _buildTabContactos(),
        _buildTabDocumentos(),
        _buildTabNotas(),
        _buildTabCotizaciones(),
      ],
    );
  }

  void _accionPorTab() {
    switch (_tabController.index) {
      case 0: _nuevoPedido(); break;
      case 1: _nuevoMovimientoCredito(); break;
      case 2: _nuevoContacto(); break;
      case 3: _nuevoDocumento(); break;
      case 4: _nuevaNota(); break;
      case 5: _nuevaCotizacion(); break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: PEDIDOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabPedidos() {
    if (_pedidos.isEmpty) {
      return _buildEmptyTab('Sin pedidos', Icons.shopping_cart_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pedidos.length,
      itemBuilder: (context, index) {
        final pedido = _pedidos[index];
        final estado = pedido['estado'] ?? 'pendiente';
        final total = (pedido['total'] ?? 0).toDouble();
        final fecha = pedido['created_at'] != null 
            ? DateTime.parse(pedido['created_at']).toString().substring(0, 10)
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
                  Text(pedido['folio'] ?? 'Sin folio', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildEstadoBadge(estado),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    String texto;
    switch (estado) {
      case 'pendiente': color = const Color(0xFFFBBF24); texto = 'Pendiente'; break;
      case 'procesando': color = const Color(0xFF06B6D4); texto = 'Procesando'; break;
      case 'enviado': color = const Color(0xFF8B5CF6); texto = 'Enviado'; break;
      case 'entregado': color = const Color(0xFF22C55E); texto = 'Entregado'; break;
      case 'cancelado': color = const Color(0xFFEF4444); texto = 'Cancelado'; break;
      default: color = Colors.grey; texto = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _nuevoPedido() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ir a pantalla de nuevo pedido'), backgroundColor: Color(0xFF8B5CF6)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: CRÉDITOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCreditos() {
    return Column(
      children: [
        // Info de crédito
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Límite de Crédito', style: TextStyle(color: Colors.white70)),
                  Text('\$${_cliente!.limiteCredito.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo Pendiente', style: TextStyle(color: Colors.white70)),
                  Text('\$${_cliente!.saldoPendiente.toStringAsFixed(2)}', style: TextStyle(color: _cliente!.saldoPendiente > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disponible', style: TextStyle(color: Colors.white70)),
                  Text('\$${(_cliente!.limiteCredito - _cliente!.saldoPendiente).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        // Historial
        Expanded(
          child: _creditos.isEmpty
              ? _buildEmptyTab('Sin movimientos', Icons.account_balance_wallet_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _creditos.length,
                  itemBuilder: (context, index) {
                    final mov = _creditos[index];
                    final tipo = mov['tipo'] ?? 'cargo';
                    final monto = (mov['monto'] ?? 0).toDouble();
                    final esAbono = tipo == 'abono' || tipo == 'pago';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(esAbono ? Icons.arrow_downward : Icons.arrow_upward, color: esAbono ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mov['concepto'] ?? tipo, style: const TextStyle(color: Colors.white)),
                                Text(mov['fecha'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('${esAbono ? '+' : '-'}\$${monto.toStringAsFixed(2)}', style: TextStyle(color: esAbono ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _nuevoMovimientoCredito() {
    final conceptoController = TextEditingController();
    final montoController = TextEditingController();
    String tipo = 'abono';

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
              const Text('Nuevo Movimiento', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => tipo = 'abono'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tipo == 'abono' ? const Color(0xFF22C55E).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tipo == 'abono' ? const Color(0xFF22C55E) : Colors.white24),
                        ),
                        child: Text('Abono/Pago', textAlign: TextAlign.center, style: TextStyle(color: tipo == 'abono' ? const Color(0xFF22C55E) : Colors.white70)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => tipo = 'cargo'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tipo == 'cargo' ? const Color(0xFFEF4444).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tipo == 'cargo' ? const Color(0xFFEF4444) : Colors.white24),
                        ),
                        child: Text('Cargo', textAlign: TextAlign.center, style: TextStyle(color: tipo == 'cargo' ? const Color(0xFFEF4444) : Colors.white70)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conceptoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Concepto',
                  labelStyle: const TextStyle(color: Colors.white54),
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
                    if (montoController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('ventas_cliente_creditos').insert({
                        'cliente_id': widget.clienteId,
                        'tipo': tipo,
                        'monto': double.parse(montoController.text),
                        'concepto': conceptoController.text.isEmpty ? (tipo == 'abono' ? 'Pago recibido' : 'Cargo') : conceptoController.text,
                        'fecha': DateTime.now().toIso8601String().substring(0, 10),
                      });
                      Navigator.pop(context);
                      _cargarCreditos();
                      _cargarCliente();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
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
  // TAB: CONTACTOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabContactos() {
    if (_contactos.isEmpty) {
      return _buildEmptyTab('Sin contactos', Icons.people_outline);
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
            border: esPrincipal ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                    child: Text(
                      (contacto['nombre'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF8B5CF6)),
                    ),
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
                                decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        if (contacto['cargo'] != null)
                          Text(contacto['cargo'], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contacto['telefono'] != null)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Color(0xFF22C55E), size: 20),
                          onPressed: () async {
                            final uri = Uri.parse('tel:${contacto['telefono']}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      if (contacto['whatsapp'] != null || contacto['telefono'] != null)
                        IconButton(
                          icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                          onPressed: () async {
                            final numero = contacto['whatsapp'] ?? contacto['telefono'];
                            final uri = Uri.parse('https://wa.me/52$numero');
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        ),
                    ],
                  ),
                ],
              ),
              if (contacto['email'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Text(contacto['email'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _nuevoContacto() {
    final nombreController = TextEditingController();
    final cargoController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();
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
              _buildTextField(cargoController, 'Cargo (ej: Compras, Gerente)'),
              const SizedBox(height: 12),
              _buildTextField(telefonoController, 'Teléfono', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(emailController, 'Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: esPrincipal,
                onChanged: (v) => setModalState(() => esPrincipal = v ?? false),
                title: const Text('Contacto Principal', style: TextStyle(color: Colors.white)),
                activeColor: const Color(0xFF8B5CF6),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nombreController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('ventas_cliente_contactos').insert({
                        'cliente_id': widget.clienteId,
                        'nombre': nombreController.text,
                        'cargo': cargoController.text.isEmpty ? null : cargoController.text,
                        'telefono': telefonoController.text.isEmpty ? null : telefonoController.text,
                        'whatsapp': telefonoController.text.isEmpty ? null : telefonoController.text,
                        'email': emailController.text.isEmpty ? null : emailController.text,
                        'es_principal': esPrincipal,
                      });
                      Navigator.pop(context);
                      _cargarContactos();
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
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
        final tipo = doc['tipo'] ?? 'otro';
        IconData icono;
        Color color;
        
        switch (tipo) {
          case 'factura': icono = Icons.receipt_long; color = const Color(0xFF22C55E); break;
          case 'contrato': icono = Icons.description; color = const Color(0xFF8B5CF6); break;
          case 'identificacion': icono = Icons.badge; color = const Color(0xFF06B6D4); break;
          case 'comprobante': icono = Icons.home; color = const Color(0xFFFBBF24); break;
          default: icono = Icons.insert_drive_file; color = Colors.white54;
        }

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
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['nombre'] ?? 'Documento', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(tipo.toUpperCase(), style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.download, color: Colors.white54), onPressed: () {}),
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
                  DropdownMenuItem(value: 'factura', child: Text('Factura')),
                  DropdownMenuItem(value: 'contrato', child: Text('Contrato')),
                  DropdownMenuItem(value: 'identificacion', child: Text('Identificación')),
                  DropdownMenuItem(value: 'comprobante', child: Text('Comprobante Domicilio')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                ],
                onChanged: (v) => setModalState(() => tipo = v ?? 'otro'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implementar selección de archivo
                      },
                      icon: const Icon(Icons.attach_file, color: Color(0xFF8B5CF6)),
                      label: const Text('Seleccionar Archivo', style: TextStyle(color: Color(0xFF8B5CF6))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nombreController.text.isEmpty) return;
                    try {
                      await AppSupabase.client.from('ventas_cliente_documentos').insert({
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
                    backgroundColor: const Color(0xFF8B5CF6),
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
                  Text(nota['autor'] ?? 'Sistema', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13)),
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
                    await AppSupabase.client.from('ventas_cliente_notas').insert({
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
                  backgroundColor: const Color(0xFF8B5CF6),
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
  // TAB: COTIZACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCotizaciones() {
    if (_cotizaciones.isEmpty) {
      return _buildEmptyTab('Sin cotizaciones', Icons.request_quote_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cotizaciones.length,
      itemBuilder: (context, index) {
        final cot = _cotizaciones[index];
        final estado = cot['estado'] ?? 'borrador';
        final total = (cot['total'] ?? 0).toDouble();
        final fecha = cot['created_at'] != null
            ? DateTime.parse(cot['created_at']).toString().substring(0, 10)
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
                  Text(cot['folio'] ?? 'Sin folio', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildEstadoCotizacion(estado),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (cot['vigencia'] != null) ...[
                const SizedBox(height: 4),
                Text('Vigente hasta: ${cot['vigencia']}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoCotizacion(String estado) {
    Color color;
    String texto;
    switch (estado) {
      case 'borrador': color = Colors.grey; texto = 'Borrador'; break;
      case 'enviada': color = const Color(0xFF06B6D4); texto = 'Enviada'; break;
      case 'aceptada': color = const Color(0xFF22C55E); texto = 'Aceptada'; break;
      case 'rechazada': color = const Color(0xFFEF4444); texto = 'Rechazada'; break;
      case 'vencida': color = const Color(0xFFFBBF24); texto = 'Vencida'; break;
      default: color = Colors.grey; texto = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _nuevaCotizacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ir a pantalla de nueva cotización'), backgroundColor: Color(0xFF8B5CF6)),
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

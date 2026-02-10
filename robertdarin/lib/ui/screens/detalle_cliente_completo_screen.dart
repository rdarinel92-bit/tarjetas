// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DETALLE CLIENTE COMPLETO - Robert Darin Platform v10.18
/// Info, estado de cuenta, préstamos, tandas, pagos, documentos KYC
/// ═══════════════════════════════════════════════════════════════════════════════
class DetalleClienteCompletoScreen extends StatefulWidget {
  final String clienteId;
  const DetalleClienteCompletoScreen({super.key, required this.clienteId});

  @override
  State<DetalleClienteCompletoScreen> createState() => _DetalleClienteCompletoScreenState();
}

class _DetalleClienteCompletoScreenState extends State<DetalleClienteCompletoScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late TabController _tabController;
  
  bool _isLoading = true;
  Map<String, dynamic> _cliente = {};
  List<Map<String, dynamic>> _prestamos = [];
  List<Map<String, dynamic>> _tandas = [];
  List<Map<String, dynamic>> _pagos = [];
  List<Map<String, dynamic>> _documentos = [];
  
  // Estadísticas
  double _deudaTotal = 0;
  double _totalPagado = 0;
  int _prestamosActivos = 0;
  int _tandasActivas = 0;
  int _score = 500;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar cliente
      final cliRes = await AppSupabase.client
          .from('clientes')
          .select('*, usuarios(*), sucursales(*)')
          .eq('id', widget.clienteId)
          .single();
      _cliente = cliRes;
      _score = (_cliente['score_crediticio'] ?? 500);

      // Cargar préstamos
      final prestRes = await AppSupabase.client
          .from('prestamos')
          .select('*, amortizaciones(*)')
          .eq('cliente_id', widget.clienteId)
          .order('created_at', ascending: false);
      _prestamos = List<Map<String, dynamic>>.from(prestRes);
      
      for (var p in _prestamos) {
        if (p['estado'] == 'activo') {
          _prestamosActivos++;
          _deudaTotal += (p['saldo_pendiente'] ?? 0).toDouble();
        }
      }

      // Cargar tandas
      try {
        final tandaRes = await AppSupabase.client
            .from('tanda_participantes')
            .select('*, tandas(*)')
            .eq('cliente_id', widget.clienteId)
            .order('created_at', ascending: false);
        _tandas = List<Map<String, dynamic>>.from(tandaRes);
        _tandasActivas = _tandas.where((t) => t['tandas']?['estado'] == 'activa').length;
      } catch (e) {
        debugPrint('Error cargando tandas: $e');
      }

      // Cargar pagos
      final pagosRes = await AppSupabase.client
          .from('pagos')
          .select('*, prestamos(*)')
          .eq('cliente_id', widget.clienteId)
          .order('fecha_pago', ascending: false)
          .limit(50);
      _pagos = List<Map<String, dynamic>>.from(pagosRes);
      
      for (var p in _pagos) {
        if (p['estado'] == 'completado') {
          _totalPagado += (p['monto'] ?? 0).toDouble();
        }
      }

      // Cargar documentos KYC
      try {
        final docsRes = await AppSupabase.client
            .from('documentos_cliente')
            .select()
            .eq('cliente_id', widget.clienteId)
            .order('created_at', ascending: false);
        _documentos = List<Map<String, dynamic>>.from(docsRes);
      } catch (e) {
        debugPrint('Tabla documentos_cliente no existe: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando cliente: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 700) return const Color(0xFF10B981);
    if (score >= 500) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getScoreLabel(int score) {
    if (score >= 700) return 'Excelente';
    if (score >= 600) return 'Bueno';
    if (score >= 500) return 'Regular';
    return 'Riesgoso';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _cliente['nombre'] ?? 'Cliente';
    
    return PremiumScaffold(
      title: nombre,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () => _mostrarEditarCliente(),
        ),
        IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _llamarCliente(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'whatsapp': _abrirWhatsApp(); break;
              case 'estado_cuenta': _generarEstadoCuenta(); break;
              case 'nuevo_prestamo': _nuevoPrestamo(); break;
              case 'bloquear': _toggleBloqueo(); break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'whatsapp', child: Text('💬 WhatsApp')),
            const PopupMenuItem(value: 'estado_cuenta', child: Text('📄 Estado de Cuenta')),
            const PopupMenuItem(value: 'nuevo_prestamo', child: Text('💰 Nuevo Préstamo')),
            PopupMenuItem(
              value: 'bloquear',
              child: Text(_cliente['activo'] == true ? '🔴 Bloquear' : '🟢 Desbloquear'),
            ),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildStats(),
                _buildTabs(),
                Expanded(child: _buildTabContent()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _registrarPago(),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.payments),
        label: const Text('Registrar Pago'),
      ),
    );
  }

  Widget _buildHeader() {
    final nombre = _cliente['nombre'] ?? 'Sin nombre';
    final telefono = _cliente['telefono'] ?? '';
    final email = _cliente['email'] ?? '';
    final activo = _cliente['activo'] == true;
    final scoreColor = _getScoreColor(_score);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activo 
              ? [const Color(0xFF1E3A5F), const Color(0xFF0D47A1)]
              : [const Color(0xFF5D0000), const Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        if (!activo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: const Text('BLOQUEADO', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                      ],
                    ),
                    if (telefono.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(telefono, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.email, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score Crediticio', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('$_score', style: TextStyle(color: scoreColor, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: scoreColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(_getScoreLabel(_score), style: TextStyle(color: scoreColor, fontSize: 11)),
                      ),
                    ]),
                  ],
                ),
                Column(
                  children: [
                    IconButton(icon: Icon(Icons.add_circle, color: scoreColor), onPressed: () => _ajustarScore(10), tooltip: '+10'),
                    IconButton(icon: Icon(Icons.remove_circle, color: Colors.red.withOpacity(0.7)), onPressed: () => _ajustarScore(-10), tooltip: '-10'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _buildStatCard('Deuda', _currencyFormat.format(_deudaTotal), Icons.credit_card, const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        _buildStatCard('Pagado', _currencyFormat.format(_totalPagado), Icons.check_circle, const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _buildStatCard('Préstamos', '$_prestamosActivos', Icons.attach_money, const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _buildStatCard('Tandas', '$_tandasActivas', Icons.group_work, const Color(0xFF8B5CF6)),
      ]),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(10)),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11),
        tabs: const [Tab(text: 'Info'), Tab(text: 'Préstamos'), Tab(text: 'Tandas'), Tab(text: 'Pagos'), Tab(text: 'Docs')],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(controller: _tabController, children: [
      _buildInfoTab(),
      _buildPrestamosTab(),
      _buildTandasTab(),
      _buildPagosTab(),
      _buildDocumentosTab(),
    ]);
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildInfoSection('Datos Personales', [
          _buildInfoRow('Nombre', _cliente['nombre'] ?? 'No especificado'),
          _buildInfoRow('Teléfono', _cliente['telefono'] ?? 'No especificado'),
          _buildInfoRow('Email', _cliente['email'] ?? 'No especificado'),
          _buildInfoRow('CURP', _cliente['curp'] ?? 'No especificado'),
          _buildInfoRow('RFC', _cliente['rfc'] ?? 'No especificado'),
        ]),
        const SizedBox(height: 16),
        _buildInfoSection('Dirección', [
          _buildInfoRow('Calle', _cliente['direccion'] ?? 'No especificada'),
          _buildInfoRow('Colonia', _cliente['colonia'] ?? 'No especificada'),
          _buildInfoRow('Ciudad', _cliente['ciudad'] ?? 'No especificada'),
          _buildInfoRow('C.P.', _cliente['codigo_postal'] ?? 'No especificado'),
        ]),
        const SizedBox(height: 16),
        _buildInfoSection('Laboral', [
          _buildInfoRow('Ocupación', _cliente['ocupacion'] ?? 'No especificada'),
          _buildInfoRow('Empresa', _cliente['empresa'] ?? 'No especificada'),
          _buildInfoRow('Ingreso', _cliente['ingreso_mensual'] != null ? _currencyFormat.format(_cliente['ingreso_mensual']) : 'No especificado'),
        ]),
      ]),
    );
  }

  Widget _buildInfoSection(String titulo, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
        Flexible(child: Text(value, style: const TextStyle(color: Colors.white), textAlign: TextAlign.end)),
      ]),
    );
  }

  Widget _buildPrestamosTab() {
    if (_prestamos.isEmpty) return _buildEmptyState('Sin préstamos', Icons.credit_card_off);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prestamos.length,
      itemBuilder: (context, index) {
        final p = _prestamos[index];
        final monto = (p['monto_principal'] ?? 0).toDouble();
        final saldo = (p['saldo_pendiente'] ?? 0).toDouble();
        final estado = p['estado'] ?? 'activo';
        Color estadoColor = estado == 'pagado' ? Colors.green : (estado == 'vencido' ? Colors.red : Colors.blue);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: estadoColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.credit_card, color: estadoColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_currencyFormat.format(monto), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Saldo: ${_currencyFormat.format(saldo)}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: estadoColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(estado.toUpperCase(), style: TextStyle(color: estadoColor, fontSize: 10)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildTandasTab() {
    if (_tandas.isEmpty) return _buildEmptyState('Sin tandas', Icons.group_work);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tandas.length,
      itemBuilder: (context, index) {
        final t = _tandas[index];
        final tanda = t['tandas'] ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.group_work, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(tanda['nombre'] ?? 'Tanda', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text('Turno ${t['numero_turno'] ?? 0}', style: const TextStyle(color: Color(0xFF8B5CF6))),
          ]),
        );
      },
    );
  }

  Widget _buildPagosTab() {
    if (_pagos.isEmpty) return _buildEmptyState('Sin pagos', Icons.receipt_long);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pagos.length,
      itemBuilder: (context, index) {
        final p = _pagos[index];
        final monto = (p['monto'] ?? 0).toDouble();
        final fecha = p['fecha_pago'] != null ? DateTime.parse(p['fecha_pago']) : DateTime.now();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(DateFormat('dd/MM/yyyy').format(fecha), style: const TextStyle(color: Colors.white))),
            Text(_currencyFormat.format(monto), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }

  Widget _buildDocumentosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Agregar Documento'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), minimumSize: const Size(double.infinity, 50)),
        ),
        const SizedBox(height: 20),
        _buildDocItem('INE Frente', _documentos.any((d) => d['tipo'] == 'ine_frente')),
        _buildDocItem('INE Reverso', _documentos.any((d) => d['tipo'] == 'ine_reverso')),
        _buildDocItem('Comprobante Domicilio', _documentos.any((d) => d['tipo'] == 'comprobante_domicilio')),
        _buildDocItem('Comprobante Ingresos', _documentos.any((d) => d['tipo'] == 'comprobante_ingresos')),
      ]),
    );
  }

  Widget _buildDocItem(String nombre, bool tiene) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tiene ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(tiene ? Icons.check_circle : Icons.cancel, color: tiene ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Text(nombre, style: const TextStyle(color: Colors.white)),
        const Spacer(),
        if (!tiene) TextButton(onPressed: () {}, child: const Text('Subir')),
      ]),
    );
  }

  Widget _buildEmptyState(String mensaje, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.white.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(mensaje, style: TextStyle(color: Colors.white.withOpacity(0.5))),
    ]));
  }

  void _mostrarEditarCliente() => Navigator.pushNamed(context, '/formularioCliente', arguments: widget.clienteId);
  void _llamarCliente() => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Llamando a ${_cliente['telefono']}...')));
  void _abrirWhatsApp() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abriendo WhatsApp...')));
  void _generarEstadoCuenta() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando estado de cuenta...')));
  void _nuevoPrestamo() => Navigator.pushNamed(context, '/formularioPrestamo');
  void _registrarPago() => Navigator.pushNamed(context, '/registrarCobro', arguments: {'clienteId': widget.clienteId, 'clienteNombre': _cliente['nombre']});
  
  void _toggleBloqueo() async {
    final nuevoEstado = !(_cliente['activo'] == true);
    await AppSupabase.client.from('clientes').update({'activo': nuevoEstado}).eq('id', widget.clienteId);
    _cargarDatos();
  }

  void _ajustarScore(int delta) async {
    final nuevoScore = (_score + delta).clamp(0, 850);
    await AppSupabase.client.from('clientes').update({'score_crediticio': nuevoScore}).eq('id', widget.clienteId);
    _cargarDatos();
  }
}

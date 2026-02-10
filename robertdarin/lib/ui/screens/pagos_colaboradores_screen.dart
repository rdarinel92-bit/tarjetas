// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';
import '../../data/models/compensacion_models.dart';
import 'package:intl/intl.dart';

/// Pantalla para registrar y ver pagos a colaboradores
class PagosColaboradoresScreen extends StatefulWidget {
  const PagosColaboradoresScreen({super.key});

  @override
  State<PagosColaboradoresScreen> createState() =>
      _PagosColaboradoresScreenState();
}

class _PagosColaboradoresScreenState extends State<PagosColaboradoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ColaboradorPagoModel> _pagos = [];
  String _filtroEstado = 'todos';

  final _formatoMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _filtroEstado = 'todos';
              break;
            case 1:
              _filtroEstado = 'pendiente';
              break;
            case 2:
              _filtroEstado = 'aprobado';
              break;
            case 3:
              _filtroEstado = 'pagado';
              break;
          }
        });
      }
    });
    _cargarPagos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarPagos() async {
    try {
      var query = AppSupabase.client
          .from('colaborador_pagos')
          .select('*, colaboradores(nombre, email)');

      final res = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pagos = (res as List)
              .map((e) => ColaboradorPagoModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ColaboradorPagoModel> get _pagosFiltrados {
    if (_filtroEstado == 'todos') return _pagos;
    return _pagos.where((p) => p.estado == _filtroEstado).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Pagos a Colaboradores',
      subtitle: 'Historial y pagos pendientes',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: _mostrarNuevoPago,
          tooltip: 'Nuevo pago',
        ),
      ],
      body: Column(
        children: [
          _buildResumen(),
          const SizedBox(height: 8),
          _buildTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildListaPagos(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final pendientes =
        _pagos.where((p) => p.estado == 'pendiente').toList();
    final montoPendiente =
        pendientes.fold<double>(0, (sum, p) => sum + p.montoTotal);
    final pagadosMes = _pagos
        .where((p) =>
            p.estado == 'pagado' &&
            p.fechaPago != null &&
            p.fechaPago!.month == DateTime.now().month)
        .toList();
    final montoPagadoMes =
        pagadosMes.fold<double>(0, (sum, p) => sum + p.montoTotal);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.pending_actions, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  _formatoMoneda.format(montoPendiente),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Por Pagar',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                const SizedBox(height: 4),
                Text(
                  _formatoMoneda.format(montoPagadoMes),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Pagado este Mes',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  pendientes.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Pendientes',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF8B5CF6),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            text: 'Todos (${_pagos.length})',
          ),
          Tab(
            text:
                'Pendientes (${_pagos.where((p) => p.estado == 'pendiente').length})',
          ),
          Tab(
            text:
                'Aprobados (${_pagos.where((p) => p.estado == 'aprobado').length})',
          ),
          Tab(
            text:
                'Pagados (${_pagos.where((p) => p.estado == 'pagado').length})',
          ),
        ],
      ),
    );
  }

  Widget _buildListaPagos() {
    final pagos = _pagosFiltrados;

    if (pagos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              _filtroEstado == 'todos'
                  ? 'No hay pagos registrados'
                  : 'No hay pagos $_filtroEstado',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarPagos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pagos.length,
        itemBuilder: (context, index) => _buildPagoCard(pagos[index]),
      ),
    );
  }

  Widget _buildPagoCard(ColaboradorPagoModel pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pago.estadoColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _mostrarDetallePago(pago),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: pago.estadoColor.withOpacity(0.2),
                    child: Icon(pago.estadoIcon, color: pago.estadoColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pago.colaboradorNombre ?? 'Colaborador',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_formatoFecha.format(pago.periodoInicio)} - ${_formatoFecha.format(pago.periodoFin)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatoMoneda.format(pago.montoTotal),
                        style: TextStyle(
                          color: pago.estadoColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pago.estadoColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pago.estadoLabel,
                          style: TextStyle(
                            color: pago.estadoColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (pago.montoBase > 0 ||
                  pago.montoComisiones > 0 ||
                  pago.montoBonos > 0) ...[
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (pago.montoBase > 0)
                      _buildDesglose('Base', pago.montoBase),
                    if (pago.montoComisiones > 0)
                      _buildDesglose('Comisiones', pago.montoComisiones),
                    if (pago.montoBonos > 0)
                      _buildDesglose('Bonos', pago.montoBonos),
                  ],
                ),
              ],
              if (pago.estado == 'pendiente') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _aprobarPago(pago),
                      icon: const Icon(Icons.thumb_up, size: 16),
                      label: const Text('Aprobar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _registrarPago(pago),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Pagar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (pago.estado == 'aprobado') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _registrarPago(pago),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Marcar como Pagado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesglose(String label, double monto) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          _formatoMoneda.format(monto),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  void _mostrarDetallePago(ColaboradorPagoModel pago) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: pago.estadoColor.withOpacity(0.2),
                  radius: 24,
                  child: Icon(pago.estadoIcon, color: pago.estadoColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pago.colaboradorNombre ?? 'Colaborador',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pago.estadoColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pago.estadoLabel,
                          style: TextStyle(
                            color: pago.estadoColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetalleRow('Período',
                '${_formatoFecha.format(pago.periodoInicio)} - ${_formatoFecha.format(pago.periodoFin)}'),
            _buildDetalleRow('Monto Base', _formatoMoneda.format(pago.montoBase)),
            _buildDetalleRow(
                'Comisiones', _formatoMoneda.format(pago.montoComisiones)),
            _buildDetalleRow('Bonos', _formatoMoneda.format(pago.montoBonos)),
            if (pago.montoAjustes != 0)
              _buildDetalleRow(
                  'Ajustes', _formatoMoneda.format(pago.montoAjustes)),
            const Divider(color: Colors.white24, height: 32),
            _buildDetalleRow(
              'TOTAL',
              _formatoMoneda.format(pago.montoTotal),
              destacado: true,
            ),
            if (pago.fechaPago != null) ...[
              const SizedBox(height: 16),
              _buildDetalleRow(
                  'Fecha de pago', _formatoFecha.format(pago.fechaPago!)),
              if (pago.metodoPago != null)
                _buildDetalleRow('Método', pago.metodoPago!),
              if (pago.referenciaPago != null)
                _buildDetalleRow('Referencia', pago.referenciaPago!),
            ],
            if (pago.notas != null && pago.notas!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Notas:',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(pago.notas!,
                  style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: destacado ? Colors.white : Colors.white54,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: destacado ? const Color(0xFF8B5CF6) : Colors.white,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
              fontSize: destacado ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aprobarPago(ColaboradorPagoModel pago) async {
    try {
      await AppSupabase.client.from('colaborador_pagos').update({
        'estado': 'aprobado',
        'fecha_aprobacion': DateTime.now().toIso8601String(),
      }).eq('id', pago.id);

      _cargarPagos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pago aprobado'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _registrarPago(ColaboradorPagoModel pago) async {
    final metodo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Método de Pago',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue),
              title: const Text('Transferencia',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Transferencia'),
            ),
            ListTile(
              leading: const Icon(Icons.payments, color: Colors.green),
              title:
                  const Text('Efectivo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Efectivo'),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.orange),
              title:
                  const Text('Cheque', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'Cheque'),
            ),
          ],
        ),
      ),
    );

    if (metodo == null) return;

    try {
      await AppSupabase.client.from('colaborador_pagos').update({
        'estado': 'pagado',
        'fecha_pago': DateTime.now().toIso8601String(),
        'metodo_pago': metodo,
      }).eq('id', pago.id);

      _cargarPagos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pago registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _mostrarNuevoPago() {
    // Implementar sheet para crear nuevo pago manual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💡 Los pagos se generan automáticamente según las compensaciones configuradas'),
      ),
    );
  }
}

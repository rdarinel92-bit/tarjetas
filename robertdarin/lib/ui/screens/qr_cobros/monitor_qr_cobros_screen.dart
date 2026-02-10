// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA MONITOR QR COBROS - ADMIN/SUPERADMIN
/// Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Dashboard para monitorear todos los cobros con QR en tiempo real
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../components/premium_scaffold.dart';
import '../../../core/supabase_client.dart';
import '../../../services/qr_cobros_service.dart';
import '../../../data/models/qr_cobro_model.dart';

class MonitorQrCobrosScreen extends StatefulWidget {
  final String negocioId;
  
  const MonitorQrCobrosScreen({
    super.key,
    required this.negocioId,
  });

  @override
  State<MonitorQrCobrosScreen> createState() => _MonitorQrCobrosScreenState();
}

class _MonitorQrCobrosScreenState extends State<MonitorQrCobrosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<QrCobroModel> _todosLosCobros = [];
  Map<String, dynamic> _resumen = {};
  Timer? _refreshTimer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
    _iniciarActualizacionEnTiempoReal();
    
    // Actualizar cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarDatos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _iniciarActualizacionEnTiempoReal() {
    // Suscribirse a cambios en tiempo real
    _subscription = AppSupabase.client
        .from('qr_cobros')
        .stream(primaryKey: ['id'])
        .eq('negocio_id', widget.negocioId)
        .listen((data) {
          if (mounted) {
            setState(() {
              _todosLosCobros = data.map((e) => QrCobroModel.fromMap(e)).toList();
            });
          }
        });
  }

  Future<void> _cargarDatos() async {
    try {
      final cobros = await QrCobrosService.obtenerHistorialNegocio(widget.negocioId);
      final resumen = await QrCobrosService.obtenerResumenDia(widget.negocioId);

      if (mounted) {
        setState(() {
          _todosLosCobros = cobros;
          _resumen = resumen;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<QrCobroModel> _filtrarPorEstado(String estado) {
    if (estado == 'todos') return _todosLosCobros;
    return _todosLosCobros.where((c) => c.estado == estado).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Monitor de Cobros QR',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : Column(
              children: [
                _buildResumenCards(),
                _buildTabBar(),
                Expanded(child: _buildTabBarView()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cargarDatos,
        backgroundColor: const Color(0xFF00D9FF),
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }

  Widget _buildResumenCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniCard(
              'Hoy',
              '${_resumen['total_generados'] ?? 0}',
              Icons.qr_code,
              const Color(0xFF00D9FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMiniCard(
              'Confirmados',
              '\$${NumberFormat('#,##0').format(_resumen['monto_confirmado'] ?? 0)}',
              Icons.check_circle,
              const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMiniCard(
              'Pendientes',
              '${_resumen['pendientes'] ?? 0}',
              Icons.pending,
              const Color(0xFFFBBF24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF00D9FF),
        indicatorWeight: 3,
        labelColor: const Color(0xFF00D9FF),
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Todos'),
          Tab(text: 'Pendientes'),
          Tab(text: 'Confirmados'),
          Tab(text: 'Expirados'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListaCobros(_filtrarPorEstado('todos')),
        _buildListaCobros(_filtrarPorEstado('pendiente')),
        _buildListaCobros(_filtrarPorEstado('confirmado')),
        _buildListaCobros(_filtrarPorEstado('expirado')),
      ],
    );
  }

  Widget _buildListaCobros(List<QrCobroModel> cobros) {
    if (cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No hay cobros',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: const Color(0xFF00D9FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cobros.length,
        itemBuilder: (ctx, i) => _buildCobroCard(cobros[i]),
      ),
    );
  }

  Widget _buildCobroCard(QrCobroModel cobro) {
    final colorEstado = _getColorEstado(cobro.estado);
    final iconEstado = _getIconEstado(cobro.estado);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorEstado.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalle(cobro),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconEstado, color: colorEstado, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cobro.clienteNombre ?? 'Cliente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            cobro.concepto,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${cobro.monto.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: colorEstado,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          cobro.tipoCobroDisplay,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Estado de confirmaciones
                Row(
                  children: [
                    _buildConfirmacionChip(
                      'Cobrador',
                      cobro.cobradorConfirmo,
                    ),
                    const SizedBox(width: 8),
                    _buildConfirmacionChip(
                      'Cliente',
                      cobro.clienteConfirmo,
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd/MM HH:mm').format(cobro.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Código QR
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cobro.codigoQr,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmacionChip(String label, bool confirmado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confirmado
            ? const Color(0xFF10B981).withOpacity(0.2)
            : Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmado ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: confirmado ? const Color(0xFF10B981) : Colors.white38,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: confirmado ? const Color(0xFF10B981) : Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'confirmado':
        return const Color(0xFF10B981);
      case 'pendiente':
        return const Color(0xFFFBBF24);
      case 'expirado':
        return const Color(0xFFEF4444);
      case 'cancelado':
        return Colors.grey;
      case 'rechazado':
        return const Color(0xFFEF4444);
      default:
        return Colors.white54;
    }
  }

  IconData _getIconEstado(String estado) {
    switch (estado) {
      case 'confirmado':
        return Icons.check_circle;
      case 'pendiente':
        return Icons.pending;
      case 'expirado':
        return Icons.timer_off;
      case 'cancelado':
        return Icons.cancel;
      case 'rechazado':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  void _mostrarDetalle(QrCobroModel cobro) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DetalleCobroSheet(cobro: cobro),
    );
  }
}

class _DetalleCobroSheet extends StatelessWidget {
  final QrCobroModel cobro;

  const _DetalleCobroSheet({required this.cobro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 20),
          const Text(
            'Detalle del Cobro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildFila('Cliente', cobro.clienteNombre ?? 'N/A'),
          _buildFila('Cobrador', cobro.cobradorNombre ?? 'N/A'),
          _buildFila('Concepto', cobro.concepto),
          _buildFila('Tipo', cobro.tipoCobroDisplay),
          _buildFila('Monto', '\$${cobro.monto.toStringAsFixed(2)}'),
          _buildFila('Código QR', cobro.codigoQr),
          _buildFila('Estado', cobro.estadoDetallado),
          _buildFila(
            'Fecha',
            DateFormat('dd/MM/yyyy HH:mm').format(cobro.createdAt),
          ),
          if (cobro.cobradorConfirmoAt != null)
            _buildFila(
              'Confirmó Cobrador',
              DateFormat('HH:mm').format(cobro.cobradorConfirmoAt!),
            ),
          if (cobro.clienteConfirmoAt != null)
            _buildFila(
              'Confirmó Cliente',
              DateFormat('HH:mm').format(cobro.clienteConfirmoAt!),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Flexible(
            child: Text(
              valor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

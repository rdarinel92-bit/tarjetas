// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DASHBOARD ADMINISTRATIVO CLIMAS - V1.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Panel de control avanzado para administradores con:
/// - KPIs en tiempo real
/// - Métricas de técnicos
/// - Control de inventario
/// - Solicitudes de clientes
/// - Comisiones pendientes
/// - Calendario de servicios
/// - Alertas y notificaciones
/// ═══════════════════════════════════════════════════════════════════════════════

class ClimasAdminDashboardScreen extends StatefulWidget {
  const ClimasAdminDashboardScreen({super.key});

  @override
  State<ClimasAdminDashboardScreen> createState() => _ClimasAdminDashboardScreenState();
}

class _ClimasAdminDashboardScreenState extends State<ClimasAdminDashboardScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  
  // KPIs principales
  int _totalClientes = 0;
  int _totalTecnicos = 0;
  int _ordenesHoy = 0;
  int _ordenesSemana = 0;
  int _ordenesPendientes = 0;
  int _ordenesEnProceso = 0;
  double _ingresosHoy = 0;
  double _ingresosSemana = 0;
  double _ingresosMes = 0;
  
  // Alertas
  int _solicitudesNuevas = 0;
  int _stockBajo = 0;
  int _incidenciasAbiertas = 0;
  int _comisionesPendientes = 0;
  int _garantiasPorVencer = 0;
  
  // Datos
  List<Map<String, dynamic>> _ordenesRecientes = [];
  List<Map<String, dynamic>> _solicitudesRecientes = [];
  List<Map<String, dynamic>> _tecnicosConMetricas = [];
  List<Map<String, dynamic>> _productosStockBajo = [];
  List<Map<String, dynamic>> _incidenciasRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final hoy = DateTime.now();
      final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
      final inicioMes = DateTime(hoy.year, hoy.month, 1);

      // Total clientes
      try {
        final clientesRes = await AppSupabase.client.from('climas_clientes').select('id').eq('activo', true);
        _totalClientes = (clientesRes as List).length;
      } catch (_) {}

      // Total técnicos
      try {
        final tecnicosRes = await AppSupabase.client.from('climas_tecnicos').select('id').eq('activo', true);
        _totalTecnicos = (tecnicosRes as List).length;
      } catch (_) {}

      // Órdenes de hoy
      try {
        final ordenesHoyRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('id, estado, total')
            .gte('fecha_programada', '${hoy.toIso8601String().split('T')[0]}T00:00:00')
            .lte('fecha_programada', '${hoy.toIso8601String().split('T')[0]}T23:59:59');
        final listaHoy = ordenesHoyRes as List;
        _ordenesHoy = listaHoy.length;
        _ingresosHoy = listaHoy.where((o) => o['estado'] == 'completada').fold(0.0, (sum, o) => sum + (o['total'] ?? 0).toDouble());
      } catch (_) {}

      // Órdenes de la semana
      try {
        final ordenesSemanaRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('id, estado, total')
            .gte('fecha_programada', inicioSemana.toIso8601String());
        final listaSemana = ordenesSemanaRes as List;
        _ordenesSemana = listaSemana.length;
        _ingresosSemana = listaSemana.where((o) => o['estado'] == 'completada').fold(0.0, (sum, o) => sum + (o['total'] ?? 0).toDouble());
      } catch (_) {}

      // Ingresos del mes
      try {
        final ordenesMesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('total')
            .eq('estado', 'completada')
            .gte('fecha_fin', inicioMes.toIso8601String());
        _ingresosMes = (ordenesMesRes as List).fold(0.0, (sum, o) => sum + (o['total'] ?? 0).toDouble());
      } catch (_) {}

      // Órdenes pendientes y en proceso
      try {
        final pendientesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('id, estado')
            .inFilter('estado', ['pendiente', 'asignada', 'en_proceso']);
        final lista = pendientesRes as List;
        _ordenesPendientes = lista.where((o) => o['estado'] == 'pendiente' || o['estado'] == 'asignada').length;
        _ordenesEnProceso = lista.where((o) => o['estado'] == 'en_proceso').length;
      } catch (_) {}

      // Solicitudes nuevas
      try {
        final solicitudesRes = await AppSupabase.client
            .from('climas_solicitudes_cliente')
            .select('id')
            .eq('estado', 'nueva');
        _solicitudesNuevas = (solicitudesRes as List).length;
      } catch (_) {}

      // Productos con stock bajo
      try {
        final stockRes = await AppSupabase.client
            .from('climas_productos')
            .select('id, nombre, stock, stock_minimo')
            .eq('activo', true);
        _productosStockBajo = (stockRes as List)
            .where((p) => (p['stock'] ?? 0) <= (p['stock_minimo'] ?? 5))
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        _stockBajo = _productosStockBajo.length;
      } catch (_) {}

      // Incidencias abiertas
      try {
        final incidenciasRes = await AppSupabase.client
            .from('climas_incidencias')
            .select('*, climas_tecnicos(nombre), climas_ordenes_servicio(folio)')
            .eq('estado', 'abierta')
            .order('created_at', ascending: false)
            .limit(5);
        _incidenciasRecientes = List<Map<String, dynamic>>.from(incidenciasRes);
        _incidenciasAbiertas = _incidenciasRecientes.length;
      } catch (_) {}

      // Comisiones pendientes
      try {
        final comisionesRes = await AppSupabase.client
            .from('climas_comisiones')
            .select('id')
            .eq('estado', 'pendiente');
        _comisionesPendientes = (comisionesRes as List).length;
      } catch (_) {}

      // Garantías por vencer (próximos 30 días)
      try {
        final garantiasRes = await AppSupabase.client
            .from('climas_garantias')
            .select('id')
            .eq('activa', true)
            .lte('fecha_fin', hoy.add(const Duration(days: 30)).toIso8601String().split('T')[0])
            .gte('fecha_fin', hoy.toIso8601String().split('T')[0]);
        _garantiasPorVencer = (garantiasRes as List).length;
      } catch (_) {}

      // Órdenes recientes
      try {
        final ordenesRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_clientes(nombre), climas_tecnicos(nombre)')
            .order('created_at', ascending: false)
            .limit(5);
        _ordenesRecientes = List<Map<String, dynamic>>.from(ordenesRes);
      } catch (_) {}

      // Solicitudes recientes
      try {
        final solRecientes = await AppSupabase.client
            .from('climas_solicitudes_cliente')
            .select('*, climas_clientes(nombre)')
            .order('created_at', ascending: false)
            .limit(5);
        _solicitudesRecientes = List<Map<String, dynamic>>.from(solRecientes);
      } catch (_) {}

      // Métricas de técnicos (del mes actual)
      try {
        final periodo = DateFormat('yyyy-MM').format(hoy);
        final metricasRes = await AppSupabase.client
            .from('climas_metricas_tecnico')
            .select('*, climas_tecnicos(nombre)')
            .eq('periodo', periodo)
            .order('ordenes_completadas', ascending: false);
        _tecnicosConMetricas = List<Map<String, dynamic>>.from(metricasRes);
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando dashboard admin: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📊 Panel de Control',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.climasAdminConfig),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAlertas(),
                    const SizedBox(height: 20),
                    _buildKPIsGenerales(),
                    const SizedBox(height: 24),
                    _buildIngresos(),
                    const SizedBox(height: 24),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    if (_solicitudesRecientes.isNotEmpty) ...[
                      _buildSolicitudesRecientes(),
                      const SizedBox(height: 24),
                    ],
                    _buildOrdenesRecientes(),
                    const SizedBox(height: 24),
                    if (_incidenciasRecientes.isNotEmpty) ...[
                      _buildIncidencias(),
                      const SizedBox(height: 24),
                    ],
                    if (_productosStockBajo.isNotEmpty) ...[
                      _buildAlertasStock(),
                      const SizedBox(height: 24),
                    ],
                    if (_tecnicosConMetricas.isNotEmpty) ...[
                      _buildRankingTecnicos(),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAlertas() {
    final totalAlertas = _solicitudesNuevas + _stockBajo + _incidenciasAbiertas + _comisionesPendientes;
    if (totalAlertas == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEF4444).withOpacity(0.2),
            const Color(0xFFF59E0B).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                '$totalAlertas Alertas Activas',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_solicitudesNuevas > 0)
                _buildAlertaChip('$_solicitudesNuevas Solicitudes', const Color(0xFF3B82F6), () => _verSolicitudes()),
              if (_stockBajo > 0)
                _buildAlertaChip('$_stockBajo Stock Bajo', const Color(0xFFEF4444), () => _verInventario()),
              if (_incidenciasAbiertas > 0)
                _buildAlertaChip('$_incidenciasAbiertas Incidencias', const Color(0xFFF59E0B), () => _verIncidencias()),
              if (_comisionesPendientes > 0)
                _buildAlertaChip('$_comisionesPendientes Comisiones', const Color(0xFF8B5CF6), () => _verComisiones()),
              if (_garantiasPorVencer > 0)
                _buildAlertaChip('$_garantiasPorVencer Garantías', const Color(0xFF10B981), () => _verGarantias()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, color: color, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIsGenerales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen General', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKPICard('Clientes', '$_totalClientes', Icons.people, const Color(0xFF3B82F6)),
            const SizedBox(width: 12),
            _buildKPICard('Técnicos', '$_totalTecnicos', Icons.engineering, const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildKPICard('Hoy', '$_ordenesHoy', Icons.today, const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _buildKPICard('Semana', '$_ordenesSemana', Icons.date_range, const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKPICard('Pendientes', '$_ordenesPendientes', Icons.pending_actions, const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _buildKPICard('En Proceso', '$_ordenesEnProceso', Icons.autorenew, const Color(0xFF3B82F6)),
            const SizedBox(width: 12),
            _buildKPICard('Stock Bajo', '$_stockBajo', Icons.inventory_2, const Color(0xFFEF4444)),
            const SizedBox(width: 12),
            _buildKPICard('Solicitudes', '$_solicitudesNuevas', Icons.mail, const Color(0xFF00D9FF)),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildIngresos() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Ingresos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildIngresoItem('Hoy', _currencyFormat.format(_ingresosHoy)),
              ),
              Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _buildIngresoItem('Semana', _currencyFormat.format(_ingresosSemana)),
              ),
              Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _buildIngresoItem('Mes', _currencyFormat.format(_ingresosMes)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngresoItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Acciones Rápidas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildAccionCard(Icons.add_circle, 'Nueva\nOrden', const Color(0xFF10B981), () => _nuevaOrden()),
            _buildAccionCard(Icons.calendar_month, 'Calendario', const Color(0xFF3B82F6), () => _verCalendario()),
            _buildAccionCard(Icons.inventory, 'Inventario', const Color(0xFFF59E0B), () => _verInventario()),
            _buildAccionCard(Icons.request_quote, 'Cotizar', const Color(0xFF8B5CF6), () => _nuevaCotizacion()),
            _buildAccionCard(Icons.people, 'Clientes', const Color(0xFF00D9FF), () => Navigator.pushNamed(context, AppRoutes.climasClientes)),
            _buildAccionCard(Icons.engineering, 'Técnicos', const Color(0xFF10B981), () => Navigator.pushNamed(context, AppRoutes.climasTecnicos)),
            _buildAccionCard(Icons.bar_chart, 'Reportes', const Color(0xFFEC4899), () => _verReportes()),
            _buildAccionCard(Icons.map, 'Zonas', const Color(0xFF6366F1), () => _verZonas()),
            _buildAccionCard(Icons.qr_code_2, 'Solicitudes\nQR', const Color(0xFFF97316), () => Navigator.pushNamed(context, AppRoutes.climasSolicitudesAdmin)),
            _buildAccionCard(Icons.receipt_long, 'Facturas\nClimas', const Color(0xFF3B82F6), () => Navigator.pushNamed(context, AppRoutes.facturacion, arguments: const {'moduloOrigen': 'climas'})),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolicitudesRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mail, color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 8),
                const Text('Solicitudes de Clientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton(
              onPressed: _verSolicitudes,
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._solicitudesRecientes.map((s) => _buildSolicitudCard(s)),
      ],
    );
  }

  Widget _buildSolicitudCard(Map<String, dynamic> solicitud) {
    final cliente = solicitud['climas_clientes'] ?? {};
    final estado = solicitud['estado'] ?? 'nueva';
    final tipo = solicitud['tipo_solicitud'] ?? 'mantenimiento';
    final urgencia = solicitud['urgencia'] ?? 'normal';
    
    Color estadoColor = estado == 'nueva' ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    Color urgenciaColor = urgencia == 'emergencia' ? const Color(0xFFEF4444) : urgencia == 'urgente' ? const Color(0xFFF59E0B) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencia != 'normal' ? urgenciaColor.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: estadoColor.withOpacity(0.2),
          child: Icon(Icons.person, color: estadoColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cliente['nombre'] ?? 'Cliente',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: urgenciaColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                urgencia.toUpperCase(),
                style: TextStyle(color: urgenciaColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tipo.toUpperCase()} - ${solicitud['descripcion'] ?? ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
              onPressed: () => _aprobarSolicitud(solicitud),
              tooltip: 'Aprobar',
            ),
            IconButton(
              icon: const Icon(Icons.visibility, color: Color(0xFF3B82F6)),
              onPressed: () => _verDetalleSolicitud(solicitud),
              tooltip: 'Ver',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdenesRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Órdenes Recientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.climasOrdenes),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ordenesRecientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text('Sin órdenes recientes', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
          )
        else
          ..._ordenesRecientes.map((o) => _buildOrdenCard(o)),
      ],
    );
  }

  Widget _buildOrdenCard(Map<String, dynamic> orden) {
    final cliente = orden['climas_clientes'] ?? {};
    final tecnico = orden['climas_tecnicos'] ?? {};
    final estado = orden['estado'] ?? 'pendiente';
    final estadoColor = _getEstadoColor(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: estadoColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.build, color: estadoColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(orden['folio'] ?? 'Sin folio', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getEstadoLabel(estado),
                style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${cliente['nombre'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            Text('Técnico: ${tecnico['nombre'] ?? 'Sin asignar'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
        onTap: () => Navigator.pushNamed(context, AppRoutes.climasOrdenDetalle, arguments: orden['id']),
      ),
    );
  }

  Widget _buildIncidencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning, color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 8),
                const Text('Incidencias Abiertas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton(
              onPressed: _verIncidencias,
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._incidenciasRecientes.map((i) => _buildIncidenciaCard(i)),
      ],
    );
  }

  Widget _buildIncidenciaCard(Map<String, dynamic> incidencia) {
    final tecnico = incidencia['climas_tecnicos'] ?? {};
    final orden = incidencia['climas_ordenes_servicio'] ?? {};
    final gravedad = incidencia['gravedad'] ?? 'media';
    final gravedadColor = gravedad == 'alta' ? const Color(0xFFEF4444) : gravedad == 'media' ? const Color(0xFFF59E0B) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gravedadColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: gravedadColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incidencia['tipo']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'INCIDENCIA',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gravedadColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(gravedad.toUpperCase(), style: TextStyle(color: gravedadColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(incidencia['descripcion'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7)), maxLines: 2),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Técnico: ${tecnico['nombre'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              const Spacer(),
              Text('Orden: ${orden['folio'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertasStock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2, color: Color(0xFFEF4444), size: 18),
                ),
                const SizedBox(width: 8),
                const Text('Stock Bajo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton(
              onPressed: _verInventario,
              child: const Text('Ver inventario', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_productosStockBajo.take(3).map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(p['nombre'] ?? '', style: const TextStyle(color: Colors.white))),
              Text(
                'Stock: ${p['stock']} / Mín: ${p['stock_minimo']}',
                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ))),
      ],
    );
  }

  Widget _buildRankingTecnicos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.leaderboard, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text('Ranking Técnicos (Mes)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ...(_tecnicosConMetricas.take(5).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final tecnico = m['climas_tecnicos'] ?? {};
          final medalColor = i == 0 ? const Color(0xFFFFD700) : i == 1 ? const Color(0xFFC0C0C0) : i == 2 ? const Color(0xFFCD7F32) : Colors.grey;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: i < 3 ? Border.all(color: medalColor.withOpacity(0.5)) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: medalColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}', style: TextStyle(color: medalColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(tecnico['nombre'] ?? 'Técnico', style: const TextStyle(color: Colors.white))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${m['ordenes_completadas'] ?? 0} órdenes', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        Text(' ${(m['calificacion_promedio'] ?? 0).toStringAsFixed(1)}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        })),
      ],
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFF59E0B);
      case 'asignada': return const Color(0xFF3B82F6);
      case 'en_proceso': return const Color(0xFF8B5CF6);
      case 'completada': return const Color(0xFF10B981);
      case 'cancelada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'asignada': return 'Asignada';
      case 'en_proceso': return 'En Proceso';
      case 'completada': return 'Completada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  // Navegación
  void _nuevaOrden() => Navigator.pushNamed(context, AppRoutes.climasOrdenNueva);
  void _verCalendario() => Navigator.pushNamed(context, AppRoutes.climasCalendario);
  void _verInventario() => Navigator.pushNamed(context, AppRoutes.climasEquipos);
  void _nuevaCotizacion() => Navigator.pushNamed(context, AppRoutes.climasCotizacionNueva);
  void _verReportes() => Navigator.pushNamed(context, AppRoutes.climasReportes);
  void _verZonas() => Navigator.pushNamed(context, AppRoutes.climasZonas);
  void _verSolicitudes() => Navigator.pushNamed(context, AppRoutes.climasSolicitudes);
  void _verIncidencias() => Navigator.pushNamed(context, AppRoutes.climasIncidencias);
  void _verComisiones() => Navigator.pushNamed(context, AppRoutes.climasComisiones);
  void _verGarantias() => Navigator.pushNamed(context, AppRoutes.climasGarantias);

  void _aprobarSolicitud(Map<String, dynamic> solicitud) async {
    // Implementar lógica de aprobación y creación de orden
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creando orden desde solicitud...'), backgroundColor: Color(0xFF3B82F6)),
    );
  }

  void _verDetalleSolicitud(Map<String, dynamic> solicitud) {
    Navigator.pushNamed(context, AppRoutes.climasSolicitudDetalle, arguments: solicitud['id']);
  }
}

// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// SISTEMA DE PAGOS PROFESIONAL - Robert Darin Fintech V10.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// - Registro de cobros en campo
/// - Confirmación de transferencias/pagos digitales
/// - Historial completo con filtros
/// - Preparado para tarjetas digitales
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import '../../core/themes/app_theme.dart';
import 'registrar_cobro_screen.dart';
import '../viewmodels/negocio_activo_provider.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  // Data
  List<Map<String, dynamic>> _cobrosPendientes = [];
  List<Map<String, dynamic>> _historialPagos = [];
  List<Map<String, dynamic>> _prestamosCobrables = [];
  
  bool _loading = true;
  
  // Stats
  double _totalCobradoHoy = 0;
  int _cobrosHoy = 0;
  int _pendientesCount = 0;

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _suscribirRealtime() {
    // Escuchar cambios en registros_cobro
    _supabase.from('registros_cobro').stream(primaryKey: ['id']).listen((_) {
      _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    try {
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      
      // 1. Cobros pendientes de confirmación
      final pendientes = await _supabase
          .from('registros_cobro')
          .select('''
            *,
            cliente:clientes(id, nombre, telefono, foto_url),
            prestamo:prestamos(id, monto, estado),
            metodo:metodos_pago(nombre, tipo, icono)
          ''')
          .eq('estado', 'pendiente')
          .order('fecha_registro', ascending: false);

      // 2. Historial de pagos (últimos 50)
      final historial = await _supabase
          .from('registros_cobro')
          .select('''
            *,
            cliente:clientes(id, nombre, telefono),
            prestamo:prestamos(id, monto)
          ''')
          .neq('estado', 'pendiente')
          .order('fecha_registro', ascending: false)
          .limit(50);

      // 3. Préstamos con cuotas pendientes (para nuevo cobro)
      final prestamos = await _supabase
          .from('prestamos')
          .select('''
            id, monto, estado, plazo_meses, interes,
            cliente:clientes(id, nombre, telefono, foto_url),
            amortizaciones(id, numero_cuota, monto_cuota, fecha_vencimiento, estado)
          ''')
          .eq('estado', 'activo')
          .order('created_at', ascending: false)
          .limit(20);

      // 4. Stats del día
      final statsHoy = await _supabase
          .from('registros_cobro')
          .select('monto')
          .eq('estado', 'confirmado')
          .gte('fecha_confirmacion', inicioHoy.toIso8601String());

      double totalHoy = 0;
      for (var s in statsHoy) {
        totalHoy += (s['monto'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _cobrosPendientes = List<Map<String, dynamic>>.from(pendientes);
          _historialPagos = List<Map<String, dynamic>>.from(historial);
          _prestamosCobrables = List<Map<String, dynamic>>.from(prestamos);
          _pendientesCount = _cobrosPendientes.length;
          _totalCobradoHoy = totalHoy;
          _cobrosHoy = statsHoy.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de pagos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsCards(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabNuevoCobro(),
                        _buildTabPendientes(),
                        _buildTabHistorial(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.payments, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de Cobros',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Registra y confirma pagos',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          // Indicador de pendientes
          if (_pendientesCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_pendientesCount',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Cobrado Hoy',
              _currencyFormat.format(_totalCobradoHoy),
              Icons.trending_up,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Cobros Hoy',
              '$_cobrosHoy',
              Icons.receipt_long,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Por Confirmar',
              '$_pendientesCount',
              Icons.pending_actions,
              _pendientesCount > 0 ? Colors.orange : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade800],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          const Tab(
            icon: Icon(Icons.add_card, size: 20),
            text: 'Cobrar',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: _pendientesCount > 0,
              label: Text('$_pendientesCount'),
              child: const Icon(Icons.pending_actions, size: 20),
            ),
            text: 'Pendientes',
          ),
          const Tab(
            icon: Icon(Icons.history, size: 20),
            text: 'Historial',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: NUEVO COBRO
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabNuevoCobro() {
    if (_prestamosCobrables.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Sin préstamos activos',
        subtitle: 'No hay préstamos con cuotas pendientes',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _prestamosCobrables.length,
        itemBuilder: (context, index) {
          final prestamo = _prestamosCobrables[index];
          return _buildPrestamoCobrableCard(prestamo);
        },
      ),
    );
  }

  Widget _buildPrestamoCobrableCard(Map<String, dynamic> prestamo) {
    final cliente = prestamo['cliente'] as Map<String, dynamic>?;
    final amortizaciones = prestamo['amortizaciones'] as List? ?? [];
    
    // Encontrar próxima cuota pendiente
    Map<String, dynamic>? proximaCuota;
    for (var a in amortizaciones) {
      if (a['estado'] == 'pendiente' || a['estado'] == 'vencido') {
        proximaCuota = a;
        break;
      }
    }

    if (proximaCuota == null) return const SizedBox.shrink();

    final montoCuota = (proximaCuota['monto_cuota'] as num?)?.toDouble() ?? 0;
    final numeroCuota = proximaCuota['numero_cuota'] ?? 0;
    final fechaVencimiento = proximaCuota['fecha_vencimiento'] != null
        ? DateTime.tryParse(proximaCuota['fecha_vencimiento'])
        : null;
    final vencido = fechaVencimiento != null && fechaVencimiento.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            vencido ? Colors.red.withOpacity(0.1) : const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vencido ? Colors.red.withOpacity(0.5) : Colors.white10,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navegarARegistrarCobro(prestamo, proximaCuota!),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar cliente
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.green.withOpacity(0.2),
                      backgroundImage: cliente?['foto_url'] != null
                          ? NetworkImage(cliente!['foto_url'])
                          : null,
                      child: cliente?['foto_url'] == null
                          ? Text(
                              (cliente?['nombre'] ?? 'C')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    
                    // Info cliente y cuota
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente?['nombre'] ?? 'Cliente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: vencido
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Cuota $numeroCuota',
                                  style: TextStyle(
                                    color: vencido ? Colors.red : Colors.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (vencido) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.red,
                                  size: 14,
                                ),
                                const Text(
                                  ' Vencida',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Monto y botón
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(montoCuota),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade600, Colors.green.shade800],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Cobrar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Fecha de vencimiento
                if (fechaVencimiento != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: vencido ? Colors.red : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vence: ${DateFormat('dd/MM/yyyy').format(fechaVencimiento)}',
                        style: TextStyle(
                          color: vencido ? Colors.red : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navegarARegistrarCobro(Map<String, dynamic> prestamo, Map<String, dynamic> cuota) {
    final cliente = prestamo['cliente'] as Map<String, dynamic>?;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarCobroScreen(
          prestamoId: prestamo['id'],
          amortizacionId: cuota['id'],
          clienteId: cliente?['id'] ?? '',
          clienteNombre: cliente?['nombre'] ?? 'Cliente',
          montoEsperado: (cuota['monto_cuota'] as num?)?.toDouble() ?? 0,
          numeroCuota: cuota['numero_cuota'],
        ),
      ),
    ).then((_) => _cargarDatos());
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: PENDIENTES DE CONFIRMACIÓN
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabPendientes() {
    if (_cobrosPendientes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.verified,
        title: 'Todo al día',
        subtitle: 'No hay pagos pendientes de confirmación',
        color: Colors.green,
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: Colors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cobrosPendientes.length,
        itemBuilder: (context, index) {
          final cobro = _cobrosPendientes[index];
          return _buildCobroPendienteCard(cobro);
        },
      ),
    );
  }

  Widget _buildCobroPendienteCard(Map<String, dynamic> cobro) {
    final cliente = cobro['cliente'] as Map<String, dynamic>?;
    final metodo = cobro['metodo'] as Map<String, dynamic>?;
    final monto = (cobro['monto'] as num?)?.toDouble() ?? 0;
    final fechaRegistro = cobro['fecha_registro'] != null
        ? DateTime.tryParse(cobro['fecha_registro'])
        : null;
    final referencia = cobro['referencia_pago'] as String?;
    final comprobanteUrl = cobro['comprobante_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Text(
                    (cliente?['nombre'] ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente?['nombre'] ?? 'Cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            _getIconoMetodo(metodo?['tipo'] ?? cobro['tipo_metodo']),
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            metodo?['nombre'] ?? cobro['tipo_metodo'] ?? 'Transferencia',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Monto
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(monto),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (fechaRegistro != null)
                      Text(
                        DateFormat('dd/MM HH:mm').format(fechaRegistro),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Referencia y comprobante
          if (referencia != null || comprobanteUrl != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  if (referencia != null) ...[
                    const Icon(Icons.tag, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Ref: $referencia',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                  if (comprobanteUrl != null)
                    TextButton.icon(
                      onPressed: () => _verComprobante(comprobanteUrl),
                      icon: const Icon(Icons.image, size: 14),
                      label: const Text('Ver', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),
          
          // Botones de acción
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rechazarCobro(cobro),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmarCobro(cobro),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirmar Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconoMetodo(String? tipo) {
    switch (tipo) {
      case 'efectivo': return Icons.payments;
      case 'transferencia': return Icons.account_balance;
      case 'tarjeta': return Icons.credit_card;
      case 'qr': return Icons.qr_code;
      case 'oxxo': return Icons.store;
      case 'tarjeta_digital': return Icons.contactless;
      default: return Icons.payment;
    }
  }

  void _verComprobante(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 200,
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Colors.black,
              child: const Center(
                child: Text('Error al cargar imagen', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarCobro(Map<String, dynamic> cobro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Confirmar Pago', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmar que recibiste ${_currencyFormat.format(cobro['monto'])}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Cliente: ${cobro['cliente']?['nombre'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        HapticFeedback.mediumImpact();
        final userId = _supabase.auth.currentUser?.id;
        
        // Actualizar registro_cobro
        await _supabase
            .from('registros_cobro')
            .update({
              'estado': 'confirmado',
              'confirmado_por': userId,
              'fecha_confirmacion': DateTime.now().toIso8601String(),
            })
            .eq('id', cobro['id']);

        // Registrar en tabla pagos
        final negocioId = context.read<NegocioActivoProvider>().negocioId;
        await _supabase.from('pagos').insert({
          'prestamo_id': cobro['prestamo_id'],
          'monto': cobro['monto'],
          'fecha_pago': DateTime.now().toIso8601String(),
          'nota': 'Confirmado desde panel de cobros',
          'comprobante_url': cobro['comprobante_url'],
          'negocio_id': negocioId,
        });

        // Actualizar amortización si existe
        if (cobro['amortizacion_id'] != null) {
          await _supabase
              .from('amortizaciones')
              .update({
                'estado': 'pagado',
                'fecha_pago': DateTime.now().toIso8601String(),
              })
              .eq('id', cobro['amortizacion_id']);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('¡Pago confirmado correctamente!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error confirmando cobro: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _rechazarCobro(Map<String, dynamic> cobro) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 12),
              Text('Rechazar Pago', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Por qué rechazas este pago?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Motivo del rechazo...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    if (motivo != null) {
      try {
        HapticFeedback.mediumImpact();
        
        await _supabase
            .from('registros_cobro')
            .update({
              'estado': 'rechazado',
              'motivo_rechazo': motivo,
              'confirmado_por': _supabase.auth.currentUser?.id,
              'fecha_confirmacion': DateTime.now().toIso8601String(),
            })
            .eq('id', cobro['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago rechazado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error rechazando cobro: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 3: HISTORIAL
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabHistorial() {
    if (_historialPagos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Sin historial',
        subtitle: 'Los pagos confirmados aparecerán aquí',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: Colors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _historialPagos.length,
        itemBuilder: (context, index) {
          final pago = _historialPagos[index];
          return _buildHistorialCard(pago);
        },
      ),
    );
  }

  Widget _buildHistorialCard(Map<String, dynamic> pago) {
    final cliente = pago['cliente'] as Map<String, dynamic>?;
    final monto = (pago['monto'] as num?)?.toDouble() ?? 0;
    final estado = pago['estado'] as String?;
    final fechaConfirmacion = pago['fecha_confirmacion'] != null
        ? DateTime.tryParse(pago['fecha_confirmacion'])
        : null;
    final esConfirmado = estado == 'confirmado';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esConfirmado
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Icono estado
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (esConfirmado ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              esConfirmado ? Icons.check_circle : Icons.cancel,
              color: esConfirmado ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente?['nombre'] ?? 'Cliente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (fechaConfirmacion != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(fechaConfirmacion),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          
          // Monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${esConfirmado ? '+' : '-'}${_currencyFormat.format(monto)}',
                style: TextStyle(
                  color: esConfirmado ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (esConfirmado ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  esConfirmado ? 'Confirmado' : 'Rechazado',
                  style: TextStyle(
                    color: esConfirmado ? Colors.green : Colors.red,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = Colors.white54,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

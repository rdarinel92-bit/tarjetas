// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import '../../services/stripe_integration_service.dart';
import 'package:intl/intl.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// MIS PAGOS PENDIENTES - Pantalla UNIVERSAL del Cliente
/// Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Permite al cliente ver y pagar TODOS sus compromisos:
/// - 📋 Préstamos Mensuales (amortizaciones)
/// - 📅 Préstamos Diarios/Arquilado (cuotas diarias)
/// - 👥 Tandas (cuotas de participación)
/// - Generar link de pago automático
/// - Pagar por diferentes métodos (Link, OXXO, SPEI, Tarjeta)
/// ══════════════════════════════════════════════════════════════════════════════

// Tipo de pago pendiente
enum TipoPago { prestamo, prestamodiario, tanda }

class PagoPendienteUnificado {
  final String id;
  final TipoPago tipo;
  final String concepto;
  final String descripcion;
  final double monto;
  final DateTime? fechaVencimiento;
  final bool esVencido;
  final String? referenciaId; // prestamo_id, tanda_id, etc
  final String? subReferenciaId; // amortizacion_id, participante_id, etc
  final IconData icono;
  final Color color;
  final Map<String, dynamic> datosOriginales;

  PagoPendienteUnificado({
    required this.id,
    required this.tipo,
    required this.concepto,
    required this.descripcion,
    required this.monto,
    this.fechaVencimiento,
    this.esVencido = false,
    this.referenciaId,
    this.subReferenciaId,
    required this.icono,
    required this.color,
    required this.datosOriginales,
  });
}

class MisPagosPendientesScreen extends StatefulWidget {
  const MisPagosPendientesScreen({super.key});

  @override
  State<MisPagosPendientesScreen> createState() => _MisPagosPendientesScreenState();
}

class _MisPagosPendientesScreenState extends State<MisPagosPendientesScreen> 
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _clienteId;
  String? _negocioId;
  
  // TODOS los pagos unificados
  List<PagoPendienteUnificado> _todosPagosPendientes = [];
  List<Map<String, dynamic>> _linksPendientes = [];
  
  // Resúmenes por tipo
  double _totalPendiente = 0;
  int _totalPrestamos = 0;
  int _totalPrestamosDiarios = 0;
  int _totalTandas = 0;
  
  // Tab controller para filtrar
  late TabController _tabController;
  int _filtroActual = 0; // 0=Todos, 1=Préstamos, 2=Diarios, 3=Tandas
  
  // Configuración de pagos
  bool _stripeHabilitado = false;
  bool _oxxoHabilitado = false;
  bool _speiHabilitado = false;
  
  final _stripeService = StripeIntegrationService();
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filtroActual = _tabController.index);
      }
    });
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Obtener cliente_id desde auth_uid
      final clienteData = await AppSupabase.client
          .from('clientes')
          .select('id, negocio_id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (clienteData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _clienteId = clienteData['id'];
      _negocioId = clienteData['negocio_id'];
      _todosPagosPendientes = [];

      // ═══════════════════════════════════════════════════════════════════════
      // 1. CARGAR PRÉSTAMOS MENSUALES (amortizaciones pendientes)
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarPrestamosMensuales();

      // ═══════════════════════════════════════════════════════════════════════
      // 2. CARGAR PRÉSTAMOS DIARIOS/ARQUILADO
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarPrestamosDiarios();

      // ═══════════════════════════════════════════════════════════════════════
      // 3. CARGAR TANDAS (cuotas pendientes)
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarTandas();

      // ═══════════════════════════════════════════════════════════════════════
      // 4. CARGAR LINKS DE PAGO EXISTENTES
      // ═══════════════════════════════════════════════════════════════════════
      final links = await AppSupabase.client
          .from('links_pago')
          .select()
          .eq('cliente_id', _clienteId!)
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);
      
      _linksPendientes = List<Map<String, dynamic>>.from(links);

      // ═══════════════════════════════════════════════════════════════════════
      // 5. VERIFICAR CONFIGURACIÓN DE PAGOS
      // ═══════════════════════════════════════════════════════════════════════
      if (_negocioId != null) {
        final stripeConfig = await AppSupabase.client
            .from('stripe_config')
            .select('link_pago_habilitado, oxxo_habilitado, spei_habilitado')
            .eq('negocio_id', _negocioId!)
            .maybeSingle();
        
        if (stripeConfig != null) {
          _stripeHabilitado = stripeConfig['link_pago_habilitado'] ?? false;
          _oxxoHabilitado = stripeConfig['oxxo_habilitado'] ?? false;
          _speiHabilitado = stripeConfig['spei_habilitado'] ?? false;
        }
      }

      // Calcular totales
      _totalPendiente = _todosPagosPendientes.fold(0.0, (sum, p) => sum + p.monto);
      
      // Ordenar por fecha de vencimiento (más urgentes primero)
      _todosPagosPendientes.sort((a, b) {
        // Vencidos primero
        if (a.esVencido && !b.esVencido) return -1;
        if (!a.esVencido && b.esVencido) return 1;
        // Luego por fecha
        if (a.fechaVencimiento == null) return 1;
        if (b.fechaVencimiento == null) return -1;
        return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
      });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPrestamosMensuales() async {
    try {
      // Préstamos activos tipo normal/mensual
      final prestamos = await AppSupabase.client
          .from('prestamos')
          .select('id, monto, tasa_interes, plazo_meses, estado, fecha_inicio, tipo_prestamo')
          .eq('cliente_id', _clienteId!)
          .inFilter('estado', ['activo', 'vigente'])
          .inFilter('tipo_prestamo', ['normal', 'mensual'])
          .order('fecha_inicio', ascending: false);
      
      if (prestamos.isEmpty) return;

      final prestamoIds = (prestamos as List).map((p) => p['id']).toList();
      
      // Amortizaciones pendientes
      final amortizaciones = await AppSupabase.client
          .from('amortizaciones')
          .select('id, prestamo_id, numero_pago, fecha_pago, monto_total, estado')
          .inFilter('prestamo_id', prestamoIds)
          .inFilter('estado', ['pendiente', 'vencido'])
          .order('fecha_pago', ascending: true);

      for (var amort in amortizaciones) {
        final fechaPago = DateTime.tryParse(amort['fecha_pago'] ?? '');
        final esVencido = amort['estado'] == 'vencido' || 
            (fechaPago != null && fechaPago.isBefore(DateTime.now()));
        
        _todosPagosPendientes.add(PagoPendienteUnificado(
          id: amort['id'],
          tipo: TipoPago.prestamo,
          concepto: "📋 Préstamo - Cuota #${amort['numero_pago']}",
          descripcion: "Pago mensual de préstamo",
          monto: (amort['monto_total'] ?? 0).toDouble(),
          fechaVencimiento: fechaPago,
          esVencido: esVencido,
          referenciaId: amort['prestamo_id'],
          subReferenciaId: amort['id'],
          icono: Icons.receipt_long,
          color: Colors.cyanAccent,
          datosOriginales: amort,
        ));
        _totalPrestamos++;
      }
    } catch (e) {
      debugPrint('Error cargando préstamos mensuales: $e');
    }
  }

  Future<void> _cargarPrestamosDiarios() async {
    try {
      // Préstamos activos tipo diario/arquilado
      final prestamos = await AppSupabase.client
          .from('prestamos')
          .select('''
            id, monto, tasa_interes, plazo_meses, estado, fecha_inicio, 
            tipo_prestamo, interes_diario, frecuencia_pago
          ''')
          .eq('cliente_id', _clienteId!)
          .inFilter('estado', ['activo', 'vigente'])
          .inFilter('tipo_prestamo', ['diario', 'arquilado'])
          .order('fecha_inicio', ascending: false);
      
      if (prestamos.isEmpty) return;

      final prestamoIds = (prestamos as List).map((p) => p['id']).toList();
      
      // Amortizaciones diarias pendientes
      final amortizaciones = await AppSupabase.client
          .from('amortizaciones')
          .select('id, prestamo_id, numero_pago, fecha_pago, monto_total, estado')
          .inFilter('prestamo_id', prestamoIds)
          .inFilter('estado', ['pendiente', 'vencido'])
          .order('fecha_pago', ascending: true);

      for (var amort in amortizaciones) {
        final fechaPago = DateTime.tryParse(amort['fecha_pago'] ?? '');
        final esVencido = amort['estado'] == 'vencido' || 
            (fechaPago != null && fechaPago.isBefore(DateTime.now()));
        
        _todosPagosPendientes.add(PagoPendienteUnificado(
          id: amort['id'],
          tipo: TipoPago.prestamodiario,
          concepto: "📅 Diario - Día #${amort['numero_pago']}",
          descripcion: "Pago diario/arquilado",
          monto: (amort['monto_total'] ?? 0).toDouble(),
          fechaVencimiento: fechaPago,
          esVencido: esVencido,
          referenciaId: amort['prestamo_id'],
          subReferenciaId: amort['id'],
          icono: Icons.calendar_today,
          color: Colors.orangeAccent,
          datosOriginales: amort,
        ));
        _totalPrestamosDiarios++;
      }
    } catch (e) {
      debugPrint('Error cargando préstamos diarios: $e');
    }
  }

  Future<void> _cargarTandas() async {
    try {
      // Tandas donde participa el cliente
      final participaciones = await AppSupabase.client
          .from('tanda_participantes')
          .select('''
            id, tanda_id, numero_turno, ha_pagado_cuota_actual, ha_recibido_bolsa,
            tandas!inner(
              id, nombre, monto_por_persona, numero_participantes, 
              turno, frecuencia, estado, fecha_inicio
            )
          ''')
          .eq('cliente_id', _clienteId!)
          .eq('ha_pagado_cuota_actual', false);

      for (var part in participaciones) {
        final tanda = part['tandas'];
        if (tanda == null || tanda['estado'] != 'activa') continue;

        final monto = (tanda['monto_por_persona'] ?? 0).toDouble();
        final turnoActual = (tanda['turno'] ?? 1) as int;
        final frecuencia = tanda['frecuencia'] ?? 'Semanal';
        
        // Calcular próxima fecha según frecuencia
        final fechaInicio = DateTime.tryParse(tanda['fecha_inicio'] ?? '');
        DateTime? proximaFecha;
        if (fechaInicio != null) {
          final diasPorTurno = frecuencia == 'Semanal' ? 7 : 
                              frecuencia == 'Quincenal' ? 15 : 30;
          proximaFecha = fechaInicio.add(Duration(days: diasPorTurno * (turnoActual - 1)));
        }
        
        final esVencido = proximaFecha != null && proximaFecha.isBefore(DateTime.now());

        _todosPagosPendientes.add(PagoPendienteUnificado(
          id: part['id'],
          tipo: TipoPago.tanda,
          concepto: "👥 Tanda: ${tanda['nombre']}",
          descripcion: "Turno $turnoActual • $frecuencia",
          monto: monto,
          fechaVencimiento: proximaFecha,
          esVencido: esVencido,
          referenciaId: tanda['id'],
          subReferenciaId: part['id'],
          icono: Icons.groups,
          color: Colors.purpleAccent,
          datosOriginales: {...part, 'tanda': tanda},
        ));
        _totalTandas++;
      }
    } catch (e) {
      debugPrint('Error cargando tandas: $e');
    }
  }

  List<PagoPendienteUnificado> get _pagosFiltrados {
    switch (_filtroActual) {
      case 1: return _todosPagosPendientes.where((p) => p.tipo == TipoPago.prestamo).toList();
      case 2: return _todosPagosPendientes.where((p) => p.tipo == TipoPago.prestamodiario).toList();
      case 3: return _todosPagosPendientes.where((p) => p.tipo == TipoPago.tanda).toList();
      default: return _todosPagosPendientes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Mis Pagos",
      subtitle: "Todos tus compromisos pendientes",
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
                    // RESUMEN TOTAL CON DESGLOSE
                    _buildResumenTotal(),
                    const SizedBox(height: 16),
                    
                    // TABS DE FILTRO POR TIPO
                    _buildTabsFiltro(),
                    const SizedBox(height: 16),
                    
                    // PRÓXIMO PAGO URGENTE (si hay)
                    if (_todosPagosPendientes.isNotEmpty) ...[
                      _buildProximoPagoUrgente(),
                      const SizedBox(height: 16),
                    ],
                    
                    // LINKS DE PAGO PENDIENTES
                    if (_linksPendientes.isNotEmpty) ...[
                      _buildLinksPendientes(),
                      const SizedBox(height: 16),
                    ],
                    
                    // LISTA DE PAGOS FILTRADOS
                    _buildListaPagosFiltrados(),
                    
                    // INFORMACIÓN DE MÉTODOS DE PAGO
                    const SizedBox(height: 20),
                    _buildInfoMetodosPago(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResumenTotal() {
    final hayPendientes = _totalPendiente > 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hayPendientes
              ? [const Color(0xFF1E3A5F), const Color(0xFF0D1B2A)]
              : [Colors.greenAccent.withOpacity(0.3), Colors.greenAccent.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hayPendientes ? const Color(0xFF3B82F6).withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hayPendientes ? Icons.account_balance_wallet : Icons.check_circle,
                color: hayPendientes ? Colors.cyanAccent : Colors.greenAccent,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hayPendientes ? "Total Pendiente" : "¡Al corriente!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    hayPendientes ? currencyFormat.format(_totalPendiente) : "Sin pagos pendientes",
                    style: TextStyle(
                      color: hayPendientes ? Colors.white : Colors.greenAccent,
                      fontSize: hayPendientes ? 26 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // DESGLOSE POR TIPO
          if (hayPendientes) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniResumen("Préstamos", _totalPrestamos, Icons.receipt_long, Colors.cyanAccent),
                _buildMiniResumen("Diarios", _totalPrestamosDiarios, Icons.calendar_today, Colors.orangeAccent),
                _buildMiniResumen("Tandas", _totalTandas, Icons.groups, Colors.purpleAccent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniResumen(String label, int count, IconData icono, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(count.toString(), 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildTabsFiltro() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: "Todos (${_todosPagosPendientes.length})"),
          Tab(text: "📋 (${ _totalPrestamos})"),
          Tab(text: "📅 ($_totalPrestamosDiarios)"),
          Tab(text: "👥 ($_totalTandas)"),
        ],
      ),
    );
  }

  Widget _buildProximoPagoUrgente() {
    // Encontrar el pago más urgente (vencido o próximo a vencer)
    final pagoUrgente = _pagosFiltrados.isNotEmpty ? _pagosFiltrados.first : null;
    if (pagoUrgente == null) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pagoUrgente.esVencido 
                      ? Colors.redAccent.withOpacity(0.2) 
                      : pagoUrgente.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  pagoUrgente.esVencido ? Icons.warning_amber : pagoUrgente.icono,
                  color: pagoUrgente.esVencido ? Colors.redAccent : pagoUrgente.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pagoUrgente.esVencido ? "⚠️ VENCIDO" : "Próximo Pago",
                      style: TextStyle(
                        color: pagoUrgente.esVencido ? Colors.redAccent : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      pagoUrgente.concepto,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      pagoUrgente.descripcion,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(pagoUrgente.monto),
                    style: TextStyle(
                      color: pagoUrgente.esVencido ? Colors.redAccent : pagoUrgente.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (pagoUrgente.fechaVencimiento != null)
                    Text(
                      DateFormat('dd/MMM').format(pagoUrgente.fechaVencimiento!),
                      style: TextStyle(
                        color: pagoUrgente.esVencido ? Colors.redAccent : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          
          // BOTONES DE ACCIÓN
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _stripeHabilitado ? () => _generarLinkPago(pagoUrgente) : null,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text("Generar Link"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _mostrarOpcionesPago(pagoUrgente),
                  icon: const Icon(Icons.more_horiz, size: 18),
                  label: const Text("Opciones"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaPagosFiltrados() {
    final pagos = _pagosFiltrados;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(_getIconoFiltro(), color: _getColorFiltro(), size: 18),
                const SizedBox(width: 8),
                Text(_getTituloFiltro(), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            Text("${pagos.length} pendiente(s)", 
              style: TextStyle(color: _getColorFiltro(), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        
        if (pagos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Text("¡Sin pagos pendientes en ${_getNombreFiltro()}!", 
                  style: const TextStyle(color: Colors.greenAccent)),
              ],
            ),
          )
        else
          ...pagos.map((pago) => _buildPagoUnificadoItem(pago)),
      ],
    );
  }

  IconData _getIconoFiltro() {
    switch (_filtroActual) {
      case 1: return Icons.receipt_long;
      case 2: return Icons.calendar_today;
      case 3: return Icons.groups;
      default: return Icons.list_alt;
    }
  }

  Color _getColorFiltro() {
    switch (_filtroActual) {
      case 1: return Colors.cyanAccent;
      case 2: return Colors.orangeAccent;
      case 3: return Colors.purpleAccent;
      default: return Colors.white70;
    }
  }

  String _getTituloFiltro() {
    switch (_filtroActual) {
      case 1: return "Préstamos Mensuales";
      case 2: return "Préstamos Diarios";
      case 3: return "Tandas";
      default: return "Todos los Pagos";
    }
  }

  String _getNombreFiltro() {
    switch (_filtroActual) {
      case 1: return "préstamos";
      case 2: return "diarios";
      case 3: return "tandas";
      default: return "este filtro";
    }
  }

  Widget _buildPagoUnificadoItem(PagoPendienteUnificado pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _mostrarOpcionesPago(pago),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pago.esVencido 
                        ? Colors.redAccent.withOpacity(0.2) 
                        : pago.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    pago.icono,
                    color: pago.esVencido ? Colors.redAccent : pago.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pago.concepto,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Text(
                            pago.descripcion,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          if (pago.fechaVencimiento != null) ...[
                            const Text(" • ", style: TextStyle(color: Colors.white24)),
                            Text(
                              pago.esVencido 
                                  ? "Venció ${DateFormat('dd/MMM').format(pago.fechaVencimiento!)}"
                                  : "Vence ${DateFormat('dd/MMM').format(pago.fechaVencimiento!)}",
                              style: TextStyle(
                                color: pago.esVencido ? Colors.redAccent : Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(pago.monto),
                      style: TextStyle(
                        color: pago.esVencido ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pago.esVencido)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("VENCIDO", 
                          style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: pago.color.withOpacity(0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinksPendientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link, color: Colors.amberAccent, size: 18),
            SizedBox(width: 8),
            Text("Links de Pago Activos", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ..._linksPendientes.map((link) => _buildLinkItem(link)),
      ],
    );
  }

  Widget _buildLinkItem(Map<String, dynamic> link) {
    final monto = (link['monto'] ?? 0).toDouble();
    final concepto = link['concepto'] ?? 'Pago';
    final url = link['url'] ?? link['stripe_url'] ?? '';
    final fechaExp = DateTime.tryParse(link['fecha_expiracion'] ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(concepto, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(currencyFormat.format(monto), 
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          if (fechaExp != null) ...[
            const SizedBox(height: 4),
            Text("Expira: ${DateFormat('dd/MMM/yy').format(fechaExp)}", 
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: url.isNotEmpty ? () => _abrirLink(url) : null,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text("Pagar Ahora", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: url.isNotEmpty ? () => _compartirLink(url, concepto, monto) : null,
                icon: const Icon(Icons.share, color: Colors.white54, size: 20),
                tooltip: "Compartir",
              ),
              IconButton(
                onPressed: url.isNotEmpty ? () => _copiarLink(url) : null,
                icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                tooltip: "Copiar",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE PAGO DISPONIBLES
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildInfoMetodosPago() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Text("Formas de Pago Disponibles", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white12),
          
          _buildMetodoInfo("Link de Pago", "Paga con tu tarjeta desde cualquier lugar", 
            Icons.link, _stripeHabilitado),
          _buildMetodoInfo("OXXO", "Genera un código y paga en cualquier OXXO", 
            Icons.store, _oxxoHabilitado),
          _buildMetodoInfo("Transferencia SPEI", "Transfiere desde tu banco", 
            Icons.account_balance, _speiHabilitado),
          _buildMetodoInfo("Efectivo", "Paga directamente al cobrador", 
            Icons.money, true),
        ],
      ),
    );
  }

  Widget _buildMetodoInfo(String nombre, String descripcion, IconData icono, bool disponible) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: disponible 
                  ? Colors.greenAccent.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, 
              color: disponible ? Colors.greenAccent : Colors.white24, 
              size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: TextStyle(
                  color: disponible ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w500,
                )),
                Text(descripcion, style: TextStyle(
                  color: disponible ? Colors.white54 : Colors.white24,
                  fontSize: 11,
                )),
              ],
            ),
          ),
          Icon(
            disponible ? Icons.check_circle : Icons.cancel,
            color: disponible ? Colors.greenAccent : Colors.white24,
            size: 18,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ACCIONES - GENERACIÓN DE LINKS Y PAGOS
  // ═══════════════════════════════════════════════════════════════════════════════
  
  Future<void> _generarLinkPago(PagoPendienteUnificado pago) async {
    if (_clienteId == null || _negocioId == null) {
      _mostrarError("Error de configuración");
      return;
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: const Color(0xFF1A1A2E),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 15),
                Text("Generando link para ${pago.concepto}...", 
                  style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generar concepto según el tipo de pago
      String conceptoLink = pago.concepto;
      String? prestamoId;
      String? amortizacionId;
      String? tandaId;

      switch (pago.tipo) {
        case TipoPago.prestamo:
        case TipoPago.prestamodiario:
          prestamoId = pago.referenciaId;
          amortizacionId = pago.subReferenciaId;
          break;
        case TipoPago.tanda:
          tandaId = pago.referenciaId;
          conceptoLink = "Cuota de Tanda: ${pago.datosOriginales['tanda']?['nombre'] ?? 'Tanda'}";
          break;
      }

      final link = await _stripeService.crearLinkPago(
        negocioId: _negocioId!,
        clienteId: _clienteId!,
        concepto: conceptoLink,
        monto: pago.monto,
        prestamoId: prestamoId,
        amortizacionId: amortizacionId,
        tandaId: tandaId,
      );

      Navigator.pop(context); // Cerrar loading

      if (link != null) {
        await _cargarDatos(); // Recargar datos
        _mostrarLinkGenerado(link, pago);
      } else {
        _mostrarError("No se pudo generar el link de pago");
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error: $e");
    }
  }

  void _mostrarLinkGenerado(dynamic link, PagoPendienteUnificado pago) {
    final url = link.url ?? link.stripeUrl ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
            ),
            const SizedBox(height: 15),
            const Text("¡Link Generado!", 
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(pago.concepto, 
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(currencyFormat.format(pago.monto), 
              style: TextStyle(color: pago.color, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (url.isNotEmpty) _abrirLink(url);
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text("Pagar Ahora"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (url.isNotEmpty) _compartirLink(url, pago.concepto, pago.monto);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Compartir"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (url.isNotEmpty) _copiarLink(url);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copiar"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesPago(PagoPendienteUnificado pago) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono del tipo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pago.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(pago.icono, color: pago.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pago.concepto, 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(pago.descripcion, 
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Text(currencyFormat.format(pago.monto), 
                  style: TextStyle(color: pago.color, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            
            const Text("Selecciona cómo quieres pagar:", 
              style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 15),
            
            // Opciones de pago
            if (_stripeHabilitado)
              _buildOpcionPago("Generar Link de Pago", "Paga con tarjeta online", 
                Icons.link, const Color(0xFF6366F1), true, () {
                  Navigator.pop(context);
                  _generarLinkPago(pago);
                }),
            
            if (_oxxoHabilitado)
              _buildOpcionPago("Pagar en OXXO", "Genera código para OXXO", 
                Icons.store, Colors.redAccent, true, () {
                  Navigator.pop(context);
                  _generarCodigoOXXO(pago);
                }),

            if (_speiHabilitado)
              _buildOpcionPago("Transferencia SPEI", "Ver datos bancarios", 
                Icons.account_balance, Colors.blueAccent, true, () {
                  Navigator.pop(context);
                  _mostrarDatosSPEI(pago);
                }),
            
            _buildOpcionPago("Contactar para Pago", "Coordina pago en efectivo", 
              Icons.chat, Colors.greenAccent, true, () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionPago(String titulo, String subtitulo, IconData icono, 
      Color color, bool disponible, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: disponible ? color.withOpacity(0.1) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: disponible ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icono, color: disponible ? color : Colors.white24, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: TextStyle(
                        color: disponible ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                      )),
                      Text(subtitulo, style: TextStyle(
                        color: disponible ? Colors.white54 : Colors.white24,
                        fontSize: 12,
                      )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, 
                  color: disponible ? color.withOpacity(0.5) : Colors.white12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _generarCodigoOXXO(PagoPendienteUnificado pago) {
    // TODO: Implementar generación de código OXXO
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Generación de código OXXO próximamente"),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  void _mostrarDatosSPEI(PagoPendienteUnificado pago) {
    // TODO: Implementar mostrar datos SPEI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Datos SPEI próximamente"),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  void _abrirLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _mostrarError("No se pudo abrir el link");
    }
  }

  void _compartirLink(String url, String concepto, double monto) {
    Share.share(
      "Hola! Aquí está mi link de pago:\n\n"
      "📋 $concepto\n"
      "💰 ${currencyFormat.format(monto)}\n\n"
      "🔗 $url\n\n"
      "Gracias!",
    );
  }

  void _copiarLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Link copiado al portapapeles"),
        backgroundColor: Colors.greenAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

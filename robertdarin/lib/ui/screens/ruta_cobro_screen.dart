// ignore_for_file: deprecated_member_use
/// ══════════════════════════════════════════════════════════════════════════════
/// RUTA DE COBRO - Panel del Cobrador/Operador
/// Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Muestra TODOS los cobros pendientes del día de TODOS los módulos:
/// - 📋 Préstamos Mensuales
/// - 📅 Préstamos Diarios/Arquilado
/// - 👥 Tandas
/// Permite registrar pagos en efectivo de forma rápida.
/// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import 'registrar_cobro_screen.dart';

// Tipo de cobro pendiente
enum TipoCobro { prestamo, prestamodiario, tanda }

class CobroPendienteUnificado {
  final String id;
  final TipoCobro tipo;
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteDireccion;
  final String concepto;
  final String descripcion;
  final double monto;
  final DateTime? fechaVencimiento;
  final bool esVencido;
  final int diasVencido;
  final String? prestamoId;
  final String? tandaId;
  final String? amortizacionId;
  final int? numeroCuota;
  final IconData icono;
  final Color color;

  CobroPendienteUnificado({
    required this.id,
    required this.tipo,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteDireccion,
    required this.concepto,
    required this.descripcion,
    required this.monto,
    this.fechaVencimiento,
    this.esVencido = false,
    this.diasVencido = 0,
    this.prestamoId,
    this.tandaId,
    this.amortizacionId,
    this.numeroCuota,
    required this.icono,
    required this.color,
  });
}

class RutaCobroScreen extends StatefulWidget {
  const RutaCobroScreen({super.key});

  @override
  State<RutaCobroScreen> createState() => _RutaCobroScreenState();
}

class _RutaCobroScreenState extends State<RutaCobroScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  
  // Todos los cobros pendientes
  List<CobroPendienteUnificado> _todosCobros = [];
  
  // Resúmenes
  double _totalPorCobrar = 0;
  double _totalVencido = 0;
  int _clientesUnicos = 0;
  int _cobrosHoy = 0;
  
  // Filtros
  late TabController _tabController;
  int _filtroActual = 0; // 0=Hoy, 1=Vencidos, 2=Todos
  String _filtroTipo = 'todos'; // todos, prestamo, diario, tanda
  
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final dateFormat = DateFormat('dd/MMM');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    setState(() => _isLoading = true);
    
    try {
      _todosCobros = [];
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      final finHoy = inicioHoy.add(const Duration(days: 1));

      // ═══════════════════════════════════════════════════════════════════════
      // 1. CARGAR PRÉSTAMOS MENSUALES PENDIENTES
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarPrestamosMensuales(inicioHoy, finHoy);

      // ═══════════════════════════════════════════════════════════════════════
      // 2. CARGAR PRÉSTAMOS DIARIOS PENDIENTES
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarPrestamosDiarios(inicioHoy, finHoy);

      // ═══════════════════════════════════════════════════════════════════════
      // 3. CARGAR TANDAS PENDIENTES
      // ═══════════════════════════════════════════════════════════════════════
      await _cargarTandas();

      // Calcular totales
      _totalPorCobrar = _todosCobros.fold(0.0, (sum, c) => sum + c.monto);
      _totalVencido = _todosCobros
          .where((c) => c.esVencido)
          .fold(0.0, (sum, c) => sum + c.monto);
      _clientesUnicos = _todosCobros.map((c) => c.clienteId).toSet().length;
      _cobrosHoy = _todosCobros
          .where((c) => c.fechaVencimiento != null && 
                       c.fechaVencimiento!.isAfter(inicioHoy) && 
                       c.fechaVencimiento!.isBefore(finHoy))
          .length;

      // Ordenar: vencidos primero, luego por fecha
      _todosCobros.sort((a, b) {
        if (a.esVencido && !b.esVencido) return -1;
        if (!a.esVencido && b.esVencido) return 1;
        if (a.diasVencido != b.diasVencido) return b.diasVencido.compareTo(a.diasVencido);
        if (a.fechaVencimiento == null) return 1;
        if (b.fechaVencimiento == null) return -1;
        return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
      });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando ruta de cobro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPrestamosMensuales(DateTime inicioHoy, DateTime finHoy) async {
    try {
      final amortizaciones = await AppSupabase.client
          .from('amortizaciones')
          .select('''
            id, prestamo_id, numero_pago, fecha_pago, monto_total, estado,
            prestamos!inner(
              id, monto, tipo_prestamo,
              clientes!inner(id, nombre, telefono, direccion)
            )
          ''')
          .inFilter('estado', ['pendiente', 'vencido'])
          .inFilter('prestamos.tipo_prestamo', ['normal', 'mensual'])
          .order('fecha_pago', ascending: true);

      for (var amort in amortizaciones) {
        final prestamo = amort['prestamos'];
        final cliente = prestamo?['clientes'];
        if (cliente == null) continue;

        final fechaPago = DateTime.tryParse(amort['fecha_pago'] ?? '');
        final esVencido = amort['estado'] == 'vencido' || 
            (fechaPago != null && fechaPago.isBefore(inicioHoy));
        
        int diasVencido = 0;
        if (esVencido && fechaPago != null) {
          diasVencido = inicioHoy.difference(fechaPago).inDays;
        }

        _todosCobros.add(CobroPendienteUnificado(
          id: amort['id'],
          tipo: TipoCobro.prestamo,
          clienteId: cliente['id'],
          clienteNombre: cliente['nombre'] ?? 'Sin nombre',
          clienteTelefono: cliente['telefono'],
          clienteDireccion: cliente['direccion'],
          concepto: "Préstamo - Cuota #${amort['numero_pago']}",
          descripcion: "Pago mensual",
          monto: (amort['monto_total'] ?? 0).toDouble(),
          fechaVencimiento: fechaPago,
          esVencido: esVencido,
          diasVencido: diasVencido,
          prestamoId: amort['prestamo_id'],
          amortizacionId: amort['id'],
          numeroCuota: amort['numero_pago'],
          icono: Icons.receipt_long,
          color: Colors.cyanAccent,
        ));
      }
    } catch (e) {
      debugPrint('Error cargando préstamos mensuales: $e');
    }
  }

  Future<void> _cargarPrestamosDiarios(DateTime inicioHoy, DateTime finHoy) async {
    try {
      final amortizaciones = await AppSupabase.client
          .from('amortizaciones')
          .select('''
            id, prestamo_id, numero_pago, fecha_pago, monto_total, estado,
            prestamos!inner(
              id, monto, tipo_prestamo,
              clientes!inner(id, nombre, telefono, direccion)
            )
          ''')
          .inFilter('estado', ['pendiente', 'vencido'])
          .inFilter('prestamos.tipo_prestamo', ['diario', 'arquilado'])
          .order('fecha_pago', ascending: true);

      for (var amort in amortizaciones) {
        final prestamo = amort['prestamos'];
        final cliente = prestamo?['clientes'];
        if (cliente == null) continue;

        final fechaPago = DateTime.tryParse(amort['fecha_pago'] ?? '');
        final esVencido = amort['estado'] == 'vencido' || 
            (fechaPago != null && fechaPago.isBefore(inicioHoy));
        
        int diasVencido = 0;
        if (esVencido && fechaPago != null) {
          diasVencido = inicioHoy.difference(fechaPago).inDays;
        }

        _todosCobros.add(CobroPendienteUnificado(
          id: amort['id'],
          tipo: TipoCobro.prestamodiario,
          clienteId: cliente['id'],
          clienteNombre: cliente['nombre'] ?? 'Sin nombre',
          clienteTelefono: cliente['telefono'],
          clienteDireccion: cliente['direccion'],
          concepto: "Diario - Día #${amort['numero_pago']}",
          descripcion: "Pago diario",
          monto: (amort['monto_total'] ?? 0).toDouble(),
          fechaVencimiento: fechaPago,
          esVencido: esVencido,
          diasVencido: diasVencido,
          prestamoId: amort['prestamo_id'],
          amortizacionId: amort['id'],
          numeroCuota: amort['numero_pago'],
          icono: Icons.calendar_today,
          color: Colors.orangeAccent,
        ));
      }
    } catch (e) {
      debugPrint('Error cargando préstamos diarios: $e');
    }
  }

  Future<void> _cargarTandas() async {
    try {
      final participaciones = await AppSupabase.client
          .from('tanda_participantes')
          .select('''
            id, tanda_id, numero_turno, ha_pagado_cuota_actual,
            clientes!inner(id, nombre, telefono, direccion),
            tandas!inner(id, nombre, monto_por_persona, turno, frecuencia, estado, fecha_inicio)
          ''')
          .eq('ha_pagado_cuota_actual', false);

      final hoy = DateTime.now();
      
      for (var part in participaciones) {
        final tanda = part['tandas'];
        final cliente = part['clientes'];
        if (tanda == null || cliente == null) continue;
        if (tanda['estado'] != 'activa') continue;

        final monto = (tanda['monto_por_persona'] ?? 0).toDouble();
        final turnoActual = (tanda['turno'] ?? 1) as int;
        final frecuencia = tanda['frecuencia'] ?? 'Semanal';
        
        // Calcular fecha de vencimiento según frecuencia
        final fechaInicio = DateTime.tryParse(tanda['fecha_inicio'] ?? '');
        DateTime? proximaFecha;
        if (fechaInicio != null) {
          final diasPorTurno = frecuencia == 'Semanal' ? 7 : 
                              frecuencia == 'Quincenal' ? 15 : 30;
          proximaFecha = fechaInicio.add(Duration(days: diasPorTurno * (turnoActual - 1)));
        }
        
        bool esVencido = false;
        int diasVencido = 0;
        if (proximaFecha != null && proximaFecha.isBefore(hoy)) {
          esVencido = true;
          diasVencido = hoy.difference(proximaFecha).inDays;
        }

        _todosCobros.add(CobroPendienteUnificado(
          id: part['id'],
          tipo: TipoCobro.tanda,
          clienteId: cliente['id'],
          clienteNombre: cliente['nombre'] ?? 'Sin nombre',
          clienteTelefono: cliente['telefono'],
          clienteDireccion: cliente['direccion'],
          concepto: "Tanda: ${tanda['nombre']}",
          descripcion: "Turno $turnoActual • $frecuencia",
          monto: monto,
          fechaVencimiento: proximaFecha,
          esVencido: esVencido,
          diasVencido: diasVencido,
          tandaId: tanda['id'],
          icono: Icons.groups,
          color: Colors.purpleAccent,
        ));
      }
    } catch (e) {
      debugPrint('Error cargando tandas: $e');
    }
  }

  List<CobroPendienteUnificado> get _cobrosFiltrados {
    var cobros = _todosCobros;
    
    // Filtrar por tipo
    if (_filtroTipo != 'todos') {
      switch (_filtroTipo) {
        case 'prestamo':
          cobros = cobros.where((c) => c.tipo == TipoCobro.prestamo).toList();
          break;
        case 'diario':
          cobros = cobros.where((c) => c.tipo == TipoCobro.prestamodiario).toList();
          break;
        case 'tanda':
          cobros = cobros.where((c) => c.tipo == TipoCobro.tanda).toList();
          break;
      }
    }
    
    // Filtrar por tab
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    
    switch (_filtroActual) {
      case 0: // Hoy
        return cobros.where((c) => 
          c.esVencido || 
          (c.fechaVencimiento != null && 
           c.fechaVencimiento!.isBefore(finHoy))
        ).toList();
      case 1: // Vencidos
        return cobros.where((c) => c.esVencido).toList();
      default: // Todos
        return cobros;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Ruta de Cobro",
      subtitle: "Cobros pendientes del día",
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white70),
          onPressed: _mostrarFiltros,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: Column(
                children: [
                  // KPIs del cobrador
                  _buildKPIs(),
                  
                  // Tabs de filtro
                  _buildTabs(),
                  
                  // Lista de cobros
                  Expanded(child: _buildListaCobros()),
                ],
              ),
            ),
    );
  }

  Widget _buildKPIs() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKPIItem(
                "Por Cobrar Hoy",
                currencyFormat.format(_totalPorCobrar),
                Icons.attach_money,
                Colors.greenAccent,
              )),
              Container(width: 1, height: 50, color: Colors.white12),
              Expanded(child: _buildKPIItem(
                "Vencido",
                currencyFormat.format(_totalVencido),
                Icons.warning_amber,
                Colors.redAccent,
              )),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(child: _buildKPIItem(
                "Clientes",
                _clientesUnicos.toString(),
                Icons.people,
                Colors.cyanAccent,
              )),
              Container(width: 1, height: 50, color: Colors.white12),
              Expanded(child: _buildKPIItem(
                "Cobros Hoy",
                _cobrosHoy.toString(),
                Icons.today,
                Colors.orangeAccent,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String label, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildTabs() {
    final cobrosFiltrados = _cobrosFiltrados;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    
    final cobrosHoy = _todosCobros.where((c) => 
      c.esVencido || 
      (c.fechaVencimiento != null && c.fechaVencimiento!.isBefore(finHoy))
    ).length;
    final cobrosVencidos = _todosCobros.where((c) => c.esVencido).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: "Hoy ($cobrosHoy)"),
          Tab(text: "Vencidos ($cobrosVencidos)"),
          Tab(text: "Todos (${_todosCobros.length})"),
        ],
      ),
    );
  }

  Widget _buildListaCobros() {
    final cobros = _cobrosFiltrados;
    
    if (cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filtroActual == 1 ? Icons.check_circle : Icons.inbox,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              _filtroActual == 1 
                  ? "¡Sin cobros vencidos!"
                  : "No hay cobros pendientes",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cobros.length,
      itemBuilder: (context, index) => _buildCobroCard(cobros[index]),
    );
  }

  Widget _buildCobroCard(CobroPendienteUnificado cobro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: cobro.esVencido 
            ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        children: [
          // Header con estado de vencimiento
          if (cobro.esVencido)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "VENCIDO hace ${cobro.diasVencido} día(s)",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icono del tipo
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cobro.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cobro.icono, color: cobro.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    
                    // Info del cliente
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cobro.clienteNombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            cobro.concepto,
                            style: TextStyle(color: cobro.color, fontSize: 12),
                          ),
                          if (cobro.clienteTelefono != null)
                            Text(
                              cobro.clienteTelefono!,
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
                          currencyFormat.format(cobro.monto),
                          style: TextStyle(
                            color: cobro.esVencido ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (cobro.fechaVencimiento != null)
                          Text(
                            dateFormat.format(cobro.fechaVencimiento!),
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Botones de acción
                Row(
                  children: [
                    // Llamar
                    if (cobro.clienteTelefono != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _llamarCliente(cobro.clienteTelefono!),
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text("Llamar", style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            side: const BorderSide(color: Colors.cyanAccent),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (cobro.clienteTelefono != null) const SizedBox(width: 8),
                    
                    // WhatsApp
                    if (cobro.clienteTelefono != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _enviarWhatsApp(cobro),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text("WhatsApp", style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.greenAccent,
                            side: const BorderSide(color: Colors.greenAccent),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    
                    // Cobrar en efectivo
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _registrarCobroEfectivo(cobro),
                        icon: const Icon(Icons.payments, size: 16),
                        label: const Text("Cobrar", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Filtrar por Tipo",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildFiltroChip("Todos", 'todos', Icons.list, Colors.white70, setSheetState),
                  _buildFiltroChip("📋 Préstamos", 'prestamo', Icons.receipt_long, Colors.cyanAccent, setSheetState),
                  _buildFiltroChip("📅 Diarios", 'diario', Icons.calendar_today, Colors.orangeAccent, setSheetState),
                  _buildFiltroChip("👥 Tandas", 'tanda', Icons.groups, Colors.purpleAccent, setSheetState),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor, IconData icono, Color color, StateSetter setSheetState) {
    final activo = _filtroTipo == valor;
    return InkWell(
      onTap: () {
        setSheetState(() => _filtroTipo = valor);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18, color: activo ? color : Colors.white54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: activo ? color : Colors.white54,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  void _llamarCliente(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    // Usar url_launcher para llamar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Llamando a $telefono..."), backgroundColor: Colors.cyanAccent),
    );
  }

  void _enviarWhatsApp(CobroPendienteUnificado cobro) async {
    final mensaje = Uri.encodeComponent(
      "Hola ${cobro.clienteNombre}, te recordamos que tienes un pago pendiente:\n\n"
      "📋 ${cobro.concepto}\n"
      "💰 ${currencyFormat.format(cobro.monto)}\n"
      "${cobro.fechaVencimiento != null ? '📅 Vence: ${dateFormat.format(cobro.fechaVencimiento!)}' : ''}\n\n"
      "¿Deseas realizar el pago hoy?"
    );
    final url = "https://wa.me/${cobro.clienteTelefono}?text=$mensaje";
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Abriendo WhatsApp..."), backgroundColor: Colors.greenAccent),
    );
  }

  void _registrarCobroEfectivo(CobroPendienteUnificado cobro) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarCobroScreen(
          prestamoId: cobro.prestamoId,
          tandaId: cobro.tandaId,
          amortizacionId: cobro.amortizacionId,
          clienteId: cobro.clienteId,
          clienteNombre: cobro.clienteNombre,
          montoEsperado: cobro.monto,
          numeroCuota: cobro.numeroCuota,
        ),
      ),
    );

    // Si se registró el cobro, recargar datos
    if (resultado == true) {
      _cargarDatos();
    }
  }
}

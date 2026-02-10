// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// PANEL DE CONTABILIDAD - ÁREA DE CONTADOR
/// Robert Darin Platform V10.11
/// ══════════════════════════════════════════════════════════════════════════════
/// Panel especializado para contadores con acceso a información financiera real
/// ══════════════════════════════════════════════════════════════════════════════

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  bool _isLoading = true;
  
  // Datos financieros reales
  Map<String, dynamic> _resumenFinanciero = {};
  List<Map<String, dynamic>> _ingresosMensuales = [];
  List<Map<String, dynamic>> _gastosMensuales = [];
  List<Map<String, dynamic>> _cuentasPorCobrar = [];
  List<Map<String, dynamic>> _comisionesPendientes = [];
  
  // Filtros
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatosFinancieros();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosFinancieros() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Cargar préstamos activos (capital en la calle)
      final prestamosRes = await AppSupabase.client
          .from('prestamos')
          .select('monto_principal, monto_total, saldo_pendiente, estado, tasa_interes, created_at');
      
      final prestamos = List<Map<String, dynamic>>.from(prestamosRes);
      
      double capitalPrestado = 0;
      double interesesGenerados = 0;
      double saldoPendiente = 0;
      int prestamosActivos = 0;
      int prestamosPagados = 0;
      
      for (var p in prestamos) {
        final principal = (p['monto_principal'] ?? 0).toDouble();
        final total = (p['monto_total'] ?? 0).toDouble();
        final saldo = (p['saldo_pendiente'] ?? 0).toDouble();
        
        capitalPrestado += principal;
        interesesGenerados += (total - principal);
        saldoPendiente += saldo;
        
        if (p['estado'] == 'activo') prestamosActivos++;
        if (p['estado'] == 'pagado') prestamosPagados++;
      }
      
      // 2. Cargar pagos recibidos en el período
      final pagosRes = await AppSupabase.client
          .from('pagos')
          .select('monto, fecha_pago, metodo_pago, estado')
          .gte('fecha_pago', _fechaInicio.toIso8601String())
          .lte('fecha_pago', _fechaFin.toIso8601String())
          .eq('estado', 'completado');
      
      final pagos = List<Map<String, dynamic>>.from(pagosRes);
      double totalCobrado = 0;
      double efectivo = 0;
      double transferencias = 0;
      
      for (var p in pagos) {
        final monto = (p['monto'] ?? 0).toDouble();
        totalCobrado += monto;
        if (p['metodo_pago'] == 'efectivo') {
          efectivo += monto;
        } else {
          transferencias += monto;
        }
      }
      
      // 3. Cargar empleados y salarios
      final empleadosRes = await AppSupabase.client
          .from('empleados')
          .select('salario, comision_porcentaje, estado')
          .eq('estado', 'activo');
      
      final empleados = List<Map<String, dynamic>>.from(empleadosRes);
      double totalSalarios = 0;
      
      for (var e in empleados) {
        totalSalarios += (e['salario'] ?? 0).toDouble();
      }
      
      // 4. Cargar cuentas por cobrar (préstamos con saldo pendiente)
      final cuentasRes = await AppSupabase.client
          .from('prestamos')
          .select('id, monto_total, saldo_pendiente, estado, created_at, clientes(nombre_completo)')
          .gt('saldo_pendiente', 0)
          .order('saldo_pendiente', ascending: false)
          .limit(20);
      
      // 5. Cargar comisiones pendientes de empleados
      final comisionesRes = await AppSupabase.client
          .from('empleados')
          .select('id, puesto, comision_porcentaje, comision_tipo, usuarios(nombre_completo)')
          .gt('comision_porcentaje', 0);
      
      setState(() {
        _resumenFinanciero = {
          'capital_prestado': capitalPrestado,
          'intereses_generados': interesesGenerados,
          'total_por_cobrar': saldoPendiente,
          'total_cobrado_periodo': totalCobrado,
          'efectivo_periodo': efectivo,
          'transferencias_periodo': transferencias,
          'prestamos_activos': prestamosActivos,
          'prestamos_pagados': prestamosPagados,
          'empleados_activos': empleados.length,
          'nomina_mensual': totalSalarios,
          'ganancia_bruta': interesesGenerados,
          'ganancia_neta': interesesGenerados - totalSalarios,
        };
        
        _cuentasPorCobrar = List<Map<String, dynamic>>.from(cuentasRes);
        _comisionesPendientes = List<Map<String, dynamic>>.from(comisionesRes);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando datos financieros: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📊 Contabilidad',
      subtitle: 'Panel Financiero',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tabs
                Container(
                  color: const Color(0xFF1A1A2E),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.greenAccent,
                    labelColor: Colors.greenAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Resumen'),
                      Tab(icon: Icon(Icons.trending_up, size: 20), text: 'Ingresos'),
                      Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Por Cobrar'),
                      Tab(icon: Icon(Icons.payments, size: 20), text: 'Nómina'),
                    ],
                  ),
                ),
                
                // Contenido
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildIngresosTab(),
                      _buildPorCobrarTab(),
                      _buildNominaTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosFinancieros,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de período
            _buildSelectorPeriodo(),
            const SizedBox(height: 20),
            
            // KPIs principales
            Row(
              children: [
                Expanded(child: _buildKpiCard(
                  'Capital Prestado',
                  _currencyFormat.format(_resumenFinanciero['capital_prestado'] ?? 0),
                  Icons.account_balance,
                  Colors.blueAccent,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(
                  'Intereses Generados',
                  _currencyFormat.format(_resumenFinanciero['intereses_generados'] ?? 0),
                  Icons.trending_up,
                  Colors.greenAccent,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildKpiCard(
                  'Por Cobrar',
                  _currencyFormat.format(_resumenFinanciero['total_por_cobrar'] ?? 0),
                  Icons.pending_actions,
                  Colors.orangeAccent,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(
                  'Cobrado (Período)',
                  _currencyFormat.format(_resumenFinanciero['total_cobrado_periodo'] ?? 0),
                  Icons.check_circle,
                  Colors.tealAccent,
                )),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Balance
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.balance, color: Colors.greenAccent),
                      ),
                      const SizedBox(width: 12),
                      const Text('Balance General', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 30),
                  _buildBalanceRow('Ingresos por Intereses', _resumenFinanciero['intereses_generados'] ?? 0, true),
                  _buildBalanceRow('(-) Nómina Mensual', _resumenFinanciero['nomina_mensual'] ?? 0, false),
                  const Divider(color: Colors.white24),
                  _buildBalanceRow('= Utilidad Bruta', _resumenFinanciero['ganancia_neta'] ?? 0, true, isTotal: true),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Estadísticas rápidas
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📈 Estadísticas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildStatRow('Préstamos Activos', '${_resumenFinanciero['prestamos_activos'] ?? 0}'),
                  _buildStatRow('Préstamos Liquidados', '${_resumenFinanciero['prestamos_pagados'] ?? 0}'),
                  _buildStatRow('Empleados Activos', '${_resumenFinanciero['empleados_activos'] ?? 0}'),
                  _buildStatRow('Cobros en Efectivo', _currencyFormat.format(_resumenFinanciero['efectivo_periodo'] ?? 0)),
                  _buildStatRow('Cobros por Transferencia', _currencyFormat.format(_resumenFinanciero['transferencias_periodo'] ?? 0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngresosTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosFinancieros,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectorPeriodo(),
            const SizedBox(height: 20),
            
            // Resumen de ingresos
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Ingresos del Período', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniKpi('Total Cobrado', _resumenFinanciero['total_cobrado_periodo'] ?? 0, Colors.greenAccent),
                      _buildMiniKpi('Efectivo', _resumenFinanciero['efectivo_periodo'] ?? 0, Colors.amber),
                      _buildMiniKpi('Transferencias', _resumenFinanciero['transferencias_periodo'] ?? 0, Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Desglose de intereses
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Desglose Financiero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white12),
                  _buildDetalleRow('Capital Total Prestado', _resumenFinanciero['capital_prestado'] ?? 0, Icons.account_balance),
                  _buildDetalleRow('Intereses Generados', _resumenFinanciero['intereses_generados'] ?? 0, Icons.trending_up),
                  _buildDetalleRow('Saldo Por Cobrar', _resumenFinanciero['total_por_cobrar'] ?? 0, Icons.pending),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tasa de Recuperación', style: TextStyle(color: Colors.white70)),
                      Text(
                        '${((_resumenFinanciero['capital_prestado'] ?? 1) > 0 ? (((_resumenFinanciero['capital_prestado'] ?? 0) - (_resumenFinanciero['total_por_cobrar'] ?? 0)) / (_resumenFinanciero['capital_prestado'] ?? 1) * 100) : 0).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botón exportar
            ElevatedButton.icon(
              onPressed: _exportarReporteFinanciero,
              icon: const Icon(Icons.download),
              label: const Text('Exportar Reporte Financiero'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPorCobrarTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosFinancieros,
      child: _cuentasPorCobrar.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
                  SizedBox(height: 16),
                  Text('¡Excelente!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('No hay cuentas pendientes', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cuentasPorCobrar.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PremiumCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Por Cobrar:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(
                            _currencyFormat.format(_resumenFinanciero['total_por_cobrar'] ?? 0),
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final cuenta = _cuentasPorCobrar[index - 1];
                final cliente = cuenta['clientes']?['nombre_completo'] ?? 'Sin nombre';
                final saldo = (cuenta['saldo_pendiente'] ?? 0).toDouble();
                final total = (cuenta['monto_total'] ?? 0).toDouble();
                final porcentajePagado = total > 0 ? ((total - saldo) / total * 100) : 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(cliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              _currencyFormat.format(saldo),
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: porcentajePagado / 100,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pagado: ${porcentajePagado.toStringAsFixed(1)}% de ${_currencyFormat.format(total)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNominaTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosFinancieros,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de nómina
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('💼 Nómina Mensual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        _currencyFormat.format(_resumenFinanciero['nomina_mensual'] ?? 0),
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_resumenFinanciero['empleados_activos'] ?? 0} empleados activos',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Empleados con comisiones
            const Text('👥 Empleados con Comisiones', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            if (_comisionesPendientes.isEmpty)
              PremiumCard(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay empleados con comisiones configuradas', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              )
            else
              ..._comisionesPendientes.map((emp) {
                final nombre = emp['usuarios']?['nombre_completo'] ?? 'Empleado';
                final puesto = emp['puesto'] ?? 'Sin puesto';
                final comision = (emp['comision_porcentaje'] ?? 0).toDouble();
                final tipo = emp['comision_tipo'] ?? 'ninguna';
                
                String tipoDesc;
                Color tipoColor;
                switch (tipo) {
                  case 'al_liquidar':
                    tipoDesc = 'Al liquidar';
                    tipoColor = Colors.greenAccent;
                    break;
                  case 'proporcional':
                    tipoDesc = 'Proporcional';
                    tipoColor = Colors.blueAccent;
                    break;
                  case 'primer_pago':
                    tipoDesc = 'Primer pago';
                    tipoColor = Colors.orangeAccent;
                    break;
                  default:
                    tipoDesc = 'Sin comisión';
                    tipoColor = Colors.grey;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Text(nombre[0].toUpperCase(), style: const TextStyle(color: Colors.blueAccent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(puesto, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${comision.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tipoColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(tipoDesc, style: TextStyle(color: tipoColor, fontSize: 10)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    return PremiumCard(
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _seleccionarFecha(true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Desde', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(DateFormat('dd/MM/yyyy').format(_fechaInicio), style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
          Expanded(
            child: InkWell(
              onTap: () => _seleccionarFecha(false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hasta', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(DateFormat('dd/MM/yyyy').format(_fechaFin), style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _cargarDatosFinancieros,
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
      _cargarDatosFinancieros();
    }
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icon, Color color) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(String titulo, double valor, Color color) {
    return Column(
      children: [
        Text(_currencyFormat.format(valor), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildBalanceRow(String concepto, double monto, bool esIngreso, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(concepto, style: TextStyle(
            color: isTotal ? Colors.white : Colors.white70,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          )),
          Text(
            _currencyFormat.format(monto),
            style: TextStyle(
              color: isTotal ? Colors.greenAccent : (esIngreso ? Colors.greenAccent : Colors.redAccent),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, double valor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(_currencyFormat.format(valor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _exportarReporteFinanciero() {
    final StringBuffer reporte = StringBuffer();
    reporte.writeln('════════════════════════════════════════');
    reporte.writeln('REPORTE FINANCIERO - ROBERT DARIN FINTECH');
    reporte.writeln('════════════════════════════════════════');
    reporte.writeln('Período: ${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}');
    reporte.writeln('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    reporte.writeln('');
    reporte.writeln('RESUMEN FINANCIERO');
    reporte.writeln('──────────────────────────────────────');
    reporte.writeln('Capital Prestado: ${_currencyFormat.format(_resumenFinanciero['capital_prestado'] ?? 0)}');
    reporte.writeln('Intereses Generados: ${_currencyFormat.format(_resumenFinanciero['intereses_generados'] ?? 0)}');
    reporte.writeln('Saldo Por Cobrar: ${_currencyFormat.format(_resumenFinanciero['total_por_cobrar'] ?? 0)}');
    reporte.writeln('');
    reporte.writeln('COBRANZA DEL PERÍODO');
    reporte.writeln('──────────────────────────────────────');
    reporte.writeln('Total Cobrado: ${_currencyFormat.format(_resumenFinanciero['total_cobrado_periodo'] ?? 0)}');
    reporte.writeln('  - Efectivo: ${_currencyFormat.format(_resumenFinanciero['efectivo_periodo'] ?? 0)}');
    reporte.writeln('  - Transferencias: ${_currencyFormat.format(_resumenFinanciero['transferencias_periodo'] ?? 0)}');
    reporte.writeln('');
    reporte.writeln('GASTOS');
    reporte.writeln('──────────────────────────────────────');
    reporte.writeln('Nómina Mensual: ${_currencyFormat.format(_resumenFinanciero['nomina_mensual'] ?? 0)}');
    reporte.writeln('Empleados Activos: ${_resumenFinanciero['empleados_activos'] ?? 0}');
    reporte.writeln('');
    reporte.writeln('UTILIDAD');
    reporte.writeln('──────────────────────────────────────');
    reporte.writeln('Utilidad Bruta: ${_currencyFormat.format(_resumenFinanciero['ganancia_neta'] ?? 0)}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('📊 Reporte Generado', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reporte.toString(),
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 Reporte copiado al portapapeles'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}

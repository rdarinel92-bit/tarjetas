// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/colaboradores_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE INVERSIONES DEL COLABORADOR
// Gestión de capital, aportaciones y rendimientos
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorInversionesScreen extends StatefulWidget {
  final String colaboradorId;
  
  const ColaboradorInversionesScreen({super.key, required this.colaboradorId});
  
  @override
  State<ColaboradorInversionesScreen> createState() => _ColaboradorInversionesScreenState();
}

class _ColaboradorInversionesScreenState extends State<ColaboradorInversionesScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  ColaboradorModel? _colaborador;
  List<ColaboradorInversionModel> _inversiones = [];
  List<Map<String, dynamic>> _rendimientos = [];
  late TabController _tabController;
  
  // Totales
  double _totalCapital = 0;
  double _totalRendimientos = 0;
  double _saldoDisponible = 0;

  final _moneyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar colaborador
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('id', widget.colaboradorId)
          .single();
      
      _colaborador = ColaboradorModel.fromMap(colabRes);

      // Cargar inversiones
      final invRes = await AppSupabase.client
          .from('colaborador_inversiones')
          .select()
          .eq('colaborador_id', widget.colaboradorId)
          .order('fecha', ascending: false);
      
      _inversiones = invRes.map((m) => ColaboradorInversionModel.fromMap(m)).toList();

      // Cargar rendimientos
      final rendRes = await AppSupabase.client
          .from('colaborador_rendimientos')
          .select()
          .eq('colaborador_id', widget.colaboradorId)
          .order('periodo_fin', ascending: false);
      
      _rendimientos = List<Map<String, dynamic>>.from(rendRes);

      // Calcular totales
      _calcularTotales();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar inversiones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotales() {
    _totalCapital = 0;
    for (var inv in _inversiones) {
      if (inv.tipo == 'aportacion') {
        _totalCapital += inv.monto;
      } else if (inv.tipo == 'retiro') {
        _totalCapital -= inv.monto;
      }
    }
    
    _totalRendimientos = 0;
    for (var r in _rendimientos) {
      if (r['estado'] == 'pagado') {
        _totalRendimientos += (r['monto_rendimiento'] as num?)?.toDouble() ?? 0;
      }
    }
    
    _saldoDisponible = _totalCapital + _totalRendimientos;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '💰 Inversiones',
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _mostrarAgregarMovimiento,
          tooltip: 'Nuevo movimiento',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumenHeader(),
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF10B981),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Resumen'),
                    Tab(text: 'Movimientos'),
                    Tab(text: 'Rendimientos'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildMovimientosTab(),
                      _buildRendimientosTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _colaborador?.iniciales ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _colaborador?.nombre ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Inversionista',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo Total', style: TextStyle(color: Colors.white70)),
                Text(
                  _moneyFormat.format(_saldoDisponible),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    final participacion = _colaborador?.porcentajeParticipacion ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats en grid
          Row(
            children: [
              Expanded(child: _buildStatCard('Capital\nAportado', _moneyFormat.format(_totalCapital), Icons.savings, const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Rendimientos\nGenerados', _moneyFormat.format(_totalRendimientos), Icons.trending_up, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Participación\nen Cartera', '${participacion.toStringAsFixed(2)}%', Icons.pie_chart, const Color(0xFF8B5CF6))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Movimientos\nRegistrados', '${_inversiones.length}', Icons.swap_horiz, const Color(0xFFF59E0B))),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Gráfico simulado de participación
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución del Capital',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Barra de participación
                Row(
                  children: [
                    Expanded(
                      flex: (participacion * 10).toInt().clamp(1, 100),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.horizontal(left: const Radius.circular(12), right: participacion >= 100 ? const Radius.circular(12) : Radius.zero),
                        ),
                        child: Center(
                          child: Text(
                            '${participacion.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    if (participacion < 100)
                      Expanded(
                        flex: ((100 - participacion) * 10).toInt().clamp(1, 100),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tu participación', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    Text('Resto de socios', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Proyección (simulada)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B5CF6).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_graph, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Proyección de Rendimientos',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProyeccionItem('Este mes (estimado)', _totalCapital * 0.03),
                _buildProyeccionItem('Próximo trimestre', _totalCapital * 0.10),
                _buildProyeccionItem('En 12 meses', _totalCapital * 0.40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyeccionItem(String periodo, double monto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(periodo, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          Text(
            '+ ${_moneyFormat.format(monto)}',
            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientosTab() {
    if (_inversiones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Sin movimientos registrados',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _mostrarAgregarMovimiento,
              icon: const Icon(Icons.add),
              label: const Text('Registrar Aportación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inversiones.length,
      itemBuilder: (context, index) {
        final inv = _inversiones[index];
        final esAportacion = inv.tipo == 'aportacion';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (esAportacion ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                esAportacion ? Icons.arrow_downward : Icons.arrow_upward,
                color: esAportacion ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
            title: Text(
              esAportacion ? 'Aportación de Capital' : 'Retiro de Capital',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(inv.fecha),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                if (inv.concepto != null && inv.concepto!.isNotEmpty)
                  Text(
                    inv.concepto!,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Text(
              '${esAportacion ? '+' : '-'} ${_moneyFormat.format(inv.monto)}',
              style: TextStyle(
                color: esAportacion ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRendimientosTab() {
    if (_rendimientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Sin rendimientos registrados',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              'Los rendimientos se calculan mensualmente',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rendimientos.length,
      itemBuilder: (context, index) {
        final r = _rendimientos[index];
        final estado = r['estado'] ?? 'pendiente';
        final monto = (r['monto_rendimiento'] as num?)?.toDouble() ?? 0;
        final periodoInicio = r['periodo_inicio'] != null ? DateTime.parse(r['periodo_inicio']) : null;
        final periodoFin = r['periodo_fin'] != null ? DateTime.parse(r['periodo_fin']) : null;
        
        Color estadoColor;
        IconData estadoIcon;
        switch (estado) {
          case 'pagado':
            estadoColor = const Color(0xFF10B981);
            estadoIcon = Icons.check_circle;
            break;
          case 'pendiente':
            estadoColor = const Color(0xFFF59E0B);
            estadoIcon = Icons.schedule;
            break;
          default:
            estadoColor = Colors.grey;
            estadoIcon = Icons.help_outline;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: estado == 'pendiente' 
                ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(estadoIcon, color: estadoColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    estado == 'pagado' ? 'Pagado' : 'Pendiente',
                    style: TextStyle(color: estadoColor, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    _moneyFormat.format(monto),
                    style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (periodoInicio != null && periodoFin != null)
                Row(
                  children: [
                    Icon(Icons.date_range, size: 14, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Text(
                      'Periodo: ${_dateFormat.format(periodoInicio)} - ${_dateFormat.format(periodoFin)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              if (r['tasa_aplicada'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.percent, size: 14, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Text(
                      'Tasa aplicada: ${r['tasa_aplicada']}%',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _mostrarAgregarMovimiento() {
    final montoController = TextEditingController();
    final conceptoController = TextEditingController();
    String tipoSeleccionado = 'aportacion';
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuevo Movimiento',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Tipo de movimiento
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => tipoSeleccionado = 'aportacion'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: tipoSeleccionado == 'aportacion' 
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tipoSeleccionado == 'aportacion'
                                ? const Color(0xFF10B981)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              color: tipoSeleccionado == 'aportacion' ? const Color(0xFF10B981) : Colors.white54,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aportación',
                              style: TextStyle(
                                color: tipoSeleccionado == 'aportacion' ? const Color(0xFF10B981) : Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => tipoSeleccionado = 'retiro'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: tipoSeleccionado == 'retiro'
                              ? const Color(0xFFEF4444).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tipoSeleccionado == 'retiro'
                                ? const Color(0xFFEF4444)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: tipoSeleccionado == 'retiro' ? const Color(0xFFEF4444) : Colors.white54,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Retiro',
                              style: TextStyle(
                                color: tipoSeleccionado == 'retiro' ? const Color(0xFFEF4444) : Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Monto
              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Concepto
              TextField(
                controller: conceptoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Concepto (opcional)',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: guardando ? null : () async {
                    final monto = double.tryParse(montoController.text.replaceAll(',', ''));
                    if (monto == null || monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa un monto válido'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setSheetState(() => guardando = true);

                    try {
                      await AppSupabase.client
                          .from('colaborador_inversiones')
                          .insert({
                            'colaborador_id': widget.colaboradorId,
                            'tipo': tipoSeleccionado,
                            'monto': monto,
                            'concepto': conceptoController.text.isEmpty ? null : conceptoController.text,
                            'fecha': DateTime.now().toIso8601String(),
                            'estado': 'confirmado',
                          });

                      if (mounted) {
                        Navigator.pop(context);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Movimiento registrado'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setSheetState(() => guardando = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tipoSeleccionado == 'aportacion' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tipoSeleccionado == 'aportacion' ? 'Registrar Aportación' : 'Registrar Retiro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

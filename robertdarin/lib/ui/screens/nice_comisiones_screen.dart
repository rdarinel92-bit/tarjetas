import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// NICE COMISIONES SCREEN V10.22
/// ═══════════════════════════════════════════════════════════════════════════════
/// Gestión de comisiones del sistema MLM Nice Joyería.
/// Muestra comisiones de ventas propias, de equipo, bonos por nivel.
/// Filtros: por vendedora, periodo, tipo de comisión, estado de pago.
/// ═══════════════════════════════════════════════════════════════════════════════

class NiceComisionesScreen extends StatefulWidget {
  const NiceComisionesScreen({super.key});

  @override
  State<NiceComisionesScreen> createState() => _NiceComisionesScreenState();
}

class _NiceComisionesScreenState extends State<NiceComisionesScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _comisiones = [];
  List<dynamic> _vendedoras = [];
  String _filtroVendedora = 'todas';
  String _filtroTipo = 'todos';
  String _filtroEstado = 'todos';
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();
  late TabController _tabController;

  double get _totalComisiones => _comisionesFiltradas.fold(0.0, (sum, c) => sum + (c['monto'] ?? 0).toDouble());
  double get _totalPagado => _comisionesFiltradas.where((c) => c['pagado'] == true).fold(0.0, (sum, c) => sum + (c['monto'] ?? 0).toDouble());
  double get _totalPendiente => _comisionesFiltradas.where((c) => c['pagado'] != true).fold(0.0, (sum, c) => sum + (c['monto'] ?? 0).toDouble());

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
      setState(() => _isLoading = true);
      
      // Cargar vendedoras para filtro
      final vendedoras = await AppSupabase.client
          .from('nice_vendedoras')
          .select('id, nombre')
          .eq('activa', true)
          .order('nombre');
      
      // Cargar comisiones
      final comisiones = await AppSupabase.client
          .from('nice_comisiones')
          .select('''
            *,
            vendedora:nice_vendedoras(id, nombre, codigo),
            pedido:nice_pedidos(id, numero_pedido, total)
          ''')
          .gte('created_at', _fechaInicio.toIso8601String())
          .lte('created_at', _fechaFin.toIso8601String())
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _vendedoras = vendedoras;
          _comisiones = comisiones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _comisionesFiltradas {
    return _comisiones.where((c) {
      if (_filtroVendedora != 'todas' && c['vendedora_id'] != _filtroVendedora) return false;
      if (_filtroTipo != 'todos' && c['tipo'] != _filtroTipo) return false;
      if (_filtroEstado != 'todos') {
        final pagado = c['pagado'] == true;
        if (_filtroEstado == 'pagado' && !pagado) return false;
        if (_filtroEstado == 'pendiente' && pagado) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Comisiones Nice',
      body: Column(
        children: [
          _buildResumen(),
          _buildFiltros(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaComisiones('todos'),
                _buildListaComisiones('venta_propia'),
                _buildListaComisiones('venta_equipo'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Resumen de Comisiones',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _seleccionarPeriodo,
                icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                label: Text(
                  '${DateFormat('dd/MM').format(_fechaInicio)} - ${DateFormat('dd/MM').format(_fechaFin)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem(
                  'Total',
                  _totalComisiones,
                  Icons.account_balance_wallet,
                  Colors.white,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.3)),
              Expanded(
                child: _buildResumenItem(
                  'Pagado',
                  _totalPagado,
                  Icons.check_circle,
                  const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.3)),
              Expanded(
                child: _buildResumenItem(
                  'Pendiente',
                  _totalPendiente,
                  Icons.pending,
                  const Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, double monto, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          '\$${_formatNumber(monto)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filtro por vendedora
            _buildDropdownFiltro(
              'Vendedora',
              _filtroVendedora,
              [
                const DropdownMenuItem(value: 'todas', child: Text('Todas')),
                ..._vendedoras.map((v) => DropdownMenuItem(
                  value: v['id'],
                  child: Text(v['nombre'] ?? ''),
                )),
              ],
              (value) => setState(() {
                _filtroVendedora = value ?? 'todas';
              }),
            ),
            const SizedBox(width: 12),
            // Filtro por estado
            _buildDropdownFiltro(
              'Estado',
              _filtroEstado,
              const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
              ],
              (value) => setState(() {
                _filtroEstado = value ?? 'todos';
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFiltro(String label, String value, List<DropdownMenuItem<String>> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          dropdownColor: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(text: 'Todas'),
          Tab(text: 'Propias'),
          Tab(text: 'Equipo'),
        ],
      ),
    );
  }

  Widget _buildListaComisiones(String tipo) {
    final comisiones = tipo == 'todos' 
        ? _comisionesFiltradas 
        : _comisionesFiltradas.where((c) => c['tipo'] == tipo).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)));
    }

    if (comisiones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on, size: 80, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin comisiones',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
            ),
            Text(
              'No hay comisiones en este periodo',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
        itemCount: comisiones.length,
        itemBuilder: (context, index) {
          final comision = comisiones[index];
          return _buildComisionCard(comision);
        },
      ),
    );
  }

  Widget _buildComisionCard(Map<String, dynamic> comision) {
    final monto = (comision['monto'] ?? 0).toDouble();
    final pagado = comision['pagado'] == true;
    final tipo = comision['tipo'] ?? 'venta_propia';
    final vendedora = comision['vendedora'];
    final pedido = comision['pedido'];
    final fecha = DateTime.tryParse(comision['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pagado 
              ? const Color(0xFF10B981).withValues(alpha: 0.3) 
              : const Color(0xFFFBBF24).withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalles(comision),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono según tipo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tipo == 'venta_propia'
                          ? [const Color(0xFF00D9FF).withValues(alpha: 0.3), const Color(0xFF8B5CF6).withValues(alpha: 0.3)]
                          : [const Color(0xFFEC4899).withValues(alpha: 0.3), const Color(0xFF8B5CF6).withValues(alpha: 0.3)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tipo == 'venta_propia' ? Icons.person : Icons.groups,
                    color: tipo == 'venta_propia' ? const Color(0xFF00D9FF) : const Color(0xFFEC4899),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tipo == 'venta_propia' ? 'Venta Propia' : 'Venta de Equipo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: pagado
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFFBBF24).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pagado ? 'Pagado' : 'Pendiente',
                              style: TextStyle(
                                color: pagado ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendedora != null ? vendedora['nombre'] ?? '' : 'Sin vendedora',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pedido != null ? 'Pedido #${pedido['numero_pedido']}' : 'Bono',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Monto y fecha
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_formatNumber(monto)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yy').format(fecha),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    if (!pagado) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _marcarPagado(comision),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pagar',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(Map<String, dynamic> comision) {
    final monto = (comision['monto'] ?? 0).toDouble();
    final porcentaje = (comision['porcentaje'] ?? 0).toDouble();
    final pagado = comision['pagado'] == true;
    final tipo = comision['tipo'] ?? 'venta_propia';
    final vendedora = comision['vendedora'];
    final pedido = comision['pedido'];
    final fecha = DateTime.tryParse(comision['created_at'] ?? '') ?? DateTime.now();
    final fechaPago = comision['fecha_pago'] != null ? DateTime.tryParse(comision['fecha_pago']) : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.monetization_on, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipo == 'venta_propia' ? 'Comisión por Venta Propia' : 'Comisión por Venta de Equipo',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        vendedora?['nombre'] ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetalleRow('Monto', '\$${_formatNumber(monto)}', Icons.attach_money),
            _buildDetalleRow('Porcentaje', '${porcentaje.toStringAsFixed(1)}%', Icons.percent),
            if (pedido != null) ...[
              _buildDetalleRow('Pedido', '#${pedido['numero_pedido']}', Icons.receipt),
              _buildDetalleRow('Total Pedido', '\$${_formatNumber((pedido['total'] ?? 0).toDouble())}', Icons.shopping_cart),
            ],
            _buildDetalleRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(fecha), Icons.calendar_today),
            _buildDetalleRow('Estado', pagado ? 'Pagado' : 'Pendiente', pagado ? Icons.check_circle : Icons.pending),
            if (fechaPago != null)
              _buildDetalleRow('Fecha de Pago', DateFormat('dd/MM/yyyy').format(fechaPago), Icons.payment),
            const SizedBox(height: 24),
            if (!pagado)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _marcarPagado(comision);
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Marcar como Pagado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _marcarPagado(Map<String, dynamic> comision) async {
    try {
      await AppSupabase.client
          .from('nice_comisiones')
          .update({
            'pagado': true,
            'fecha_pago': DateTime.now().toIso8601String(),
          })
          .eq('id', comision['id']);
      
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comisión marcada como pagada'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _seleccionarPeriodo() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
      _cargarDatos();
    }
  }

  String _formatNumber(num number) {
    return number.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

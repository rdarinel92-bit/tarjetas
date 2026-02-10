// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

/// Pantalla de rendimientos para inversionistas
/// Calcula automáticamente ganancias basadas en capital y % pactado
class RendimientosInversionistaScreen extends StatefulWidget {
  final String? inversionistaId;

  const RendimientosInversionistaScreen({super.key, this.inversionistaId});

  @override
  State<RendimientosInversionistaScreen> createState() =>
      _RendimientosInversionistaScreenState();
}

class _RendimientosInversionistaScreenState
    extends State<RendimientosInversionistaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inversionistas = [];
  String? _inversionistaSeleccionado;
  Map<String, dynamic>? _datosInversionista;
  List<Map<String, dynamic>> _rendimientosHistorico = [];
  
  final _formatoMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarInversionistas();
  }

  Future<void> _cargarInversionistas() async {
    try {
      final res = await AppSupabase.client
          .from('colaboradores')
          .select('*, colaborador_tipos(*)')
          .eq('es_inversionista', true)
          .eq('estado', 'activo')
          .order('nombre');

      if (mounted) {
        setState(() {
          _inversionistas = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
          
          if (widget.inversionistaId != null) {
            _inversionistaSeleccionado = widget.inversionistaId;
            _cargarDatosInversionista(widget.inversionistaId!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarDatosInversionista(String id) async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar datos del inversionista
      final inv = await AppSupabase.client
          .from('colaboradores')
          .select('*, colaborador_tipos(*)')
          .eq('id', id)
          .single();

      // Cargar historial de rendimientos
      final rendimientos = await AppSupabase.client
          .from('colaborador_rendimientos')
          .select()
          .eq('colaborador_id', id)
          .order('periodo_inicio', ascending: false);

      if (mounted) {
        setState(() {
          _datosInversionista = inv;
          _rendimientosHistorico = List<Map<String, dynamic>>.from(rendimientos);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Rendimientos',
      subtitle: 'Calculadora de ganancias para inversionistas',
      actions: [
        if (_datosInversionista != null)
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _mostrarCalculadora,
            tooltip: 'Calculadora',
          ),
        IconButton(
          icon: const Icon(Icons.add_chart),
          onPressed: _generarRendimientoMes,
          tooltip: 'Generar rendimiento del mes',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    return Column(
      children: [
        _buildSelectorInversionista(),
        if (_datosInversionista != null) ...[
          _buildResumenInversion(),
          _buildCalculadoraRapida(),
          const SizedBox(height: 16),
          Expanded(child: _buildHistorialRendimientos()),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona un inversionista',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectorInversionista() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _inversionistaSeleccionado,
          isExpanded: true,
          hint: const Text(
            '📈 Selecciona un inversionista',
            style: TextStyle(color: Colors.white54),
          ),
          dropdownColor: const Color(0xFF1A1A2E),
          items: _inversionistas.map((inv) {
            final monto = (inv['monto_invertido'] ?? 0).toDouble();
            return DropdownMenuItem(
              value: inv['id'] as String,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                    child: Text(
                      (inv['nombre'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          inv['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Inversión: ${_formatoMoneda.format(monto)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            setState(() => _inversionistaSeleccionado = v);
            if (v != null) _cargarDatosInversionista(v);
          },
        ),
      ),
    );
  }

  Widget _buildResumenInversion() {
    if (_datosInversionista == null) return const SizedBox();

    final capital = (_datosInversionista!['monto_invertido'] ?? 0).toDouble();
    final porcentaje = (_datosInversionista!['porcentaje_participacion'] ?? 0).toDouble();
    final rendimientoPactado = (_datosInversionista!['rendimiento_pactado'] ?? 0).toDouble();
    
    // Calcular rendimiento mensual
    final rendimientoMensual = capital * (rendimientoPactado / 100);
    
    // Calcular total pagado
    final totalPagado = _rendimientosHistorico
        .where((r) => r['estado'] == 'pagado')
        .fold<double>(0, (sum, r) => sum + (r['monto_rendimiento'] ?? 0).toDouble());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  (_datosInversionista!['nombre'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datosInversionista!['nombre'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
          Row(
            children: [
              Expanded(
                child: _buildStatInversion(
                  'Capital',
                  _formatoMoneda.format(capital),
                  Icons.account_balance_wallet,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              Expanded(
                child: _buildStatInversion(
                  'Rendimiento',
                  '${rendimientoPactado.toStringAsFixed(1)}% mensual',
                  Icons.percent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatInversion(
                  'Gana/Mes',
                  _formatoMoneda.format(rendimientoMensual),
                  Icons.trending_up,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              Expanded(
                child: _buildStatInversion(
                  'Total Pagado',
                  _formatoMoneda.format(totalPagado),
                  Icons.payments,
                ),
              ),
            ],
          ),
          if (porcentaje > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pie_chart, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text(
                    'Participación en el negocio: ${porcentaje.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatInversion(String label, String valor, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculadoraRapida() {
    if (_datosInversionista == null) return const SizedBox();

    final capital = (_datosInversionista!['monto_invertido'] ?? 0).toDouble();
    final rendimientoPactado = (_datosInversionista!['rendimiento_pactado'] ?? 0).toDouble();
    final mensual = capital * (rendimientoPactado / 100);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text(
                'Proyección de Ganancias',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildProyeccion('1 Mes', mensual)),
              Expanded(child: _buildProyeccion('3 Meses', mensual * 3)),
              Expanded(child: _buildProyeccion('6 Meses', mensual * 6)),
              Expanded(child: _buildProyeccion('1 Año', mensual * 12)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En 1 año recupera ${((mensual * 12 / capital) * 100).toStringAsFixed(1)}% de su inversión',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyeccion(String periodo, double monto) {
    return Column(
      children: [
        Text(
          periodo,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          _formatoMoneda.format(monto),
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialRendimientos() {
    if (_rendimientosHistorico.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Sin rendimientos registrados',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generarRendimientoMes,
              icon: const Icon(Icons.add),
              label: const Text('Generar Primer Rendimiento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial de Rendimientos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _generarRendimientoMes,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nuevo'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rendimientosHistorico.length,
            itemBuilder: (context, index) {
              final rend = _rendimientosHistorico[index];
              return _buildRendimientoCard(rend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRendimientoCard(Map<String, dynamic> rend) {
    final monto = (rend['monto_rendimiento'] ?? 0).toDouble();
    final estado = rend['estado'] ?? 'pendiente';
    final periodoInicio = DateTime.parse(rend['periodo_inicio']);
    final periodoFin = DateTime.parse(rend['periodo_fin']);

    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;

    switch (estado) {
      case 'pagado':
        estadoColor = const Color(0xFF10B981);
        estadoIcon = Icons.check_circle;
        estadoTexto = 'Pagado';
        break;
      case 'aprobado':
        estadoColor = const Color(0xFF3B82F6);
        estadoIcon = Icons.thumb_up;
        estadoTexto = 'Aprobado';
        break;
      default:
        estadoColor = const Color(0xFFF59E0B);
        estadoIcon = Icons.schedule;
        estadoTexto = 'Pendiente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: estadoColor.withOpacity(0.2),
            child: Icon(estadoIcon, color: estadoColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'es').format(periodoInicio),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_formatoFecha.format(periodoInicio)} - ${_formatoFecha.format(periodoFin)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatoMoneda.format(monto),
                style: TextStyle(
                  color: estadoColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  estadoTexto,
                  style: TextStyle(color: estadoColor, fontSize: 10),
                ),
              ),
            ],
          ),
          if (estado == 'pendiente') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: const Color(0xFF1A1A2E),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'aprobar',
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Aprobar', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pagar',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Marcar Pagado', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) => _actualizarEstado(rend['id'], value),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _actualizarEstado(String id, String accion) async {
    try {
      String nuevoEstado;
      Map<String, dynamic> updates = {};

      if (accion == 'aprobar') {
        nuevoEstado = 'aprobado';
        updates['fecha_aprobacion'] = DateTime.now().toIso8601String();
      } else {
        nuevoEstado = 'pagado';
        updates['fecha_pago'] = DateTime.now().toIso8601String();
      }

      updates['estado'] = nuevoEstado;

      await AppSupabase.client
          .from('colaborador_rendimientos')
          .update(updates)
          .eq('id', id);

      _cargarDatosInversionista(_inversionistaSeleccionado!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accion == 'aprobar' ? '✅ Rendimiento aprobado' : '✅ Rendimiento pagado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _mostrarCalculadora() {
    if (_datosInversionista == null) return;

    final capitalCtrl = TextEditingController(
      text: (_datosInversionista!['monto_invertido'] ?? 0).toString(),
    );
    final porcentajeCtrl = TextEditingController(
      text: (_datosInversionista!['rendimiento_pactado'] ?? 0).toString(),
    );
    double resultado = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void calcular() {
            final capital = double.tryParse(capitalCtrl.text) ?? 0;
            final porcentaje = double.tryParse(porcentajeCtrl.text) ?? 0;
            setSheetState(() {
              resultado = capital * (porcentaje / 100);
            });
          }

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D14),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.calculate, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Calculadora de Rendimientos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: capitalCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Capital Invertido',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => calcular(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: porcentajeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Porcentaje Mensual',
                    labelStyle: const TextStyle(color: Colors.white54),
                    suffixText: '%',
                    suffixStyle: const TextStyle(color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => calcular(),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Rendimiento Mensual',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatoMoneda.format(resultado),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniProyeccion('Trimestral', resultado * 3),
                          _buildMiniProyeccion('Semestral', resultado * 6),
                          _buildMiniProyeccion('Anual', resultado * 12),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniProyeccion(String label, double monto) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(
          _formatoMoneda.format(monto),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _generarRendimientoMes() async {
    if (_datosInversionista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un inversionista primero')),
      );
      return;
    }

    final capital = (_datosInversionista!['monto_invertido'] ?? 0).toDouble();
    final rendimientoPactado = (_datosInversionista!['rendimiento_pactado'] ?? 0).toDouble();
    final rendimientoMensual = capital * (rendimientoPactado / 100);

    // Determinar el período (mes actual)
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final finMes = DateTime(ahora.year, ahora.month + 1, 0);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Generar Rendimiento', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período: ${DateFormat('MMMM yyyy', 'es').format(inicioMes)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Capital: ${_formatoMoneda.format(capital)}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Tasa: ${rendimientoPactado.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70),
            ),
            const Divider(color: Colors.white24, height: 24),
            Text(
              'Rendimiento: ${_formatoMoneda.format(rendimientoMensual)}',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Generar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await AppSupabase.client.from('colaborador_rendimientos').insert({
        'colaborador_id': _inversionistaSeleccionado,
        'negocio_id': _datosInversionista!['negocio_id'],
        'periodo_inicio': inicioMes.toIso8601String().split('T')[0],
        'periodo_fin': finMes.toIso8601String().split('T')[0],
        'capital_base': capital,
        'tasa_aplicada': rendimientoPactado,
        'monto_rendimiento': rendimientoMensual,
        'estado': 'pendiente',
      });

      _cargarDatosInversionista(_inversionistaSeleccionado!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Rendimiento generado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

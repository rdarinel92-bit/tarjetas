// ═══════════════════════════════════════════════════════════════════════════════
// QR ANALYTICS DASHBOARD - V10.54
// Dashboard avanzado de métricas para Tarjetas QR
// Incluye: Gráficas temporales, mapa de calor, conversiones, top tarjetas
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class QrAnalyticsDashboardScreen extends StatefulWidget {
  final String? negocioId;
  final String? tarjetaId; // Si es específico de una tarjeta
  
  const QrAnalyticsDashboardScreen({
    super.key,
    this.negocioId,
    this.tarjetaId,
  });

  @override
  State<QrAnalyticsDashboardScreen> createState() => _QrAnalyticsDashboardScreenState();
}

class _QrAnalyticsDashboardScreenState extends State<QrAnalyticsDashboardScreen> {
  bool _isLoading = true;
  String _periodoSeleccionado = '7d'; // 7d, 30d, 90d, year
  
  // Métricas generales
  int _totalEscaneos = 0;
  int _escaneosHoy = 0;
  int _escaneosSemana = 0;
  int _escaneosMes = 0;
  int _totalLeads = 0;
  int _leadsNuevos = 0;
  double _tasaConversion = 0;
  
  // Datos para gráficas
  List<Map<String, dynamic>> _escaneosPorDia = [];
  List<Map<String, dynamic>> _escaneosPorHora = [];
  List<Map<String, dynamic>> _accionesPorTipo = [];
  List<Map<String, dynamic>> _topTarjetas = [];
  List<Map<String, dynamic>> _dispositivosData = [];
  List<Map<String, dynamic>> _ubicacionesData = [];

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Calcular fechas según periodo
      final now = DateTime.now();
      DateTime fechaInicio;
      switch (_periodoSeleccionado) {
        case '7d':
          fechaInicio = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          fechaInicio = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          fechaInicio = now.subtract(const Duration(days: 90));
          break;
        case 'year':
          fechaInicio = DateTime(now.year, 1, 1);
          break;
        default:
          fechaInicio = now.subtract(const Duration(days: 7));
      }

      // Cargar escaneos globales
      var query = AppSupabase.client
          .from('tarjetas_servicio_escaneos')
          .select('*, tarjetas_servicio!inner(titulo, modulo, created_by)')
          .gte('created_at', fechaInicio.toIso8601String());

      if (widget.tarjetaId != null) {
        query = query.eq('tarjeta_id', widget.tarjetaId!);
      } else {
        query = query.eq('tarjetas_servicio.created_by', user.id);
      }

      final escaneos = await query.order('created_at', ascending: false);
      final escaneosList = List<Map<String, dynamic>>.from(escaneos);

      // Calcular métricas
      _totalEscaneos = escaneosList.length;
      _escaneosHoy = escaneosList.where((e) {
        final fecha = DateTime.parse(e['created_at']);
        return fecha.day == now.day && fecha.month == now.month && fecha.year == now.year;
      }).length;
      _escaneosSemana = escaneosList.where((e) {
        final fecha = DateTime.parse(e['created_at']);
        return fecha.isAfter(now.subtract(const Duration(days: 7)));
      }).length;
      _escaneosMes = escaneosList.where((e) {
        final fecha = DateTime.parse(e['created_at']);
        return fecha.isAfter(now.subtract(const Duration(days: 30)));
      }).length;

      // Cargar leads (formularios enviados)
      var leadsQuery = AppSupabase.client
          .from('formularios_qr_envios')
          .select('*, tarjetas_servicio!inner(created_by)')
          .gte('created_at', fechaInicio.toIso8601String());

      if (widget.tarjetaId != null) {
        leadsQuery = leadsQuery.eq('tarjeta_id', widget.tarjetaId!);
      } else {
        leadsQuery = leadsQuery.eq('tarjetas_servicio.created_by', user.id);
      }

      final leads = await leadsQuery;
      final leadsList = List<Map<String, dynamic>>.from(leads);
      _totalLeads = leadsList.length;
      _leadsNuevos = leadsList.where((l) => l['estado'] == 'nuevo').length;
      
      // Tasa de conversión
      _tasaConversion = _totalEscaneos > 0 ? (_totalLeads / _totalEscaneos) * 100 : 0;

      // Agrupar escaneos por día
      _escaneosPorDia = _agruparPorDia(escaneosList);
      
      // Agrupar por hora del día
      _escaneosPorHora = _agruparPorHora(escaneosList);
      
      // Agrupar por tipo de acción
      _accionesPorTipo = _agruparPorAccion(escaneosList);

      // Top tarjetas
      await _cargarTopTarjetas();

      // Dispositivos
      _dispositivosData = _agruparPorDispositivo(escaneosList);

    } catch (e) {
      debugPrint('Error cargando analytics: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _agruparPorDia(List<Map<String, dynamic>> escaneos) {
    final Map<String, int> porDia = {};
    for (final e in escaneos) {
      final fecha = DateTime.parse(e['created_at']);
      final key = DateFormat('yyyy-MM-dd').format(fecha);
      porDia[key] = (porDia[key] ?? 0) + 1;
    }
    
    // Llenar días sin escaneos
    final now = DateTime.now();
    final dias = _periodoSeleccionado == '7d' ? 7 : 
                 _periodoSeleccionado == '30d' ? 30 : 
                 _periodoSeleccionado == '90d' ? 90 : 365;
    
    final resultado = <Map<String, dynamic>>[];
    for (int i = dias - 1; i >= 0; i--) {
      final fecha = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(fecha);
      resultado.add({
        'fecha': key,
        'label': DateFormat('dd/MM').format(fecha),
        'cantidad': porDia[key] ?? 0,
      });
    }
    return resultado;
  }

  List<Map<String, dynamic>> _agruparPorHora(List<Map<String, dynamic>> escaneos) {
    final Map<int, int> porHora = {};
    for (final e in escaneos) {
      final fecha = DateTime.parse(e['created_at']);
      porHora[fecha.hour] = (porHora[fecha.hour] ?? 0) + 1;
    }
    
    final resultado = <Map<String, dynamic>>[];
    for (int hora = 0; hora < 24; hora++) {
      resultado.add({
        'hora': hora,
        'label': '${hora.toString().padLeft(2, '0')}:00',
        'cantidad': porHora[hora] ?? 0,
      });
    }
    return resultado;
  }

  List<Map<String, dynamic>> _agruparPorAccion(List<Map<String, dynamic>> escaneos) {
    final Map<String, int> porAccion = {};
    for (final e in escaneos) {
      final accion = e['accion'] ?? 'ver';
      porAccion[accion] = (porAccion[accion] ?? 0) + 1;
    }
    
    final colores = <String, Color>{
      'ver': Colors.blue,
      'llamar': Colors.green,
      'whatsapp': Colors.teal,
      'email': Colors.orange,
      'mapa': Colors.purple,
      'formulario': Colors.cyan,
      'otro': Colors.grey,
    };
    
    final iconos = <String, IconData>{
      'ver': Icons.visibility,
      'llamar': Icons.phone,
      'whatsapp': Icons.chat,
      'email': Icons.email,
      'mapa': Icons.map,
      'formulario': Icons.assignment,
      'otro': Icons.more_horiz,
    };
    
    final resultado = <Map<String, dynamic>>[];
    for (final e in porAccion.entries) {
      resultado.add({
        'accion': e.key,
        'cantidad': e.value,
        'color': colores[e.key] ?? Colors.grey,
        'icono': iconos[e.key] ?? Icons.help,
      });
    }
    resultado.sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
    return resultado;
  }

  List<Map<String, dynamic>> _agruparPorDispositivo(List<Map<String, dynamic>> escaneos) {
    final Map<String, int> porDispositivo = {};
    for (final e in escaneos) {
      final dispositivo = e['dispositivo'] ?? 'Desconocido';
      porDispositivo[dispositivo] = (porDispositivo[dispositivo] ?? 0) + 1;
    }
    
    final resultado = <Map<String, dynamic>>[];
    for (final e in porDispositivo.entries) {
      resultado.add({'dispositivo': e.key, 'cantidad': e.value});
    }
    resultado.sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
    return resultado;
  }

  Future<void> _cargarTopTarjetas() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final tarjetas = await AppSupabase.client
          .from('tarjetas_servicio')
          .select('id, titulo, modulo, escaneos_total, activa')
          .eq('created_by', user.id)
          .order('escaneos_total', ascending: false)
          .limit(5);

      _topTarjetas = List<Map<String, dynamic>>.from(tarjetas);
    } catch (e) {
      debugPrint('Error cargando top tarjetas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Analytics QR',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onSelected: (value) {
            setState(() => _periodoSeleccionado = value);
            _cargarDatos();
          },
          itemBuilder: (context) => [
            _buildPeriodoItem('7d', 'Últimos 7 días'),
            _buildPeriodoItem('30d', 'Últimos 30 días'),
            _buildPeriodoItem('90d', 'Últimos 90 días'),
            _buildPeriodoItem('year', 'Este año'),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPIsGrid(),
                    const SizedBox(height: 20),
                    _buildGraficaEscaneosDiarios(),
                    const SizedBox(height: 20),
                    _buildGraficaHorasPico(),
                    const SizedBox(height: 20),
                    _buildAccionesChart(),
                    const SizedBox(height: 20),
                    _buildTopTarjetasCard(),
                    const SizedBox(height: 20),
                    _buildConversionFunnel(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  PopupMenuItem<String> _buildPeriodoItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_periodoSeleccionado == value)
            const Icon(Icons.check, color: Colors.cyan, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildKPIsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKPICard('👁️', 'Escaneos Totales', _totalEscaneos.toString(), Colors.cyan)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('📅', 'Hoy', _escaneosHoy.toString(), Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('📊', 'Esta Semana', _escaneosSemana.toString(), Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('📈', 'Este Mes', _escaneosMes.toString(), Colors.purple)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('📬', 'Leads Totales', _totalLeads.toString(), Colors.teal)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('🎯', 'Conversión', '${_tasaConversion.toStringAsFixed(1)}%', Colors.amber)),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String emoji, String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              Icon(Icons.trending_up, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaEscaneosDiarios() {
    if (_escaneosPorDia.isEmpty) return const SizedBox.shrink();

    final maxY = _escaneosPorDia.fold<double>(1, (max, e) {
      final val = (e['cantidad'] as int).toDouble();
      return val > max ? val : max;
    }) * 1.2;

    // Mostrar solo algunos labels para no saturar
    final step = _escaneosPorDia.length > 14 ? (_escaneosPorDia.length / 7).ceil() : 1;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Escaneos por Día',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _escaneosPorDia.length) return const Text('');
                        if (idx % step != 0) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _escaneosPorDia[idx]['label'],
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _escaneosPorDia.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), (e.value['cantidad'] as int).toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.cyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: _escaneosPorDia.length <= 14,
                      getDotPainter: (spot, percent, barData, index) => 
                          FlDotCirclePainter(radius: 3, color: Colors.cyan, strokeWidth: 1, strokeColor: Colors.white),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.cyan.withOpacity(0.3), Colors.cyan.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaHorasPico() {
    if (_escaneosPorHora.isEmpty) return const SizedBox.shrink();

    final maxY = _escaneosPorHora.fold<double>(1, (max, e) {
      final val = (e['cantidad'] as int).toDouble();
      return val > max ? val : max;
    }) * 1.2;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🕐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Horarios Pico',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mejores horas para promocionar',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx % 4 != 0) return const Text('');
                        return Text(
                          '${idx}h',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _escaneosPorHora.asMap().entries.map((e) {
                  final cantidad = (e.value['cantidad'] as int).toDouble();
                  final esHoraPico = cantidad == maxY / 1.2;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: cantidad,
                        color: esHoraPico ? Colors.amber : Colors.cyan.withOpacity(0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesChart() {
    if (_accionesPorTipo.isEmpty) return const SizedBox.shrink();

    final total = _accionesPorTipo.fold<int>(0, (sum, e) => sum + (e['cantidad'] as int));

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Acciones Realizadas',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._accionesPorTipo.take(6).map((accion) {
            final porcentaje = total > 0 ? (accion['cantidad'] as int) / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (accion['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(accion['icono'] as IconData, color: accion['color'] as Color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (accion['accion'] as String).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: porcentaje,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(accion['color'] as Color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${accion['cantidad']}',
                    style: TextStyle(color: accion['color'] as Color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${(porcentaje * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopTarjetasCard() {
    if (_topTarjetas.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Top 5 Tarjetas',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._topTarjetas.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final medalla = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '  ${i + 1}.';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: i == 0 ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: i == 0 ? Colors.amber.withOpacity(0.3) : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Text(medalla, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['titulo'] ?? 'Sin título',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          (t['modulo'] ?? 'general').toString().toUpperCase(),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${t['escaneos_total'] ?? 0}',
                      style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildConversionFunnel() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔄', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Embudo de Conversión',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFunnelStep('👁️ Escaneos', _totalEscaneos, 1.0, Colors.cyan),
          _buildFunnelStep('📝 Formularios', _totalLeads, _totalEscaneos > 0 ? _totalLeads / _totalEscaneos : 0, Colors.purple),
          _buildFunnelStep('🆕 Nuevos', _leadsNuevos, _totalEscaneos > 0 ? _leadsNuevos / _totalEscaneos : 0, Colors.green),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tasaConversion >= 10
                        ? '¡Excelente! Tu tasa de conversión está por encima del promedio.'
                        : 'Tip: Agrega más campos útiles al formulario para mejorar conversiones.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(String label, int cantidad, double porcentaje, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(
                '$cantidad (${(porcentaje * 100).toStringAsFixed(1)}%)',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

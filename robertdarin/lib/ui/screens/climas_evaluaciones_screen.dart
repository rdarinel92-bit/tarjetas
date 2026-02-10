// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS SISTEMA DE EVALUACIONES - V10.55
// Calificaciones de técnicos, encuestas de satisfacción, métricas de servicio
// Para Superadmin (gestión), Clientes (calificar), Técnicos (ver su desempeño)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class ClimasEvaluacionesScreen extends StatefulWidget {
  final String? negocioId;
  final String? tecnicoId; // Si se pasa, muestra evaluaciones de ese técnico específico
  final bool modoCliente; // Si es true, muestra formulario para calificar
  final String? ordenId; // Para calificar una orden específica
  
  const ClimasEvaluacionesScreen({
    super.key, 
    this.negocioId, 
    this.tecnicoId,
    this.modoCliente = false,
    this.ordenId,
  });

  @override
  State<ClimasEvaluacionesScreen> createState() => _ClimasEvaluacionesScreenState();
}

class _ClimasEvaluacionesScreenState extends State<ClimasEvaluacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  String _periodoSeleccionado = '30d';
  
  // Datos de evaluaciones
  List<Map<String, dynamic>> _evaluaciones = [];
  List<Map<String, dynamic>> _rankingTecnicos = [];
  Map<String, dynamic>? _estadisticasGenerales;
  
  // Para formulario de evaluación (modo cliente)
  int _calificacionServicio = 0;
  int _calificacionPuntualidad = 0;
  int _calificacionPresentacion = 0;
  int _calificacionSolucion = 0;
  final _comentarioController = TextEditingController();
  bool _recomendaria = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.modoCliente ? 1 : 3, vsync: this);
    
    if (widget.modoCliente && widget.ordenId != null) {
      _isLoading = false;
    } else {
      _cargarDatos();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final dias = _periodoSeleccionado == '7d' ? 7 
                 : _periodoSeleccionado == '30d' ? 30 
                 : _periodoSeleccionado == '90d' ? 90 : 365;
      final fechaInicio = DateTime.now().subtract(Duration(days: dias));
      
      // Cargar evaluaciones
      var evalQuery = AppSupabase.client
          .from('climas_evaluaciones')
          .select('*, climas_ordenes_servicio(id, tipo_servicio), climas_tecnicos(id, nombre, foto_url), climas_clientes(nombre)')
          .gte('created_at', fechaInicio.toIso8601String());
      
      if (widget.negocioId != null) {
        evalQuery = evalQuery.eq('negocio_id', widget.negocioId!);
      }
      if (widget.tecnicoId != null) {
        evalQuery = evalQuery.eq('tecnico_id', widget.tecnicoId!);
      }
      
      final evalRes = await evalQuery.order('created_at', ascending: false);
      _evaluaciones = List<Map<String, dynamic>>.from(evalRes);
      
      // Calcular ranking de técnicos
      await _calcularRanking(fechaInicio);
      
      // Estadísticas generales
      _calcularEstadisticas();
      
    } catch (e) {
      debugPrint('Error cargando evaluaciones: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _calcularRanking(DateTime fechaInicio) async {
    try {
      // Obtener todos los técnicos
      var tecnicosQuery = AppSupabase.client
          .from('climas_tecnicos')
          .select('id, nombre, foto_url')
          .eq('activo', true);
      
      if (widget.negocioId != null) {
        tecnicosQuery = tecnicosQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final tecnicosRes = await tecnicosQuery;
      final tecnicos = List<Map<String, dynamic>>.from(tecnicosRes);
      
      _rankingTecnicos = [];
      
      for (final tecnico in tecnicos) {
        // Evaluaciones del técnico
        final evalsTecnico = _evaluaciones.where((e) => e['tecnico_id'] == tecnico['id']).toList();
        
        if (evalsTecnico.isEmpty) {
          _rankingTecnicos.add({
            ...tecnico,
            'promedio': 0.0,
            'total_evaluaciones': 0,
            'recomendaciones': 0,
          });
          continue;
        }
        
        // Calcular promedio
        double suma = 0;
        int recomendaciones = 0;
        for (final e in evalsTecnico) {
          final promEval = _calcularPromedioEvaluacion(e);
          suma += promEval;
          if (e['recomendaria'] == true) recomendaciones++;
        }
        
        _rankingTecnicos.add({
          ...tecnico,
          'promedio': suma / evalsTecnico.length,
          'total_evaluaciones': evalsTecnico.length,
          'recomendaciones': recomendaciones,
          'tasa_recomendacion': (recomendaciones / evalsTecnico.length * 100),
        });
      }
      
      // Ordenar por promedio
      _rankingTecnicos.sort((a, b) => (b['promedio'] as double).compareTo(a['promedio'] as double));
      
    } catch (e) {
      debugPrint('Error calculando ranking: $e');
    }
  }

  double _calcularPromedioEvaluacion(Map<String, dynamic> eval) {
    final servicio = eval['calificacion_servicio'] ?? 0;
    final puntualidad = eval['calificacion_puntualidad'] ?? 0;
    final presentacion = eval['calificacion_presentacion'] ?? 0;
    final solucion = eval['calificacion_solucion'] ?? 0;
    
    int count = 0;
    int suma = 0;
    if (servicio > 0) { suma += servicio as int; count++; }
    if (puntualidad > 0) { suma += puntualidad as int; count++; }
    if (presentacion > 0) { suma += presentacion as int; count++; }
    if (solucion > 0) { suma += solucion as int; count++; }
    
    return count > 0 ? suma / count : 0;
  }

  void _calcularEstadisticas() {
    if (_evaluaciones.isEmpty) {
      _estadisticasGenerales = null;
      return;
    }
    
    double sumaPromedios = 0;
    int totalRecomendaciones = 0;
    final distribucion = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    for (final e in _evaluaciones) {
      final prom = _calcularPromedioEvaluacion(e);
      sumaPromedios += prom;
      if (e['recomendaria'] == true) totalRecomendaciones++;
      
      final promRedondeado = prom.round().clamp(1, 5);
      distribucion[promRedondeado] = (distribucion[promRedondeado] ?? 0) + 1;
    }
    
    _estadisticasGenerales = {
      'promedio_general': sumaPromedios / _evaluaciones.length,
      'total_evaluaciones': _evaluaciones.length,
      'tasa_recomendacion': (totalRecomendaciones / _evaluaciones.length * 100),
      'distribucion': distribucion,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Modo cliente - formulario de evaluación
    if (widget.modoCliente) {
      return _buildFormularioEvaluacion();
    }
    
    // Modo admin/técnico - ver evaluaciones
    return PremiumScaffold(
      title: widget.tecnicoId != null ? 'Mis Evaluaciones' : 'Evaluaciones',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          onSelected: (value) {
            setState(() => _periodoSeleccionado = value);
            _cargarDatos();
          },
          itemBuilder: (context) => [
            _buildPeriodoItem('7d', '7 días'),
            _buildPeriodoItem('30d', '30 días'),
            _buildPeriodoItem('90d', '3 meses'),
            _buildPeriodoItem('365d', '1 año'),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
              children: [
                // Tabs
                Container(
                  color: const Color(0xFF0D0D14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.amber,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.star, size: 20), text: 'Resumen'),
                      Tab(icon: Icon(Icons.leaderboard, size: 20), text: 'Ranking'),
                      Tab(icon: Icon(Icons.rate_review, size: 20), text: 'Reseñas'),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildRankingTab(),
                      _buildResenasTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<String> _buildPeriodoItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_periodoSeleccionado == value)
            const Icon(Icons.check, color: Colors.amber, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    if (_estadisticasGenerales == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No hay evaluaciones', style: TextStyle(color: Colors.white.withOpacity(0.4))),
          ],
        ),
      );
    }
    
    final promedio = _estadisticasGenerales!['promedio_general'] as double;
    final total = _estadisticasGenerales!['total_evaluaciones'] as int;
    final tasaRec = _estadisticasGenerales!['tasa_recomendacion'] as double;
    final distribucion = _estadisticasGenerales!['distribucion'] as Map<int, int>;
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Calificación general
            _buildCalificacionGeneral(promedio, total, tasaRec),
            
            const SizedBox(height: 20),
            
            // Distribución de calificaciones
            _buildDistribucion(distribucion, total),
            
            const SizedBox(height: 20),
            
            // Últimas evaluaciones destacadas
            _buildEvaluacionesDestacadas(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalificacionGeneral(double promedio, int total, double tasaRec) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Estrellas y número grande
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                promedio.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEstrellas(promedio, 24),
                  const SizedBox(height: 4),
                  Text(
                    '$total evaluaciones',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Métricas adicionales
          Row(
            children: [
              Expanded(child: _buildMetricaResumen(
                '👍',
                '${tasaRec.toStringAsFixed(0)}%',
                'Lo recomiendan',
              )),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: _buildMetricaResumen(
                '📊',
                '${_evaluaciones.length}',
                'Este período',
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstrellas(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        }
        return Icon(Icons.star_border, color: Colors.amber.withOpacity(0.3), size: size);
      }),
    );
  }

  Widget _buildMetricaResumen(String emoji, String valor, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDistribucion(Map<int, int> distribucion, int total) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Distribución de Calificaciones',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...List.generate(5, (index) {
            final estrellas = 5 - index;
            final cantidad = distribucion[estrellas] ?? 0;
            final porcentaje = total > 0 ? cantidad / total : 0.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$estrellas',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: porcentaje,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getColorEstrellas(estrellas),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$cantidad',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getColorEstrellas(int estrellas) {
    switch (estrellas) {
      case 5: return Colors.green;
      case 4: return Colors.lightGreen;
      case 3: return Colors.amber;
      case 2: return Colors.orange;
      case 1: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildEvaluacionesDestacadas() {
    final destacadas = _evaluaciones.where((e) {
      final prom = _calcularPromedioEvaluacion(e);
      return prom >= 4.5 && (e['comentario']?.toString().isNotEmpty ?? false);
    }).take(3).toList();
    
    if (destacadas.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⭐ Evaluaciones Destacadas',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...destacadas.map((e) => _buildEvaluacionCard(e)),
      ],
    );
  }

  Widget _buildRankingTab() {
    if (_rankingTecnicos.isEmpty) {
      return _buildEmptyState('No hay ranking disponible');
    }
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rankingTecnicos.length,
        itemBuilder: (context, index) => _buildTecnicoRankingCard(_rankingTecnicos[index], index + 1),
      ),
    );
  }

  Widget _buildTecnicoRankingCard(Map<String, dynamic> tecnico, int posicion) {
    final promedio = tecnico['promedio'] as double;
    final totalEvals = tecnico['total_evaluaciones'] as int;
    final tasaRec = tecnico['tasa_recomendacion'] as double? ?? 0;
    
    Color posicionColor = posicion == 1 ? Colors.amber 
                        : posicion == 2 ? Colors.grey[400]! 
                        : posicion == 3 ? Colors.brown[400]! 
                        : Colors.white24;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: posicion <= 3 ? Border.all(color: posicionColor, width: 2) : null,
      ),
      child: Row(
        children: [
          // Posición
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: posicionColor.withOpacity(posicion <= 3 ? 0.3 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: posicion <= 3
                  ? Icon(Icons.emoji_events, color: posicionColor, size: 22)
                  : Text(
                      '$posicion',
                      style: TextStyle(
                        color: posicionColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.cyan.withOpacity(0.2),
            backgroundImage: tecnico['foto_url'] != null 
                ? NetworkImage(tecnico['foto_url']) 
                : null,
            child: tecnico['foto_url'] == null 
                ? const Icon(Icons.person, color: Colors.cyan) 
                : null,
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tecnico['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildEstrellas(promedio, 14),
                    const SizedBox(width: 4),
                    Text(
                      '($totalEvals)',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Promedio
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                promedio.toStringAsFixed(1),
                style: TextStyle(
                  color: promedio >= 4 ? Colors.green : promedio >= 3 ? Colors.amber : Colors.orange,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (totalEvals > 0)
                Text(
                  '${tasaRec.toStringAsFixed(0)}% rec.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResenasTab() {
    if (_evaluaciones.isEmpty) {
      return _buildEmptyState('No hay reseñas');
    }
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _evaluaciones.length,
        itemBuilder: (context, index) => _buildEvaluacionCard(_evaluaciones[index]),
      ),
    );
  }

  Widget _buildEvaluacionCard(Map<String, dynamic> eval) {
    final promedio = _calcularPromedioEvaluacion(eval);
    final cliente = eval['climas_clientes'];
    final tecnico = eval['climas_tecnicos'];
    final fecha = DateTime.tryParse(eval['created_at'] ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente?['nombre'] ?? 'Cliente anónimo',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (tecnico != null)
                      Text(
                        'Técnico: ${tecnico['nombre']}',
                        style: TextStyle(color: Colors.cyan.withOpacity(0.8), fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildEstrellas(promedio, 16),
                  if (fecha != null)
                    Text(
                      _dateFormat.format(fecha),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
          
          // Desglose de calificaciones
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (eval['calificacion_servicio'] != null)
                _buildMiniCalificacion('Servicio', eval['calificacion_servicio']),
              if (eval['calificacion_puntualidad'] != null)
                _buildMiniCalificacion('Puntualidad', eval['calificacion_puntualidad']),
              if (eval['calificacion_presentacion'] != null)
                _buildMiniCalificacion('Presentación', eval['calificacion_presentacion']),
              if (eval['calificacion_solucion'] != null)
                _buildMiniCalificacion('Solución', eval['calificacion_solucion']),
            ],
          ),
          
          // Comentario
          if (eval['comentario'] != null && (eval['comentario'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${eval['comentario']}"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          
          // Recomendación
          if (eval['recomendaria'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  eval['recomendaria'] ? Icons.thumb_up : Icons.thumb_down,
                  size: 14,
                  color: eval['recomendaria'] ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  eval['recomendaria'] ? 'Recomienda el servicio' : 'No recomienda',
                  style: TextStyle(
                    color: eval['recomendaria'] ? Colors.green : Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCalificacion(String label, int valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (i) => Icon(
          i < valor ? Icons.star : Icons.star_border,
          size: 10,
          color: Colors.amber,
        )),
      ],
    );
  }

  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(mensaje, style: TextStyle(color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // FORMULARIO DE EVALUACIÓN (MODO CLIENTE)
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildFormularioEvaluacion() {
    return PremiumScaffold(
      title: 'Calificar Servicio',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.rate_review, color: Colors.amber, size: 48),
                  SizedBox(height: 12),
                  Text(
                    '¿Cómo fue tu experiencia?',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tu opinión nos ayuda a mejorar',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Calificaciones
            _buildSeccionCalificacion(
              'Calidad del Servicio',
              'El trabajo realizado en tu equipo',
              _calificacionServicio,
              (val) => setState(() => _calificacionServicio = val),
            ),
            
            _buildSeccionCalificacion(
              'Puntualidad',
              'Llegó a la hora acordada',
              _calificacionPuntualidad,
              (val) => setState(() => _calificacionPuntualidad = val),
            ),
            
            _buildSeccionCalificacion(
              'Presentación',
              'Uniforme, herramientas, limpieza',
              _calificacionPresentacion,
              (val) => setState(() => _calificacionPresentacion = val),
            ),
            
            _buildSeccionCalificacion(
              'Solución del Problema',
              '¿Se resolvió tu problema?',
              _calificacionSolucion,
              (val) => setState(() => _calificacionSolucion = val),
            ),
            
            const SizedBox(height: 20),
            
            // Comentario
            const Text(
              'Comentarios adicionales (opcional)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comentarioController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cuéntanos más sobre tu experiencia...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Recomendación
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Recomendarías nuestro servicio?',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'A amigos o familiares',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _recomendaria = true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _recomendaria ? Colors.green.withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: _recomendaria ? Border.all(color: Colors.green) : null,
                          ),
                          child: Icon(
                            Icons.thumb_up,
                            color: _recomendaria ? Colors.green : Colors.white54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _recomendaria = false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !_recomendaria ? Colors.red.withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: !_recomendaria ? Border.all(color: Colors.red) : null,
                          ),
                          child: Icon(
                            Icons.thumb_down,
                            color: !_recomendaria ? Colors.red : Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botón enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _puedeEnviar() ? _enviarEvaluacion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Enviar Evaluación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCalificacion(String titulo, String subtitulo, int valor, Function(int) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(subtitulo, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final estrella = index + 1;
              return GestureDetector(
                onTap: () => onChanged(estrella),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    estrella <= valor ? Icons.star : Icons.star_border,
                    color: estrella <= valor ? Colors.amber : Colors.white24,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _puedeEnviar() {
    return _calificacionServicio > 0 &&
           _calificacionPuntualidad > 0 &&
           _calificacionPresentacion > 0 &&
           _calificacionSolucion > 0;
  }

  Future<void> _enviarEvaluacion() async {
    if (!_puedeEnviar()) return;
    
    try {
      await AppSupabase.client.from('climas_evaluaciones').insert({
        'orden_id': widget.ordenId,
        'negocio_id': widget.negocioId,
        'calificacion_servicio': _calificacionServicio,
        'calificacion_puntualidad': _calificacionPuntualidad,
        'calificacion_presentacion': _calificacionPresentacion,
        'calificacion_solucion': _calificacionSolucion,
        'comentario': _comentarioController.text.trim(),
        'recomendaria': _recomendaria,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por tu evaluación!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error enviando evaluación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al enviar. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

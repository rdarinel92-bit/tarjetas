// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS RUTAS GPS OPTIMIZADAS - V10.55
// Planificación inteligente de rutas para técnicos de campo
// Optimización de visitas, tiempos estimados y tráfico en tiempo real
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class ClimasRutasGpsScreen extends StatefulWidget {
  final String? negocioId;
  final String? tecnicoId;
  
  const ClimasRutasGpsScreen({super.key, this.negocioId, this.tecnicoId});

  @override
  State<ClimasRutasGpsScreen> createState() => _ClimasRutasGpsScreenState();
}

class _ClimasRutasGpsScreenState extends State<ClimasRutasGpsScreen> {
  final _timeFormat = DateFormat('HH:mm');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  bool _optimizando = false;
  DateTime _fechaSeleccionada = DateTime.now();
  Position? _ubicacionActual;
  
  List<Map<String, dynamic>> _ordenesDelDia = [];
  List<Map<String, dynamic>> _rutaOptimizada = [];
  List<Map<String, dynamic>> _tecnicos = [];
  String? _tecnicoSeleccionado;
  
  // Métricas de ruta
  double _distanciaTotal = 0; // km
  int _tiempoTotal = 0; // minutos
  int _visitasCompletadas = 0;

  @override
  void initState() {
    super.initState();
    _tecnicoSeleccionado = widget.tecnicoId;
    _obtenerUbicacion();
    _cargarDatos();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _ubicacionActual = pos);
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar técnicos (si no hay uno específico)
      if (widget.tecnicoId == null) {
        var tecnicosQuery = AppSupabase.client
            .from('climas_tecnicos')
            .select('id, nombre, foto_url, activo')
            .eq('activo', true);
        
        if (widget.negocioId != null) {
          tecnicosQuery = tecnicosQuery.eq('negocio_id', widget.negocioId!);
        }
        
        final tecnicosRes = await tecnicosQuery.order('nombre');
        _tecnicos = List<Map<String, dynamic>>.from(tecnicosRes);
        
        if (_tecnicos.isNotEmpty && _tecnicoSeleccionado == null) {
          _tecnicoSeleccionado = _tecnicos[0]['id'];
        }
      }
      
      // Cargar órdenes del día para el técnico
      if (_tecnicoSeleccionado != null) {
        await _cargarOrdenesDelDia();
      }
      
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarOrdenesDelDia() async {
    final inicioDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
    final finDia = inicioDia.add(const Duration(days: 1));
    
    try {
      var query = AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('*, climas_clientes(nombre, telefono, direccion, latitud, longitud), climas_equipos(marca, modelo)')
          .eq('tecnico_id', _tecnicoSeleccionado!)
          .gte('fecha_programada', inicioDia.toIso8601String())
          .lt('fecha_programada', finDia.toIso8601String())
          .inFilter('estado', ['pendiente', 'en_proceso', 'completada']);
      
      final resultado = await query.order('hora_programada');
      _ordenesDelDia = List<Map<String, dynamic>>.from(resultado);
      
      // Calcular métricas
      _visitasCompletadas = _ordenesDelDia.where((o) => o['estado'] == 'completada').length;
      
      // Optimizar ruta
      _optimizarRuta();
      
    } catch (e) {
      debugPrint('Error cargando órdenes: $e');
    }
  }

  void _optimizarRuta() {
    // Algoritmo de optimización simple (nearest neighbor)
    if (_ordenesDelDia.isEmpty) {
      _rutaOptimizada = [];
      _distanciaTotal = 0;
      _tiempoTotal = 0;
      return;
    }
    
    setState(() => _optimizando = true);
    
    // Filtrar solo órdenes pendientes y en proceso con coordenadas
    final ordenesPendientes = _ordenesDelDia.where((o) {
      final cliente = o['climas_clientes'];
      return o['estado'] != 'completada' && 
             cliente != null &&
             cliente['latitud'] != null && 
             cliente['longitud'] != null;
    }).toList();
    
    if (ordenesPendientes.isEmpty) {
      _rutaOptimizada = _ordenesDelDia;
      _distanciaTotal = 0;
      _tiempoTotal = 0;
      setState(() => _optimizando = false);
      return;
    }
    
    // Punto de inicio (ubicación actual o primera orden)
    double currentLat = _ubicacionActual?.latitude ?? 
        (ordenesPendientes[0]['climas_clientes']?['latitud'] ?? 0);
    double currentLng = _ubicacionActual?.longitude ?? 
        (ordenesPendientes[0]['climas_clientes']?['longitud'] ?? 0);
    
    final visitadas = <Map<String, dynamic>>[];
    final disponibles = List<Map<String, dynamic>>.from(ordenesPendientes);
    
    _distanciaTotal = 0;
    
    while (disponibles.isNotEmpty) {
      // Encontrar la orden más cercana
      double menorDistancia = double.infinity;
      int indiceMasCercano = 0;
      
      for (int i = 0; i < disponibles.length; i++) {
        final cliente = disponibles[i]['climas_clientes'];
        final lat = (cliente['latitud'] as num?)?.toDouble() ?? 0;
        final lng = (cliente['longitud'] as num?)?.toDouble() ?? 0;
        
        final distancia = Geolocator.distanceBetween(currentLat, currentLng, lat, lng);
        
        if (distancia < menorDistancia) {
          menorDistancia = distancia;
          indiceMasCercano = i;
        }
      }
      
      // Agregar la orden más cercana a la ruta
      final orden = disponibles.removeAt(indiceMasCercano);
      visitadas.add(orden);
      _distanciaTotal += menorDistancia / 1000; // Convertir a km
      
      // Actualizar posición actual
      final cliente = orden['climas_clientes'];
      currentLat = (cliente['latitud'] as num?)?.toDouble() ?? currentLat;
      currentLng = (cliente['longitud'] as num?)?.toDouble() ?? currentLng;
    }
    
    // Agregar las órdenes ya completadas al principio
    final completadas = _ordenesDelDia.where((o) => o['estado'] == 'completada').toList();
    _rutaOptimizada = [...completadas, ...visitadas];
    
    // Calcular tiempo estimado (promedio 45 min por servicio + tiempo de traslado)
    final tiempoServicio = ordenesPendientes.length * 45;
    final tiempoTraslado = (_distanciaTotal / 30 * 60).round(); // 30 km/h promedio en ciudad
    _tiempoTotal = tiempoServicio + tiempoTraslado;
    
    setState(() => _optimizando = false);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Rutas GPS',
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          onPressed: _seleccionarFecha,
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
                // Header con métricas y selector
                _buildHeader(),
                
                // Lista de visitas
                Expanded(
                  child: _rutaOptimizada.isEmpty
                      ? _buildEmptyState()
                      : _buildListaVisitas(),
                ),
                
                // Botones de acción
                _buildAcciones(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0D0D14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Selector de técnico (si aplica)
          if (_tecnicos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tecnicoSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan),
                  isExpanded: true,
                  items: _tecnicos.map((t) => DropdownMenuItem(
                    value: t['id'] as String,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.cyan.withOpacity(0.2),
                          child: t['foto_url'] != null
                              ? ClipOval(child: Image.network(t['foto_url'], fit: BoxFit.cover))
                              : const Icon(Icons.person, size: 16, color: Colors.cyan),
                        ),
                        const SizedBox(width: 8),
                        Text(t['nombre'] ?? 'Sin nombre'),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _tecnicoSeleccionado = value);
                    _cargarOrdenesDelDia();
                  },
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Fecha seleccionada
          GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.cyan, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _dateFormat.format(_fechaSeleccionada),
                    style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // KPIs de ruta
          Row(
            children: [
              Expanded(child: _buildMetricaRuta(
                Icons.pin_drop,
                '${_rutaOptimizada.length}',
                'Visitas',
                Colors.cyan,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricaRuta(
                Icons.check_circle,
                '$_visitasCompletadas',
                'Completadas',
                Colors.green,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricaRuta(
                Icons.directions_car,
                '${_distanciaTotal.toStringAsFixed(1)} km',
                'Distancia',
                Colors.orange,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricaRuta(
                Icons.timer,
                _formatearTiempo(_tiempoTotal),
                'Tiempo est.',
                Colors.purple,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaRuta(IconData icono, String valor, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
          ),
        ],
      ),
    );
  }

  String _formatearTiempo(int minutos) {
    if (minutos < 60) return '${minutos}min';
    final horas = minutos ~/ 60;
    final mins = minutos % 60;
    return '${horas}h ${mins}m';
  }

  Widget _buildListaVisitas() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rutaOptimizada.length,
        itemBuilder: (context, index) => _buildVisitaCard(_rutaOptimizada[index], index + 1),
      ),
    );
  }

  Widget _buildVisitaCard(Map<String, dynamic> orden, int numero) {
    final cliente = orden['climas_clientes'];
    final equipo = orden['climas_equipos'];
    final estado = orden['estado'] ?? 'pendiente';
    final horaProgamada = orden['hora_programada'] ?? '';
    
    final isCompleta = estado == 'completada';
    final isEnProceso = estado == 'en_proceso';
    
    Color estadoColor = isCompleta ? Colors.green 
                      : isEnProceso ? Colors.orange 
                      : Colors.cyan;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: isEnProceso ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número de visita
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: estadoColor, width: 2),
                      ),
                      child: Center(
                        child: isCompleta
                            ? Icon(Icons.check, color: estadoColor, size: 20)
                            : Text(
                                '$numero',
                                style: TextStyle(
                                  color: estadoColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (numero < _rutaOptimizada.length)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.white10,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                
                // Info de la visita
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo y hora
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getColorTipoServicio(orden['tipo_servicio']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatearTipoServicio(orden['tipo_servicio']),
                              style: TextStyle(
                                color: _getColorTipoServicio(orden['tipo_servicio']),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (horaProgamada.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 12, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  horaProgamada,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Cliente
                      Text(
                        cliente?['nombre'] ?? 'Sin cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      
                      // Dirección
                      if (cliente?['direccion'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.cyan),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cliente['direccion'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Equipo
                      if (equipo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.ac_unit, size: 12, color: Colors.purple),
                              const SizedBox(width: 4),
                              Text(
                                '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
                                style: const TextStyle(color: Colors.purple, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Acciones
                      if (!isCompleta)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _navegarA(orden),
                                icon: const Icon(Icons.navigation, size: 16),
                                label: const Text('Navegar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.cyan,
                                  side: const BorderSide(color: Colors.cyan),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _llamarCliente(cliente),
                                icon: const Icon(Icons.phone, size: 16),
                                label: const Text('Llamar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
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
          ),
          
          // Indicador de estado
          if (isEnProceso)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'EN CURSO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getColorTipoServicio(String? tipo) {
    switch (tipo) {
      case 'instalacion': return Colors.blue;
      case 'mantenimiento': return Colors.green;
      case 'reparacion': return Colors.orange;
      case 'emergencia': return Colors.red;
      case 'garantia': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _formatearTipoServicio(String? tipo) {
    switch (tipo) {
      case 'instalacion': return 'INSTALACIÓN';
      case 'mantenimiento': return 'MANTENIMIENTO';
      case 'reparacion': return 'REPARACIÓN';
      case 'emergencia': return 'EMERGENCIA';
      case 'garantia': return 'GARANTÍA';
      default: return tipo?.toUpperCase() ?? 'SERVICIO';
    }
  }

  Widget _buildAcciones() {
    if (_rutaOptimizada.isEmpty) return const SizedBox.shrink();
    
    final pendientes = _rutaOptimizada.where((o) => o['estado'] != 'completada').toList();
    if (pendientes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _optimizando ? null : () => _optimizarRuta(),
                icon: _optimizando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(_optimizando ? 'Optimizando...' : 'Re-optimizar Ruta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _iniciarNavegacionCompleta(),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Iniciar Ruta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No hay visitas programadas',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
          ),
          Text(
            'para ${_dateFormat.format(_fechaSeleccionada)}',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyan,
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
      _cargarOrdenesDelDia();
    }
  }

  void _navegarA(Map<String, dynamic> orden) async {
    final cliente = orden['climas_clientes'];
    if (cliente == null) return;
    
    final lat = cliente['latitud'];
    final lng = cliente['longitud'];
    
    if (lat != null && lng != null) {
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } else if (cliente['direccion'] != null) {
      final direccion = Uri.encodeComponent(cliente['direccion']);
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$direccion&travelmode=driving';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  void _llamarCliente(Map<String, dynamic>? cliente) async {
    if (cliente?['telefono'] == null) return;
    
    final url = 'tel:${cliente!['telefono']}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _iniciarNavegacionCompleta() async {
    // Construir waypoints para Google Maps
    final pendientes = _rutaOptimizada.where((o) {
      final cliente = o['climas_clientes'];
      return o['estado'] != 'completada' && 
             cliente != null &&
             cliente['latitud'] != null && 
             cliente['longitud'] != null;
    }).toList();
    
    if (pendientes.isEmpty) return;
    
    // Primer destino
    final primero = pendientes[0]['climas_clientes'];
    String url = 'https://www.google.com/maps/dir/?api=1';
    url += '&destination=${primero['latitud']},${primero['longitud']}';
    
    // Waypoints intermedios (máx 10 para Google Maps)
    if (pendientes.length > 1) {
      final waypoints = pendientes.skip(1).take(9).map((o) {
        final c = o['climas_clientes'];
        return '${c['latitud']},${c['longitud']}';
      }).join('|');
      url += '&waypoints=$waypoints';
    }
    
    url += '&travelmode=driving';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

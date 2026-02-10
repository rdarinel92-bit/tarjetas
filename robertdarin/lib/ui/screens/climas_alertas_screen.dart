// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS ALERTAS INTELIGENTES - V10.55
// Sistema predictivo de mantenimientos, vencimientos y alertas de fallas
// Para Superadmin, Empleados y configuración de notificaciones automáticas
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class ClimasAlertasScreen extends StatefulWidget {
  final String? negocioId;
  
  const ClimasAlertasScreen({super.key, this.negocioId});

  @override
  State<ClimasAlertasScreen> createState() => _ClimasAlertasScreenState();
}

class _ClimasAlertasScreenState extends State<ClimasAlertasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  
  // Alertas por categoría
  List<Map<String, dynamic>> _alertasMantenimiento = [];
  List<Map<String, dynamic>> _alertasGarantia = [];
  List<Map<String, dynamic>> _alertasContrato = [];
  List<Map<String, dynamic>> _alertasFallas = [];
  List<Map<String, dynamic>> _alertasStock = [];
  
  // Contadores
  int _totalAlertas = 0;
  int _alertasCriticas = 0;
  int _alertasAltas = 0;
  int _alertasMedias = 0;

  // Configuración de alertas
  Map<String, bool> _configNotificaciones = {
    'mantenimiento_7dias': true,
    'mantenimiento_30dias': true,
    'garantia_30dias': true,
    'garantia_60dias': true,
    'contrato_30dias': true,
    'fallas_recurrentes': true,
    'stock_bajo': true,
    'email': true,
    'push': true,
    'sms': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      final ahora = DateTime.now();
      
      // === ALERTAS DE MANTENIMIENTO ===
      // Equipos que necesitan mantenimiento próximamente
      final en7Dias = ahora.add(const Duration(days: 7));
      final en30Dias = ahora.add(const Duration(days: 30));
      
      var mantQuery = AppSupabase.client
          .from('climas_equipos')
          .select('*, climas_clientes(nombre, telefono, email)')
          .lte('proximo_mantenimiento', en30Dias.toIso8601String())
          .gte('proximo_mantenimiento', ahora.subtract(const Duration(days: 7)).toIso8601String());
      
      if (widget.negocioId != null) {
        mantQuery = mantQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final mantRes = await mantQuery.order('proximo_mantenimiento');
      _alertasMantenimiento = List<Map<String, dynamic>>.from(mantRes).map((e) {
        final fecha = DateTime.tryParse(e['proximo_mantenimiento'] ?? '');
        final diasRestantes = fecha?.difference(ahora).inDays ?? 0;
        return {
          ...e,
          'dias_restantes': diasRestantes,
          'prioridad': diasRestantes < 0 ? 'critica' 
                     : diasRestantes <= 7 ? 'alta' 
                     : 'media',
          'tipo_alerta': 'mantenimiento',
        };
      }).toList();
      
      // === ALERTAS DE GARANTÍA ===
      final en60Dias = ahora.add(const Duration(days: 60));
      
      var garantiaQuery = AppSupabase.client
          .from('climas_equipos')
          .select('*, climas_clientes(nombre, telefono, email)')
          .lte('garantia_hasta', en60Dias.toIso8601String())
          .gte('garantia_hasta', ahora.toIso8601String());
      
      if (widget.negocioId != null) {
        garantiaQuery = garantiaQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final garantiaRes = await garantiaQuery.order('garantia_hasta');
      _alertasGarantia = List<Map<String, dynamic>>.from(garantiaRes).map((e) {
        final fecha = DateTime.tryParse(e['garantia_hasta'] ?? '');
        final diasRestantes = fecha?.difference(ahora).inDays ?? 0;
        return {
          ...e,
          'dias_restantes': diasRestantes,
          'prioridad': diasRestantes <= 15 ? 'alta' : 'media',
          'tipo_alerta': 'garantia',
        };
      }).toList();
      
      // === ALERTAS DE CONTRATOS ===
      var contratosQuery = AppSupabase.client
          .from('climas_contratos')
          .select('*, climas_clientes(nombre, telefono, email)')
          .eq('estado', 'activo')
          .lte('fecha_vencimiento', en30Dias.toIso8601String())
          .gte('fecha_vencimiento', ahora.toIso8601String());
      
      if (widget.negocioId != null) {
        contratosQuery = contratosQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final contratosRes = await contratosQuery.order('fecha_vencimiento');
      _alertasContrato = List<Map<String, dynamic>>.from(contratosRes).map((e) {
        final fecha = DateTime.tryParse(e['fecha_vencimiento'] ?? '');
        final diasRestantes = fecha?.difference(ahora).inDays ?? 0;
        return {
          ...e,
          'dias_restantes': diasRestantes,
          'prioridad': diasRestantes <= 7 ? 'critica' : diasRestantes <= 15 ? 'alta' : 'media',
          'tipo_alerta': 'contrato',
        };
      }).toList();
      
      // === ALERTAS DE FALLAS RECURRENTES ===
      // Equipos con más de 2 órdenes de reparación en los últimos 90 días
      await _cargarAlertasFallas();
      
      // === ALERTAS DE STOCK BAJO ===
      await _cargarAlertasStock();
      
      // === CALCULAR TOTALES ===
      final todasAlertas = [
        ..._alertasMantenimiento,
        ..._alertasGarantia,
        ..._alertasContrato,
        ..._alertasFallas,
        ..._alertasStock,
      ];
      
      _totalAlertas = todasAlertas.length;
      _alertasCriticas = todasAlertas.where((a) => a['prioridad'] == 'critica').length;
      _alertasAltas = todasAlertas.where((a) => a['prioridad'] == 'alta').length;
      _alertasMedias = todasAlertas.where((a) => a['prioridad'] == 'media').length;
      
      // Cargar configuración de notificaciones
      await _cargarConfiguracion();
      
    } catch (e) {
      debugPrint('Error cargando alertas: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarAlertasFallas() async {
    try {
      final hace90Dias = DateTime.now().subtract(const Duration(days: 90));
      
      // Buscar equipos con órdenes de reparación recurrentes
      var ordenesQuery = AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('equipo_id, climas_equipos(id, marca, modelo, serie, climas_clientes(nombre, telefono))')
          .eq('tipo_servicio', 'reparacion')
          .gte('created_at', hace90Dias.toIso8601String());
      
      if (widget.negocioId != null) {
        ordenesQuery = ordenesQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final ordenesRes = await ordenesQuery;
      
      // Agrupar por equipo y contar
      final conteoEquipos = <String, Map<String, dynamic>>{};
      for (final o in ordenesRes) {
        final equipoId = o['equipo_id']?.toString();
        if (equipoId != null && equipoId.isNotEmpty) {
          if (!conteoEquipos.containsKey(equipoId)) {
            conteoEquipos[equipoId] = {
              'equipo': o['climas_equipos'],
              'conteo': 0,
            };
          }
          conteoEquipos[equipoId]!['conteo'] = (conteoEquipos[equipoId]!['conteo'] as int) + 1;
        }
      }
      
      // Filtrar los que tienen 2 o más reparaciones
      _alertasFallas = conteoEquipos.entries
          .where((e) => (e.value['conteo'] as int) >= 2)
          .map((e) {
            final equipo = e.value['equipo'] as Map<String, dynamic>?;
            final conteo = e.value['conteo'] as int;
            return {
              'equipo_id': e.key,
              'equipo': equipo,
              'climas_clientes': equipo?['climas_clientes'],
              'reparaciones_recientes': conteo,
              'prioridad': conteo >= 4 ? 'critica' : conteo >= 3 ? 'alta' : 'media',
              'tipo_alerta': 'falla_recurrente',
            };
          })
          .toList()
        ..sort((a, b) => (b['reparaciones_recientes'] as int).compareTo(a['reparaciones_recientes'] as int));
      
    } catch (e) {
      debugPrint('Error cargando fallas: $e');
    }
  }

  Future<void> _cargarAlertasStock() async {
    try {
      var stockQuery = AppSupabase.client
          .from('climas_inventario')
          .select()
          .lte('cantidad', 5) // Stock bajo = menos de 5 unidades
          .gt('cantidad', 0);
      
      if (widget.negocioId != null) {
        stockQuery = stockQuery.eq('negocio_id', widget.negocioId!);
      }
      
      final stockRes = await stockQuery.order('cantidad');
      _alertasStock = List<Map<String, dynamic>>.from(stockRes).map((e) {
        final cantidad = e['cantidad'] as int? ?? 0;
        return {
          ...e,
          'prioridad': cantidad <= 2 ? 'alta' : 'media',
          'tipo_alerta': 'stock_bajo',
        };
      }).toList();
      
    } catch (e) {
      debugPrint('Error cargando stock: $e');
    }
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final res = await AppSupabase.client
          .from('climas_config_alertas')
          .select()
          .eq('usuario_id', userId)
          .maybeSingle();
      
      if (res != null) {
        _configNotificaciones = Map<String, bool>.from(res['configuracion'] ?? {});
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
  }

  Future<void> _guardarConfiguracion() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await AppSupabase.client
          .from('climas_config_alertas')
          .upsert({
            'usuario_id': userId,
            'negocio_id': widget.negocioId,
            'configuracion': _configNotificaciones,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'usuario_id');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Alertas Inteligentes',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: _mostrarConfiguracion,
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
                // Resumen de alertas
                _buildResumenAlertas(),
                
                // Tabs
                Container(
                  color: const Color(0xFF0D0D14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.cyan,
                    labelColor: Colors.cyan,
                    unselectedLabelColor: Colors.white54,
                    isScrollable: true,
                    tabs: [
                      _buildTab('🔧', 'Mantenim.', _alertasMantenimiento.length),
                      _buildTab('🛡️', 'Garantías', _alertasGarantia.length),
                      _buildTab('📄', 'Contratos', _alertasContrato.length),
                      _buildTab('⚠️', 'Fallas', _alertasFallas.length),
                      _buildTab('📦', 'Stock', _alertasStock.length),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaAlertas(_alertasMantenimiento, 'mantenimiento'),
                      _buildListaAlertas(_alertasGarantia, 'garantia'),
                      _buildListaAlertas(_alertasContrato, 'contrato'),
                      _buildListaAlertas(_alertasFallas, 'falla'),
                      _buildListaAlertas(_alertasStock, 'stock'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTab(String emoji, String texto, int cantidad) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 12)),
          if (cantidad > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cantidad > 5 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$cantidad',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenAlertas() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildMiniKPI(
            '📊',
            '$_totalAlertas',
            'Total',
            Colors.cyan,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            '🔴',
            '$_alertasCriticas',
            'Críticas',
            Colors.red,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            '🟠',
            '$_alertasAltas',
            'Altas',
            Colors.orange,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            '🟡',
            '$_alertasMedias',
            'Medias',
            Colors.amber,
          )),
        ],
      ),
    );
  }

  Widget _buildMiniKPI(String emoji, String valor, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildListaAlertas(List<Map<String, dynamic>> alertas, String tipo) {
    if (alertas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No hay alertas de ${_getTipoNombre(tipo)}',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alertas.length,
        itemBuilder: (context, index) => _buildAlertaCard(alertas[index], tipo),
      ),
    );
  }

  String _getTipoNombre(String tipo) {
    switch (tipo) {
      case 'mantenimiento': return 'mantenimiento';
      case 'garantia': return 'garantías';
      case 'contrato': return 'contratos';
      case 'falla': return 'fallas';
      case 'stock': return 'stock bajo';
      default: return tipo;
    }
  }

  Widget _buildAlertaCard(Map<String, dynamic> alerta, String tipo) {
    final prioridad = alerta['prioridad'] ?? 'media';
    final color = prioridad == 'critica' ? Colors.red 
                : prioridad == 'alta' ? Colors.orange 
                : Colors.amber;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIconoTipo(tipo), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTituloAlerta(alerta, tipo),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _getSubtituloAlerta(alerta, tipo),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _buildBadgePrioridad(prioridad),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Detalles específicos por tipo
            _buildDetallesAlerta(alerta, tipo),
            
            const SizedBox(height: 12),
            
            // Acciones
            Row(
              children: [
                if (tipo != 'stock')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _contactarCliente(alerta),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Contactar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (tipo != 'stock') const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tomarAccion(alerta, tipo),
                    icon: Icon(_getIconoAccion(tipo), size: 16),
                    label: Text(_getTextoAccion(tipo)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  IconData _getIconoTipo(String tipo) {
    switch (tipo) {
      case 'mantenimiento': return Icons.build;
      case 'garantia': return Icons.security;
      case 'contrato': return Icons.description;
      case 'falla': return Icons.warning;
      case 'stock': return Icons.inventory_2;
      default: return Icons.notifications;
    }
  }

  String _getTituloAlerta(Map<String, dynamic> alerta, String tipo) {
    switch (tipo) {
      case 'mantenimiento':
      case 'garantia':
        final equipo = alerta;
        return '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim();
      case 'contrato':
        final cliente = alerta['climas_clientes'];
        return cliente?['nombre'] ?? 'Sin cliente';
      case 'falla':
        final equipo = alerta['equipo'];
        return '${equipo?['marca'] ?? ''} ${equipo?['modelo'] ?? ''}'.trim();
      case 'stock':
        return alerta['nombre'] ?? alerta['producto'] ?? 'Sin nombre';
      default:
        return 'Alerta';
    }
  }

  String _getSubtituloAlerta(Map<String, dynamic> alerta, String tipo) {
    switch (tipo) {
      case 'mantenimiento':
        final cliente = alerta['climas_clientes'];
        return cliente?['nombre'] ?? 'Sin cliente';
      case 'garantia':
        final cliente = alerta['climas_clientes'];
        return cliente?['nombre'] ?? 'Sin cliente';
      case 'contrato':
        return 'Contrato ${alerta['tipo_contrato'] ?? 'de mantenimiento'}';
      case 'falla':
        final cliente = alerta['climas_clientes'];
        return cliente?['nombre'] ?? 'Sin cliente';
      case 'stock':
        return 'Código: ${alerta['codigo'] ?? alerta['sku'] ?? '-'}';
      default:
        return '';
    }
  }

  Widget _buildBadgePrioridad(String prioridad) {
    final color = prioridad == 'critica' ? Colors.red 
                : prioridad == 'alta' ? Colors.orange 
                : Colors.amber;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        prioridad.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetallesAlerta(Map<String, dynamic> alerta, String tipo) {
    switch (tipo) {
      case 'mantenimiento':
        final dias = alerta['dias_restantes'] as int? ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text(
                dias < 0 
                    ? 'Mantenimiento vencido hace ${dias.abs()} días'
                    : dias == 0 
                        ? 'Mantenimiento programado para HOY'
                        : 'Mantenimiento en $dias días',
                style: TextStyle(
                  color: dias <= 0 ? Colors.red : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
        
      case 'garantia':
        final dias = alerta['dias_restantes'] as int? ?? 0;
        final fechaVence = alerta['garantia_hasta'];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.security, size: 16, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Garantía vence en $dias días',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
              if (fechaVence != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      'Fecha: ${_dateFormat.format(DateTime.parse(fechaVence))}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
        
      case 'contrato':
        final dias = alerta['dias_restantes'] as int? ?? 0;
        final monto = double.tryParse(alerta['monto']?.toString() ?? '0') ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vence en $dias días',
                    style: TextStyle(
                      color: dias <= 7 ? Colors.red : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(monto),
                    style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
        
      case 'falla':
        final reparaciones = alerta['reparaciones_recientes'] ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                '$reparaciones reparaciones en los últimos 90 días',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        );
        
      case 'stock':
        final cantidad = alerta['cantidad'] ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Stock actual: $cantidad unidades',
                style: TextStyle(
                  color: cantidad <= 2 ? Colors.red : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getIconoAccion(String tipo) {
    switch (tipo) {
      case 'mantenimiento': return Icons.event;
      case 'garantia': return Icons.info;
      case 'contrato': return Icons.autorenew;
      case 'falla': return Icons.build;
      case 'stock': return Icons.add_shopping_cart;
      default: return Icons.arrow_forward;
    }
  }

  String _getTextoAccion(String tipo) {
    switch (tipo) {
      case 'mantenimiento': return 'Agendar';
      case 'garantia': return 'Ver detalle';
      case 'contrato': return 'Renovar';
      case 'falla': return 'Crear orden';
      case 'stock': return 'Reabastecer';
      default: return 'Acción';
    }
  }

  void _contactarCliente(Map<String, dynamic> alerta) {
    final cliente = alerta['climas_clientes'];
    if (cliente == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contactar a ${cliente['nombre']}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (cliente['telefono'] != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(cliente['telefono'], style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Llamar
                },
              ),
            if (cliente['email'] != null)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: Text(cliente['email'], style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Email
                },
              ),
          ],
        ),
      ),
    );
  }

  void _tomarAccion(Map<String, dynamic> alerta, String tipo) {
    // Navegar a la pantalla correspondiente según el tipo
    switch (tipo) {
      case 'mantenimiento':
        Navigator.pushNamed(context, '/climas/ordenes/nueva', arguments: {
          'equipo_id': alerta['id'],
          'tipo_servicio': 'mantenimiento',
        });
        break;
      case 'garantia':
        Navigator.pushNamed(context, '/climas/equipos/detalle', arguments: alerta);
        break;
      case 'contrato':
        Navigator.pushNamed(context, '/climas/contratos');
        break;
      case 'falla':
        Navigator.pushNamed(context, '/climas/ordenes/nueva', arguments: {
          'equipo_id': alerta['equipo_id'],
          'tipo_servicio': 'reparacion',
        });
        break;
      case 'stock':
        Navigator.pushNamed(context, '/climas/inventario');
        break;
    }
  }

  void _mostrarConfiguracion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚙️ Configuración de Alertas',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSeccionConfig('Alertas de Mantenimiento', [
                        _buildSwitchConfig('mantenimiento_7dias', '7 días antes', setStateModal),
                        _buildSwitchConfig('mantenimiento_30dias', '30 días antes', setStateModal),
                      ]),
                      
                      _buildSeccionConfig('Alertas de Garantía', [
                        _buildSwitchConfig('garantia_30dias', '30 días antes', setStateModal),
                        _buildSwitchConfig('garantia_60dias', '60 días antes', setStateModal),
                      ]),
                      
                      _buildSeccionConfig('Otras Alertas', [
                        _buildSwitchConfig('contrato_30dias', 'Contratos por vencer', setStateModal),
                        _buildSwitchConfig('fallas_recurrentes', 'Fallas recurrentes', setStateModal),
                        _buildSwitchConfig('stock_bajo', 'Stock bajo', setStateModal),
                      ]),
                      
                      _buildSeccionConfig('Canales de Notificación', [
                        _buildSwitchConfig('email', 'Email', setStateModal),
                        _buildSwitchConfig('push', 'Push (App)', setStateModal),
                        _buildSwitchConfig('sms', 'SMS', setStateModal),
                      ]),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _guardarConfiguracion();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Guardar Configuración'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionConfig(String titulo, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            titulo,
            style: const TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildSwitchConfig(String key, String label, StateSetter setStateModal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Switch(
            value: _configNotificaciones[key] ?? false,
            activeColor: Colors.cyan,
            onChanged: (value) {
              setStateModal(() {
                _configNotificaciones[key] = value;
              });
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

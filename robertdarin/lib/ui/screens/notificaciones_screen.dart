// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

/// Pantalla de Notificaciones del Sistema
/// Muestra notificaciones push, alertas, recordatorios y mensajes importantes
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = true;
  
  List<Map<String, dynamic>> _notificaciones = [];
  List<Map<String, dynamic>> _alertas = [];
  List<Map<String, dynamic>> _recordatorios = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarNotificaciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() => _cargando = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        setState(() => _cargando = false);
        return;
      }

      // Cargar notificaciones generales de la BD
      List<Map<String, dynamic>> notifs = [];
      try {
        final data = await AppSupabase.client
            .from('notificaciones')
            .select()
            .or('usuario_id.eq.${user.id},usuario_id.is.null')
            .order('created_at', ascending: false)
            .limit(100);
        notifs = List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('Tabla notificaciones no existe: $e');
      }

      // Generar alertas reales del sistema
      final alertasReales = await _generarAlertasReales();

      // Cargar recordatorios
      List<Map<String, dynamic>> recordatorios = [];
      try {
        final data = await AppSupabase.client
            .from('recordatorios')
            .select()
            .or('usuario_id.eq.${user.id},publico.eq.true')
            .gte('fecha_recordatorio', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
            .order('fecha_recordatorio')
            .limit(50);
        recordatorios = List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('Tabla recordatorios no existe: $e');
      }

      setState(() {
        _notificaciones = notifs;
        _alertas = alertasReales;
        _recordatorios = recordatorios;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando notificaciones: $e');
      setState(() {
        _notificaciones = [];
        _alertas = [];
        _recordatorios = [];
        _cargando = false;
      });
    }
  }

  /// Genera alertas reales basadas en el estado actual del sistema
  Future<List<Map<String, dynamic>>> _generarAlertasReales() async {
    List<Map<String, dynamic>> alertas = [];

    try {
      // 1. Buscar cuotas vencidas (amortizaciones no pagadas con fecha pasada)
      final cuotasVencidas = await AppSupabase.client
          .from('amortizaciones')
          .select('id, prestamo_id, numero_cuota, monto_cuota, fecha_vencimiento')
          .eq('estado', 'pendiente')
          .lt('fecha_vencimiento', DateTime.now().toIso8601String())
          .limit(100);

      if ((cuotasVencidas as List).isNotEmpty) {
        final cantidadVencidas = cuotasVencidas.length;
        double montoTotal = 0;
        for (var cuota in cuotasVencidas) {
          montoTotal += (cuota['monto_cuota'] ?? 0).toDouble();
        }
        
        alertas.add({
          'id': 'vencidas_${DateTime.now().millisecondsSinceEpoch}',
          'titulo': '⚠️ $cantidadVencidas cuotas vencidas',
          'mensaje': 'Hay \$${montoTotal.toStringAsFixed(0)} en cuotas vencidas pendientes de cobro',
          'prioridad': 3,
          'tipo': 'pago_vencido',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 2. Buscar cuotas que vencen hoy
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      final finHoy = inicioHoy.add(const Duration(days: 1));
      
      final cuotasHoy = await AppSupabase.client
          .from('amortizaciones')
          .select('id')
          .eq('estado', 'pendiente')
          .gte('fecha_vencimiento', inicioHoy.toIso8601String())
          .lt('fecha_vencimiento', finHoy.toIso8601String());

      if ((cuotasHoy as List).isNotEmpty) {
        alertas.add({
          'id': 'hoy_${DateTime.now().millisecondsSinceEpoch}',
          'titulo': '📅 ${cuotasHoy.length} cuotas vencen hoy',
          'mensaje': 'Hay cobros programados para hoy que requieren atención',
          'prioridad': 2,
          'tipo': 'pago_hoy',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. Buscar cuotas que vencen esta semana
      final finSemana = inicioHoy.add(const Duration(days: 7));
      final cuotasSemana = await AppSupabase.client
          .from('amortizaciones')
          .select('id')
          .eq('estado', 'pendiente')
          .gt('fecha_vencimiento', finHoy.toIso8601String())
          .lte('fecha_vencimiento', finSemana.toIso8601String());

      if ((cuotasSemana as List).isNotEmpty) {
        alertas.add({
          'id': 'semana_${DateTime.now().millisecondsSinceEpoch}',
          'titulo': '📆 ${cuotasSemana.length} cuotas esta semana',
          'mensaje': 'Cuotas por vencer en los próximos 7 días',
          'prioridad': 1,
          'tipo': 'pago_semana',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 4. Préstamos activos
      final prestamosActivos = await AppSupabase.client
          .from('prestamos')
          .select('id')
          .eq('estado', 'activo');

      if ((prestamosActivos as List).isNotEmpty) {
        alertas.add({
          'id': 'prestamos_${DateTime.now().millisecondsSinceEpoch}',
          'titulo': '💰 ${prestamosActivos.length} préstamos activos',
          'mensaje': 'Préstamos en curso que requieren seguimiento',
          'prioridad': 1,
          'tipo': 'prestamo',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 5. Tandas activas
      final tandasActivas = await AppSupabase.client
          .from('tandas')
          .select('id')
          .eq('estado', 'activa');

      if ((tandasActivas as List).isNotEmpty) {
        alertas.add({
          'id': 'tandas_${DateTime.now().millisecondsSinceEpoch}',
          'titulo': '🔄 ${tandasActivas.length} tandas activas',
          'mensaje': 'Tandas en curso',
          'prioridad': 1,
          'tipo': 'tanda',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 6. Comisiones pendientes de pago (para SuperAdmin)
      try {
        final comisionesPendientes = await AppSupabase.client
            .from('comisiones_empleados')
            .select('id, monto_comision')
            .eq('estado', 'pendiente');

        if ((comisionesPendientes as List).isNotEmpty) {
          double totalComisiones = 0;
          for (var c in comisionesPendientes) {
            totalComisiones += (c['monto_comision'] ?? 0).toDouble();
          }
          
          alertas.add({
            'id': 'comisiones_${DateTime.now().millisecondsSinceEpoch}',
            'titulo': '👔 ${comisionesPendientes.length} comisiones pendientes',
            'mensaje': '\$${totalComisiones.toStringAsFixed(0)} en comisiones por pagar a empleados',
            'prioridad': 2,
            'tipo': 'comision',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        // Tabla de comisiones puede no existir
      }

    } catch (e) {
      debugPrint('Error generando alertas: $e');
    }

    // Si no hay alertas, mostrar mensaje positivo
    if (alertas.isEmpty) {
      alertas.add({
        'id': 'ok_${DateTime.now().millisecondsSinceEpoch}',
        'titulo': '✅ Todo en orden',
        'mensaje': 'No hay alertas pendientes en el sistema',
        'prioridad': 0,
        'tipo': 'info',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return alertas;
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = _notificaciones.where((n) => n['leida'] != true).length;
    
    return PremiumScaffold(
      title: "Notificaciones",
      subtitle: noLeidas > 0 ? "$noLeidas sin leer" : "Todo al día",
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all, color: Colors.greenAccent),
          tooltip: "Marcar todas como leídas",
          onPressed: _marcarTodasLeidas,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: "Actualizar",
          onPressed: _cargarNotificaciones,
        ),
      ],
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                  icon: Badge(
                    isLabelVisible: noLeidas > 0,
                    label: Text('$noLeidas', style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.notifications, size: 20),
                  ),
                  text: "General",
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: _alertas.isNotEmpty,
                    label: Text('${_alertas.length}', style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.warning_amber, size: 20),
                  ),
                  text: "Alertas",
                ),
                const Tab(icon: Icon(Icons.schedule, size: 20), text: "Recordatorios"),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabNotificaciones(),
                      _buildTabAlertas(),
                      _buildTabRecordatorios(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearRecordatorio,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add_alert),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: NOTIFICACIONES GENERALES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabNotificaciones() {
    if (_notificaciones.isEmpty) {
      return _buildEmptyState("No hay notificaciones", Icons.notifications_off);
    }

    return RefreshIndicator(
      onRefresh: _cargarNotificaciones,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _notificaciones.length,
        itemBuilder: (context, index) {
          final notif = _notificaciones[index];
          return _buildNotificacionCard(notif);
        },
      ),
    );
  }

  Widget _buildNotificacionCard(Map<String, dynamic> notif) {
    final leida = notif['leida'] == true;
    final tipo = notif['tipo'] ?? 'info';
    final fecha = DateTime.tryParse(notif['created_at'] ?? '') ?? DateTime.now();
    
    Color iconColor;
    IconData iconData;
    
    switch (tipo) {
      case 'success':
        iconColor = Colors.greenAccent;
        iconData = Icons.check_circle;
        break;
      case 'warning':
        iconColor = Colors.orangeAccent;
        iconData = Icons.warning;
        break;
      case 'error':
        iconColor = Colors.redAccent;
        iconData = Icons.error;
        break;
      default:
        iconColor = Colors.blueAccent;
        iconData = Icons.info;
    }

    return Dismissible(
      key: Key(notif['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _eliminarNotificacion(notif['id']),
      child: PremiumCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.2),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              if (!leida)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            notif['titulo'] ?? 'Notificación',
            style: TextStyle(
              color: leida ? Colors.white54 : Colors.white,
              fontWeight: leida ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notif['mensaje'] ?? '',
                style: TextStyle(color: leida ? Colors.white38 : Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatearFecha(fecha),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          trailing: !leida
              ? IconButton(
                  icon: const Icon(Icons.done, color: Colors.greenAccent, size: 20),
                  onPressed: () => _marcarLeida(notif['id']),
                )
              : null,
          onTap: () => _verDetalleNotificacion(notif),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: ALERTAS DEL SISTEMA
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabAlertas() {
    if (_alertas.isEmpty) {
      return _buildEmptyState("No hay alertas activas", Icons.check_circle, 
          subtitle: "Todo está funcionando correctamente");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _alertas.length,
      itemBuilder: (context, index) {
        final alerta = _alertas[index];
        return _buildAlertaCard(alerta);
      },
    );
  }

  Widget _buildAlertaCard(Map<String, dynamic> alerta) {
    final prioridad = alerta['prioridad'] ?? 1;
    final tipo = alerta['tipo'] ?? 'info';
    
    Color color;
    IconData icon;
    
    switch (prioridad) {
      case 3:
        color = Colors.redAccent;
        icon = Icons.error;
        break;
      case 2:
        color = Colors.orangeAccent;
        icon = Icons.warning;
        break;
      default:
        color = Colors.blueAccent;
        icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          alerta['titulo'] ?? 'Alerta',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          alerta['mensaje'] ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: () => _atenderAlerta(alerta),
          child: Text("Atender", style: TextStyle(color: color)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 3: RECORDATORIOS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabRecordatorios() {
    if (_recordatorios.isEmpty) {
      return _buildEmptyState("No hay recordatorios", Icons.event_note,
          subtitle: "Crea un recordatorio con el botón +");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _recordatorios.length,
      itemBuilder: (context, index) {
        final recordatorio = _recordatorios[index];
        return _buildRecordatorioCard(recordatorio);
      },
    );
  }

  Widget _buildRecordatorioCard(Map<String, dynamic> recordatorio) {
    final fecha = DateTime.tryParse(recordatorio['fecha_recordatorio'] ?? '') ?? DateTime.now();
    final completado = recordatorio['completado'] == true;
    final esHoy = fecha.day == DateTime.now().day && fecha.month == DateTime.now().month;
    final esPasado = fecha.isBefore(DateTime.now());

    Color color = esHoy ? Colors.orangeAccent : (esPasado ? Colors.redAccent : Colors.greenAccent);

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: completado,
          activeColor: Colors.greenAccent,
          onChanged: (v) => _toggleRecordatorio(recordatorio['id'], v ?? false),
        ),
        title: Text(
          recordatorio['titulo'] ?? 'Recordatorio',
          style: TextStyle(
            color: completado ? Colors.white38 : Colors.white,
            decoration: completado ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recordatorio['descripcion'] != null)
              Text(
                recordatorio['descripcion'],
                style: TextStyle(color: completado ? Colors.white24 : Colors.white54, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  esHoy ? "Hoy ${DateFormat('HH:mm').format(fecha)}" : DateFormat('dd/MM/yyyy HH:mm').format(fecha),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
          onPressed: () => _eliminarRecordatorio(recordatorio['id']),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String mensaje, IconData icon, {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white24),
          const SizedBox(height: 15),
          Text(mensaje, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) return 'Ahora mismo';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} horas';
    if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays} días';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _marcarTodasLeidas() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;
      
      await AppSupabase.client
          .from('notificaciones')
          .update({'leida': true})
          .or('usuario_id.eq.${user.id},usuario_id.is.null');
      
      setState(() {
        for (var n in _notificaciones) {
          n['leida'] = true;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas las notificaciones marcadas como leídas'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Si falla, solo actualizar localmente
      setState(() {
        for (var n in _notificaciones) {
          n['leida'] = true;
        }
      });
    }
  }

  Future<void> _marcarLeida(String? id) async {
    if (id == null) return;
    try {
      await AppSupabase.client.from('notificaciones').update({'leida': true}).eq('id', id);
    } catch (e) {
      debugPrint('Error marcando leída: $e');
    }
    setState(() {
      final notif = _notificaciones.firstWhere((n) => n['id'] == id, orElse: () => {});
      if (notif.isNotEmpty) notif['leida'] = true;
    });
  }

  Future<void> _eliminarNotificacion(String? id) async {
    if (id == null) return;
    try {
      await AppSupabase.client.from('notificaciones').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando notificación: $e');
    }
    setState(() {
      _notificaciones.removeWhere((n) => n['id'] == id);
    });
  }

  void _verDetalleNotificacion(Map<String, dynamic> notif) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notif['titulo'] ?? 'Notificación',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            Text(
              notif['mensaje'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            Text(
              'Recibida: ${_formatearFecha(DateTime.tryParse(notif['created_at'] ?? '') ?? DateTime.now())}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _atenderAlerta(Map<String, dynamic> alerta) async {
    // Navegar según el tipo de alerta
    final tipo = alerta['tipo'] ?? '';
    
    switch (tipo) {
      case 'pago_vencido':
      case 'pago_hoy':
      case 'pago_semana':
        Navigator.pushNamed(context, '/cobrosPendientes');
        break;
      case 'prestamo':
        Navigator.pushNamed(context, '/prestamos');
        break;
      case 'tanda':
        Navigator.pushNamed(context, '/tandas');
        break;
      case 'comision':
        // Navegar a panel de comisiones (por implementar) o empleados
        Navigator.pushNamed(context, '/empleados');
        break;
      case 'info':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sistema funcionando correctamente'), backgroundColor: Colors.green),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta atendida'), backgroundColor: Colors.green),
        );
    }
  }

  Future<void> _toggleRecordatorio(String? id, bool completado) async {
    if (id == null) return;
    try {
      await AppSupabase.client.from('recordatorios').update({'completado': completado}).eq('id', id);
    } catch (e) {
      debugPrint('Error actualizando recordatorio: $e');
    }
    setState(() {
      final rec = _recordatorios.firstWhere((r) => r['id'] == id, orElse: () => {});
      if (rec.isNotEmpty) rec['completado'] = completado;
    });
  }

  Future<void> _eliminarRecordatorio(String? id) async {
    if (id == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar recordatorio', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar este recordatorio?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await AppSupabase.client.from('recordatorios').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando recordatorio: $e');
    }
    setState(() {
      _recordatorios.removeWhere((r) => r['id'] == id);
    });
  }

  void _crearRecordatorio() {
    final tituloCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    DateTime fechaSeleccionada = DateTime.now().add(const Duration(hours: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_alert, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Nuevo Recordatorio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 15),
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descripcionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 15),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.orangeAccent),
                title: const Text('Fecha y hora', style: TextStyle(color: Colors.white70)),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(fechaSeleccionada),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: fechaSeleccionada,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (fecha != null && context.mounted) {
                    final hora = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(fechaSeleccionada),
                    );
                    if (hora != null) {
                      setModalState(() {
                        fechaSeleccionada = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (tituloCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa un título'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    
                    try {
                      final user = AppSupabase.client.auth.currentUser;
                      await AppSupabase.client.from('recordatorios').insert({
                        'usuario_id': user?.id,
                        'titulo': tituloCtrl.text,
                        'descripcion': descripcionCtrl.text.isNotEmpty ? descripcionCtrl.text : null,
                        'fecha_recordatorio': fechaSeleccionada.toIso8601String(),
                        'completado': false,
                        'publico': false,
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        _cargarNotificaciones();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recordatorio creado'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      // Si falla, agregar localmente
                      setState(() {
                        _recordatorios.insert(0, {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'titulo': tituloCtrl.text,
                          'descripcion': descripcionCtrl.text,
                          'fecha_recordatorio': fechaSeleccionada.toIso8601String(),
                          'completado': false,
                        });
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recordatorio creado (local)'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Recordatorio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

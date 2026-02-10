// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

/// Widget de Notificaciones In-App estilo banner no invasivo
/// Muestra promociones y mensajes del administrador con redirección
class InAppNotificationBanner extends StatefulWidget {
  final Widget child;

  const InAppNotificationBanner({super.key, required this.child});

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner> {
  List<Map<String, dynamic>> _notificacionesPendientes = [];
  Map<String, dynamic>? _notificacionActual;
  bool _mostrandoBanner = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _iniciarRealtime() {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = AppSupabase.client
        .channel('notificaciones_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: userId,
          ),
          callback: (payload) {
            final nueva = payload.newRecord;
            _agregarNotificacion(nueva);
          },
        )
        .subscribe();
  }

  Future<void> _cargarNotificaciones() async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final notifs = await AppSupabase.client
          .from('notificaciones')
          .select()
          .eq('usuario_id', userId)
          .eq('leida', false)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _notificacionesPendientes = List<Map<String, dynamic>>.from(notifs);
      });

      _mostrarSiguiente();
    } catch (e) {
      debugPrint("Error cargando notificaciones: $e");
    }
  }

  void _agregarNotificacion(Map<String, dynamic> notif) {
    setState(() {
      _notificacionesPendientes.insert(0, notif);
    });
    if (!_mostrandoBanner) {
      _mostrarSiguiente();
    }
  }

  void _mostrarSiguiente() {
    if (_notificacionesPendientes.isEmpty) {
      setState(() {
        _notificacionActual = null;
        _mostrandoBanner = false;
      });
      return;
    }

    setState(() {
      _notificacionActual = _notificacionesPendientes.removeAt(0);
      _mostrandoBanner = true;
    });

    // Auto-ocultar después de 8 segundos
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _mostrandoBanner) {
        _cerrarBanner();
      }
    });
  }

  Future<void> _marcarComoLeida(String notifId) async {
    try {
      await AppSupabase.client.from('notificaciones').update({
        'leida': true,
        'leida_at': DateTime.now().toIso8601String()
      }).eq('id', notifId);
    } catch (e) {
      debugPrint("Error marcando como leída: $e");
    }
  }

  void _cerrarBanner() {
    if (_notificacionActual != null) {
      _marcarComoLeida(_notificacionActual!['id']);
    }
    setState(() {
      _notificacionActual = null;
      _mostrandoBanner = false;
    });
    // Mostrar siguiente después de un delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _mostrarSiguiente();
    });
  }

  void _onBannerTap() {
    final ruta = _notificacionActual?['ruta_destino'];
    if (_notificacionActual != null) {
      _marcarComoLeida(_notificacionActual!['id']);
    }
    setState(() {
      _notificacionActual = null;
      _mostrandoBanner = false;
    });

    if (ruta != null && ruta.isNotEmpty && mounted) {
      Navigator.pushNamed(context, ruta);
    }

    _mostrarSiguiente();
  }

  IconData _getIconByType(String? tipo) {
    switch (tipo) {
      case 'tanda':
        return Icons.loop;
      case 'prestamo':
        return Icons.attach_money;
      case 'promocion':
        return Icons.local_offer;
      case 'aviso':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorByType(String? tipo) {
    switch (tipo) {
      case 'tanda':
        return Colors.orangeAccent;
      case 'prestamo':
        return Colors.greenAccent;
      case 'promocion':
        return Colors.purpleAccent;
      case 'aviso':
        return Colors.amberAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Banner de notificación
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          top:
              _mostrandoBanner ? MediaQuery.of(context).padding.top + 10 : -120,
          left: 10,
          right: 10,
          child: _notificacionActual == null
              ? const SizedBox.shrink()
              : _buildBanner(_notificacionActual!),
        ),
      ],
    );
  }

  Widget _buildBanner(Map<String, dynamic> notif) {
    final tipo = notif['tipo'] as String?;
    final color = _getColorByType(tipo);
    final icon = _getIconByType(tipo);
    final tieneRuta = notif['ruta_destino'] != null &&
        notif['ruta_destino'].toString().isNotEmpty;

    return GestureDetector(
      onTap: tieneRuta ? _onBannerTap : null,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > 100) {
          _cerrarBanner();
        }
      },
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E2C),
                color.withOpacity(0.2),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notif['titulo'] ?? 'Notificación',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif['mensaje'] ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tieneRuta) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.touch_app, color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            "Toca para ver más",
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Botón cerrar
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                onPressed: _cerrarBanner,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de campanita con contador de notificaciones
class NotificationBellWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const NotificationBellWidget({
    super.key,
    this.onTap,
    this.color,
    this.size = 24,
  });

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  int _count = 0;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _cargarContador();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _iniciarRealtime() {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = AppSupabase.client
        .channel('notif_count_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          callback: (payload) => _cargarContador(),
        )
        .subscribe();
  }

  Future<void> _cargarContador() async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final result = await AppSupabase.client
          .from('notificaciones')
          .select('id')
          .eq('usuario_id', userId)
          .eq('leida', false)
          .count(CountOption.exact);

      setState(() {
        _count = (result as List).length;
      });
    } catch (e) {
      debugPrint("Error contando notificaciones: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          Icon(
            Icons.notifications_outlined,
            color: widget.color ?? Colors.white,
            size: widget.size,
          ),
          if (_count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _count > 9 ? '9+' : _count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

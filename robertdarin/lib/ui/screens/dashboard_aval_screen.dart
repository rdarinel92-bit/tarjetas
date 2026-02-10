// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';
import '../widgets/firma_digital_widget.dart';
import '../../services/notificaciones_mora_service.dart';
import '../../services/push_notification_service.dart'; // V10.26 Push Notifications
import 'chat_aval_cobrador_screen.dart';

/// Panel exclusivo para AVALES
/// Muestra los préstamos que están garantizando y su estado
class DashboardAvalScreen extends StatefulWidget {
  const DashboardAvalScreen({super.key});

  @override
  State<DashboardAvalScreen> createState() => _DashboardAvalScreenState();
}

class _DashboardAvalScreenState extends State<DashboardAvalScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _miInfoAval;
  List<Map<String, dynamic>> _prestamosGarantizados = [];
  List<Map<String, dynamic>> _pagosProximos = [];
  List<Map<String, dynamic>> _historialCheckins = [];
  List<Map<String, dynamic>> _documentosAval = []; // ← V10.26: Documentos con historial
  List<Map<String, dynamic>> _notificacionesDocumentos = []; // ← V10.26: Notifs de docs
  List<MoraInfo> _morasActivas = []; // ← NUEVO: Moras activas
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
  
  // Estado de ubicación
  bool _ubicacionActiva = false;
  // ignore: unused_field
  Position? _ultimaUbicacion; // Se usa para mostrar última ubicación en UI futura
  DateTime? _ultimoCheckin;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _registrarTokenPush(); // V10.26: Registrar token FCM del aval
  }

  /// V10.26: Guardar token FCM del aval para recibir push notifications
  Future<void> _registrarTokenPush() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVm.usuarioActual?.id;
    if (userId == null) return;

    try {
      // Obtener el aval_id asociado a este usuario
      final avalRes = await AppSupabase.client
          .from('avales')
          .select('id')
          .eq('usuario_id', userId)
          .maybeSingle();

      if (avalRes != null) {
        final avalId = avalRes['id'];
        await PushNotificationService().guardarTokenAval(avalId);
        debugPrint('✅ Token FCM registrado para aval: $avalId');
      }
    } catch (e) {
      debugPrint('⚠️ Error registrando token push del aval: $e');
    }
  }

  Future<void> _cargarDatos() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVm.usuarioActual?.id;
    if (userId == null) return;

    try {
      // 1. Obtener info del aval
      final avalRes = await AppSupabase.client
          .from('avales')
          .select('*, clientes(nombre_completo)')
          .eq('usuario_id', userId)
          .maybeSingle();

      if (avalRes != null) {
        _miInfoAval = avalRes;
        _ubicacionActiva = avalRes['ubicacion_consentida'] ?? false;

        // 2. Obtener préstamos donde soy aval (tabla prestamos_avales para multi-aval)
        final prestamosMulti = await AppSupabase.client
            .from('prestamos_avales')
            .select('prestamo_id, prestamos(*, clientes(nombre_completo))')
            .eq('aval_id', avalRes['id']);

        // También buscar en el campo aval_id directo (legacy)
        final prestamosLegacy = await AppSupabase.client
            .from('prestamos')
            .select('*, clientes(nombre_completo)')
            .eq('aval_id', avalRes['id']);

        // Combinar ambas fuentes
        final todosLosPrestamos = <Map<String, dynamic>>[];
        
        for (var pm in prestamosMulti as List) {
          if (pm['prestamos'] != null) {
            todosLosPrestamos.add(pm['prestamos']);
          }
        }
        for (var p in prestamosLegacy as List) {
          if (!todosLosPrestamos.any((tp) => tp['id'] == p['id'])) {
            todosLosPrestamos.add(p);
          }
        }

        _prestamosGarantizados = todosLosPrestamos;

        // 3. Obtener próximos pagos de los préstamos garantizados
        if (todosLosPrestamos.isNotEmpty) {
          final prestamoIds = todosLosPrestamos.map((p) => p['id']).toList();
          final pagosRes = await AppSupabase.client
              .from('amortizaciones')
              .select('*, prestamos(clientes(nombre_completo))')
              .inFilter('prestamo_id', prestamoIds)
              .eq('pagado', false)
              .order('fecha_vencimiento')
              .limit(10);
          
          _pagosProximos = List<Map<String, dynamic>>.from(pagosRes);
          
          // 5. NUEVO: Verificar moras activas
          _morasActivas = await NotificacionesMoraService.verificarMorasParaAval(
            avalRes['id'],
            todosLosPrestamos,
          );
        }

        // 4. Cargar historial de check-ins (ubicaciones voluntarias)
        final checkinsRes = await AppSupabase.client
            .from('aval_checkins')
            .select()
            .eq('aval_id', avalRes['id'])
            .order('fecha', ascending: false)
            .limit(5);
        
        _historialCheckins = List<Map<String, dynamic>>.from(checkinsRes);
        if (_historialCheckins.isNotEmpty) {
          _ultimoCheckin = DateTime.tryParse(_historialCheckins.first['fecha'] ?? '');
        }

        // 6. V10.26: Cargar documentos del aval con estado de verificación
        final docsRes = await AppSupabase.client
            .from('documentos_aval')
            .select('*, usuarios:verificado_por(nombre)')
            .eq('aval_id', avalRes['id'])
            .order('created_at', ascending: false);
        
        _documentosAval = List<Map<String, dynamic>>.from(docsRes);

        // 7. V10.26: Cargar notificaciones de documentos no leídas
        final notifsRes = await AppSupabase.client
            .from('notificaciones_documento_aval')
            .select()
            .eq('aval_id', avalRes['id'])
            .eq('leida', false)
            .order('created_at', ascending: false);
        
        _notificacionesDocumentos = List<Map<String, dynamic>>.from(notifsRes);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error cargando datos del aval: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = Provider.of<AuthViewModel>(context);
    final user = authVm.usuarioActual;

    return PremiumScaffold(
      title: "Mi Panel de Aval",
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.notificaciones),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === BANNER DE MORA (SI EXISTE) ===
                    if (_morasActivas.isNotEmpty) ...[
                      for (final mora in _morasActivas)
                        BannerMoraWidget(
                          diasMora: mora.diasMora,
                          montoPendiente: mora.montoPendiente,
                          clienteNombre: mora.clienteNombre,
                          onContactar: _abrirChatCobrador,
                        ),
                      const SizedBox(height: 15),
                    ],

                    // === NOTIFICACIONES DE DOCUMENTOS (V10.26) ===
                    if (_notificacionesDocumentos.isNotEmpty) ...[
                      _buildBannerNotificacionesDocumentos(),
                      const SizedBox(height: 15),
                    ],

                    // === SALUDO ===
                    Text("¡Hola, ${user?.userMetadata?['full_name'] ?? _miInfoAval?['nombre'] ?? 'Aval'}!",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text("Panel de seguimiento de préstamos que garantizas",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 20),

                    // === RESUMEN RÁPIDO ===
                    _buildResumenRapido(),
                    const SizedBox(height: 20),

                    // === CHECK-IN DE UBICACIÓN (VOLUNTARIO Y LEGAL) ===
                    _buildSeccionUbicacion(),
                    const SizedBox(height: 20),

                    // === PRÉSTAMOS QUE GARANTIZO ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Préstamos que Garantizo",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("${_prestamosGarantizados.length}", 
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    if (_prestamosGarantizados.isEmpty)
                      _buildEmptyState(
                        Icons.shield_outlined,
                        "No tienes préstamos activos como aval",
                        "Cuando garantices un préstamo, aparecerá aquí",
                      )
                    else
                      ..._prestamosGarantizados.map(_buildPrestamoCard),

                    const SizedBox(height: 25),

                    // === PRÓXIMOS PAGOS (ALERTA) ===
                    const Text("⚠️ Próximos Pagos a Vencer",
                        style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    if (_pagosProximos.isEmpty)
                      _buildEmptyState(
                        Icons.check_circle_outline,
                        "No hay pagos pendientes",
                        "Todo está al día",
                      )
                    else
                      ..._pagosProximos.take(5).map(_buildPagoProximoCard),

                    const SizedBox(height: 25),

                    // === ACCIONES PRINCIPALES ===
                    const Text("Acciones Principales",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.payment, 
                          "Pagar por Cliente", 
                          Colors.greenAccent,
                          () => _mostrarPagarPorCliente(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.calendar_month, 
                          "Calendario Pagos", 
                          Colors.blueAccent,
                          () => _mostrarCalendarioPagos(),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.phone_in_talk, 
                          "Contactar Cliente", 
                          Colors.tealAccent,
                          () => _contactarCliente(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.history, 
                          "Historial Pagos", 
                          Colors.amberAccent,
                          () => _mostrarHistorialPagos(),
                        )),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // === ACCIONES SECUNDARIAS ===
                    const Text("Más Opciones",
                        style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.support_agent, 
                          "Chat Cobrador", 
                          Colors.orangeAccent,
                          () => _abrirChatCobrador(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.draw_outlined, 
                          "Firma Digital", 
                          Colors.pinkAccent,
                          () => _mostrarFirmaDigital(),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.upload_file, 
                          "Subir Documentos", 
                          Colors.purpleAccent,
                          () => _subirDocumentos(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.description_outlined, 
                          "Ver Contratos", 
                          Colors.cyanAccent,
                          () => _verContratos(),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.account_balance_wallet, 
                          "Resumen Pagos", 
                          Colors.greenAccent,
                          () => _mostrarDesgloseCapitalInteres(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.map_outlined, 
                          "Mapa Check-ins", 
                          Colors.lightGreenAccent,
                          () => _mostrarMapaCheckins(),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAccionRapida(
                          Icons.notifications_active, 
                          "Config. Alertas", 
                          Colors.redAccent,
                          () => _configurarAlertas(),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionRapida(
                          Icons.settings_outlined, 
                          "Ajustes", 
                          Colors.grey,
                          () => Navigator.pushNamed(context, AppRoutes.settings),
                        )),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  /// SECCIÓN DE UBICACIÓN - 100% LEGAL Y CON CONSENTIMIENTO
  Widget _buildSeccionUbicacion() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _ubicacionActiva ? Icons.location_on : Icons.location_off,
                color: _ubicacionActiva ? Colors.greenAccent : Colors.grey,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text("Check-in de Ubicación",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              // Toggle de consentimiento
              Switch(
                value: _ubicacionActiva,
                onChanged: (value) => _toggleConsentimientoUbicacion(value),
                activeColor: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _ubicacionActiva 
              ? "✅ Has dado tu consentimiento para compartir ubicación voluntariamente"
              : "Activa para poder hacer check-ins voluntarios",
            style: TextStyle(
              color: _ubicacionActiva ? Colors.greenAccent : Colors.white54, 
              fontSize: 11,
            ),
          ),
          
          if (_ubicacionActiva) ...[
            const Divider(color: Colors.white12, height: 20),
            
            // Último check-in
            if (_ultimoCheckin != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      "Último check-in: ${DateFormat('dd/MMM HH:mm').format(_ultimoCheckin!)}",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            
            // Botón de Check-in
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _realizarCheckin(),
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text("Hacer Check-in Ahora"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "📍 El check-in registra tu ubicación actual de forma voluntaria.\n"
              "Esto ayuda a verificar tu domicilio y agilizar trámites.",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
          
          // Aviso legal siempre visible
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.privacy_tip, size: 16, color: Colors.lightBlueAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Tu privacidad es importante. Solo tú decides cuándo compartir tu ubicación. "
                    "Cumplimos con LFPDPPP y GDPR.",
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle de consentimiento con aviso legal
  Future<void> _toggleConsentimientoUbicacion(bool activar) async {
    if (activar) {
      // Mostrar términos antes de activar
      final acepta = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text("Consentimiento de Ubicación"),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Al activar esta función, aceptas:", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 15),
                Text("✅ Compartir tu ubicación SOLO cuando presiones 'Hacer Check-in'",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 8),
                Text("✅ La ubicación se usa para verificar tu domicilio registrado",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 8),
                Text("✅ NO se rastrea tu ubicación en segundo plano",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 8),
                Text("✅ Puedes desactivar esto en cualquier momento",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 15),
                Divider(color: Colors.white24),
                SizedBox(height: 10),
                Text("Propósito:", 
                  style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("• Verificación de domicilio\n• Agilizar trámites de cobranza\n• Confirmar visitas acordadas",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 15),
                Text("Tus datos están protegidos según la Ley Federal de Protección de Datos Personales (LFPDPPP) y GDPR.",
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No acepto"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              child: const Text("Acepto", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (acepta != true) return;
    }

    // Guardar consentimiento en BD
    try {
      await AppSupabase.client
          .from('avales')
          .update({
            'ubicacion_consentida': activar,
            'fecha_consentimiento_ubicacion': activar ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', _miInfoAval!['id']);

      setState(() => _ubicacionActiva = activar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activar 
              ? "✅ Check-in de ubicación activado" 
              : "Ubicación desactivada"),
            backgroundColor: activar ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error actualizando consentimiento: $e");
    }
  }

  /// Realizar check-in voluntario
  Future<void> _realizarCheckin() async {
    // 1. Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _mostrarErrorUbicacion("Permiso de ubicación denegado");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _mostrarErrorUbicacion("Permisos de ubicación bloqueados. Habilítalos en Configuración.");
      return;
    }

    // 2. Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Obteniendo ubicación..."),
          ],
        ),
      ),
    );

    try {
      // 3. Obtener ubicación
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // 4. Guardar check-in en BD
      await AppSupabase.client.from('aval_checkins').insert({
        'aval_id': _miInfoAval!['id'],
        'latitud': position.latitude,
        'longitud': position.longitude,
        'precision': position.accuracy,
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'voluntario',
        'ip_dispositivo': null, // Opcional: agregar IP
      });

      // 5. Actualizar última ubicación del aval
      await AppSupabase.client.from('avales').update({
        'ultima_latitud': position.latitude,
        'ultima_longitud': position.longitude,
        'ultimo_checkin': DateTime.now().toIso8601String(),
      }).eq('id', _miInfoAval!['id']);

      Navigator.pop(context); // Cerrar loading

      setState(() {
        _ultimaUbicacion = position;
        _ultimoCheckin = DateTime.now();
      });

      // 6. Mostrar confirmación
      _mostrarConfirmacionCheckin(position);

    } catch (e) {
      Navigator.pop(context); // Cerrar loading
      _mostrarErrorUbicacion("Error obteniendo ubicación: $e");
    }
  }

  void _mostrarConfirmacionCheckin(Position position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text("¡Check-in Exitoso!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tu ubicación ha sido registrada:", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
            _buildInfoCheckin("📍 Latitud", position.latitude.toStringAsFixed(6)),
            _buildInfoCheckin("📍 Longitud", position.longitude.toStringAsFixed(6)),
            _buildInfoCheckin("🎯 Precisión", "${position.accuracy.toStringAsFixed(0)} metros"),
            _buildInfoCheckin("🕐 Hora", DateFormat('HH:mm:ss').format(DateTime.now())),
            const SizedBox(height: 15),
            const Text(
              "Este registro queda guardado y puede ser consultado por el administrador para verificación.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cargarDatos(); // Recargar
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Entendido", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCheckin(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _mostrarErrorUbicacion(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  /// Muestra historial de check-ins - disponible para uso futuro
  // ignore: unused_element
  void _mostrarHistorialCheckins() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Historial de Check-ins", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Tus últimas 5 ubicaciones compartidas", 
              style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 15),
            
            if (_historialCheckins.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No has hecho check-ins aún", style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              ...(_historialCheckins.map((checkin) {
                final fecha = DateTime.tryParse(checkin['fecha'] ?? '');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.location_on, color: Colors.white, size: 18),
                  ),
                  title: Text(
                    fecha != null ? DateFormat('dd/MMM/yyyy HH:mm').format(fecha) : '-',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Lat: ${checkin['latitud']?.toStringAsFixed(4)}, Lng: ${checkin['longitud']?.toStringAsFixed(4)}",
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: Text(
                    checkin['tipo'] ?? 'voluntario',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  /// V10.26: Banner de notificaciones de documentos aprobados/rechazados
  Widget _buildBannerNotificacionesDocumentos() {
    return Column(
      children: _notificacionesDocumentos.map((notif) {
        final esAprobado = notif['tipo_notificacion'] == 'aprobado';
        final color = esAprobado ? Colors.greenAccent : Colors.orangeAccent;
        final icono = esAprobado ? Icons.check_circle : Icons.warning;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif['mensaje'] ?? '',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (notif['motivo_rechazo'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Motivo: ${notif['motivo_rechazo']}",
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => _marcarNotificacionLeida(notif['id']),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Marcar notificación de documento como leída
  Future<void> _marcarNotificacionLeida(String notifId) async {
    try {
      await AppSupabase.client
          .from('notificaciones_documento_aval')
          .update({
            'leida': true,
            'fecha_lectura': DateTime.now().toIso8601String(),
          })
          .eq('id', notifId);
      
      // Recargar para actualizar UI
      await _cargarDatos();
    } catch (e) {
      debugPrint('Error marcando notificación: $e');
    }
  }

  Widget _buildResumenRapido() {
    final prestamosActivos = _prestamosGarantizados.where((p) => p['estado'] == 'activo').length;
    final pagosVencidos = _pagosProximos.where((p) {
      final fecha = DateTime.tryParse(p['fecha_vencimiento'] ?? '');
      return fecha != null && fecha.isBefore(DateTime.now());
    }).length;

    // Calcular total a pagar (monto + intereses)
    double totalAPagar = 0;
    for (var p in _prestamosGarantizados) {
      final monto = (p['monto'] ?? 0).toDouble();
      final interes = (p['interes'] ?? 0).toDouble();
      final plazo = (p['plazo'] ?? 1);
      totalAPagar += monto + (monto * (interes / 100) * plazo);
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard(
          "Garantizando",
          prestamosActivos.toString(),
          Icons.shield,
          Colors.orangeAccent,
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(
          "Total a Pagar",
          _currencyFormat.format(totalAPagar),
          Icons.attach_money,
          Colors.greenAccent,
          small: true,
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(
          "Vencidos",
          pagosVencidos.toString(),
          Icons.warning,
          pagosVencidos > 0 ? Colors.redAccent : Colors.grey,
        )),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool small = false}) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, 
            style: TextStyle(
              color: color, 
              fontSize: small ? 12 : 18, 
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildPrestamoCard(Map<String, dynamic> prestamo) {
    final cliente = prestamo['clientes']?['nombre_completo'] ?? 'Cliente';
    final monto = (prestamo['monto'] ?? 0).toDouble();
    final interes = (prestamo['interes'] ?? 0).toDouble();
    final plazo = (prestamo['plazo'] ?? 1);
    final estado = prestamo['estado'] ?? 'activo';
    final fechaInicio = DateTime.tryParse(prestamo['fecha_inicio'] ?? '');
    
    // Calcular total a pagar (monto + intereses)
    final totalInteres = monto * (interes / 100) * plazo;
    final totalAPagar = monto + totalInteres;
    
    final esActivo = estado == 'activo';
    final estadoColor = esActivo ? Colors.green : (estado == 'vencido' ? Colors.red : Colors.grey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.orangeAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text("Total a Pagar: ${_currencyFormat.format(totalAPagar)}", 
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(estado.toUpperCase(), 
                    style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoMini("Fecha Inicio", 
                  fechaInicio != null ? DateFormat('dd/MMM/yy').format(fechaInicio) : '-'),
                _buildInfoMini("Cuotas", "${prestamo['plazo'] ?? '-'}"),
                _buildInfoMini("Frecuencia", prestamo['frecuencia_pago'] ?? 'mensual'),
              ],
            ),
            const SizedBox(height: 10),
            // Barra de progreso - Calcular porcentaje real
            Builder(
              builder: (context) {
                final pagos = _pagosProximos.where((p) => p['prestamo_id'] == prestamo['id']).toList();
                final totalCuotas = prestamo['plazo'] ?? 1;
                final cuotasPagadas = pagos.where((p) => p['estado'] == 'pagado' || p['estado'] == 'pagada').length;
                final porcentaje = totalCuotas > 0 ? (cuotasPagadas / totalCuotas).clamp(0.0, 1.0) : 0.0;
                final porcentajeTexto = (porcentaje * 100).toStringAsFixed(0);
                
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: porcentaje,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(estadoColor),
                    ),
                    const SizedBox(height: 5),
                    Text("$porcentajeTexto% pagado ($cuotasPagadas/$totalCuotas cuotas)", 
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagoProximoCard(Map<String, dynamic> pago) {
    final fechaVencimiento = DateTime.tryParse(pago['fecha_vencimiento'] ?? '');
    final monto = (pago['monto'] ?? 0).toDouble();
    final cliente = pago['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente';
    
    final hoy = DateTime.now();
    final diasRestantes = fechaVencimiento?.difference(hoy).inDays ?? 0;
    final estaVencido = diasRestantes < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (estaVencido ? Colors.red : Colors.orange).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (estaVencido ? Colors.red : Colors.orange).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              estaVencido ? Icons.error : Icons.schedule,
              color: estaVencido ? Colors.redAccent : Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cliente, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    estaVencido 
                      ? "VENCIDO hace ${-diasRestantes} días" 
                      : "Vence en $diasRestantes días",
                    style: TextStyle(
                      color: estaVencido ? Colors.redAccent : Colors.orangeAccent, 
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currencyFormat.format(monto), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (fechaVencimiento != null)
                  Text(DateFormat('dd/MMM').format(fechaVencimiento), 
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMini(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildAccionRapida(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white54)),
          Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  /// Muestra documentos del aval - disponible para uso futuro
  // ignore: unused_element
  void _mostrarDocumentos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mis Documentos", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildDocumentoItemConSubida(Icons.badge, "INE/Identificación", _miInfoAval?['identificacion_url'] != null, 'identificacion'),
            _buildDocumentoItemConSubida(Icons.home, "Comprobante Domicilio", _miInfoAval?['comprobante_domicilio_url'] != null, 'comprobante_domicilio'),
            _buildDocumentoItemConSubida(Icons.description, "Contrato Firmado", _miInfoAval?['contrato_url'] != null, 'contrato'),
            _buildDocumentoItemConSubida(Icons.face, "Selfie de Verificación", _miInfoAval?['selfie_url'] != null, 'selfie'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentoItemConSubida(IconData icon, String nombre, bool subido, String tipoDoc) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: subido ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        child: Icon(icon, color: subido ? Colors.green : Colors.grey),
      ),
      title: Text(nombre, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subido ? 'Subido ✓' : 'Pendiente',
        style: TextStyle(color: subido ? Colors.green : Colors.orange, fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(subido ? Icons.visibility : Icons.upload, color: Colors.orangeAccent),
        onPressed: () => _seleccionarYSubirDoc(tipoDoc),
      ),
    );
  }

  // ============================================================
  // === NUEVAS FUNCIONES: FIRMA DIGITAL Y CHAT CON COBRADOR ===
  // ============================================================

  /// Abre el chat directo con el cobrador/admin
  void _abrirChatCobrador() {
    if (_miInfoAval == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Información de aval no disponible')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatAvalCobradorScreen(
          avalId: _miInfoAval!['id'],
          avalNombre: _miInfoAval!['nombre'] ?? 'Aval',
          prestamoId: _prestamosGarantizados.isNotEmpty 
              ? _prestamosGarantizados.first['id'] 
              : null,
        ),
      ),
    );
  }

  /// Muestra el modal de firma digital
  Future<void> _mostrarFirmaDigital() async {
    final firma = await FirmaDigitalModal.mostrar(
      context,
      titulo: 'Tu Firma Digital',
      descripcion: 'Esta firma se usará para autorizar documentos relacionados con los préstamos que garantizas.',
    );

    if (firma != null && mounted) {
      // Guardar firma en Supabase storage
      try {
        final fileName = 'firma_aval_${_miInfoAval?['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
        
        await AppSupabase.client.storage
            .from('firmas')
            .uploadBinary(fileName, firma);

        // Actualizar referencia en el aval
        await AppSupabase.client
            .from('avales')
            .update({'firma_digital_url': fileName})
            .eq('id', _miInfoAval!['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Firma guardada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error guardando firma: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error guardando firma: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // ============================================================
  // === NUEVAS FUNCIONES COMPLETAS ===
  // ============================================================

  /// 1. PAGAR EN NOMBRE DEL CLIENTE
  void _mostrarPagarPorCliente() {
    if (_pagosProximos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pagos pendientes'), backgroundColor: Colors.grey),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text("Pagar en Nombre del Cliente", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text("Selecciona el pago que deseas cubrir como aval",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _pagosProximos.length,
                  itemBuilder: (context, index) {
                    final pago = _pagosProximos[index];
                    final monto = (pago['monto'] ?? 0).toDouble();
                    final fechaVenc = DateTime.tryParse(pago['fecha_vencimiento'] ?? '');
                    final cliente = pago['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente';
                    final diasRestantes = fechaVenc?.difference(DateTime.now()).inDays ?? 0;
                    final vencido = diasRestantes < 0;

                    return Card(
                      color: vencido ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: vencido ? Colors.redAccent : Colors.greenAccent,
                          child: Icon(
                            vencido ? Icons.warning : Icons.receipt_long,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(cliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vencido ? "VENCIDO hace ${-diasRestantes} días" : "Vence en $diasRestantes días",
                              style: TextStyle(color: vencido ? Colors.redAccent : Colors.white54, fontSize: 11),
                            ),
                            if (fechaVenc != null)
                              Text(DateFormat('dd/MMM/yyyy').format(fechaVenc),
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(monto),
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text("Pagar", style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                          ],
                        ),
                        onTap: () => _confirmarPagoComoAval(pago),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarPagoComoAval(Map<String, dynamic> pago) async {
    final monto = (pago['monto'] ?? 0).toDouble();
    final cliente = pago['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Confirmar Pago"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¿Deseas pagar ${_currencyFormat.format(monto)} en nombre de $cliente?",
              style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Este pago quedará registrado como realizado por ti (aval) y se te notificará al cliente.",
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Confirmar Pago", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      Navigator.pop(context); // Cerrar bottom sheet
      
      try {
        // Obtener negocio_id del préstamo
        String? negocioId;
        if (pago['prestamo_id'] != null) {
          final prestamoData = await AppSupabase.client
              .from('prestamos')
              .select('negocio_id')
              .eq('id', pago['prestamo_id'])
              .maybeSingle();
          negocioId = prestamoData?['negocio_id'];
        }
        
        // Registrar el pago
        await AppSupabase.client.from('pagos').insert({
          'prestamo_id': pago['prestamo_id'],
          'amortizacion_id': pago['id'],
          'monto': monto,
          'fecha_pago': DateTime.now().toIso8601String(),
          'metodo_pago': 'efectivo',
          'pagado_por_aval': true,
          'aval_id': _miInfoAval?['id'],
          'notas': 'Pago realizado por aval: ${_miInfoAval?['nombre']}',
          'negocio_id': negocioId,
        });

        // Marcar amortización como pagada
        await AppSupabase.client
            .from('amortizaciones')
            .update({'pagado': true, 'fecha_pago': DateTime.now().toIso8601String()})
            .eq('id', pago['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pago registrado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarDatos(); // Recargar
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 2. CALENDARIO DE PAGOS
  void _mostrarCalendarioPagos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _CalendarioPagosWidget(
          pagos: _pagosProximos,
          currencyFormat: _currencyFormat,
          scrollController: scrollController,
        ),
      ),
    );
  }

  /// 3. CONTACTAR AL CLIENTE
  void _contactarCliente() {
    if (_prestamosGarantizados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes clientes para contactar')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_in_talk, color: Colors.tealAccent),
                SizedBox(width: 10),
                Text("Contactar Cliente", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            
            // Lista de clientes que garantiza
            ...(_prestamosGarantizados.map((prestamo) {
              final cliente = prestamo['clientes'];
              final nombreCliente = cliente?['nombre_completo'] ?? 'Cliente';
              final telefono = cliente?['telefono'] ?? '';
              final email = cliente?['email'] ?? '';

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.tealAccent.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.tealAccent),
                  ),
                  title: Text(nombreCliente, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(telefono.isNotEmpty ? telefono : 'Sin teléfono',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (telefono.isNotEmpty) ...[
                        IconButton(
                          onPressed: () => _llamarTelefono(telefono),
                          icon: const Icon(Icons.phone, color: Colors.greenAccent),
                          tooltip: 'Llamar',
                        ),
                        IconButton(
                          onPressed: () => _abrirWhatsApp(telefono, nombreCliente),
                          icon: const Icon(Icons.chat, color: Colors.green),
                          tooltip: 'WhatsApp',
                        ),
                      ],
                      if (email.isNotEmpty)
                        IconButton(
                          onPressed: () => _enviarEmail(email),
                          icon: const Icon(Icons.email, color: Colors.blueAccent),
                          tooltip: 'Email',
                        ),
                    ],
                  ),
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Future<void> _llamarTelefono(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede llamar: $e')),
        );
      }
    }
  }

  Future<void> _abrirWhatsApp(String telefono, String nombre) async {
    final mensaje = Uri.encodeComponent('Hola $nombre, soy tu aval y me gustaría hablar contigo sobre el préstamo.');
    final uri = Uri.parse('https://wa.me/$telefono?text=$mensaje');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede abrir WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _enviarEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Sobre tu préstamo');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede enviar email: $e')),
        );
      }
    }
  }

  /// 4. HISTORIAL COMPLETO DE PAGOS
  void _mostrarHistorialPagos() async {
    // Cargar historial de pagos de los préstamos garantizados
    List<Map<String, dynamic>> historialPagos = [];
    
    if (_prestamosGarantizados.isNotEmpty) {
      final prestamoIds = _prestamosGarantizados.map((p) => p['id']).toList();
      final pagosRes = await AppSupabase.client
          .from('pagos')
          .select('*, prestamos(clientes(nombre_completo))')
          .inFilter('prestamo_id', prestamoIds)
          .order('fecha_pago', ascending: false)
          .limit(50);
      
      historialPagos = List<Map<String, dynamic>>.from(pagosRes);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Colors.amberAccent),
                  SizedBox(width: 10),
                  Text("Historial de Pagos", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Text("${historialPagos.length} pagos registrados",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 15),
              
              Expanded(
                child: historialPagos.isEmpty
                  ? const Center(
                      child: Text("No hay pagos registrados", style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: historialPagos.length,
                      itemBuilder: (context, index) {
                        final pago = historialPagos[index];
                        final monto = (pago['monto'] ?? 0).toDouble();
                        final fecha = DateTime.tryParse(pago['fecha_pago'] ?? '');
                        final cliente = pago['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente';
                        final porAval = pago['pagado_por_aval'] == true;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: porAval ? Colors.orangeAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                            child: Icon(
                              porAval ? Icons.shield : Icons.check,
                              color: porAval ? Colors.orangeAccent : Colors.greenAccent,
                              size: 18,
                            ),
                          ),
                          title: Text(cliente, style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fecha != null)
                                Text(DateFormat('dd/MMM/yyyy HH:mm').format(fecha),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              if (porAval)
                                const Text("💰 Pagado por ti (aval)",
                                  style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                            ],
                          ),
                          trailing: Text(_currencyFormat.format(monto),
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 5. SUBIR DOCUMENTOS - V10.26 CON HISTORIAL Y VERIFICACIÓN
  void _subirDocumentos() {
    // Mapeo de tipos a labels
    final tiposDoc = {
      'ine_frente': {'icon': Icons.badge, 'label': 'INE Frente', 'desc': 'Parte frontal de tu INE'},
      'ine_reverso': {'icon': Icons.badge_outlined, 'label': 'INE Reverso', 'desc': 'Parte trasera de tu INE'},
      'comprobante_domicilio': {'icon': Icons.home, 'label': 'Comprobante Domicilio', 'desc': 'Recibo de luz, agua, etc.'},
      'selfie': {'icon': Icons.face, 'label': 'Selfie Verificación', 'desc': 'Foto de tu rostro'},
      'comprobante_ingresos': {'icon': Icons.work, 'label': 'Comprobante Ingresos', 'desc': 'Nómina o constancia'},
    };

    // Verificar qué documentos ya tiene subidos
    Map<String, Map<String, dynamic>?> docsPorTipo = {};
    for (var tipo in tiposDoc.keys) {
      final doc = _documentosAval.where((d) => d['tipo'] == tipo).firstOrNull;
      docsPorTipo[tipo] = doc;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.folder_shared, color: Colors.purpleAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text("Mis Documentos", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  // Indicador de completitud
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorCompletitud(docsPorTipo),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${docsPorTipo.values.where((d) => d != null).length}/${tiposDoc.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text("Sube tus documentos para verificación. El admin los revisará.",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 20),
              
              // Lista de documentos
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: tiposDoc.entries.map((entry) {
                    final tipo = entry.key;
                    final info = entry.value;
                    final docExistente = docsPorTipo[tipo];
                    
                    return _buildOpcionDocumentoV2(
                      info['icon'] as IconData,
                      info['label'] as String,
                      info['desc'] as String,
                      tipo,
                      docExistente,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorCompletitud(Map<String, Map<String, dynamic>?> docs) {
    final completados = docs.values.where((d) => d != null).length;
    final total = docs.length;
    final porcentaje = completados / total;
    
    if (porcentaje >= 1.0) return Colors.greenAccent;
    if (porcentaje >= 0.6) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildOpcionDocumentoV2(IconData icon, String titulo, String subtitulo, String tipoDoc, Map<String, dynamic>? docExistente) {
    // Determinar estado
    String estado = 'pendiente';
    Color colorEstado = Colors.grey;
    IconData iconoEstado = Icons.upload;
    
    if (docExistente != null) {
      if (docExistente['verificado'] == true) {
        estado = 'verificado';
        colorEstado = Colors.greenAccent;
        iconoEstado = Icons.check_circle;
      } else {
        estado = 'en revisión';
        colorEstado = Colors.orangeAccent;
        iconoEstado = Icons.hourglass_bottom;
      }
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: docExistente != null 
                  ? colorEstado.withOpacity(0.2) 
                  : Colors.purpleAccent.withOpacity(0.2),
              child: Icon(icon, color: docExistente != null ? colorEstado : Colors.purpleAccent),
            ),
            if (docExistente != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colorEstado,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconoEstado, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            if (docExistente != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(color: colorEstado, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MMM/yy').format(DateTime.parse(docExistente['created_at'])),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: docExistente != null
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: const Color(0xFF2A2A3E),
                onSelected: (value) {
                  if (value == 'ver') {
                    _verDocumento(docExistente);
                  } else if (value == 'actualizar') {
                    _seleccionarYSubirDoc(tipoDoc);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'ver', child: Text('👁️ Ver documento', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'actualizar', child: Text('🔄 Actualizar', style: TextStyle(color: Colors.white))),
                ],
              )
            : IconButton(
                icon: const Icon(Icons.add_a_photo, color: Colors.purpleAccent),
                onPressed: () => _seleccionarYSubirDoc(tipoDoc),
              ),
        onTap: docExistente != null ? () => _verDocumento(docExistente) : () => _seleccionarYSubirDoc(tipoDoc),
      ),
    );
  }

  void _verDocumento(Map<String, dynamic> doc) async {
    try {
      final url = AppSupabase.client.storage
          .from('documentos')
          .getPublicUrl(doc['archivo_url']);
      
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarYSubirDoc(String tipoDoc) async {
    // Cerrar el bottom sheet si está abierto
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Usar image_picker o file_picker
    try {
      final picker = ImagePicker();
      final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
      
      if (imagen != null && mounted) {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            backgroundColor: Color(0xFF1E1E2C),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Subiendo documento...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );

        final bytes = await imagen.readAsBytes();
        final fileName = '${tipoDoc}_aval_${_miInfoAval?['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // 1. Subir archivo a Storage
        await AppSupabase.client.storage
            .from('documentos')
            .uploadBinary(fileName, bytes);

        // 2. V10.26: Insertar en documentos_aval (con historial)
        await AppSupabase.client.from('documentos_aval').insert({
          'aval_id': _miInfoAval!['id'],
          'tipo': tipoDoc,
          'archivo_url': fileName,
          'verificado': false,
          'notas': 'Subido por el aval desde la app',
        });

        // 3. También actualizar referencia rápida en tabla avales (compatibilidad)
        final campoLegacy = _mapearTipoACampo(tipoDoc);
        if (campoLegacy != null) {
          await AppSupabase.client
              .from('avales')
              .update({campoLegacy: fileName})
              .eq('id', _miInfoAval!['id']);
        }

        Navigator.pop(context); // Cerrar loading

        // 4. Recargar documentos
        await _cargarDatos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Documento subido. Pendiente de verificación.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Cerrar loading si hay error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Mapear tipo de documento a campo legacy en tabla avales
  String? _mapearTipoACampo(String tipoDoc) {
    final mapa = {
      'ine_frente': 'ine_url',
      'ine_reverso': 'ine_reverso_url',
      'comprobante_domicilio': 'domicilio_url',
      'selfie': 'selfie_url',
      'comprobante_ingresos': 'ingresos_url',
    };
    return mapa[tipoDoc];
  }

  /// 6. VER CONTRATOS FIRMADOS
  void _verContratos() async {
    // Buscar contratos asociados a los préstamos
    List<Map<String, dynamic>> contratos = [];
    
    if (_prestamosGarantizados.isNotEmpty) {
      for (var prestamo in _prestamosGarantizados) {
        if (prestamo['contrato_url'] != null) {
          contratos.add({
            'prestamo_id': prestamo['id'],
            'cliente': prestamo['clientes']?['nombre_completo'] ?? 'Cliente',
            'url': prestamo['contrato_url'],
            'fecha': prestamo['fecha_inicio'],
          });
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text("Contratos Firmados", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            
            if (contratos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off, size: 48, color: Colors.white24),
                      SizedBox(height: 10),
                      Text("No hay contratos disponibles", style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
              )
            else
              ...(contratos.map((contrato) {
                final fecha = DateTime.tryParse(contrato['fecha'] ?? '');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.cyanAccent,
                    child: Icon(Icons.picture_as_pdf, color: Colors.white),
                  ),
                  title: Text("Contrato - ${contrato['cliente']}", 
                    style: const TextStyle(color: Colors.white)),
                  subtitle: fecha != null 
                    ? Text(DateFormat('dd/MMM/yyyy').format(fecha),
                        style: const TextStyle(color: Colors.white54, fontSize: 11))
                    : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.download, color: Colors.cyanAccent),
                    onPressed: () => _descargarContrato(contrato['url']),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Future<void> _descargarContrato(String url) async {
    try {
      final publicUrl = AppSupabase.client.storage.from('contratos').getPublicUrl(url);
      await launchUrl(Uri.parse(publicUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error abriendo contrato: $e')),
        );
      }
    }
  }

  /// 7. DESGLOSE CAPITAL / INTERÉS
  void _mostrarDesgloseCapitalInteres() {
    double totalAPagar = 0;
    double totalPagado = 0;
    double totalPendiente = 0;
    int totalCuotas = 0;
    int cuotasPagadas = 0;

    for (var prestamo in _prestamosGarantizados) {
      final monto = (prestamo['monto'] ?? 0).toDouble();
      final interes = (prestamo['interes'] ?? 0).toDouble();
      final plazo = (prestamo['plazo'] ?? 1);
      
      // Total a pagar incluye capital + intereses
      totalAPagar += monto + (monto * (interes / 100) * plazo);
      totalCuotas += plazo as int;
    }

    for (var pago in _pagosProximos) {
      if (pago['pagado'] == true) {
        totalPagado += (pago['monto'] ?? 0).toDouble();
        cuotasPagadas++;
      } else {
        totalPendiente += (pago['monto'] ?? 0).toDouble();
      }
    }
    
    // Calcular porcentaje de avance
    final porcentajePagado = totalAPagar > 0 ? (totalPagado / totalAPagar * 100) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text("Resumen de Pagos", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            
            // Gráfico visual de progreso
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Progreso de pago", style: TextStyle(color: Colors.white70)),
                    Text("${porcentajePagado.toStringAsFixed(1)}%", 
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: porcentajePagado / 100,
                    minHeight: 20,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLeyenda(Colors.greenAccent, "Pagado"),
                _buildLeyenda(Colors.white24, "Pendiente"),
              ],
            ),
            const SizedBox(height: 20),
            
            // Detalle simplificado (sin mostrar interés)
            _buildFilaDesglose("💰 Total del Préstamo", _currencyFormat.format(totalAPagar), Colors.white),
            _buildFilaDesglose("✅ Ya Pagado", _currencyFormat.format(totalPagado), Colors.greenAccent),
            _buildFilaDesglose("⏳ Pendiente por Pagar", _currencyFormat.format(totalPendiente), Colors.orangeAccent),
            const Divider(color: Colors.white24),
            _buildFilaDesglose("📊 Cuotas Pagadas", "$cuotasPagadas de $totalCuotas", Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyenda(Color color, String texto) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildFilaDesglose(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  /// 8. MAPA DE CHECK-INS
  void _mostrarMapaCheckins() {
    if (_historialCheckins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes check-ins registrados'), backgroundColor: Colors.grey),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.map, color: Colors.lightGreenAccent),
                  SizedBox(width: 10),
                  Text("Mis Check-ins en Mapa", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Text("${_historialCheckins.length} ubicaciones registradas",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 15),
              
              // Lista de ubicaciones con opción de ver en mapa
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _historialCheckins.length,
                  itemBuilder: (context, index) {
                    final checkin = _historialCheckins[index];
                    final fecha = DateTime.tryParse(checkin['fecha'] ?? '');
                    final lat = checkin['latitud'];
                    final lng = checkin['longitud'];

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.lightGreenAccent.withOpacity(0.2),
                          child: Text("${index + 1}", 
                            style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold)),
                        ),
                        title: fecha != null 
                          ? Text(DateFormat('dd/MMM/yyyy HH:mm').format(fecha),
                              style: const TextStyle(color: Colors.white))
                          : const Text("Sin fecha", style: TextStyle(color: Colors.white)),
                        subtitle: Text("Lat: ${lat?.toStringAsFixed(4)}, Lng: ${lng?.toStringAsFixed(4)}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new, color: Colors.lightGreenAccent),
                          onPressed: () => _abrirEnMapa(lat, lng),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEnMapa(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error abriendo mapa: $e')),
        );
      }
    }
  }

  /// 9. CONFIGURAR ALERTAS
  void _configurarAlertas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Valores iniciales de configuración
          bool alertaPagos = _miInfoAval?['alerta_pagos'] ?? true;
          bool alertaMoras = _miInfoAval?['alerta_moras'] ?? true;
          bool alertaVencimientos = _miInfoAval?['alerta_vencimientos'] ?? true;
          int diasAnticipacion = _miInfoAval?['dias_anticipacion_alerta'] ?? 3;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("Configurar Alertas", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                
                SwitchListTile(
                  title: const Text("Alertas de pagos próximos", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Notificar cuando hay pagos por vencer", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: alertaPagos,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setModalState(() => alertaPagos = v),
                ),
                SwitchListTile(
                  title: const Text("Alertas de mora", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Notificar cuando hay mora activa", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: alertaMoras,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setModalState(() => alertaMoras = v),
                ),
                SwitchListTile(
                  title: const Text("Alertas de vencimiento", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Notificar fecha de vencimiento", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: alertaVencimientos,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setModalState(() => alertaVencimientos = v),
                ),
                
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Anticipación: ", style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: diasAnticipacion,
                      dropdownColor: const Color(0xFF252536),
                      style: const TextStyle(color: Colors.white),
                      items: [1, 2, 3, 5, 7].map((d) => DropdownMenuItem(
                        value: d,
                        child: Text("$d días antes"),
                      )).toList(),
                      onChanged: (v) => setModalState(() => diasAnticipacion = v!),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Guardar configuración
                      try {
                        await AppSupabase.client
                            .from('avales')
                            .update({
                              'alerta_pagos': alertaPagos,
                              'alerta_moras': alertaMoras,
                              'alerta_vencimientos': alertaVencimientos,
                              'dias_anticipacion_alerta': diasAnticipacion,
                            })
                            .eq('id', _miInfoAval!['id']);

                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Configuración guardada'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                    child: const Text("Guardar Configuración", style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// === WIDGET AUXILIAR: CALENDARIO DE PAGOS ===
// ============================================================

class _CalendarioPagosWidget extends StatefulWidget {
  final List<Map<String, dynamic>> pagos;
  final NumberFormat currencyFormat;
  final ScrollController scrollController;

  const _CalendarioPagosWidget({
    required this.pagos,
    required this.currencyFormat,
    required this.scrollController,
  });

  @override
  State<_CalendarioPagosWidget> createState() => _CalendarioPagosWidgetState();
}

class _CalendarioPagosWidgetState extends State<_CalendarioPagosWidget> {
  late DateTime _mesActual;
  late List<DateTime> _diasDelMes;

  @override
  void initState() {
    super.initState();
    _mesActual = DateTime.now();
    _generarDiasDelMes();
  }

  void _generarDiasDelMes() {
    // ignore: unused_local_variable
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final ultimoDia = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    
    _diasDelMes = List.generate(
      ultimoDia.day,
      (index) => DateTime(_mesActual.year, _mesActual.month, index + 1),
    );
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + delta, 1);
      _generarDiasDelMes();
    });
  }

  List<Map<String, dynamic>> _pagosDeDia(DateTime dia) {
    return widget.pagos.where((p) {
      final fecha = DateTime.tryParse(p['fecha_vencimiento'] ?? '');
      return fecha != null && 
             fecha.year == dia.year && 
             fecha.month == dia.month && 
             fecha.day == dia.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _cambiarMes(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                DateFormat('MMMM yyyy', 'es').format(_mesActual).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _cambiarMes(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Días de la semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) => 
              Text(d, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))
            ).toList(),
          ),
          const SizedBox(height: 10),
          
          // Calendario
          Expanded(
            child: GridView.builder(
              controller: widget.scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: _diasDelMes.length + (_diasDelMes.first.weekday - 1),
              itemBuilder: (context, index) {
                // Espacios vacíos al inicio
                if (index < _diasDelMes.first.weekday - 1) {
                  return const SizedBox();
                }
                
                final diaIndex = index - (_diasDelMes.first.weekday - 1);
                if (diaIndex >= _diasDelMes.length) return const SizedBox();
                
                final dia = _diasDelMes[diaIndex];
                final pagosDelDia = _pagosDeDia(dia);
                final esHoy = dia.year == DateTime.now().year && 
                              dia.month == DateTime.now().month && 
                              dia.day == DateTime.now().day;
                final tienePagos = pagosDelDia.isNotEmpty;
                final esPasado = dia.isBefore(DateTime.now());

                return InkWell(
                  onTap: tienePagos ? () => _mostrarPagosDia(dia, pagosDelDia) : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: esHoy 
                        ? Colors.blueAccent.withOpacity(0.3) 
                        : tienePagos 
                          ? (esPasado ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: esHoy ? Border.all(color: Colors.blueAccent) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${dia.day}',
                          style: TextStyle(
                            color: tienePagos ? Colors.white : Colors.white54,
                            fontWeight: tienePagos ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (tienePagos)
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: esPasado ? Colors.redAccent : Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Leyenda
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLeyendaCalendario(Colors.orangeAccent, "Pago próximo"),
              const SizedBox(width: 20),
              _buildLeyendaCalendario(Colors.redAccent, "Vencido"),
              const SizedBox(width: 20),
              _buildLeyendaCalendario(Colors.blueAccent, "Hoy"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaCalendario(Color color, String texto) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  void _mostrarPagosDia(DateTime dia, List<Map<String, dynamic>> pagos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(
          "Pagos del ${DateFormat('dd/MMM/yyyy').format(dia)}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: pagos.map((p) {
            final monto = (p['monto'] ?? 0).toDouble();
            final cliente = p['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt, color: Colors.orangeAccent),
              title: Text(cliente, style: const TextStyle(color: Colors.white)),
              trailing: Text(widget.currencyFormat.format(monto),
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
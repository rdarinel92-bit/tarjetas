// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';
import 'package:intl/intl.dart';

class ChatListaScreen extends StatefulWidget {
  const ChatListaScreen({super.key});

  @override
  State<ChatListaScreen> createState() => _ChatListaScreenState();
}

class _ChatListaScreenState extends State<ChatListaScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _conversaciones = [];
  bool _cargando = true;
  String? _miUsuarioId;
  RealtimeChannel? _subscription;
  
  // V10.56 - Tabs para mensajes internos y web QR
  late TabController _tabController;
  List<Map<String, dynamic>> _mensajesWebQR = [];
  bool _cargandoWebQR = false;
  int _mensajesWebNoLeidos = 0;
  List<String> _misNegociosIds = [];
  bool _esSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _miUsuarioId = AppSupabase.client.auth.currentUser?.id;
    _cargarMisNegocios().then((_) {
      _cargarConversaciones();
      _cargarMensajesWebQR();
    });
    _iniciarRealtime();
  }
  
  Future<void> _cargarMisNegocios() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;
      
      debugPrint('📧 Usuario actual: ${user.email}');
      
      // Verificar si es superadmin por email conocido
      final ownerEmails = ['rdarinel992@gmail.com', 'rdarinel92@gmail.com'];
      if (ownerEmails.contains(user.email?.toLowerCase())) {
        _esSuperAdmin = true;
        debugPrint('✅ Usuario es superadmin por email');
      }
      
      // También verificar por rol si no es por email
      if (!_esSuperAdmin) {
        try {
          final userInfo = await AppSupabase.client
              .from('usuarios')
              .select('rol_id, roles!inner(nombre)')
              .eq('id', user.id)
              .maybeSingle();
          
          if (userInfo != null) {
            final rolNombre = userInfo['roles']?['nombre']?.toString().toLowerCase() ?? '';
            _esSuperAdmin = rolNombre == 'superadmin' || rolNombre == 'admin';
          }
        } catch (e) {
          debugPrint('⚠️ Error verificando rol: $e');
        }
      }
      
      if (_esSuperAdmin) {
        // Superadmin ve todos los negocios
        final negocios = await AppSupabase.client
            .from('negocios')
            .select('id')
            .eq('activo', true);
        _misNegociosIds = negocios.map((n) => n['id'] as String).toList();
        debugPrint('🏢 Superadmin: ${_misNegociosIds.length} negocios');
      } else {
        // 1. Buscar negocios donde es owner
        final negociosOwner = await AppSupabase.client
            .from('negocios')
            .select('id')
            .eq('owner_email', user.email ?? '')
            .eq('activo', true);
        
        _misNegociosIds = negociosOwner.map((n) => n['id'] as String).toList();
        debugPrint('🏢 Negocios como owner: ${_misNegociosIds.length}');
        
        // 2. Buscar asignaciones directas
        final asignaciones = await AppSupabase.client
            .from('empleados_negocios')
            .select('negocio_id')
            .eq('auth_uid', user.id)
            .eq('activo', true);
        
        for (var a in asignaciones) {
          final nid = a['negocio_id'] as String;
          if (!_misNegociosIds.contains(nid)) {
            _misNegociosIds.add(nid);
          }
        }
        
        // 3. Buscar por empleado-sucursal
        if (_misNegociosIds.isEmpty) {
          final empleado = await AppSupabase.client
              .from('empleados')
              .select('id, sucursal_id, sucursales!inner(negocio_id)')
              .eq('usuario_id', user.id)
              .eq('activo', true)
              .maybeSingle();
          
          if (empleado != null && empleado['sucursales'] != null) {
            final negocioId = empleado['sucursales']['negocio_id'];
            if (negocioId != null) {
              _misNegociosIds.add(negocioId as String);
            }
          }
        }
      }
      
      debugPrint('📊 Total negocios del usuario: ${_misNegociosIds.length}');
    } catch (e) {
      debugPrint('❌ Error cargando mis negocios: $e');
    }
  }
  
  Future<void> _cargarMensajesWebQR() async {
    debugPrint('🔄 Cargando mensajes Web QR...');
    debugPrint('   - Negocios: $_misNegociosIds');
    debugPrint('   - SuperAdmin: $_esSuperAdmin');
    
    // Si es superadmin pero no tiene negocios cargados, cargar todos
    if (_esSuperAdmin && _misNegociosIds.isEmpty) {
      try {
        final negocios = await AppSupabase.client
            .from('negocios')
            .select('id')
            .eq('activo', true);
        _misNegociosIds = negocios.map((n) => n['id'] as String).toList();
      } catch (e) {
        debugPrint('⚠️ Error cargando negocios para superadmin: $e');
      }
    }
    
    setState(() => _cargandoWebQR = true);
    try {
      List<dynamic> mensajes;
      
      if (_esSuperAdmin) {
        // Superadmin ve TODOS los mensajes
        mensajes = await AppSupabase.client
            .from('tarjetas_chat')
            .select('*')
            .order('created_at', ascending: false);
        debugPrint('📩 Superadmin: cargando todos los mensajes');
      } else if (_misNegociosIds.isNotEmpty) {
        // Usuario normal: mensajes de sus negocios
        mensajes = await AppSupabase.client
            .from('tarjetas_chat')
            .select('*')
            .inFilter('negocio_id', _misNegociosIds)
            .order('created_at', ascending: false);
        debugPrint('📩 Usuario: cargando mensajes de ${_misNegociosIds.length} negocios');
      } else {
        debugPrint('⚠️ Sin negocios asignados, no se cargan mensajes');
        if (mounted) setState(() => _cargandoWebQR = false);
        return;
      }
      
      debugPrint('📩 Mensajes encontrados: ${mensajes.length}');
      
      // Agrupar por visitante_id para obtener conversaciones únicas
      Map<String, Map<String, dynamic>> conversacionesPorVisitante = {};
      int noLeidos = 0;
      
      for (var msg in mensajes) {
        final visitanteId = msg['visitante_id'] ?? '';
        if (visitanteId.isEmpty) continue;
        
        if (!conversacionesPorVisitante.containsKey(visitanteId)) {
          final leido = msg['leido'] ?? false;
          if (!leido) noLeidos++;
          
          conversacionesPorVisitante[visitanteId] = {
            'visitante_id': visitanteId,
            'visitante_nombre': msg['visitante_nombre'] ?? 'Visitante',
            'visitante_email': msg['visitante_email'],
            'visitante_telefono': msg['visitante_telefono'],
            'ultimo_mensaje': msg['mensaje'],
            'created_at': msg['created_at'],
            'negocio_id': msg['negocio_id'],
            'tarjeta_id': msg['tarjeta_id'],
            'tarjeta_nombre': 'Tarjeta Web',
            'leido': leido,
          };
        }
      }
      
      debugPrint('💬 Conversaciones únicas: ${conversacionesPorVisitante.length}');
      
      if (mounted) {
        setState(() {
          _mensajesWebQR = conversacionesPorVisitante.values.toList();
          _mensajesWebNoLeidos = noLeidos;
          _cargandoWebQR = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando mensajes web QR: $e');
      if (mounted) setState(() => _cargandoWebQR = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _iniciarRealtime() {
    // Suscribirse a nuevos mensajes para actualizar la lista
    _subscription = AppSupabase.client
        .channel('chat_mensajes_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_mensajes',
          callback: (payload) {
            // Recargar conversaciones cuando llega un nuevo mensaje
            _cargarConversaciones();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tarjetas_chat',
          callback: (payload) {
            // Recargar mensajes web QR cuando llega uno nuevo
            _cargarMensajesWebQR();
          },
        )
        .subscribe();
  }

  Future<void> _cargarConversaciones() async {
    if (_miUsuarioId == null) return;

    setState(() => _cargando = true);
    try {
      // Obtener conversaciones donde participo
      final participaciones = await AppSupabase.client
          .from('chat_participantes')
          .select('conversacion_id')
          .eq('usuario_id', _miUsuarioId!);

      if (participaciones.isEmpty) {
        setState(() {
          _conversaciones = [];
          _cargando = false;
        });
        return;
      }

      final conversacionIds =
          (participaciones as List).map((p) => p['conversacion_id']).toList();

      // Obtener detalles de conversaciones
      final conversaciones = await AppSupabase.client
          .from('chat_conversaciones')
          .select('''
            *,
            clientes:cliente_id(nombre_completo),
            prestamos:prestamo_id(id, monto),
            tandas:tanda_id(nombre)
          ''')
          .inFilter('id', conversacionIds)
          .eq('estado', 'activa')
          .order('created_at', ascending: false);

      // Para cada conversación, obtener el último mensaje y participantes
      List<Map<String, dynamic>> conversacionesConInfo = [];

      for (var conv in conversaciones) {
        // Último mensaje
        final ultimoMensaje = await AppSupabase.client
            .from('chat_mensajes')
            .select('contenido_texto, created_at, remitente_usuario_id')
            .eq('conversacion_id', conv['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // Participantes
        final participantes = await AppSupabase.client
            .from('chat_participantes')
            .select(
                'usuario_id, rol_chat, usuarios:usuario_id(nombre_completo, email)')
            .eq('conversacion_id', conv['id']);

        // Contar mensajes no leídos (simplificado)
        final mensajesNoLeidos = await AppSupabase.client
            .from('chat_mensajes')
            .select('id')
            .eq('conversacion_id', conv['id'])
            .neq('remitente_usuario_id', _miUsuarioId!)
            .count(CountOption.exact);

        conversacionesConInfo.add({
          ...conv,
          'ultimo_mensaje': ultimoMensaje,
          'participantes': participantes,
          'no_leidos': (mensajesNoLeidos as List).length,
        });
      }

      setState(() {
        _conversaciones = conversacionesConInfo;
        _cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando conversaciones: $e");
      setState(() => _cargando = false);
    }
  }

  String _obtenerNombreConversacion(Map<String, dynamic> conv) {
    final tipo = conv['tipo_conversacion'];

    if (tipo == 'prestamo' && conv['prestamos'] != null) {
      return '💰 Préstamo #${conv['prestamos']['id'].toString().substring(0, 8)}';
    }

    if (tipo == 'tanda' && conv['tandas'] != null) {
      return '🔄 ${conv['tandas']['nombre']}';
    }

    if (conv['clientes'] != null) {
      return conv['clientes']['nombre_completo'] ?? 'Cliente';
    }

    // Buscar el otro participante
    final participantes = conv['participantes'] as List? ?? [];
    for (var p in participantes) {
      if (p['usuario_id'] != _miUsuarioId && p['usuarios'] != null) {
        return p['usuarios']['nombre_completo'] ??
            p['usuarios']['email'] ??
            'Usuario';
      }
    }

    return 'Conversación';
  }

  String _obtenerAvatar(Map<String, dynamic> conv) {
    final nombre = _obtenerNombreConversacion(conv);
    if (nombre.startsWith('💰')) return '💰';
    if (nombre.startsWith('🔄')) return '🔄';
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  Color _obtenerColorTipo(String tipo) {
    switch (tipo) {
      case 'prestamo':
        return Colors.greenAccent;
      case 'tanda':
        return Colors.orangeAccent;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Mensajes",
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white54),
          onPressed: () => _mostrarAjustesChat(),
          tooltip: 'Ajustes de chat',
        ),
      ],
      body: Column(
        children: [
          // V10.56 - TabBar para Internos y Web QR
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF25D366),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 18),
                      SizedBox(width: 8),
                      Text('Internos'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2, size: 18),
                      const SizedBox(width: 8),
                      const Text('Web QR'),
                      if (_mensajesWebNoLeidos > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _mensajesWebNoLeidos.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenido de los tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Conversaciones internas
                _buildTabInternos(),
                // Tab 2: Mensajes Web QR
                _buildTabWebQR(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366), // Verde WhatsApp
        onPressed: () => _mostrarNuevaConversacion(),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  // Tab de conversaciones internas
  Widget _buildTabInternos() {
    return Column(
      children: [
        // Barra de búsqueda estilo WhatsApp
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Buscar conversación...",
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.search, color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
        ),
        // Lista de conversaciones
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _conversaciones.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _cargarConversaciones,
                      child: ListView.builder(
                        itemCount: _conversaciones.length,
                        itemBuilder: (context, index) {
                          return _buildConversacionTile(_conversaciones[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // Tab de mensajes Web QR (visitantes que escanean tarjetas)
  Widget _buildTabWebQR() {
    if (_cargandoWebQR) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_mensajesWebQR.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 20),
            const Text("Sin mensajes de tarjetas web",
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text("Cuando alguien escanee tu QR y te escriba,\naparecerá aquí",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.tarjetasServicio),
              icon: const Icon(Icons.add_card),
              label: const Text("Crear tarjeta QR"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _cargarMensajesWebQR,
      child: ListView.builder(
        itemCount: _mensajesWebQR.length,
        itemBuilder: (context, index) {
          return _buildMensajeWebQRTile(_mensajesWebQR[index]);
        },
      ),
    );
  }

  Widget _buildMensajeWebQRTile(Map<String, dynamic> msg) {
    final nombre = msg['visitante_nombre'] ?? 'Visitante';
    final email = msg['visitante_email'] ?? '';
    final telefono = msg['visitante_telefono'] ?? '';
    final ultimoMensaje = msg['ultimo_mensaje'] ?? '';
    final tarjetaNombre = msg['tarjeta_nombre'] ?? 'Tarjeta';
    final leido = msg['leido'] ?? true;
    
    String subtitulo = email.isNotEmpty ? email : (telefono.isNotEmpty ? telefono : '');
    
    // Formatear fecha
    String horaFormateada = '';
    if (msg['created_at'] != null) {
      final fecha = DateTime.parse(msg['created_at']);
      final ahora = DateTime.now();
      if (fecha.day == ahora.day && fecha.month == ahora.month && fecha.year == ahora.year) {
        horaFormateada = DateFormat('HH:mm').format(fecha);
      } else if (fecha.isAfter(ahora.subtract(const Duration(days: 7)))) {
        horaFormateada = DateFormat('EEE', 'es').format(fecha);
      } else {
        horaFormateada = DateFormat('dd/MM').format(fecha);
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: () {
          // Navegar al chat de tarjetas con el visitante seleccionado
          Navigator.pushNamed(context, AppRoutes.tarjetasChat);
        },
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            // Indicador QR
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E2C), width: 2),
                ),
                child: const Icon(Icons.qr_code_2, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: leido ? FontWeight.normal : FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(horaFormateada, style: TextStyle(
              color: leido ? Colors.white38 : const Color(0xFF8B5CF6),
              fontSize: 12,
            )),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitulo.isNotEmpty)
              Text(subtitulo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('🎴 $tarjetaNombre', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10)),
                ),
                Expanded(
                  child: Text(
                    ultimoMensaje.length > 25 ? '${ultimoMensaje.substring(0, 25)}...' : ultimoMensaje,
                    style: TextStyle(
                      color: leido ? Colors.white38 : Colors.white70,
                      fontWeight: leido ? FontWeight.normal : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!leido)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text("No tienes conversaciones",
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Inicia una nueva conversación",
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _mostrarNuevaConversacion(),
            icon: const Icon(Icons.add),
            label: const Text("Nueva conversación"),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }

  Widget _buildConversacionTile(Map<String, dynamic> conv) {
    final nombre = _obtenerNombreConversacion(conv);
    final avatar = _obtenerAvatar(conv);
    final colorTipo = _obtenerColorTipo(conv['tipo_conversacion']);
    final ultimoMensaje = conv['ultimo_mensaje'];
    final noLeidos = conv['no_leidos'] ?? 0;

    String textoUltimo = "Sin mensajes aún";
    String horaUltimo = "";

    if (ultimoMensaje != null) {
      textoUltimo = ultimoMensaje['contenido_texto'] ?? '📎 Archivo';
      if (textoUltimo.length > 35) {
        textoUltimo = '${textoUltimo.substring(0, 35)}...';
      }
      final fecha = DateTime.parse(ultimoMensaje['created_at']);
      final ahora = DateTime.now();
      if (fecha.day == ahora.day &&
          fecha.month == ahora.month &&
          fecha.year == ahora.year) {
        horaUltimo = DateFormat('HH:mm').format(fecha);
      } else if (fecha.isAfter(ahora.subtract(const Duration(days: 7)))) {
        horaUltimo = DateFormat('EEE', 'es').format(fecha);
      } else {
        horaUltimo = DateFormat('dd/MM').format(fecha);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.chatDetalle,
            arguments: {'conversacionId': conv['id'], 'nombre': nombre},
          );
        },
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorTipo.withOpacity(0.2),
              child: avatar.length == 1
                  ? Text(avatar,
                      style: TextStyle(
                          color: colorTipo,
                          fontSize: 22,
                          fontWeight: FontWeight.bold))
                  : Text(avatar, style: const TextStyle(fontSize: 20)),
            ),
            // Indicador de tipo
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorTipo,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E2C), width: 2),
                ),
                child: Icon(
                  conv['tipo_conversacion'] == 'prestamo'
                      ? Icons.attach_money
                      : conv['tipo_conversacion'] == 'tanda'
                          ? Icons.loop
                          : Icons.person,
                  size: 10,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      noLeidos > 0 ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              horaUltimo,
              style: TextStyle(
                color: noLeidos > 0 ? const Color(0xFF25D366) : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            // Doble check para mensajes enviados
            if (ultimoMensaje != null &&
                ultimoMensaje['remitente_usuario_id'] == _miUsuarioId)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.done_all, size: 16, color: Colors.blueAccent),
              ),
            Expanded(
              child: Text(
                textoUltimo,
                style: TextStyle(
                  color: noLeidos > 0 ? Colors.white70 : Colors.white38,
                  fontWeight:
                      noLeidos > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (noLeidos > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  noLeidos.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarNuevaConversacion() {
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
            const Text("Nueva Conversación",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: const Text("Chat Directo",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Conversación 1 a 1 con un cliente",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarUsuarioParaChat();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.greenAccent,
                child: Icon(Icons.attach_money, color: Colors.black),
              ),
              title: const Text("Chat de Préstamo",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Vincular conversación a un préstamo",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarPrestamoParaChat();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orangeAccent,
                child: Icon(Icons.groups, color: Colors.black),
              ),
              title: const Text("Chat de Tanda",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Chat grupal con participantes de tanda",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarTandaParaChat();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarUsuarioParaChat() async {
    final usuarios = await AppSupabase.client
        .from('usuarios')
        .select('id, nombre_completo, email, rol')
        .neq('id', _miUsuarioId ?? '')
        .order('nombre_completo');

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
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text("Seleccionar Usuario",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: usuarios.length,
                itemBuilder: (context, index) {
                  final u = usuarios[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: Text(
                        (u['nombre_completo'] ?? u['email'] ?? '?')[0]
                            .toUpperCase(),
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    title: Text(u['nombre_completo'] ?? u['email'],
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(u['rol'] ?? 'usuario',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _crearConversacionDirecta(u['id']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearConversacionDirecta(String otroUsuarioId) async {
    try {
      // Verificar si ya existe una conversación directa
      final existente = await AppSupabase.client
          .from('chat_participantes')
          .select('conversacion_id')
          .eq('usuario_id', _miUsuarioId!)
          .then((res) async {
        for (var p in res) {
          final conv = await AppSupabase.client
              .from('chat_conversaciones')
              .select()
              .eq('id', p['conversacion_id'])
              .eq('tipo_conversacion', 'directo')
              .maybeSingle();
          if (conv != null) {
            final otroParticipante = await AppSupabase.client
                .from('chat_participantes')
                .select()
                .eq('conversacion_id', conv['id'])
                .eq('usuario_id', otroUsuarioId)
                .maybeSingle();
            if (otroParticipante != null) return conv;
          }
        }
        return null;
      });

      String conversacionId;

      if (existente != null) {
        conversacionId = existente['id'];
      } else {
        // Crear nueva conversación
        final nuevaConv = await AppSupabase.client
            .from('chat_conversaciones')
            .insert({
              'tipo_conversacion': 'directo',
              'creado_por_usuario_id': _miUsuarioId,
              'estado': 'activa',
            })
            .select()
            .single();

        conversacionId = nuevaConv['id'];

        // Agregar participantes
        await AppSupabase.client.from('chat_participantes').insert([
          {
            'conversacion_id': conversacionId,
            'usuario_id': _miUsuarioId,
            'rol_chat': 'operador'
          },
          {
            'conversacion_id': conversacionId,
            'usuario_id': otroUsuarioId,
            'rol_chat': 'cliente'
          },
        ]);
      }

      // Navegar al chat
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.chatDetalle,
          arguments: {'conversacionId': conversacionId, 'nombre': 'Chat'},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarPrestamoParaChat() async {
    final prestamos = await AppSupabase.client
        .from('prestamos')
        .select('id, monto, estado, cliente_id, clientes(nombre_completo)')
        .eq('estado', 'activo')
        .order('created_at', ascending: false);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Seleccionar Préstamo",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: prestamos.isEmpty
                  ? const Center(
                      child: Text("No hay préstamos activos",
                          style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: prestamos.length,
                      itemBuilder: (context, index) {
                        final p = prestamos[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.greenAccent,
                            child:
                                Icon(Icons.attach_money, color: Colors.black),
                          ),
                          title: Text(
                              p['clientes']?['nombre_completo'] ?? 'Cliente',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('\$${p['monto']} - ${p['estado']}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            await _crearConversacionPrestamo(
                                p['id'], p['cliente_id']);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearConversacionPrestamo(
      String prestamoId, String clienteId) async {
    try {
      // Verificar si ya existe
      final existente = await AppSupabase.client
          .from('chat_conversaciones')
          .select()
          .eq('prestamo_id', prestamoId)
          .maybeSingle();

      String conversacionId;

      if (existente != null) {
        conversacionId = existente['id'];
      } else {
        final nuevaConv = await AppSupabase.client
            .from('chat_conversaciones')
            .insert({
              'tipo_conversacion': 'prestamo',
              'prestamo_id': prestamoId,
              'cliente_id': clienteId,
              'creado_por_usuario_id': _miUsuarioId,
              'estado': 'activa',
            })
            .select()
            .single();

        conversacionId = nuevaConv['id'];

        await AppSupabase.client.from('chat_participantes').insert([
          {
            'conversacion_id': conversacionId,
            'usuario_id': _miUsuarioId,
            'rol_chat': 'operador'
          },
          {
            'conversacion_id': conversacionId,
            'usuario_id': clienteId,
            'rol_chat': 'cliente'
          },
        ]);
      }

      if (mounted) {
        Navigator.pushNamed(context, AppRoutes.chatDetalle, arguments: {
          'conversacionId': conversacionId,
          'nombre': 'Préstamo'
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _seleccionarTandaParaChat() async {
    final tandas = await AppSupabase.client
        .from('tandas')
        .select('id, nombre, estado, numero_participantes')
        .eq('estado', 'activa')
        .order('created_at', ascending: false);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Seleccionar Tanda",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (tandas.isEmpty)
              const Text("No hay tandas activas",
                  style: TextStyle(color: Colors.white54))
            else
              ...tandas.map((t) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orangeAccent,
                      child: Icon(Icons.loop, color: Colors.black),
                    ),
                    title: Text(t['nombre'],
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${t['numero_participantes']} participantes',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      // Similar a préstamo pero para tanda
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Chat de tanda creado"),
                            backgroundColor: Colors.green),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  void _mostrarAjustesChat() {
    bool notificacionesPush = true;
    bool sonidosMensajes = true;
    bool vibracion = true;
    bool mostrarVisto = true;
    bool mostrarEnLinea = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  const Text(
                    "Ajustes de Chat",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Sección: Notificaciones
              const Text(
                "Notificaciones",
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildChatSettingSwitch(
                "Notificaciones Push",
                "Recibir alertas de mensajes nuevos",
                Icons.notifications_active,
                notificacionesPush,
                (v) => setModalState(() => notificacionesPush = v),
              ),
              _buildChatSettingSwitch(
                "Sonidos de mensaje",
                "Reproducir sonido al recibir mensaje",
                Icons.volume_up,
                sonidosMensajes,
                (v) => setModalState(() => sonidosMensajes = v),
              ),
              _buildChatSettingSwitch(
                "Vibración",
                "Vibrar al recibir mensajes",
                Icons.vibration,
                vibracion,
                (v) => setModalState(() => vibracion = v),
              ),
              
              const SizedBox(height: 20),
              
              // Sección: Privacidad
              const Text(
                "Privacidad",
                style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildChatSettingSwitch(
                "Confirmación de lectura",
                "Mostrar cuándo leíste los mensajes",
                Icons.done_all,
                mostrarVisto,
                (v) => setModalState(() => mostrarVisto = v),
              ),
              _buildChatSettingSwitch(
                "Mostrar en línea",
                "Permitir que vean cuando estás activo",
                Icons.circle,
                mostrarEnLinea,
                (v) => setModalState(() => mostrarEnLinea = v),
              ),
              
              const SizedBox(height: 20),
              
              // Acciones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _archivarTodas();
                      },
                      icon: const Icon(Icons.archive, size: 18),
                      label: const Text("Archivar todo"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _limpiarChats();
                      },
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text("Limpiar chats"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSettingSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: value ? Colors.greenAccent : Colors.white38, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.greenAccent,
      ),
    );
  }

  void _archivarTodas() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📁 Todas las conversaciones archivadas"),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  void _limpiarChats() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Limpiar Chats", style: TextStyle(color: Colors.white)),
        content: const Text(
          "¿Estás seguro? Se eliminarán todos los mensajes de todas las conversaciones.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🗑️ Chats limpiados"),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Limpiar"),
          ),
        ],
      ),
    );
  }
}

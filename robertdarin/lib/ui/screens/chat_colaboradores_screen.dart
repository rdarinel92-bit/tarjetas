// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';
import '../../data/models/compensacion_models.dart';
import 'package:intl/intl.dart';

/// Chat entre superadmin y colaboradores
class ChatColaboradoresScreen extends StatefulWidget {
  final String? conversacionId;
  final String? colaboradorId;

  const ChatColaboradoresScreen({
    super.key,
    this.conversacionId,
    this.colaboradorId,
  });

  @override
  State<ChatColaboradoresScreen> createState() =>
      _ChatColaboradoresScreenState();
}

class _ChatColaboradoresScreenState extends State<ChatColaboradoresScreen> {
  bool _isLoading = true;
  List<ChatConversacionModel> _conversaciones = [];
  String? _conversacionActiva;
  List<ChatMensajeModel> _mensajes = [];
  final _mensajeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarConversaciones();
    if (widget.conversacionId != null) {
      _conversacionActiva = widget.conversacionId;
    }
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConversaciones() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;

      // Obtener conversaciones donde participa el usuario
      final participaciones = await AppSupabase.client
          .from('chat_participantes')
          .select('conversacion_id')
          .eq('usuario_id', userId);

      final conversacionIds = (participaciones as List)
          .map((p) => p['conversacion_id'] as String)
          .toList();

      if (conversacionIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final conversaciones = await AppSupabase.client
          .from('chat_conversaciones')
          .select()
          .inFilter('id', conversacionIds)
          .eq('estado', 'activo')
          .order('fecha_ultimo_mensaje', ascending: false);

      if (mounted) {
        final List<ChatConversacionModel> convs = [];
        for (final c in (conversaciones as List)) {
          final noLeidosRes = await AppSupabase.client
              .from('chat_mensajes')
              .select('id')
              .eq('conversacion_id', c['id'])
              .eq('leido', false)
              .neq('remitente_usuario_id', userId);

          c['mensajes_no_leidos'] = (noLeidosRes as List).length;
          c['tipo'] = c['tipo_conversacion'];
          c['creador_id'] = c['creado_por_usuario_id'];
          c['activa'] = c['estado'] == 'activo';
          c['ultimo_mensaje_at'] =
              c['fecha_ultimo_mensaje'] ?? c['updated_at'] ?? c['created_at'];
          c['ultimo_mensaje_preview'] = c['ultimo_mensaje'];
          convs.add(ChatConversacionModel.fromMap(c));
        }

        setState(() {
          _conversaciones = convs;
          _isLoading = false;
        });

        if (_conversacionActiva != null) {
          _cargarMensajes(_conversacionActiva!);
        }
      }
    } catch (e) {
      debugPrint('Error cargando conversaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMensajes(String conversacionId) async {
    try {
      final mensajes = await AppSupabase.client
          .from('chat_mensajes')
          .select()
          .eq('conversacion_id', conversacionId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _mensajes = (mensajes as List)
              .map((m) => ChatMensajeModel.fromMap(m))
              .toList();
        });

        // Scroll al final
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        // Marcar como leído
        _marcarLeido(conversacionId);
      }
    } catch (e) {
      debugPrint('Error cargando mensajes: $e');
    }
  }

  Future<void> _marcarLeido(String conversacionId) async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;

      await AppSupabase.client
          .from('chat_mensajes')
          .update({
            'leido': true,
            'fecha_lectura': DateTime.now().toIso8601String(),
          })
          .eq('conversacion_id', conversacionId)
          .neq('remitente_usuario_id', userId)
          .eq('leido', false);
    } catch (e) {
      debugPrint('Error marcando leído: $e');
    }
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeCtrl.text.trim().isEmpty || _conversacionActiva == null) return;

    final contenido = _mensajeCtrl.text.trim();
    _mensajeCtrl.clear();
    setState(() => _enviando = true);

    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;

      await AppSupabase.client.from('chat_mensajes').insert({
        'conversacion_id': _conversacionActiva,
        'remitente_usuario_id': userId,
        'tipo_mensaje': 'texto',
        'contenido_texto': contenido,
      });

      await AppSupabase.client.from('chat_conversaciones').update({
        'ultimo_mensaje': contenido,
        'fecha_ultimo_mensaje': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _conversacionActiva!);

      _cargarMensajes(_conversacionActiva!);
    } catch (e) {
      debugPrint('Error enviando mensaje: $e');
      // Restaurar el texto si falló
      _mensajeCtrl.text = contenido;
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Chat Colaboradores',
      subtitle: 'Comunicación directa',
      actions: [
        IconButton(
          icon: const Icon(Icons.group_add),
          onPressed: _mostrarNuevaConversacion,
          tooltip: 'Nueva conversación',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Lista de conversaciones (sidebar)
                Container(
                  width: MediaQuery.of(context).size.width > 600 ? 300 : 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    border: Border(
                      right: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: _buildListaConversaciones(),
                ),
                // Chat activo
                Expanded(
                  child: _conversacionActiva == null
                      ? _buildSinSeleccion()
                      : _buildChat(),
                ),
              ],
            ),
    );
  }

  Widget _buildListaConversaciones() {
    if (_conversaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: Colors.white24, size: 48),
            const SizedBox(height: 8),
            if (MediaQuery.of(context).size.width > 600)
              const Text(
                'Sin conversaciones',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
      );
    }

    final esCompacto = MediaQuery.of(context).size.width <= 600;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversaciones.length,
      itemBuilder: (context, index) {
        final conv = _conversaciones[index];
        final activa = conv.id == _conversacionActiva;

        return InkWell(
          onTap: () {
            setState(() => _conversacionActiva = conv.id);
            _cargarMensajes(conv.id);
          },
          child: Container(
            padding: EdgeInsets.all(esCompacto ? 12 : 16),
            decoration: BoxDecoration(
              color: activa
                  ? const Color(0xFF8B5CF6).withOpacity(0.2)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: activa ? const Color(0xFF8B5CF6) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: conv.colorValue.withOpacity(0.2),
                      child: Icon(conv.iconData, color: conv.colorValue, size: 20),
                    ),
                    if (conv.mensajesNoLeidos > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conv.mensajesNoLeidos > 9
                                ? '9+'
                                : conv.mensajesNoLeidos.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!esCompacto) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv.nombre ?? _getNombreConversacion(conv),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: conv.mensajesNoLeidos > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (conv.ultimoMensajePreview != null)
                          Text(
                            conv.ultimoMensajePreview!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (conv.ultimoMensajeAt != null)
                    Text(
                      _formatoTiempo(conv.ultimoMensajeAt!),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getNombreConversacion(ChatConversacionModel conv) {
    if (conv.tipo == 'privada') {
      return 'Chat Privado';
    }
    return conv.nombre ?? 'Conversación';
  }

  String _formatoTiempo(DateTime fecha) {
    final ahora = DateTime.now();
    final diff = ahora.difference(fecha);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd/MM').format(fecha);
  }

  Widget _buildSinSeleccion() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat, color: Colors.white24, size: 64),
          SizedBox(height: 16),
          Text(
            'Selecciona una conversación',
            style: TextStyle(color: Colors.white54),
          ),
          SizedBox(height: 8),
          Text(
            'o inicia una nueva',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    final userId = AppSupabase.client.auth.currentUser?.id;

    return Column(
      children: [
        // Header del chat
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            border: Border(
              bottom: BorderSide(color: Colors.white10),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                child: const Icon(Icons.person, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversaciones
                              .firstWhere((c) => c.id == _conversacionActiva,
                                  orElse: () => ChatConversacionModel(
                                        id: '',
                                        negocioId: '',
                                        tipo: 'privada',
                                        creadorId: '',
                                        createdAt: DateTime.now(),
                                      ))
                              .nombre ??
                          'Conversación',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_mensajes.length} mensajes',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Mensajes
        Expanded(
          child: _mensajes.isEmpty
              ? const Center(
                  child: Text(
                    'Inicia la conversación',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = _mensajes[index];
                    final esMio = mensaje.remitenteId == userId;
                    final mostrarFecha = index == 0 ||
                        !_mismoDia(
                            _mensajes[index - 1].createdAt, mensaje.createdAt);

                    return Column(
                      children: [
                        if (mostrarFecha) _buildFechaSeparador(mensaje.createdAt),
                        _buildMensaje(mensaje, esMio),
                      ],
                    );
                  },
                ),
        ),

        // Input de mensaje
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            border: Border(
              top: BorderSide(color: Colors.white10),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.white54),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  controller: _mensajeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF8B5CF6),
                child: IconButton(
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _enviando ? null : _enviarMensaje,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildFechaSeparador(DateTime fecha) {
    String texto;
    final ahora = DateTime.now();

    if (_mismoDia(fecha, ahora)) {
      texto = 'Hoy';
    } else if (_mismoDia(fecha, ahora.subtract(const Duration(days: 1)))) {
      texto = 'Ayer';
    } else {
      texto = DateFormat('d MMMM yyyy', 'es').format(fecha);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white10)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const Expanded(child: Divider(color: Colors.white10)),
        ],
      ),
    );
  }

  Widget _buildMensaje(ChatMensajeModel mensaje, bool esMio) {
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: esMio
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esMio && mensaje.remitenteNombre != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  mensaje.remitenteNombre!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              mensaje.contenido,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(mensaje.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
                if (esMio) ...[
                  const SizedBox(width: 4),
                  Icon(
                    mensaje.leido ? Icons.done_all : Icons.done,
                    size: 14,
                    color: mensaje.leido
                        ? Colors.lightBlueAccent
                        : Colors.white.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarNuevaConversacion() async {
    // Cargar colaboradores para iniciar chat
    try {
      final colaboradores = await AppSupabase.client
          .from('colaboradores')
          .select('id, nombre, email, auth_uid')
          .eq('activo', true)
          .not('auth_uid', 'is', null);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nueva Conversación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona un colaborador',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: (colaboradores as List).length,
                  itemBuilder: (context, index) {
                    final colab = colaboradores[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF8B5CF6).withOpacity(0.2),
                        child: Text(
                          (colab['nombre'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                      title: Text(
                        colab['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        colab['email'] ?? '',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _crearConversacion(colab['id']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _crearConversacion(String colaboradorId) async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;

      // Obtener negocio_id del colaborador
      final colab = await AppSupabase.client
          .from('colaboradores')
          .select('negocio_id, auth_uid, usuario_id')
          .eq('id', colaboradorId)
          .single();

      final colabUserId = colab['auth_uid'] ?? colab['usuario_id'];
      if (colabUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El colaborador aun no tiene cuenta activa'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      String? conversacionId;

      // Buscar conversacion existente entre ambos usuarios
      final misParticipaciones = await AppSupabase.client
          .from('chat_participantes')
          .select('conversacion_id')
          .eq('usuario_id', userId);

      final conversacionIds = (misParticipaciones as List)
          .map((p) => p['conversacion_id'] as String)
          .toList();

      if (conversacionIds.isNotEmpty) {
        final convs = await AppSupabase.client
            .from('chat_conversaciones')
            .select('id')
            .eq('tipo_conversacion', 'colaborador')
            .inFilter('id', conversacionIds);

        final convIds = (convs as List).map((c) => c['id'] as String).toList();
        if (convIds.isNotEmpty) {
          final colabConv = await AppSupabase.client
              .from('chat_participantes')
              .select('conversacion_id')
              .eq('usuario_id', colabUserId)
              .inFilter('conversacion_id', convIds)
              .limit(1);

          if ((colabConv as List).isNotEmpty) {
            conversacionId = colabConv.first['conversacion_id'] as String?;
          }
        }
      }

      if (conversacionId == null) {
        final nuevaConv = await AppSupabase.client
            .from('chat_conversaciones')
            .insert({
              'tipo_conversacion': 'colaborador',
              'creado_por_usuario_id': userId,
              'estado': 'activo',
            })
            .select()
            .single();

        conversacionId = nuevaConv['id'];

        await AppSupabase.client.from('chat_participantes').insert([
          {
            'conversacion_id': conversacionId,
            'usuario_id': userId,
            'rol_chat': 'admin',
          },
          {
            'conversacion_id': conversacionId,
            'usuario_id': colabUserId,
            'rol_chat': 'participante',
          },
        ]);
      }

      if (conversacionId != null) {
        await _cargarConversaciones();
        setState(() => _conversacionActiva = conversacionId);
        _cargarMensajes(conversacionId);
      }
    } catch (e) {
      debugPrint('Error creando conversación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

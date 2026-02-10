// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

class ChatMensajesScreen extends StatefulWidget {
  final String conversacionId;
  final String nombreChat;

  const ChatMensajesScreen({
    super.key,
    required this.conversacionId,
    this.nombreChat = 'Chat',
  });

  @override
  State<ChatMensajesScreen> createState() => _ChatMensajesScreenState();
}

class _ChatMensajesScreenState extends State<ChatMensajesScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _miUsuarioId;
  RealtimeChannel? _subscription;
  Map<String, dynamic>? _conversacion;
  List<Map<String, dynamic>> _participantes = [];

  @override
  void initState() {
    super.initState();
    _miUsuarioId = AppSupabase.client.auth.currentUser?.id;
    _cargarDatos();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _iniciarRealtime() {
    // Escuchar nuevos mensajes en esta conversación
    _subscription = AppSupabase.client
        .channel('mensajes_${widget.conversacionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversacion_id',
            value: widget.conversacionId,
          ),
          callback: (payload) {
            final nuevoMensaje = payload.newRecord;
            // Solo agregar si no es nuestro mensaje (ya lo agregamos localmente)
            if (nuevoMensaje['remitente_usuario_id'] != _miUsuarioId) {
              _agregarMensaje(nuevoMensaje);
            }
          },
        )
        .subscribe();
  }

  void _agregarMensaje(Map<String, dynamic> mensaje) {
    // Buscar nombre del remitente
    String nombreRemitente = 'Usuario';
    for (var p in _participantes) {
      if (p['usuario_id'] == mensaje['remitente_usuario_id']) {
        nombreRemitente = p['usuarios']?['nombre_completo'] ??
            p['usuarios']?['email'] ??
            'Usuario';
        break;
      }
    }

    setState(() {
      _mensajes.add({...mensaje, 'remitente_nombre': nombreRemitente});
    });
    _scrollAlFinal();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Cargar info de conversación
      _conversacion = await AppSupabase.client
          .from('chat_conversaciones')
          .select()
          .eq('id', widget.conversacionId)
          .single();

      // Cargar participantes
      _participantes = await AppSupabase.client
          .from('chat_participantes')
          .select('*, usuarios:usuario_id(nombre_completo, email)')
          .eq('conversacion_id', widget.conversacionId);

      // Cargar mensajes
      final mensajes = await AppSupabase.client
          .from('chat_mensajes')
          .select()
          .eq('conversacion_id', widget.conversacionId)
          .order('created_at', ascending: true);

      // Agregar nombre del remitente a cada mensaje
      List<Map<String, dynamic>> mensajesConNombre = [];
      for (var m in mensajes) {
        String nombreRemitente = 'Usuario';
        for (var p in _participantes) {
          if (p['usuario_id'] == m['remitente_usuario_id']) {
            nombreRemitente = p['usuarios']?['nombre_completo'] ??
                p['usuarios']?['email'] ??
                'Usuario';
            break;
          }
        }
        mensajesConNombre.add({...m, 'remitente_nombre': nombreRemitente});
      }

      setState(() {
        _mensajes = mensajesConNombre;
        _cargando = false;
      });

      // Scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAlFinal());
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      setState(() => _cargando = false);
    }
  }

  void _scrollAlFinal() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _mensajeController.clear();

    try {
      // Insertar mensaje
      final nuevoMensaje = await AppSupabase.client
          .from('chat_mensajes')
          .insert({
            'conversacion_id': widget.conversacionId,
            'remitente_usuario_id': _miUsuarioId,
            'tipo_mensaje': 'texto',
            'contenido_texto': texto,
          })
          .select()
          .single();

      // Agregar a la lista local
      _agregarMensaje({
        ...nuevoMensaje,
        'remitente_nombre': 'Yo',
      });
    } catch (e) {
      debugPrint("Error enviando: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A), // Fondo oscuro estilo WhatsApp
      appBar: _buildAppBar(),
      body: Container(
        // Fondo con patrón sutil
        decoration: const BoxDecoration(
          color: Color(0xFF0B141A),
        ),
        child: Column(
          children: [
            // Lista de mensajes
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _mensajes.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          itemCount: _mensajes.length,
                          itemBuilder: (context, index) {
                            return _buildMensajeBurbuja(
                                _mensajes[index], index);
                          },
                        ),
            ),

            // Input de mensaje
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String subtitulo = '';
    if (_conversacion != null) {
      final tipo = _conversacion!['tipo_conversacion'];
      if (tipo == 'prestamo') subtitulo = '💰 Chat de Préstamo';
      if (tipo == 'tanda') subtitulo = '🔄 Chat de Tanda';
      if (tipo == 'directo')
        subtitulo = '${_participantes.length} participantes';
    }

    return AppBar(
      backgroundColor: const Color(0xFF1F2C34),
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.greenAccent.withOpacity(0.2),
            child: Text(
              widget.nombreChat.isNotEmpty
                  ? widget.nombreChat[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombreChat,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo.isNotEmpty)
                  Text(
                    subtitulo,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.white54),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white54),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1F2C34),
          onSelected: (value) {
            if (value == 'info') _mostrarInfoConversacion();
            if (value == 'archivos') _verArchivos();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child:
                  Text('Info del chat', style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'archivos',
              child: Text('Archivos compartidos',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'silenciar',
              child: Text('Silenciar notificaciones',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline,
                size: 60, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Inicia la conversación",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Los mensajes están cifrados de extremo a extremo 🔒",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMensajeBurbuja(Map<String, dynamic> mensaje, int index) {
    final esMio = mensaje['remitente_usuario_id'] == _miUsuarioId;
    final fecha = DateTime.parse(mensaje['created_at']);
    final hora = DateFormat('HH:mm').format(fecha);
    final tipo = mensaje['tipo_mensaje'];

    // Verificar si mostrar fecha
    bool mostrarFecha = false;
    if (index == 0) {
      mostrarFecha = true;
    } else {
      final fechaAnterior = DateTime.parse(_mensajes[index - 1]['created_at']);
      if (fecha.day != fechaAnterior.day ||
          fecha.month != fechaAnterior.month ||
          fecha.year != fechaAnterior.year) {
        mostrarFecha = true;
      }
    }

    return Column(
      children: [
        // Separador de fecha
        if (mostrarFecha)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2C34),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatearFecha(fecha),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),

        // Burbuja del mensaje
        Align(
          alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: esMio
                  ? const Color(0xFF005C4B) // Verde oscuro para mis mensajes
                  : const Color(0xFF1F2C34), // Gris oscuro para otros
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
                // Nombre del remitente (solo si no es mío y hay más de 2 participantes)
                if (!esMio && _participantes.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      mensaje['remitente_nombre'] ?? '',
                      style: TextStyle(
                        color: Colors.primaries[
                            mensaje['remitente_nombre'].hashCode %
                                Colors.primaries.length],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Contenido según tipo
                if (tipo == 'texto')
                  Text(
                    mensaje['contenido_texto'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  )
                else if (tipo == 'archivo')
                  _buildArchivoWidget(mensaje)
                else if (tipo == 'ubicacion')
                  _buildUbicacionWidget(mensaje)
                else if (mensaje['es_sistema'] == true)
                  Text(
                    mensaje['contenido_texto'] ?? '',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),

                // Hora y estado
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hora,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    if (esMio) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 14,
                        color: Colors.blue.shade300, // Azul = leído
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArchivoWidget(Map<String, dynamic> mensaje) {
    final url = mensaje['archivo_url'] ?? '';
    final esImagen =
        url.contains('.jpg') || url.contains('.png') || url.contains('.jpeg');

    if (esImagen) {
      return GestureDetector(
        onTap: () => _abrirImagen(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 200,
              height: 100,
              color: Colors.grey[800],
              child: const Icon(Icons.broken_image, color: Colors.white38),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.white54),
          const SizedBox(width: 8),
          const Flexible(
            child: Text("Archivo adjunto",
                style: TextStyle(color: Colors.white70)),
          ),
          IconButton(
            icon:
                const Icon(Icons.download, color: Colors.greenAccent, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildUbicacionWidget(Map<String, dynamic> mensaje) {
    return GestureDetector(
      onTap: () => _abrirMapa(mensaje['latitud'], mensaje['longitud']),
      child: Container(
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.redAccent, size: 40),
            SizedBox(height: 8),
            Text("Ubicación compartida",
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text("Toca para ver en mapa",
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2C34),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón de adjuntar
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.white54),
              onPressed: () => _mostrarOpcionesAdjuntar(),
            ),

            // Campo de texto
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3942),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mensajeController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 5,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: "Mensaje",
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _enviarMensaje(),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {}, // Emoji picker
                      child: const Icon(Icons.emoji_emotions_outlined,
                          color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Botón enviar/grabar
            GestureDetector(
              onTap: _mensajeController.text.isEmpty ? null : _enviarMensaje,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A884),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _enviando
                      ? Icons.hourglass_empty
                      : _mensajeController.text.isEmpty
                          ? Icons.mic
                          : Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final ayer = ahora.subtract(const Duration(days: 1));

    if (fecha.day == ahora.day &&
        fecha.month == ahora.month &&
        fecha.year == ahora.year) {
      return "Hoy";
    } else if (fecha.day == ayer.day &&
        fecha.month == ayer.month &&
        fecha.year == ayer.year) {
      return "Ayer";
    } else {
      return DateFormat('dd/MM/yyyy').format(fecha);
    }
  }

  void _mostrarOpcionesAdjuntar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOpcionAdjuntar(
                  icon: Icons.insert_drive_file,
                  label: "Documento",
                  color: Colors.purple,
                  onTap: () => _adjuntarArchivo('documento'),
                ),
                _buildOpcionAdjuntar(
                  icon: Icons.camera_alt,
                  label: "Cámara",
                  color: Colors.pink,
                  onTap: () => _adjuntarArchivo('camara'),
                ),
                _buildOpcionAdjuntar(
                  icon: Icons.photo,
                  label: "Galería",
                  color: Colors.purple,
                  onTap: () => _adjuntarArchivo('galeria'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOpcionAdjuntar(
                  icon: Icons.headphones,
                  label: "Audio",
                  color: Colors.orange,
                  onTap: () => _adjuntarArchivo('audio'),
                ),
                _buildOpcionAdjuntar(
                  icon: Icons.location_on,
                  label: "Ubicación",
                  color: Colors.green,
                  onTap: () => _enviarUbicacion(),
                ),
                _buildOpcionAdjuntar(
                  icon: Icons.person,
                  label: "Contacto",
                  color: Colors.blue,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionAdjuntar({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _adjuntarArchivo(String tipo) async {
    try {
      if (tipo == 'imagen' || tipo == 'camara') {
        final picker = ImagePicker();
        final XFile? imagen = await picker.pickImage(
          source: tipo == 'camara' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        
        if (imagen != null && mounted) {
          _mostrarLoadingDialog('Subiendo imagen...');
          
          final bytes = await imagen.readAsBytes();
          final fileName = 'chat_${widget.conversacionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          await AppSupabase.client.storage
              .from('documentos')
              .uploadBinary(fileName, bytes);
          
          final urlPublica = AppSupabase.client.storage
              .from('documentos')
              .getPublicUrl(fileName);
          
          await _enviarMensajeAdjunto('imagen', urlPublica, '🖼️ Imagen');
          Navigator.pop(context);
        }
      } else if (tipo == 'documento') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
          withData: true,
        );
        
        if (result != null && result.files.single.bytes != null && mounted) {
          _mostrarLoadingDialog('Subiendo documento...');
          
          final bytes = result.files.single.bytes!;
          final nombre = result.files.single.name;
          final fileName = 'chat_doc_${widget.conversacionId}_${DateTime.now().millisecondsSinceEpoch}_$nombre';
          
          await AppSupabase.client.storage
              .from('documentos')
              .uploadBinary(fileName, bytes);
          
          final urlPublica = AppSupabase.client.storage
              .from('documentos')
              .getPublicUrl(fileName);
          
          await _enviarMensajeAdjunto('documento', urlPublica, '📄 $nombre');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarLoadingDialog(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(mensaje, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarMensajeAdjunto(String tipo, String url, String texto) async {
    if (_miUsuarioId == null) return;
    
    try {
      await AppSupabase.client.from('chat_mensajes').insert({
        'conversacion_id': widget.conversacionId,
        'remitente_usuario_id': _miUsuarioId,
        'contenido_texto': texto,
        'tipo_mensaje': tipo,
        'archivo_url': url,
      });
      
      _scrollToBottom();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Enviado'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Error enviando adjunto: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarUbicacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permiso de ubicación denegado'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habilita permisos de ubicación en Configuración'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      
      _mostrarLoadingDialog('Obteniendo ubicación...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      final urlMapa = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      
      await _enviarMensajeAdjunto(
        'ubicacion', 
        urlMapa, 
        '📍 Ubicación compartida',
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirImagen(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  Future<void> _abrirMapa(double? lat, double? lon) async {
    if (lat == null || lon == null) return;
    
    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir el mapa'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarInfoConversacion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Participantes",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _participantes.length,
                  itemBuilder: (context, index) {
                    final p = _participantes[index];
                    final nombre = p['usuarios']?['nombre_completo'] ??
                        p['usuarios']?['email'] ??
                        'Usuario';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.greenAccent.withOpacity(0.2),
                        child: Text(nombre[0].toUpperCase(),
                            style: const TextStyle(color: Colors.greenAccent)),
                      ),
                      title: Text(nombre,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(p['rol_chat'] ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
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

  void _verArchivos() async {
    try {
      // Obtener mensajes con adjuntos de esta conversación
      final archivos = await AppSupabase.client
          .from('chat_mensajes')
          .select('id, tipo_mensaje, archivo_url, contenido_texto, created_at')
          .eq('conversacion_id', widget.conversacionId)
          .inFilter('tipo_mensaje', ['imagen', 'documento', 'ubicacion'])
          .order('created_at', ascending: false)
          .limit(50);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1F2C34),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text("Archivos compartidos (${archivos.length})",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Expanded(
                  child: archivos.isEmpty
                      ? const Center(
                          child: Text('No hay archivos compartidos',
                              style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: archivos.length,
                          itemBuilder: (context, index) {
                            final archivo = archivos[index];
                            final tipo = archivo['tipo_mensaje'] ?? 'documento';
                            IconData icono;
                            Color color;
                            
                            switch (tipo) {
                              case 'imagen':
                                icono = Icons.image;
                                color = Colors.purpleAccent;
                                break;
                              case 'ubicacion':
                                icono = Icons.location_on;
                                color = Colors.greenAccent;
                                break;
                              default:
                                icono = Icons.insert_drive_file;
                                color = Colors.orangeAccent;
                            }
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Icon(icono, color: color),
                              ),
                              title: Text(
                                archivo['contenido_texto'] ?? 'Archivo',
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(
                                    DateTime.parse(archivo['created_at'])),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              onTap: () async {
                                final url = archivo['archivo_url'];
                                if (url != null) {
                                  if (tipo == 'imagen') {
                                    Navigator.pop(context);
                                    _abrirImagen(url);
                                  } else {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

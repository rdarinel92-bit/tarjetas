// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// Pantalla de Chat directo entre Aval y Cobrador/Admin
/// Permite comunicación específica sobre el préstamo que garantiza
class ChatAvalCobradorScreen extends StatefulWidget {
  final String avalId;
  final String? prestamoId;
  final String nombreCobrador;
  final String? avalNombre;

  const ChatAvalCobradorScreen({
    super.key,
    required this.avalId,
    this.prestamoId,
    this.nombreCobrador = "Soporte",
    this.avalNombre,
  });

  @override
  State<ChatAvalCobradorScreen> createState() => _ChatAvalCobradorScreenState();
}

class _ChatAvalCobradorScreenState extends State<ChatAvalCobradorScreen> {
  final TextEditingController _mensajeCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  String? _conversacionId;

  @override
  void initState() {
    super.initState();
    _inicializarChat();
  }

  Future<void> _inicializarChat() async {
    try {
      final currentUserId = AppSupabase.client.auth.currentUser?.id;
      final prestamoId = widget.prestamoId;

      final aval = await AppSupabase.client
          .from('avales')
          .select('usuario_id')
          .eq('id', widget.avalId)
          .maybeSingle();
      final avalUserId = aval?['usuario_id'];

      // Buscar o crear conversación específica aval-admin
      var conversacion = await AppSupabase.client
          .from('chat_conversaciones')
          .select()
          .eq('tipo_conversacion', 'aval_soporte')
          .eq('aval_id', widget.avalId)
          .maybeSingle();

      if (prestamoId != null && conversacion == null) {
        conversacion = await AppSupabase.client
            .from('chat_conversaciones')
            .select()
            .eq('tipo_conversacion', 'aval_soporte')
            .eq('aval_id', widget.avalId)
            .eq('prestamo_id', prestamoId)
            .maybeSingle();
      }

      if (conversacion == null) {
        // Crear nueva conversación
        final nuevaConv = await AppSupabase.client
            .from('chat_conversaciones')
            .insert({
              'tipo_conversacion': 'aval_soporte',
              'aval_id': widget.avalId,
              'prestamo_id': prestamoId,
              'creado_por_usuario_id': currentUserId,
              'estado': 'activo',
            })
            .select()
            .single();
        conversacion = nuevaConv;
      }

      _conversacionId = conversacion['id'];

      if (_conversacionId != null) {
        if (currentUserId != null) {
          await _asegurarParticipante(_conversacionId!, currentUserId, 'admin');
        }
        if (avalUserId != null) {
          await _asegurarParticipante(_conversacionId!, avalUserId, 'participante');
        }
      }

      // Cargar mensajes
      await _cargarMensajes();

      // Suscribirse a nuevos mensajes (Realtime)
      _suscribirseAMensajes();

    } catch (e) {
      debugPrint("Error inicializando chat: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMensajes() async {
    if (_conversacionId == null) return;

    final mensajesRes = await AppSupabase.client
        .from('chat_mensajes')
        .select('*, usuarios(nombre_completo, foto_url)')
        .eq('conversacion_id', _conversacionId!)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() => _mensajes = List<Map<String, dynamic>>.from(mensajesRes));
      _scrollAlFinal();
    }
  }

  void _suscribirseAMensajes() {
    if (_conversacionId == null) return;

    AppSupabase.client
        .from('chat_mensajes')
        .stream(primaryKey: ['id'])
        .eq('conversacion_id', _conversacionId!)
        .listen((data) {
          if (mounted) {
            setState(() => _mensajes = List<Map<String, dynamic>>.from(data));
            _scrollAlFinal();
          }
        });
  }

  Future<void> _asegurarParticipante(
      String conversacionId, String usuarioId, String rol) async {
    final existente = await AppSupabase.client
        .from('chat_participantes')
        .select('id')
        .eq('conversacion_id', conversacionId)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (existente == null) {
      await AppSupabase.client.from('chat_participantes').insert({
        'conversacion_id': conversacionId,
        'usuario_id': usuarioId,
        'rol_chat': rol,
      });
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty || _conversacionId == null) return;

    _mensajeCtrl.clear();

    try {
      await AppSupabase.client.from('chat_mensajes').insert({
        'conversacion_id': _conversacionId,
        'remitente_usuario_id': AppSupabase.client.auth.currentUser?.id,
        'contenido_texto': texto,
        'tipo_mensaje': 'texto',
      });

      // Actualizar último mensaje en conversación
      await AppSupabase.client.from('chat_conversaciones').update({
        'ultimo_mensaje': texto,
        'fecha_ultimo_mensaje': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _conversacionId!);

    } catch (e) {
      debugPrint("Error enviando mensaje: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AppSupabase.client.auth.currentUser?.id;

    return PremiumScaffold(
      title: "Chat con ${widget.nombreCobrador}",
      actions: [
        IconButton(
          icon: const Icon(Icons.phone),
          onPressed: () => _mostrarOpcionesContacto(),
        ),
      ],
      body: Column(
        children: [
          // Información del préstamo (si aplica)
          if (widget.prestamoId != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Conversación sobre préstamo #${widget.prestamoId?.substring(0, 8)}",
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de mensajes
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _mensajes.length,
                        itemBuilder: (context, index) {
                          final mensaje = _mensajes[index];
                          final esMio = mensaje['remitente_usuario_id'] == currentUserId;
                          return _buildMensajeBurbuja(mensaje, esMio);
                        },
                      ),
          ),

          // Input de mensaje
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                // Adjuntar archivo
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.white54),
                  onPressed: () => _adjuntarArchivo(),
                ),
                // Campo de texto
                Expanded(
                  child: TextField(
                    controller: _mensajeCtrl,
                    decoration: const InputDecoration(
                      hintText: "Escribe un mensaje...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _enviarMensaje(),
                  ),
                ),
                // Botón enviar
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _enviarMensaje,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 15),
          const Text("Inicia la conversación", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 5),
          const Text("Escribe tu primer mensaje", style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMensajeBurbuja(Map<String, dynamic> mensaje, bool esMio) {
    final fecha = DateTime.tryParse(mensaje['created_at'] ?? '');
    final nombreEmisor = mensaje['usuarios']?['nombre_completo'] ?? 'Usuario';

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: esMio ? 60 : 10,
          right: esMio ? 10 : 60,
          bottom: 8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: esMio ? Colors.blueAccent : const Color(0xFF2D3748),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(esMio ? 15 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esMio)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  nombreEmisor,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              mensaje['contenido_texto'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              fecha != null ? DateFormat('HH:mm').format(fecha) : '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesContacto() {
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
            const Text("Opciones de Contacto",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.greenAccent,
                child: Icon(Icons.phone, color: Colors.black),
              ),
              title: const Text("Llamar", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Llamada telefónica directa", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _realizarLlamada();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.video_call, color: Colors.white),
              ),
              title: const Text("Videollamada", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Reunión por video", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _iniciarVideollamada();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade700,
                child: const Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Enviar mensaje por WhatsApp", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _abrirWhatsApp();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _realizarLlamada() async {
    // Obtener teléfono del admin/soporte desde configuración
    try {
      final config = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'telefono_soporte')
          .maybeSingle();
      
      String telefono = config?['valor'] ?? '+52';
      final uri = Uri.parse('tel:$telefono');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se puede realizar la llamada'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _iniciarVideollamada() async {
    // Para videollamada se puede usar un link de Meet/Zoom o similar
    // Por ahora mostramos mensaje informativo
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videollamadas disponibles a través de WhatsApp o Google Meet'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _abrirWhatsApp() async {
    try {
      final config = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'telefono_soporte')
          .maybeSingle();
      
      String telefono = config?['valor'] ?? '+52';
      // Limpiar el teléfono de caracteres especiales
      telefono = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
      
      final mensaje = Uri.encodeComponent('Hola, soy aval y necesito soporte.');
      final uri = Uri.parse('https://wa.me/$telefono?text=$mensaje');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se puede abrir WhatsApp'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _adjuntarArchivo() {
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
            const Text("Adjuntar",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAdjuntarOpcion(Icons.photo, "Imagen", Colors.purpleAccent, () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.gallery);
                }),
                _buildAdjuntarOpcion(Icons.camera_alt, "Cámara", Colors.blueAccent, () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                }),
                _buildAdjuntarOpcion(Icons.description, "Documento", Colors.orangeAccent, () {
                  Navigator.pop(context);
                  _seleccionarDocumento();
                }),
                _buildAdjuntarOpcion(Icons.location_on, "Ubicación", Colors.greenAccent, () {
                  Navigator.pop(context);
                  _enviarUbicacion();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? imagen = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (imagen != null && mounted) {
        _mostrarLoadingDialog('Subiendo imagen...');
        
        final bytes = await imagen.readAsBytes();
        final fileName = 'chat_${_conversacionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await AppSupabase.client.storage
            .from('documentos')
            .uploadBinary(fileName, bytes);
        
        final urlPublica = AppSupabase.client.storage
            .from('documentos')
            .getPublicUrl(fileName);
        
        // Enviar mensaje con la imagen
        await _enviarMensajeConAdjunto('imagen', urlPublica, 'Imagen adjunta');
        
        Navigator.pop(context); // Cerrar loading
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarDocumento() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      
      if (result != null && result.files.single.bytes != null && mounted) {
        _mostrarLoadingDialog('Subiendo documento...');
        
        final bytes = result.files.single.bytes!;
        final nombre = result.files.single.name;
        final fileName = 'chat_doc_${_conversacionId}_${DateTime.now().millisecondsSinceEpoch}_$nombre';
        
        await AppSupabase.client.storage
            .from('documentos')
            .uploadBinary(fileName, bytes);
        
        final urlPublica = AppSupabase.client.storage
            .from('documentos')
            .getPublicUrl(fileName);
        
        await _enviarMensajeConAdjunto('documento', urlPublica, 'Documento: $nombre');
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _enviarUbicacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permiso de ubicación denegado'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación bloqueados. Habilítalos en Configuración.'), backgroundColor: Colors.red),
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
      
      await _enviarMensajeConAdjunto(
        'ubicacion', 
        urlMapa, 
        '📍 Ubicación: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
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

  Future<void> _enviarMensajeConAdjunto(String tipo, String url, String texto) async {
    if (_conversacionId == null) return;
    
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await AppSupabase.client.from('chat_mensajes').insert({
        'conversacion_id': _conversacionId,
        'remitente_usuario_id': userId,
        'contenido_texto': texto,
        'tipo_mensaje': tipo,
        'archivo_url': url,
      });

      await AppSupabase.client.from('chat_conversaciones').update({
        'ultimo_mensaje': texto,
        'fecha_ultimo_mensaje': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _conversacionId!);
      
      await _cargarMensajes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Enviado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error enviando adjunto: $e');
    }
  }

  Widget _buildAdjuntarOpcion(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

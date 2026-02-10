import 'package:flutter/material.dart';
import '../../../data/models/chat_conversacion_model.dart';
import '../../../data/models/chat_mensaje_model.dart';
import '../controllers/chat_controller.dart';
import '../../clientes/controllers/usuarios_controller.dart';

class ChatDetalleOperadorView extends StatefulWidget {
  final String conversacionId;
  final String operadorUsuarioId;
  final ChatController chatController;
  final UsuariosController usuariosController;

  const ChatDetalleOperadorView({
    super.key,
    required this.conversacionId,
    required this.operadorUsuarioId,
    required this.chatController,
    required this.usuariosController,
  });

  @override
  State<ChatDetalleOperadorView> createState() => _ChatDetalleOperadorViewState();
}

class _ChatDetalleOperadorViewState extends State<ChatDetalleOperadorView> {
  bool _cargando = true;
  ChatConversacionModel? _conversacion;
  List<ChatMensajeModel> _mensajes = [];
  final TextEditingController _mensajeCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarConversacionYMensajes();
  }

  Future<void> _cargarConversacionYMensajes() async {
    final conversacion = await widget.chatController.obtenerConversacionPorId(widget.conversacionId);
    final mensajes = await widget.chatController.obtenerMensajes(widget.conversacionId);
    setState(() {
      _conversacion = conversacion;
      _mensajes = mensajes;
      _cargando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty) return;
    await widget.chatController.enviarMensajeTexto(
      conversacionId: widget.conversacionId,
      remitenteUsuarioId: widget.operadorUsuarioId,
      contenido: texto,
    );
    _mensajeCtrl.clear();
    await _cargarConversacionYMensajes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    String titulo = '';
    if (_conversacion != null) {
      if (_conversacion!.tipoConversacion == 'directo') {
        titulo = 'Chat con usuario';
      } else if (_conversacion!.tipoConversacion == 'prestamo') {
        titulo = 'Chat de préstamo';
      } else if (_conversacion!.tipoConversacion == 'tanda') {
        titulo = 'Chat de tanda';
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _mensajes.length,
                    itemBuilder: (context, index) {
                      final m = _mensajes[index];
                      final esPropio = m.remitenteUsuarioId == widget.operadorUsuarioId;
                      Alignment align = esPropio ? Alignment.centerRight : Alignment.centerLeft;
                      Color color = esPropio ? Colors.blue[100]! : Colors.grey[200]!;
                      Widget contenido;
                      if (m.tipoMensaje == 'texto') {
                        contenido = Text(m.contenidoTexto ?? '', style: const TextStyle(fontSize: 16));
                      } else if (m.tipoMensaje == 'archivo') {
                        contenido = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file, size: 18),
                            const SizedBox(width: 4),
                            Text(m.contenidoTexto ?? 'Archivo adjunto'),
                          ],
                        );
                      } else if (m.tipoMensaje == 'ubicacion') {
                        contenido = Text('Ubicación: ${m.latitud}, ${m.longitud}');
                      } else {
                        contenido = const SizedBox();
                      }
                      return Align(
                        alignment: align,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              contenido,
                              if (m.esSistema)
                                const Text('Mensaje del sistema', style: TextStyle(fontSize: 10)),
                              Text(
                                '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mensajeCtrl,
                          decoration: const InputDecoration(hintText: 'Escribe un mensaje'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _enviarMensaje,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

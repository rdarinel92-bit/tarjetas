import 'package:flutter/material.dart';
import '../../../data/models/chat_conversacion_model.dart';
import '../../../data/models/usuario_model.dart';
import '../controllers/chat_controller.dart';
import 'chat_detalle_operador_view.dart';
import '../../clientes/controllers/usuarios_controller.dart';

class ChatConversacionesListView extends StatefulWidget {
  final ChatController chatController;
  final UsuariosController usuariosController;
  final String operadorUsuarioId;

  const ChatConversacionesListView({
    super.key,
    required this.chatController,
    required this.usuariosController,
    required this.operadorUsuarioId,
  });

  @override
  State<ChatConversacionesListView> createState() => _ChatConversacionesListViewState();
}

class _ChatConversacionesListViewState extends State<ChatConversacionesListView> {
  bool _cargando = true;
  List<ChatConversacionModel> _conversaciones = [];
  Map<String, UsuarioModel> _usuarios = {};

  @override
  void initState() {
    super.initState();
    _cargarConversaciones();
  }

  Future<void> _cargarConversaciones() async {
    final conversaciones = await widget.chatController.obtenerConversacionesPorUsuario(widget.operadorUsuarioId);
    final Map<String, UsuarioModel> usuarios = {};
    for (final c in conversaciones) {
      if (c.tipoConversacion == 'directo') {
        final otroUsuarioId = c.creadoPorUsuarioId == widget.operadorUsuarioId ? c.clienteId : c.creadoPorUsuarioId;
        if (otroUsuarioId != null && !usuarios.containsKey(otroUsuarioId)) {
          final u = await widget.usuariosController.obtenerUsuario(otroUsuarioId);
          if (u != null) {
            usuarios[otroUsuarioId] = u;
          }
        }
      }
    }
    setState(() {
      _conversaciones = conversaciones;
      _usuarios = usuarios;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversaciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _conversaciones.isEmpty
              ? const Center(child: Text('Sin conversaciones.'))
              : ListView.builder(
                  itemCount: _conversaciones.length,
                  itemBuilder: (context, index) {
                    final c = _conversaciones[index];
                    String titulo = '';
                    if (c.tipoConversacion == 'directo') {
                      final otroUsuarioId = c.creadoPorUsuarioId == widget.operadorUsuarioId ? c.clienteId : c.creadoPorUsuarioId;
                      final otroUsuario = otroUsuarioId != null ? _usuarios[otroUsuarioId] : null;
                      titulo = otroUsuario?.nombre ?? 'Chat directo';
                    } else if (c.tipoConversacion == 'prestamo') {
                      titulo = 'Chat de préstamo #${c.prestamoId}';
                    } else if (c.tipoConversacion == 'tanda') {
                      titulo = 'Chat de tanda #${c.tandaId}';
                    }
                    return ListTile(
                      title: Text(titulo),
                      subtitle: Text(c.estado),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetalleOperadorView(
                              conversacionId: c.id,
                              operadorUsuarioId: widget.operadorUsuarioId,
                              chatController: widget.chatController,
                              usuariosController: widget.usuariosController,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

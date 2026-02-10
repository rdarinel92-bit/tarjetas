import 'package:flutter/foundation.dart';
import '../../data/repositories/chat_repository.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository repo;
  final String userId;

  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> mensajes = [];
  bool cargando = false;

  ChatViewModel({required this.repo, required this.userId});

  Future<void> cargarChats() async {
    cargando = true;
    notifyListeners();
    final result = await repo.obtenerChats(userId);
    chats = result.map((e) => Map<String, dynamic>.from(e)).toList();
    cargando = false;
    notifyListeners();
  }

  Future<void> cargarMensajes(String chatId) async {
    cargando = true;
    notifyListeners();
    final result = await repo.obtenerMensajes(chatId);
    mensajes = result.map((e) => Map<String, dynamic>.from(e)).toList();
    cargando = false;
    notifyListeners();
  }

  Future<void> enviarMensaje(String chatId, String contenido) async {
    await repo.enviarMensaje(chatId, userId, contenido);
    await cargarMensajes(chatId);
  }
}

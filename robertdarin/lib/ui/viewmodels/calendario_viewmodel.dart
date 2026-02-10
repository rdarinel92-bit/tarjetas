import 'package:flutter/foundation.dart';
import '../../data/repositories/calendario_repository.dart';

class CalendarioViewModel extends ChangeNotifier {
  final CalendarioRepository repo;

  List<Map<String, dynamic>> eventos = [];
  bool cargando = false;

  CalendarioViewModel({required this.repo});

  Future<void> cargarEventos() async {
    cargando = true;
    notifyListeners();
    eventos = await repo.obtenerEventos();
    cargando = false;
    notifyListeners();
  }

  Future<void> crearEvento({
    required String titulo,
    required String descripcion,
    required DateTime fecha,
    required String tipo,
    required String usuarioId,
  }) async {
    await repo.crearEvento(
      titulo: titulo,
      descripcion: descripcion,
      fecha: fecha,
      tipo: tipo,
      usuarioId: usuarioId,
    );
    await cargarEventos();
  }
}

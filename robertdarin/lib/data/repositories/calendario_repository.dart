import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarioRepository {
  final SupabaseClient supabase;

  CalendarioRepository(this.supabase);

  Future<List<Map<String, dynamic>>> obtenerEventos() async {
    final res = await supabase
        .from('calendario')
        .select()
        .order('fecha');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> crearEvento({
    required String titulo,
    required String descripcion,
    required DateTime fecha,
    required String tipo,
    required String usuarioId,
  }) async {
    await supabase.from('calendario').insert({
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha': fecha.toIso8601String(),
      'tipo': tipo,
      'usuario_id': usuarioId,
    });
  }
}

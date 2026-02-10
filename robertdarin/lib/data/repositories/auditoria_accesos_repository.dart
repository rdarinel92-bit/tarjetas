import '../models/auditoria_acceso_model.dart';
import '../services/api_service.dart';

class AuditoriaAccesosRepository {
  final client = ApiService.client;

  Future<bool> registrarAcceso(AuditoriaAccesoModel registro) async {
    final response = await client.from('auditoria_accesos').insert(registro.toMap());
    return response != null;
  }

  Future<List<AuditoriaAccesoModel>> obtenerAuditoria() async {
    final response = await client.from('auditoria_accesos').select().order('created_at', ascending: false);
    return (response as List).map((e) => AuditoriaAccesoModel.fromMap(e)).toList();
  }

  Future<List<AuditoriaAccesoModel>> obtenerAuditoriaPorUsuario(String usuarioId) async {
    final response = await client.from('auditoria_accesos').select().eq('usuario_id', usuarioId).order('created_at', ascending: false);
    return (response as List).map((e) => AuditoriaAccesoModel.fromMap(e)).toList();
  }
}

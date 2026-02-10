import '../models/auditoria_legal_model.dart';

class AuditoriaLegalRepository {
  Future<List<AuditoriaLegalModel>> obtenerAuditorias() async => [];
  Future<bool> crearAuditoria(AuditoriaLegalModel auditoria) async => true;

  Future<void> registrarAuditoria(AuditoriaLegalModel auditoria) async {
    // TODO: Implement actual persistence logic
    await Future.delayed(Duration(milliseconds: 100));
  }
}

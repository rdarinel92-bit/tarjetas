import 'package:flutter/material.dart';
import '../../../data/repositories/auditoria_accesos_repository.dart';
import '../../../data/models/auditoria_acceso_model.dart';

class AuditoriaAccesosView extends StatefulWidget {
  final AuditoriaAccesosRepository repository;
  const AuditoriaAccesosView({super.key, required this.repository});

  @override
  State<AuditoriaAccesosView> createState() => _AuditoriaAccesosViewState();
}

class _AuditoriaAccesosViewState extends State<AuditoriaAccesosView> {
  List<AuditoriaAccesoModel> _registros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    final registros = await widget.repository.obtenerAuditoria();
    setState(() {
      _registros = registros;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría de Accesos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _registros.length,
              itemBuilder: (context, index) {
                final r = _registros[index];
                return ListTile(
                  title: Text('Usuario: ${r.usuarioId}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rol: ${r.rolId}'),
                      Text('Acción: ${r.accion}'),
                      Text('Entidad: ${r.entidad}'),
                      Text('EntidadId: ${r.entidadId}'),
                      Text('Fecha: ${r.createdAt.toIso8601String()}'),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

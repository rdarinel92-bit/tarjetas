import 'package:flutter/material.dart';
import '../controllers/roles_permisos_controller.dart';
import '../../../data/models/rol_model.dart';
import '../../../data/models/rol_permiso_model.dart';

class RolDetalleView extends StatefulWidget {
  final String rolId;
  final RolesPermisosController controller;
  const RolDetalleView({super.key, required this.rolId, required this.controller});

  @override
  State<RolDetalleView> createState() => _RolDetalleViewState();
}

class _RolDetalleViewState extends State<RolDetalleView> {
  RolModel? _rol;
  List<RolPermisoModel> _permisosAsignados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final roles = await widget.controller.obtenerRoles();
    final rol = roles.firstWhere((r) => r.id == widget.rolId);
    final permisosAsignados = await widget.controller.obtenerPermisosPorRol(widget.rolId);
    setState(() {
      _rol = rol;
      _permisosAsignados = permisosAsignados;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rol')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_rol != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nombre: ${_rol!.nombre}', style: const TextStyle(fontSize: 18)),
                        Text('Descripción: ${_rol!.descripcion}'),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Permisos asignados:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _permisosAsignados.length,
                      itemBuilder: (context, index) {
                        final rp = _permisosAsignados[index];
                        return ListTile(
                          title: Text(rp.permisoId),
                          trailing: TextButton(
                            onPressed: () {},
                            child: const Text('Quitar'),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Agregar permiso'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

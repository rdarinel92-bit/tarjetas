import 'package:flutter/material.dart';
import '../controllers/roles_permisos_controller.dart';
import '../../../data/models/permiso_model.dart';

class PermisosListView extends StatefulWidget {
  final RolesPermisosController controller;
  const PermisosListView({super.key, required this.controller});

  @override
  State<PermisosListView> createState() => _PermisosListViewState();
}

class _PermisosListViewState extends State<PermisosListView> {
  List<PermisoModel> _permisos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
    final permisos = await widget.controller.obtenerPermisos();
    setState(() {
      _permisos = permisos;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permisos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _permisos.length,
              itemBuilder: (context, index) {
                final p = _permisos[index];
                return ListTile(
                  title: Text(p.clavePermiso),
                  subtitle: Text(p.descripcion),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Editar'),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

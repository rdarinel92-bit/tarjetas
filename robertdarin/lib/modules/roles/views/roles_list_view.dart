import 'package:flutter/material.dart';
import '../controllers/roles_permisos_controller.dart';
import '../../../data/models/rol_model.dart';

class RolesListView extends StatefulWidget {
  final RolesPermisosController controller;
  const RolesListView({super.key, required this.controller});

  @override
  State<RolesListView> createState() => _RolesListViewState();
}

class _RolesListViewState extends State<RolesListView> {
  List<RolModel> _roles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    final roles = await widget.controller.obtenerRoles();
    setState(() {
      _roles = roles;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final r = _roles[index];
                return ListTile(
                  title: Text(r.nombre),
                  subtitle: Text(r.descripcion),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Permisos'),
                      ),
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

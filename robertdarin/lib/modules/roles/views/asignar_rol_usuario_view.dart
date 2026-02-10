import 'package:flutter/material.dart';
import '../controllers/roles_permisos_controller.dart';
import '../../../data/models/usuario_rol_model.dart';
import '../../../data/models/rol_model.dart';

class AsignarRolUsuarioView extends StatefulWidget {
  final String usuarioId;
  final RolesPermisosController controller;
  const AsignarRolUsuarioView({super.key, required this.usuarioId, required this.controller});

  @override
  State<AsignarRolUsuarioView> createState() => _AsignarRolUsuarioViewState();
}

class _AsignarRolUsuarioViewState extends State<AsignarRolUsuarioView> {
  UsuarioRolModel? _usuarioRol;
  List<RolModel> _roles = [];
  String? _rolSeleccionado;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final usuarioRol = await widget.controller.obtenerRolDeUsuario(widget.usuarioId);
    final roles = await widget.controller.obtenerRoles();
    setState(() {
      _usuarioRol = usuarioRol;
      _roles = roles;
      _rolSeleccionado = usuarioRol?.rolId;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Rol')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rol actual:', style: TextStyle(fontSize: 16)),
                  if (_usuarioRol != null)
                    Text(_usuarioRol!.rolId, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  const Text('Selecciona nuevo rol:', style: TextStyle(fontSize: 16)),
                  DropdownButton<String>(
                    value: _rolSeleccionado,
                    items: _roles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(r.nombre),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _rolSeleccionado = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
    );
  }
}

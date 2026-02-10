
import 'package:flutter/material.dart';
import '../../../../data/models/aval_model.dart';
import '../../../clientes/controllers/usuarios_controller.dart';
import '../controllers/avales_controller.dart';

class NuevoAvalView extends StatefulWidget {
  final AvalesController controller;
  final UsuariosController usuariosController;

  const NuevoAvalView({
    super.key,
    required this.controller,
    required this.usuariosController,
  });

  @override
  State<NuevoAvalView> createState() => _NuevoAvalViewState();
}

class _NuevoAvalViewState extends State<NuevoAvalView> {
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();
  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController relacionCtrl = TextEditingController();

  String? clienteSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Aval')),
      body: FutureBuilder(
        // Usar obtenerUsuariosClientes para excluir superadmin/admin
        future: widget.usuariosController.obtenerUsuariosClientes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clientes = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField(
                  value: clienteSeleccionado,
                  items: clientes.map((u) {
                    return DropdownMenuItem(
                      value: u.id,
                      child: Text(u.nombre),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      clienteSeleccionado = v;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
                TextField(controller: direccionCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
                TextField(controller: relacionCtrl, decoration: const InputDecoration(labelText: 'Relación')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final aval = AvalModel(
                      id: '',
                      nombre: nombreCtrl.text,
                      email: '',
                      telefono: telefonoCtrl.text,
                      direccion: direccionCtrl.text,
                      relacion: relacionCtrl.text,
                      clienteId: clienteSeleccionado ?? '',
                    );

                    await widget.controller.crearAval(aval);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

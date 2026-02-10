import 'package:flutter/material.dart';
import '../controllers/usuarios_controller.dart';

class UsuariosView extends StatelessWidget {
  final UsuariosController controller;

  const UsuariosView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder(
        future: controller.obtenerUsuarios(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data!;

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final u = usuarios[index];
              return ListTile(
                title: Text(u.nombre),
                subtitle: Text(u.telefono ?? 'Sin teléfono'),
              );
            },
          );
        },
      ),
    );
  }
}

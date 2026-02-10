import 'package:flutter/material.dart';
import '../../../../data/models/usuario_model.dart';

class UsuarioCard extends StatelessWidget {
  final UsuarioModel usuario;

  const UsuarioCard({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(usuario.nombre),
        subtitle: Text(usuario.telefono ?? 'Sin teléfono'),
      ),
    );
  }
}

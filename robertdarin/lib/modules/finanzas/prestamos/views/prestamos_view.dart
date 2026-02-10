import 'package:flutter/material.dart';
import '../controllers/prestamos_controller.dart';

class PrestamosView extends StatelessWidget {
  final PrestamosController controller;

  const PrestamosView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préstamos')),
      body: FutureBuilder(
        future: controller.obtenerPrestamos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final prestamos = snapshot.data!;

          return ListView.builder(
            itemCount: prestamos.length,
            itemBuilder: (context, index) {
              final p = prestamos[index];
              return ListTile(
                title: Text('Monto: \$${p.monto}'),
                subtitle: Text('Cliente: ${p.clienteId}'),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../controllers/tandas_controller.dart';

class TandasView extends StatelessWidget {
  final TandasController controller;

  const TandasView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tandas')),
      body: FutureBuilder(
        future: controller.obtenerTandas(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tandas = snapshot.data!;

          return ListView.builder(
            itemCount: tandas.length,
            itemBuilder: (context, index) {
              final t = tandas[index];
              return ListTile(
                title: Text(t.nombre),
                subtitle: Text('Monto por persona: \$${t.montoPorPersona}'),
              );
            },
          );
        },
      ),
    );
  }
}

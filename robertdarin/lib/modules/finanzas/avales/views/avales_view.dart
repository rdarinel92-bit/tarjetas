import 'package:flutter/material.dart';
import '../controllers/avales_controller.dart';

class AvalesView extends StatelessWidget {
  final AvalesController controller;

  const AvalesView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avales')),
      body: FutureBuilder(
        future: controller.obtenerAvales(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final avales = snapshot.data!;

          return ListView.builder(
            itemCount: avales.length,
            itemBuilder: (context, index) {
              final a = avales[index];
              return ListTile(
                title: Text(a.nombre),
                subtitle: Text(a.telefono),
              );
            },
          );
        },
      ),
    );
  }
}

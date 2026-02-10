import 'package:flutter/material.dart';
import '../../../data/models/usuario_model.dart';
import '../../../data/models/prestamo_model.dart';
import '../../../data/models/aval_model.dart';
import '../../finanzas/prestamos/views/nuevo_prestamo_view.dart';
import '../../finanzas/avales/views/nuevo_aval_view.dart';
import '../../finanzas/prestamos/controllers/prestamos_controller.dart';
import '../../finanzas/avales/controllers/avales_controller.dart';
import '../controllers/usuarios_controller.dart';

class DetalleUsuarioView extends StatelessWidget {
  final UsuarioModel usuario;
  final UsuariosController usuariosController;
  final PrestamosController prestamosController;
  final AvalesController avalesController;

  const DetalleUsuarioView({
    super.key,
    required this.usuario,
    required this.usuariosController,
    required this.prestamosController,
    required this.avalesController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(usuario.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(usuario.telefono ?? 'Sin teléfono'),
            Text(usuario.email),
            const SizedBox(height: 20),

            const Text('Préstamos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FutureBuilder(
              future: prestamosController.obtenerPrestamos(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final prestamos = (snapshot.data as List<PrestamoModel>)
                    .where((p) => p.clienteId == usuario.id)
                    .toList();

                if (prestamos.isEmpty) {
                  return const Text('Sin préstamos');
                }

                return Column(
                  children: prestamos.map((p) {
                    return ListTile(
                      title: Text('Monto: \$${p.monto}'),
                      subtitle: Text('Interés: ${p.interes}%'),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NuevoPrestamoView(
                      controller: prestamosController,
                      usuariosController: usuariosController,
                      avalesController: avalesController,
                    ),
                  ),
                );
              },
              child: const Text('Crear Préstamo'),
            ),

            const SizedBox(height: 30),
            const Text('Avales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FutureBuilder(
              future: avalesController.obtenerAvales(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final avales = (snapshot.data as List<AvalModel>)
                    .where((a) => a.clienteId == usuario.id)
                    .toList();

                if (avales.isEmpty) {
                  return const Text('Sin avales');
                }

                return Column(
                  children: avales.map((a) {
                    return ListTile(
                      title: Text(a.nombre),
                      subtitle: Text(a.telefono),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NuevoAvalView(
                      controller: avalesController,
                      usuariosController: usuariosController,
                    ),
                  ),
                );
              },
              child: const Text('Crear Aval'),
            ),
          ],
        ),
      ),
    );
  }
}

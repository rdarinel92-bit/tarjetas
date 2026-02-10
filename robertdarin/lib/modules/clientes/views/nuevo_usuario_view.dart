import 'package:flutter/material.dart';
import '../../../../data/models/usuario_model.dart';
import '../controllers/usuarios_controller.dart';

class NuevoUsuarioView extends StatefulWidget {
  final UsuariosController controller;

  const NuevoUsuarioView({super.key, required this.controller});

  @override
  State<NuevoUsuarioView> createState() => _NuevoUsuarioViewState();
}

class _NuevoUsuarioViewState extends State<NuevoUsuarioView> {
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();
  
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Nuevo Usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre Completo')),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo Electrónico')),
            const SizedBox(height: 10),
            TextField(
              controller: passwordCtrl, 
              decoration: const InputDecoration(
                labelText: 'Contraseña Temporal',
                helperText: 'El usuario deberá cambiarla al iniciar sesión'
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 30),
            if (_cargando)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                  onPressed: _crearUsuarioYAcceso,
                  child: const Text('Crear Usuario y Acceso'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearUsuarioYAcceso() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email y Contraseña son obligatorios")),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear el usuario en la base de datos (usando tu controlador existente)
      final nuevoUsuario = UsuarioModel(
        email: emailCtrl.text.trim(),
        nombreCompleto: nombreCtrl.text.trim(),
        telefono: telefonoCtrl.text.trim(),
      );

      // Nota: Aquí se asume que el backend o un trigger maneja la creación en Auth
      // o que el controller se encargará de la lógica extendida.
      final exito = await widget.controller.crearUsuario(nuevoUsuario);

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario creado con éxito. Se le notificará por email.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}

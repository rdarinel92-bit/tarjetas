import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../modules/clientes/controllers/usuarios_controller.dart';
import '../../data/models/usuario_model.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  @override
  Widget build(BuildContext context) {
    final usuariosCtrl = Provider.of<UsuariosController>(context);

    return PremiumScaffold(
      title: "Gestión de Usuarios",
      body: Column(
        children: [
          PremiumButton(
            text: "Crear Nuevo Acceso",
            icon: Icons.person_add,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.formularioCliente),
          ),
          const SizedBox(height: 10),
          PremiumButton(
            text: "Configurar Roles y Permisos",
            icon: Icons.admin_panel_settings,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.roles),
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: FutureBuilder<List<UsuarioModel>>(
              future: usuariosCtrl.obtenerUsuarios(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final usuarios = snapshot.data ?? [];
                
                if (usuarios.isEmpty) {
                  return const Center(
                    child: Text("No hay usuarios registrados", style: TextStyle(color: Colors.white70)),
                  );
                }

                return ListView.builder(
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = usuarios[index];
                    return _buildUsuarioItem(usuario);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuarioItem(UsuarioModel usuario) {
    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
          child: Text(usuario.nombreCompleto?[0].toUpperCase() ?? "U", 
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
        title: Text(usuario.nombreCompleto ?? "Usuario Nuevo", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(usuario.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
        onTap: () {
          // Lógica para editar usuario
        },
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';

class RolesPermisosScreen extends StatefulWidget {
  const RolesPermisosScreen({super.key});

  @override
  State<RolesPermisosScreen> createState() => _RolesPermisosScreenState();
}

class _RolesPermisosScreenState extends State<RolesPermisosScreen> {
  List<dynamic> _roles = [];
  List<dynamic> _permisos = [];
  Map<String, List<String>> _permisosAsignados = {}; // rolId -> [permisoIds]
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _cargarDatos();
  }

  void _checkAccess() async {
    final role = await Provider.of<AuthViewModel>(context, listen: false).obtenerRol();
    if (role != 'superadmin' && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final rolesRes = await AppSupabase.client.from('roles').select();
      final permisosRes = await AppSupabase.client.from('permisos').select();
      final rolesPermisosRes = await AppSupabase.client.from('roles_permisos').select();
      
      // Construir mapa de permisos por rol
      Map<String, List<String>> asignados = {};
      for (var rp in rolesPermisosRes) {
        final rolId = rp['rol_id'].toString();
        final permisoId = rp['permiso_id'].toString();
        if (!asignados.containsKey(rolId)) asignados[rolId] = [];
        asignados[rolId]!.add(permisoId);
      }

      setState(() {
        _roles = rolesRes;
        _permisos = permisosRes;
        _permisosAsignados = asignados;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Roles y Permisos",
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      text: "Nuevo Rol",
                      icon: Icons.add_moderator,
                      onPressed: () => _mostrarDialogoNuevoRol(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PremiumButton(
                      text: "Nuevo Permiso",
                      icon: Icons.security,
                      onPressed: () => _mostrarDialogoNuevoPermiso(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              
              // SECCIÓN ROLES
              _buildSeccionRoles(),
              
              const SizedBox(height: 25),
              
              // SECCIÓN PERMISOS DISPONIBLES
              _buildSeccionPermisos(),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionRoles() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Roles del Sistema",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${_roles.length} roles", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Tap en ⚙️ para configurar permisos de cada rol",
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const Divider(color: Colors.white10, height: 20),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_roles.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No hay roles", style: TextStyle(color: Colors.white38))))
          else
            ..._roles.map((rol) => _buildRoleItem(rol)),
        ],
      ),
    );
  }

  Widget _buildRoleItem(dynamic rol) {
    final rolId = rol['id'].toString();
    final nombre = rol['nombre'].toString();
    final descripcion = rol['descripcion'] ?? 'Sin descripción';
    final cantPermisos = _permisosAsignados[rolId]?.length ?? 0;
    
    Color roleColor;
    IconData roleIcon;
    
    switch (nombre.toLowerCase()) {
      case 'superadmin':
        roleColor = Colors.redAccent;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'admin':
        roleColor = Colors.orangeAccent;
        roleIcon = Icons.manage_accounts;
        break;
      case 'operador':
        roleColor = Colors.blueAccent;
        roleIcon = Icons.person;
        break;
      case 'cliente':
        roleColor = Colors.greenAccent;
        roleIcon = Icons.person_outline;
        break;
      default:
        roleColor = Colors.grey;
        roleIcon = Icons.badge;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.2),
          child: Icon(roleIcon, color: roleColor, size: 20),
        ),
        title: Text(nombre.toUpperCase(), 
          style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text("$cantPermisos permisos asignados", 
              style: TextStyle(color: cantPermisos > 0 ? Colors.greenAccent : Colors.white38, fontSize: 10)),
          ],
        ),
        trailing: nombre.toLowerCase() != 'superadmin' 
          ? IconButton(
              icon: const Icon(Icons.settings, color: Colors.blueAccent, size: 22),
              onPressed: () => _abrirEditorPermisos(rol),
            )
          : const Icon(Icons.lock, color: Colors.white24, size: 18),
      ),
    );
  }

  Widget _buildSeccionPermisos() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Permisos Disponibles",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${_permisos.length} permisos", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Estos permisos pueden asignarse a los roles",
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const Divider(color: Colors.white10, height: 20),
          
          if (_permisos.isEmpty)
            const Text("No hay permisos registrados", style: TextStyle(color: Colors.white38))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _permisos.map((p) => Chip(
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                label: Text(p['clave_permiso'] ?? p['nombre'] ?? 'Sin nombre', 
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _eliminarPermiso(p['id']),
              )).toList(),
            ),
        ],
      ),
    );
  }

  void _abrirEditorPermisos(dynamic rol) {
    final rolId = rol['id'].toString();
    final rolNombre = rol['nombre'].toString().toUpperCase();
    final permisosDelRol = _permisosAsignados[rolId] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Permisos de $rolNombre", 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _permisos.length,
                          itemBuilder: (context, index) {
                            final permiso = _permisos[index];
                            final permisoId = permiso['id'].toString();
                            final tienePermiso = permisosDelRol.contains(permisoId);
                            
                            return CheckboxListTile(
                              value: tienePermiso,
                              activeColor: Colors.greenAccent,
                              title: Text(permiso['clave_permiso'] ?? 'Permiso', 
                                style: const TextStyle(color: Colors.white)),
                              subtitle: Text(permiso['descripcion'] ?? '', 
                                style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              onChanged: (value) async {
                                if (value == true) {
                                  await _asignarPermiso(rolId, permisoId);
                                } else {
                                  await _quitarPermiso(rolId, permisoId);
                                }
                                setModalState(() {
                                  if (value == true) {
                                    permisosDelRol.add(permisoId);
                                  } else {
                                    permisosDelRol.remove(permisoId);
                                  }
                                });
                                _cargarDatos(); // Refrescar estado principal
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _asignarPermiso(String rolId, String permisoId) async {
    try {
      await AppSupabase.client.from('roles_permisos').insert({
        'rol_id': rolId,
        'permiso_id': permisoId,
      });
    } catch (e) {
      debugPrint("Error asignando permiso: $e");
    }
  }

  Future<void> _quitarPermiso(String rolId, String permisoId) async {
    try {
      await AppSupabase.client
          .from('roles_permisos')
          .delete()
          .eq('rol_id', rolId)
          .eq('permiso_id', permisoId);
    } catch (e) {
      debugPrint("Error quitando permiso: $e");
    }
  }

  Future<void> _eliminarPermiso(String permisoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("¿Eliminar permiso?"),
        content: const Text("Se quitará de todos los roles que lo tengan asignado."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppSupabase.client.from('permisos').delete().eq('id', permisoId);
        _cargarDatos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _mostrarDialogoNuevoRol() {
    final nombreCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Crear Nuevo Rol"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: "Nombre del Rol", hintText: "Ej: supervisor"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isNotEmpty) {
                try {
                  await AppSupabase.client.from('roles').insert({
                    'nombre': nombreCtrl.text.toLowerCase().trim(),
                    'descripcion': descripcionCtrl.text.trim(),
                  });
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Rol creado"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevoPermiso() {
    final claveCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Crear Nuevo Permiso"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: claveCtrl,
              decoration: const InputDecoration(labelText: "Clave del Permiso", hintText: "Ej: gestionar_inventario"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (claveCtrl.text.isNotEmpty) {
                try {
                  await AppSupabase.client.from('permisos').insert({
                    'clave_permiso': claveCtrl.text.toLowerCase().trim().replaceAll(' ', '_'),
                    'descripcion': descripcionCtrl.text.trim(),
                  });
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Permiso creado"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }
}

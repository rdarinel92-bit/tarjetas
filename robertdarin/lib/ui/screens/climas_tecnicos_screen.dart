// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/auth_creacion_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE TÉCNICOS CLIMAS - Robert Darin Platform v10.22
/// CRUD completo: Crear, listar, editar, activar/desactivar técnicos
/// NUEVO: Crear cuenta de acceso para que técnicos entren a la app
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasTecnicosScreen extends StatefulWidget {
  const ClimasTecnicosScreen({super.key});

  @override
  State<ClimasTecnicosScreen> createState() => _ClimasTecnicosScreenState();
}

class _ClimasTecnicosScreenState extends State<ClimasTecnicosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tecnicos = [];
  bool _mostrarInactivos = false;

  @override
  void initState() {
    super.initState();
    _cargarTecnicos();
  }

  Future<void> _cargarTecnicos() async {
    try {
      var query = AppSupabase.client.from('climas_tecnicos').select();
      if (!_mostrarInactivos) query = query.eq('activo', true);
      final res = await query.order('nombre');
      if (mounted) setState(() { _tecnicos = List<Map<String, dynamic>>.from(res); _isLoading = false; });
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '👷 Técnicos Climas',
      actions: [
        IconButton(
          icon: Icon(_mostrarInactivos ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: () { setState(() => _mostrarInactivos = !_mostrarInactivos); _cargarTecnicos(); },
          tooltip: _mostrarInactivos ? 'Ocultar inactivos' : 'Mostrar inactivos',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLista(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nuevo Técnico', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLista() {
    if (_tecnicos.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.engineering, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sin técnicos registrados', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTecnicos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tecnicos.length,
        itemBuilder: (context, index) => _buildTecnicoCard(_tecnicos[index]),
      ),
    );
  }

  Widget _buildTecnicoCard(Map<String, dynamic> tecnico) {
    final activo = tecnico['activo'] ?? true;
    final especialidad = tecnico['especialidad'] ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activo ? const Color(0xFF00D9FF).withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: activo ? const Color(0xFF00D9FF).withOpacity(0.2) : Colors.red.withOpacity(0.2),
          child: Icon(Icons.engineering, color: activo ? const Color(0xFF00D9FF) : Colors.red),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(tecnico['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (!activo) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('INACTIVO', style: TextStyle(color: Colors.red, fontSize: 10)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📱 ${tecnico['telefono'] ?? 'Sin teléfono'}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
            Text('🔧 $especialidad', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF0D0D14),
          onSelected: (v) => _handleAccion(v, tecnico),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'editar', child: Text('✏️ Editar', style: TextStyle(color: Colors.white))),
            PopupMenuItem(
              value: 'toggle',
              child: Text(activo ? '🚫 Desactivar' : '✅ Activar', style: const TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(value: 'ver_ordenes', child: Text('📋 Ver Órdenes', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _handleAccion(String accion, Map<String, dynamic> tecnico) async {
    switch (accion) {
      case 'editar':
        _mostrarFormulario(tecnico: tecnico);
        break;
      case 'toggle':
        await AppSupabase.client.from('climas_tecnicos').update({'activo': !(tecnico['activo'] ?? true)}).eq('id', tecnico['id']);
        _cargarTecnicos();
        break;
      case 'ver_ordenes':
        // Navegar a órdenes filtradas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ver órdenes de ${tecnico['nombre']}'), backgroundColor: Colors.blue),
        );
        break;
    }
  }

  void _mostrarFormulario({Map<String, dynamic>? tecnico}) {
    final esEdicion = tecnico != null;
    final nombreCtrl = TextEditingController(text: tecnico?['nombre'] ?? '');
    final telefonoCtrl = TextEditingController(text: tecnico?['telefono'] ?? '');
    final especialidadCtrl = TextEditingController(text: tecnico?['especialidad'] ?? '');
    final notasCtrl = TextEditingController(text: tecnico?['notas'] ?? '');
    
    // V10.22: Campos para crear cuenta de acceso
    final emailCtrl = TextEditingController(text: tecnico?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    bool crearCuenta = false;
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(esEdicion ? 'Editar Técnico' : 'Nuevo Técnico', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                TextField(
                  controller: nombreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Nombre completo'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Teléfono'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: especialidadCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Especialidad (ej: Minisplit, Industrial)'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notasCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Notas adicionales'),
                ),
                
                // V10.22: Sección de acceso a la app (solo para nuevos)
                if (!esEdicion) ...[
                  CamposAuthWidget(
                    emailController: emailCtrl,
                    passwordController: passwordCtrl,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setModalState(() => crearCuenta = v),
                    tipoUsuario: 'tecnico_climas',
                  ),
                ],
                
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: guardando ? null : () async {
                    if (nombreCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre'), backgroundColor: Colors.orange));
                      return;
                    }

                    // Validar email si se va a crear cuenta
                    if (crearCuenta && !esEdicion) {
                      if (emailCtrl.text.trim().isEmpty || !emailCtrl.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un email válido'), backgroundColor: Colors.orange));
                        return;
                      }
                      if (passwordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange));
                        return;
                      }
                    }

                    setModalState(() => guardando = true);

                    String? authUid;
                    
                    // Crear cuenta de auth si se solicitó
                    if (crearCuenta && !esEdicion) {
                      authUid = await AuthCreacionService.crearCuentaAuth(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        nombreCompleto: nombreCtrl.text.trim(),
                        tipoUsuario: 'tecnico_climas',
                        // Rol específico para técnicos → ve dashboardTecnicoClimas
                      );
                      
                      if (authUid == null) {
                        setModalState(() => guardando = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al crear cuenta. El email puede estar en uso.'), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }
                    }

                    final data = {
                      'nombre': nombreCtrl.text.trim(),
                      'telefono': telefonoCtrl.text.trim(),
                      'especialidad': especialidadCtrl.text.trim(),
                      'notas': notasCtrl.text.trim(),
                      'activo': true,
                      if (crearCuenta && authUid != null) 'auth_uid': authUid,
                      if (crearCuenta) 'email': emailCtrl.text.trim(),
                    };

                    if (esEdicion) {
                      await AppSupabase.client.from('climas_tecnicos').update(data).eq('id', tecnico['id']);
                    } else {
                      await AppSupabase.client.from('climas_tecnicos').insert(data);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _cargarTecnicos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(esEdicion 
                            ? '✅ Técnico actualizado' 
                            : crearCuenta 
                              ? '✅ Técnico creado con acceso a la app'
                              : '✅ Técnico creado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF), minimumSize: const Size(double.infinity, 50)),
                  child: guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(esEdicion ? 'Guardar Cambios' : 'Crear Técnico', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF0D0D14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

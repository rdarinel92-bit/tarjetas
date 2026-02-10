import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';

class EmpleadosUniversalScreen extends StatefulWidget {
  const EmpleadosUniversalScreen({super.key});

  @override
  State<EmpleadosUniversalScreen> createState() => _EmpleadosUniversalScreenState();
}

class _EmpleadosUniversalScreenState extends State<EmpleadosUniversalScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> _negocios = [];
  List<Map<String, dynamic>> _asignaciones = [];

  String? _empleadoSeleccionadoId;
  String? _negocioSeleccionadoId;
  String _rolModulo = 'operador';
  bool _esAdministrador = false;
  final Set<String> _modulosSeleccionados = {};

  static const List<String> _rolesDisponibles = [
    'operador',
    'admin',
    'tecnico',
    'repartidor',
    'vendedor',
    'cobrador',
  ];

  static const List<String> _modulosDisponibles = [
    'prestamos',
    'tandas',
    'cobranza',
    'climas',
    'purificadora',
    'ventas',
    'nice',
    'servicios',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final empleadosRes = await AppSupabase.client
          .from('empleados')
          .select('id, puesto, estado, usuarios(nombre_completo, email)')
          .order('created_at', ascending: false);
      final negociosRes = await AppSupabase.client
          .from('negocios')
          .select('id, nombre, tipo')
          .order('nombre');
      final asignacionesRes = await AppSupabase.client
          .from('empleados_negocios')
          .select('id, empleado_id, negocio_id, rol_modulo, modulos_acceso, activo, negocios(nombre), empleados(puesto, usuarios(nombre_completo, email))')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _empleados = List<Map<String, dynamic>>.from(empleadosRes);
        _negocios = List<Map<String, dynamic>>.from(negociosRes);
        _asignaciones = List<Map<String, dynamic>>.from(asignacionesRes);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando empleados universales: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarAsignacion() async {
    if (_empleadoSeleccionadoId == null || _negocioSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona empleado y negocio.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await AppSupabase.client.from('empleados_negocios').upsert({
        'empleado_id': _empleadoSeleccionadoId,
        'negocio_id': _negocioSeleccionadoId,
        'rol_modulo': _rolModulo,
        'modulos_acceso': _modulosSeleccionados.toList(),
        'es_administrador': _esAdministrador,
        'activo': true,
      }, onConflict: 'empleado_id,negocio_id');

      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asignacion guardada.')),
        );
      }
    } catch (e) {
      debugPrint('Error guardando asignacion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la asignacion.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Mis empleados',
      subtitle: 'Recursos humanos universal',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildAsignacionCard(),
                  const SizedBox(height: 20),
                  _buildAsignacionesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.orangeAccent, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro de Empleados',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Crea empleados y asignalos a negocios y modulos.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PremiumButton(
                text: 'Crear empleado',
                icon: Icons.person_add,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.formularioEmpleado),
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumButton(
                text: 'Lista empleados',
                icon: Icons.badge,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.empleados),
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumButton(
          text: 'Recursos humanos',
          icon: Icons.groups,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.recursosHumanos),
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildAsignacionCard() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asignar empleado',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vincula empleados a negocios y define modulos de acceso.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _empleadoSeleccionadoId,
            items: _empleados.map((e) {
              final usuario = e['usuarios'] as Map<String, dynamic>?;
              final nombre = (usuario?['nombre_completo'] ?? e['puesto'] ?? 'Empleado').toString();
              final email = (usuario?['email'] ?? '').toString();
              return DropdownMenuItem(
                value: e['id'].toString(),
                child: Text(email.isEmpty ? nombre : '$nombre - $email'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _empleadoSeleccionadoId = v),
            decoration: const InputDecoration(
              labelText: 'Empleado',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _negocioSeleccionadoId,
            items: _negocios.map((n) {
              final nombre = (n['nombre'] ?? 'Negocio').toString();
              return DropdownMenuItem(
                value: n['id'].toString(),
                child: Text(nombre),
              );
            }).toList(),
            onChanged: (v) => setState(() => _negocioSeleccionadoId = v),
            decoration: const InputDecoration(
              labelText: 'Negocio',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _rolModulo,
            items: _rolesDisponibles
                .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _rolModulo = v ?? 'operador'),
            decoration: const InputDecoration(
              labelText: 'Rol del modulo',
              prefixIcon: Icon(Icons.assignment_ind),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Modulos de acceso', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modulosDisponibles.map((m) {
              final selected = _modulosSeleccionados.contains(m);
              return FilterChip(
                selected: selected,
                label: Text(m.toUpperCase()),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _modulosSeleccionados.add(m);
                    } else {
                      _modulosSeleccionados.remove(m);
                    }
                  });
                },
                selectedColor: Colors.orangeAccent.withOpacity(0.2),
                checkmarkColor: Colors.orangeAccent,
                labelStyle: TextStyle(
                  color: selected ? Colors.orangeAccent : Colors.white70,
                  fontSize: 11,
                ),
                side: BorderSide(color: Colors.white12),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Administrador del negocio', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Puede administrar este negocio', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _esAdministrador,
            onChanged: (v) => setState(() => _esAdministrador = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardarAsignacion,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar asignacion'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsignacionesList() {
    final asignacionesFiltradas = _empleadoSeleccionadoId == null
        ? _asignaciones
        : _asignaciones.where((a) => a['empleado_id'] == _empleadoSeleccionadoId).toList();

    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asignaciones activas',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (asignacionesFiltradas.isEmpty)
            const Text(
              'Sin asignaciones registradas.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          else
            ...asignacionesFiltradas.take(8).map(_buildAsignacionTile),
        ],
      ),
    );
  }

  Widget _buildAsignacionTile(Map<String, dynamic> asignacion) {
    final empleado = asignacion['empleados'] as Map<String, dynamic>?;
    final usuario = empleado?['usuarios'] as Map<String, dynamic>?;
    final nombre = (usuario?['nombre_completo'] ?? 'Empleado').toString();
    final negocio = asignacion['negocios'] as Map<String, dynamic>?;
    final negocioNombre = (negocio?['nombre'] ?? 'Negocio').toString();
    final rol = (asignacion['rol_modulo'] ?? 'operador').toString();
    final modulos = (asignacion['modulos_acceso'] as List?)?.map((m) => m.toString()).toList() ?? [];
    final activo = asignacion['activo'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(activo ? Icons.verified_user : Icons.pause_circle, color: activo ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$negocioNombre · ${rol.toUpperCase()}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (modulos.isNotEmpty)
                  Text(modulos.join(', '), style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE PERSONAL PROFESIONAL - Robert Darin Fintech V10.5
/// ═══════════════════════════════════════════════════════════════════════════════
/// - Búsqueda por nombre, puesto
/// - Filtros por estado (activo, inactivo)
/// - Contadores y estadísticas
/// - Vista de detalle mejorada
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import 'empleado_form_screen.dart';
import 'detalle_empleado_screen.dart';

class EmpleadosScreen extends StatefulWidget {
  const EmpleadosScreen({super.key});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> _empleadosFiltrados = [];
  
  // Filtros
  String _filtroEstado = 'todos';
  String _busqueda = '';
  
  // KPIs
  int _totalEmpleados = 0;
  int _activos = 0;
  int _inactivos = 0;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final response = await AppSupabase.client
          .from('empleados')
          .select('*, usuarios!empleados_usuario_id_fkey(nombre_completo, email)')
          .order('fecha_contratacion', ascending: false);
      
      final empleados = List<Map<String, dynamic>>.from(response);

      // Calcular KPIs
      int activos = 0;
      int inactivos = 0;

      for (var e in empleados) {
        if (e['estado'] == 'activo') {
          activos++;
        } else {
          inactivos++;
        }
      }

      if (mounted) {
        setState(() {
          _empleados = empleados;
          _totalEmpleados = empleados.length;
          _activos = activos;
          _inactivos = inactivos;
          _isLoading = false;
        });
        _aplicarFiltros();
      }
    } catch (e) {
      debugPrint('Error cargando empleados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_empleados);

    // Filtro por estado
    if (_filtroEstado != 'todos') {
      resultado = resultado.where((e) => e['estado'] == _filtroEstado).toList();
    }

    // Filtro por búsqueda
    if (_busqueda.isNotEmpty) {
      final busquedaLower = _busqueda.toLowerCase();
      resultado = resultado.where((e) {
        final usuario = e['usuarios'] as Map<String, dynamic>?;
        final nombre = (usuario?['nombre_completo'] ?? e['puesto'] ?? '').toString().toLowerCase();
        final puesto = (e['puesto'] ?? '').toString().toLowerCase();
        final email = (usuario?['email'] ?? '').toString().toLowerCase();
        return nombre.contains(busquedaLower) || 
               puesto.contains(busquedaLower) ||
               email.contains(busquedaLower);
      }).toList();
    }

    setState(() => _empleadosFiltrados = resultado);
  }

  void _agregarEmpleado() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmpleadoFormScreen()),
    );
    if (result == true) _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Gestión de Personal",
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.blueAccent),
          onPressed: _agregarEmpleado,
          tooltip: 'Nuevo empleado',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: Colors.blueAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPIs
                    _buildKPIsSection(),
                    const SizedBox(height: 20),

                    // BOTÓN NUEVO EMPLEADO
                    PremiumButton(
                      text: "Registrar Nuevo Empleado",
                      icon: Icons.person_add,
                      onPressed: _agregarEmpleado,
                    ),
                    const SizedBox(height: 20),

                    // BUSCADOR
                    _buildSearchBar(),
                    const SizedBox(height: 15),

                    // FILTROS
                    _buildFiltros(),
                    const SizedBox(height: 20),

                    // TÍTULO + CONTADOR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Equipo de Trabajo", 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("${_empleadosFiltrados.length} empleados",
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LISTA DE EMPLEADOS
                    if (_empleadosFiltrados.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _empleadosFiltrados.length,
                        itemBuilder: (context, index) => _buildEmpleadoCard(_empleadosFiltrados[index]),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKPIsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), Colors.blueAccent.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildKPIItem("👥 Total", _totalEmpleados.toString(), Colors.white),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildKPIItem("✅ Activos", _activos.toString(), const Color(0xFF10B981)),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildKPIItem("⏸️ Inactivos", _inactivos.toString(), Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Buscar por nombre, puesto o email...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _busqueda = '');
                  _aplicarFiltros();
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      onChanged: (value) {
        setState(() => _busqueda = value);
        _aplicarFiltros();
      },
    );
  }

  Widget _buildFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFiltroChip("Todos", _filtroEstado == 'todos', () {
            setState(() => _filtroEstado = 'todos');
            _aplicarFiltros();
          }),
          _buildFiltroChip("Activos", _filtroEstado == 'activo', () {
            setState(() => _filtroEstado = 'activo');
            _aplicarFiltros();
          }, color: const Color(0xFF10B981), icon: Icons.check_circle),
          _buildFiltroChip("Inactivos", _filtroEstado == 'inactivo', () {
            setState(() => _filtroEstado = 'inactivo');
            _aplicarFiltros();
          }, color: Colors.grey, icon: Icons.pause_circle),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, bool activo, VoidCallback onTap, {Color? color, IconData? icon}) {
    final chipColor = color ?? Colors.blueAccent;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? chipColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: activo ? chipColor : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: activo ? chipColor : Colors.white54),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(
                color: activo ? chipColor : Colors.white54,
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpleadoCard(Map<String, dynamic> emp) {
    final usuario = emp['usuarios'] as Map<String, dynamic>?;
    final nombre = usuario?['nombre_completo'] ?? emp['puesto'] ?? 'Empleado';
    final email = usuario?['email'] ?? '';
    final puesto = emp['puesto'] ?? 'Sin puesto';
    final estado = emp['estado'] ?? 'activo';
    final fechaContratacion = DateTime.tryParse(emp['fecha_contratacion'] ?? '');
    
    final esActivo = estado == 'activo';
    final estadoColor = esActivo ? const Color(0xFF10B981) : Colors.grey;

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              radius: 24,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: estadoColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D0D14), width: 2),
                ),
                child: Icon(
                  esActivo ? Icons.check : Icons.pause,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(nombre,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(estado.toUpperCase(),
                style: TextStyle(color: estadoColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.work, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(puesto, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            if (email.isNotEmpty)
              Text("✉️ $email", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            if (fechaContratacion != null)
              Text("📅 Desde ${DateFormat('dd/MM/yyyy').format(fechaContratacion)}",
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () {
          final empleadoId = emp['id']?.toString() ?? '';
          if (empleadoId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleEmpleadoScreen(empleadoId: empleadoId),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              _busqueda.isNotEmpty || _filtroEstado != 'todos'
                  ? "No hay empleados con estos filtros"
                  : "No hay empleados registrados",
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
            if (_busqueda.isNotEmpty || _filtroEstado != 'todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _busqueda = '';
                    _filtroEstado = 'todos';
                  });
                  _aplicarFiltros();
                },
                icon: const Icon(Icons.clear_all, color: Colors.blueAccent),
                label: const Text("Limpiar filtros", style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

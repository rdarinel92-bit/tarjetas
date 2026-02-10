// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE CLIENTES PROFESIONAL - Robert Darin Fintech V10.5
/// ═══════════════════════════════════════════════════════════════════════════════
/// - Búsqueda por nombre, teléfono, email
/// - Filtros por estado (con préstamo activo, sin préstamo)
/// - Contadores y KPIs
/// - Badges indicadores de estado
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import 'detalle_cliente_completo_screen.dart';
import '../viewmodels/negocio_activo_provider.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _clientesFiltrados = [];
  
  // Filtros
  String _filtro = 'todos';
  String _busqueda = '';
  
  // KPIs
  int _totalClientes = 0;
  int _conPrestamo = 0;
  int _sinPrestamo = 0;
  int _enMora = 0;

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
      // V10.55: Obtener negocio activo para filtrar
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      // Cargar clientes con sus préstamos
      var query = AppSupabase.client
          .from('clientes')
          .select('''
            *,
            prestamos(id, monto, estado)
          ''');
      
      // Filtrar por negocio si hay uno activo
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      
      final clientesRes = await query.order('nombre');

      final clientes = List<Map<String, dynamic>>.from(clientesRes);

      // Calcular KPIs
      int conPrestamo = 0;
      int sinPrestamo = 0;
      int enMora = 0;

      for (var c in clientes) {
        final prestamos = c['prestamos'] as List? ?? [];
        final tienePrestamoActivo = prestamos.any((p) => p['estado'] == 'activo');
        final tienePrestamoMora = prestamos.any((p) => p['estado'] == 'mora');
        
        if (tienePrestamoActivo) {
          conPrestamo++;
        } else {
          sinPrestamo++;
        }
        
        if (tienePrestamoMora) enMora++;
      }

      if (mounted) {
        setState(() {
          _clientes = clientes;
          _totalClientes = clientes.length;
          _conPrestamo = conPrestamo;
          _sinPrestamo = sinPrestamo;
          _enMora = enMora;
          _isLoading = false;
        });
        _aplicarFiltros();
      }
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_clientes);

    // Filtro por estado
    if (_filtro == 'con_prestamo') {
      resultado = resultado.where((c) {
        final prestamos = c['prestamos'] as List? ?? [];
        return prestamos.any((p) => p['estado'] == 'activo');
      }).toList();
    } else if (_filtro == 'sin_prestamo') {
      resultado = resultado.where((c) {
        final prestamos = c['prestamos'] as List? ?? [];
        return !prestamos.any((p) => p['estado'] == 'activo');
      }).toList();
    } else if (_filtro == 'en_mora') {
      resultado = resultado.where((c) {
        final prestamos = c['prestamos'] as List? ?? [];
        return prestamos.any((p) => p['estado'] == 'mora');
      }).toList();
    }

    // Filtro por búsqueda
    if (_busqueda.isNotEmpty) {
      final busquedaLower = _busqueda.toLowerCase();
      resultado = resultado.where((c) {
        final nombre = (c['nombre'] ?? '').toString().toLowerCase();
        final telefono = (c['telefono'] ?? '').toString();
        final email = (c['email'] ?? '').toString().toLowerCase();
        return nombre.contains(busquedaLower) || 
               telefono.contains(_busqueda) ||
               email.contains(busquedaLower);
      }).toList();
    }

    setState(() => _clientesFiltrados = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Gestión de Clientes",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: const Color(0xFF00D9FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPIs
                    _buildKPIsSection(),
                    const SizedBox(height: 20),

                    // BOTÓN NUEVO CLIENTE
                    PremiumButton(
                      text: "Registrar Nuevo Cliente",
                      icon: Icons.person_add,
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.formularioCliente);
                        _cargarDatos();
                      },
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
                        const Text("Lista de Clientes", 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("${_clientesFiltrados.length} clientes",
                            style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LISTA DE CLIENTES
                    if (_clientesFiltrados.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _clientesFiltrados.length,
                        itemBuilder: (context, index) => _buildClienteCard(_clientesFiltrados[index]),
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
            child: _buildKPIItem("👥 Total", _totalClientes.toString(), Colors.white),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildKPIItem("💰 Con Préstamo", _conPrestamo.toString(), const Color(0xFF10B981)),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildKPIItem("📋 Sin Préstamo", _sinPrestamo.toString(), Colors.white54),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildKPIItem("⚠️ En Mora", _enMora.toString(), const Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Buscar por nombre, teléfono o email...",
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
          _buildFiltroChip("Todos", _filtro == 'todos', () {
            setState(() => _filtro = 'todos');
            _aplicarFiltros();
          }),
          _buildFiltroChip("Con Préstamo", _filtro == 'con_prestamo', () {
            setState(() => _filtro = 'con_prestamo');
            _aplicarFiltros();
          }, color: const Color(0xFF10B981), icon: Icons.attach_money),
          _buildFiltroChip("Sin Préstamo", _filtro == 'sin_prestamo', () {
            setState(() => _filtro = 'sin_prestamo');
            _aplicarFiltros();
          }, icon: Icons.person_outline),
          _buildFiltroChip("En Mora", _filtro == 'en_mora', () {
            setState(() => _filtro = 'en_mora');
            _aplicarFiltros();
          }, color: const Color(0xFFEF4444), icon: Icons.warning_amber),
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

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    final nombre = cliente['nombre'] ?? 'Sin nombre';
    final telefono = cliente['telefono'] ?? '';
    final email = cliente['email'] ?? '';
    final prestamos = cliente['prestamos'] as List? ?? [];
    
    // Determinar estado
    final tienePrestamoActivo = prestamos.any((p) => p['estado'] == 'activo');
    final tienePrestamoMora = prestamos.any((p) => p['estado'] == 'mora');
    final totalPrestamos = prestamos.length;
    
    // Calcular monto total prestado
    double montoTotal = 0;
    for (var p in prestamos) {
      if (p['estado'] == 'activo') {
        montoTotal += (p['monto'] as num?)?.toDouble() ?? 0;
      }
    }

    Color estadoColor;
    String estadoTexto;
    IconData estadoIcon;
    
    if (tienePrestamoMora) {
      estadoColor = const Color(0xFFEF4444);
      estadoTexto = 'EN MORA';
      estadoIcon = Icons.warning;
    } else if (tienePrestamoActivo) {
      estadoColor = const Color(0xFF10B981);
      estadoTexto = 'ACTIVO';
      estadoIcon = Icons.check_circle;
    } else {
      estadoColor = Colors.white38;
      estadoTexto = 'SIN CRÉDITO';
      estadoIcon = Icons.person;
    }

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              radius: 24,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : "C",
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (tienePrestamoActivo || tienePrestamoMora)
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
                  child: Icon(estadoIcon, color: Colors.white, size: 10),
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
              child: Text(estadoTexto,
                style: TextStyle(color: estadoColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (telefono.isNotEmpty)
              Text("📱 $telefono", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (email.isNotEmpty)
              Text("✉️ $email", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            if (tienePrestamoActivo) ...[
              const SizedBox(height: 4),
              Text("💰 Deuda activa: ${NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(montoTotal)}",
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
            if (totalPrestamos > 0)
              Text("📊 $totalPrestamos préstamo${totalPrestamos > 1 ? 's' : ''} en historial",
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () {
          final clienteId = cliente['id']?.toString() ?? '';
          if (clienteId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleClienteCompletoScreen(clienteId: clienteId),
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
              _busqueda.isNotEmpty || _filtro != 'todos'
                  ? "No hay clientes con estos filtros"
                  : "No hay clientes registrados",
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
            if (_busqueda.isNotEmpty || _filtro != 'todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _busqueda = '';
                    _filtro = 'todos';
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

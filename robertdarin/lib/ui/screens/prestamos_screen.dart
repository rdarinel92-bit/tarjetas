// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// CONTROL DE PRÉSTAMOS PROFESIONAL - Robert Darin Fintech V10.5
/// ═══════════════════════════════════════════════════════════════════════════════
/// - KPIs en tiempo real (Total prestado, activos, en mora, pagados)
/// - Filtros por estado y tipo de préstamo
/// - Búsqueda por nombre de cliente
/// - Progress bar de avance de pago
/// - Soporte para préstamos nuevos y migración de existentes
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import 'detalle_prestamo_screen.dart';
import '../../data/models/prestamo_model.dart';
import '../viewmodels/negocio_activo_provider.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _prestamos = [];
  List<Map<String, dynamic>> _prestamosFiltrados = [];
  
  // Filtros
  String _filtroEstado = 'todos';
  String _filtroTipo = 'todos';
  String _busqueda = '';
  
  // KPIs
  double _totalPrestado = 0;
  int _prestamosActivos = 0;
  int _prestamosEnMora = 0;
  int _prestamosPagados = 0;
  double _totalRecuperado = 0;

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
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
      
      // Cargar préstamos con información del cliente
      var query = AppSupabase.client
          .from('prestamos')
          .select('''
            *,
            cliente:clientes(id, nombre, telefono, foto_url),
            amortizaciones(id, monto_cuota, estado, fecha_pago)
          ''');
      
      // Filtrar por negocio si hay uno activo
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      
      final prestamosRes = await query.order('created_at', ascending: false);

      final prestamos = List<Map<String, dynamic>>.from(prestamosRes);

      // Calcular KPIs
      double totalPrestado = 0;
      double totalRecuperado = 0;
      int activos = 0;
      int enMora = 0;
      int pagados = 0;

      for (var p in prestamos) {
        final monto = (p['monto'] as num?)?.toDouble() ?? 0;
        final estado = p['estado'] ?? 'activo';
        
        totalPrestado += monto;
        
        if (estado == 'activo') {
          activos++;
          // Verificar si tiene cuotas vencidas
          final amortizaciones = p['amortizaciones'] as List? ?? [];
          final tieneVencidas = amortizaciones.any((a) {
            if (a['estado'] == 'pendiente' && a['fecha_pago'] != null) {
              final fechaVence = DateTime.tryParse(a['fecha_pago'].toString());
              return fechaVence != null && fechaVence.isBefore(DateTime.now());
            }
            return false;
          });
          if (tieneVencidas) enMora++;
        } else if (estado == 'pagado' || estado == 'liquidado') {
          pagados++;
          totalRecuperado += monto;
        }

        // Calcular pagos realizados
        final amortizaciones = p['amortizaciones'] as List? ?? [];
        for (var a in amortizaciones) {
          if (a['estado'] == 'pagado' || a['estado'] == 'pagada') {
            totalRecuperado += (a['monto_cuota'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      if (mounted) {
        setState(() {
          _prestamos = prestamos;
          _totalPrestado = totalPrestado;
          _prestamosActivos = activos;
          _prestamosEnMora = enMora;
          _prestamosPagados = pagados;
          _totalRecuperado = totalRecuperado;
          _isLoading = false;
        });
        _aplicarFiltros();
      }
    } catch (e) {
      debugPrint('Error cargando préstamos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_prestamos);

    // Filtro por estado
    if (_filtroEstado != 'todos') {
      if (_filtroEstado == 'mora') {
        resultado = resultado.where((p) {
          final amortizaciones = p['amortizaciones'] as List? ?? [];
          return amortizaciones.any((a) {
            if (a['estado'] == 'pendiente' && a['fecha_pago'] != null) {
              final fechaVence = DateTime.tryParse(a['fecha_pago'].toString());
              return fechaVence != null && fechaVence.isBefore(DateTime.now());
            }
            return false;
          });
        }).toList();
      } else {
        resultado = resultado.where((p) => p['estado'] == _filtroEstado).toList();
      }
    }

    // Filtro por tipo
    if (_filtroTipo != 'todos') {
      resultado = resultado.where((p) => p['tipo_prestamo'] == _filtroTipo).toList();
    }

    // Filtro por búsqueda
    if (_busqueda.isNotEmpty) {
      final busquedaLower = _busqueda.toLowerCase();
      resultado = resultado.where((p) {
        final cliente = p['cliente'] as Map<String, dynamic>?;
        final nombreCliente = (cliente?['nombre'] ?? '').toString().toLowerCase();
        final telefono = (cliente?['telefono'] ?? '').toString();
        return nombreCliente.contains(busquedaLower) || telefono.contains(_busqueda);
      }).toList();
    }

    setState(() => _prestamosFiltrados = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Control de Préstamos",
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
                    
                    // BOTONES DE ACCIÓN
                    Row(
                      children: [
                        Expanded(
                          child: PremiumButton(
                            text: "Nuevo Préstamo",
                            icon: Icons.add_card,
                            onPressed: () async {
                              await Navigator.pushNamed(context, AppRoutes.formularioPrestamo);
                              _cargarDatos();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PremiumButton(
                            text: "Migrar Existente",
                            icon: Icons.upload_file,
                            color: Colors.orangeAccent,
                            onPressed: () async {
                              await Navigator.pushNamed(context, AppRoutes.formularioPrestamoExistente);
                              _cargarDatos();
                            },
                          ),
                        ),
                      ],
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
                        const Text("Historial de Créditos", 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("${_prestamosFiltrados.length} préstamos",
                            style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LISTA DE PRÉSTAMOS
                    if (_prestamosFiltrados.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prestamosFiltrados.length,
                        itemBuilder: (context, index) => _buildPrestamoCard(_prestamosFiltrados[index]),
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
          colors: [const Color(0xFF1A1A2E), const Color(0xFF00D9FF).withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Fila principal
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CARTERA TOTAL", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(_currencyFormat.format(_totalPrestado),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Recuperado: ${_currencyFormat.format(_totalRecuperado)}",
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildMiniKPI("Activos", _prestamosActivos.toString(), const Color(0xFF00D9FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fila secundaria
          Row(
            children: [
              Expanded(child: _buildKPIChip("📈 Pagados", _prestamosPagados.toString(), const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildKPIChip("⚠️ En Mora", _prestamosEnMora.toString(), const Color(0xFFEF4444))),
              const SizedBox(width: 8),
              Expanded(child: _buildKPIChip("📊 Total", _prestamos.length.toString(), Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKPI(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildKPIChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Buscar por nombre o teléfono...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF00D9FF)),
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
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
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
          // Filtro por Estado
          _buildFiltroChip("Todos", _filtroEstado == 'todos', () {
            setState(() => _filtroEstado = 'todos');
            _aplicarFiltros();
          }),
          _buildFiltroChip("Activos", _filtroEstado == 'activo', () {
            setState(() => _filtroEstado = 'activo');
            _aplicarFiltros();
          }, color: const Color(0xFF00D9FF)),
          _buildFiltroChip("En Mora", _filtroEstado == 'mora', () {
            setState(() => _filtroEstado = 'mora');
            _aplicarFiltros();
          }, color: const Color(0xFFEF4444)),
          _buildFiltroChip("Pagados", _filtroEstado == 'pagado', () {
            setState(() => _filtroEstado = 'pagado');
            _aplicarFiltros();
          }, color: const Color(0xFF10B981)),
          _buildFiltroChip("Cancelados", _filtroEstado == 'cancelado', () {
            setState(() => _filtroEstado = 'cancelado');
            _aplicarFiltros();
          }, color: Colors.grey),
          
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 16),
          
          // Filtro por Tipo
          _buildFiltroChip("Normal", _filtroTipo == 'normal', () {
            setState(() => _filtroTipo = _filtroTipo == 'normal' ? 'todos' : 'normal');
            _aplicarFiltros();
          }, icon: Icons.account_balance_wallet),
          _buildFiltroChip("Diario", _filtroTipo == 'diario', () {
            setState(() => _filtroTipo = _filtroTipo == 'diario' ? 'todos' : 'diario');
            _aplicarFiltros();
          }, icon: Icons.today),
          _buildFiltroChip("Arquilado", _filtroTipo == 'arquilado', () {
            setState(() => _filtroTipo = _filtroTipo == 'arquilado' ? 'todos' : 'arquilado');
            _aplicarFiltros();
          }, icon: Icons.auto_graph),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, bool activo, VoidCallback onTap, {Color? color, IconData? icon}) {
    final chipColor = color ?? const Color(0xFF00D9FF);
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

  Widget _buildPrestamoCard(Map<String, dynamic> prestamo) {
    final cliente = prestamo['cliente'] as Map<String, dynamic>?;
    final nombreCliente = cliente?['nombre'] ?? 'Sin cliente';
    final telefono = cliente?['telefono'] ?? '';
    final monto = (prestamo['monto'] as num?)?.toDouble() ?? 0;
    final interes = (prestamo['interes'] as num?)?.toDouble() ?? 0;
    final estado = prestamo['estado'] ?? 'activo';
    final tipoPrestamo = prestamo['tipo_prestamo'] ?? 'normal';
    final fechaCreacion = DateTime.tryParse(prestamo['created_at'] ?? '') ?? DateTime.now();
    
    // Calcular progreso de pago
    final amortizaciones = prestamo['amortizaciones'] as List? ?? [];
    int cuotasPagadas = 0;
    int totalCuotas = amortizaciones.length;
    bool tieneVencidas = false;
    
    for (var a in amortizaciones) {
      if (a['estado'] == 'pagado' || a['estado'] == 'pagada') {
        cuotasPagadas++;
      }
      if (a['estado'] == 'pendiente' && a['fecha_pago'] != null) {
        final fechaVence = DateTime.tryParse(a['fecha_pago'].toString());
        if (fechaVence != null && fechaVence.isBefore(DateTime.now())) {
          tieneVencidas = true;
        }
      }
    }
    
    final progreso = totalCuotas > 0 ? cuotasPagadas / totalCuotas : 0.0;

    // Colores según estado
    Color estadoColor;
    String estadoTexto;
    IconData estadoIcon;
    
    if (estado == 'pagado' || estado == 'liquidado') {
      estadoColor = const Color(0xFF10B981);
      estadoTexto = 'PAGADO';
      estadoIcon = Icons.check_circle;
    } else if (tieneVencidas) {
      estadoColor = const Color(0xFFEF4444);
      estadoTexto = 'EN MORA';
      estadoIcon = Icons.warning;
    } else if (estado == 'cancelado') {
      estadoColor = Colors.grey;
      estadoTexto = 'CANCELADO';
      estadoIcon = Icons.cancel;
    } else {
      estadoColor = const Color(0xFF00D9FF);
      estadoTexto = 'ACTIVO';
      estadoIcon = Icons.play_circle;
    }

    // Icono según tipo
    IconData tipoIcon;
    Color tipoColor;
    switch (tipoPrestamo) {
      case 'diario':
        tipoIcon = Icons.today;
        tipoColor = Colors.orangeAccent;
        break;
      case 'arquilado':
        tipoIcon = Icons.auto_graph;
        tipoColor = Colors.purpleAccent;
        break;
      default:
        tipoIcon = Icons.account_balance_wallet;
        tipoColor = const Color(0xFF00D9FF);
    }

    return PremiumCard(
      child: InkWell(
        onTap: () => _navegarADetalle(prestamo),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar con tipo
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: tipoColor.withOpacity(0.2),
                        radius: 24,
                        child: Icon(tipoIcon, color: tipoColor, size: 24),
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
                          child: Icon(estadoIcon, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nombreCliente,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: estadoColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(estadoTexto,
                                style: TextStyle(color: estadoColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (telefono.isNotEmpty)
                          Text("📱 $telefono", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(_currencyFormat.format(monto),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            Text("${interes.toStringAsFixed(0)}% int.",
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            const Spacer(),
                            Text(DateFormat('dd/MM/yy').format(fechaCreacion),
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
              
              // Progress bar
              if (totalCuotas > 0 && estado != 'cancelado') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progreso,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(estadoColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("$cuotasPagadas/$totalCuotas",
                      style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navegarADetalle(Map<String, dynamic> prestamoMap) {
    try {
      final prestamo = PrestamoModel(
        id: prestamoMap['id'] ?? '',
        clienteId: prestamoMap['cliente_id'] ?? '',
        monto: (prestamoMap['monto'] as num?)?.toDouble() ?? 0,
        interes: (prestamoMap['interes'] as num?)?.toDouble() ?? 0,
        plazoMeses: prestamoMap['plazo_meses'] ?? 0,
        estado: prestamoMap['estado'] ?? 'activo',
        fechaCreacion: DateTime.tryParse(prestamoMap['created_at'] ?? '') ?? DateTime.now(),
        tipoPrestamo: prestamoMap['tipo_prestamo'] ?? 'normal',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetallePrestamoScreen(prestamo: prestamo),
        ),
      );
    } catch (e) {
      debugPrint('Error navegando a detalle: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              _busqueda.isNotEmpty || _filtroEstado != 'todos' || _filtroTipo != 'todos'
                  ? "No hay préstamos con estos filtros"
                  : "No hay préstamos registrados",
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
            if (_busqueda.isNotEmpty || _filtroEstado != 'todos' || _filtroTipo != 'todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _busqueda = '';
                    _filtroEstado = 'todos';
                    _filtroTipo = 'todos';
                  });
                  _aplicarFiltros();
                },
                icon: const Icon(Icons.clear_all, color: Color(0xFF00D9FF)),
                label: const Text("Limpiar filtros", style: TextStyle(color: Color(0xFF00D9FF))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DASHBOARD MÓDULO CLIMAS - Robert Darin Platform
/// Gestión de aires acondicionados, servicios e instalaciones
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasDashboardScreen extends StatefulWidget {
  const ClimasDashboardScreen({super.key});
  @override
  State<ClimasDashboardScreen> createState() => _ClimasDashboardScreenState();
}

class _ClimasDashboardScreenState extends State<ClimasDashboardScreen> {
  bool _isLoading = true;
  int _clientesTotal = 0;
  int _productosTotal = 0;
  int _tecnicosActivos = 0;
  int _ordenesHoy = 0;
  int _ordenesPendientes = 0;
  double _ventasMes = 0;
  List<ClimasOrdenServicioModel> _ordenesRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar estadísticas
      final clientesRes = await AppSupabase.client.from('climas_clientes').select('id').eq('activo', true);
      final productosRes = await AppSupabase.client.from('climas_productos').select('id').eq('activo', true);
      final tecnicosRes = await AppSupabase.client.from('climas_tecnicos').select('id').eq('activo', true);
      
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final ordenesHoyRes = await AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('id')
          .eq('fecha_programada', hoy);
      
      final ordenesPendientesRes = await AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('id')
          .eq('estado', 'pendiente');

      // Órdenes recientes
      final ordenesRes = await AppSupabase.client
          .from('climas_ordenes_servicio')
          .select('*, climas_clientes(nombre), climas_tecnicos(nombre)')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _clientesTotal = (clientesRes as List).length;
          _productosTotal = (productosRes as List).length;
          _tecnicosActivos = (tecnicosRes as List).length;
          _ordenesHoy = (ordenesHoyRes as List).length;
          _ordenesPendientes = (ordenesPendientesRes as List).length;
          _ordenesRecientes = (ordenesRes as List)
              .map((e) => ClimasOrdenServicioModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos climas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Módulo Climas',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildKPIs(),
                    const SizedBox(height: 24),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    _buildOrdenesRecientes(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.climasOrdenNueva),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nueva Orden', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.ac_unit, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aires Acondicionados',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Servicios, ventas e instalaciones',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard('Clientes', '$_clientesTotal', Icons.people, const Color(0xFF10B981)),
        _buildKPICard('Productos', '$_productosTotal', Icons.inventory_2, const Color(0xFF8B5CF6)),
        _buildKPICard('Técnicos', '$_tecnicosActivos', Icons.engineering, const Color(0xFFF59E0B)),
        _buildKPICard('Órdenes Hoy', '$_ordenesHoy', Icons.today, const Color(0xFF00D9FF)),
        _buildKPICard('Pendientes', '$_ordenesPendientes', Icons.pending_actions, const Color(0xFFEF4444)),
        _buildKPICard('Ventas Mes', '\$${_ventasMes.toStringAsFixed(0)}', Icons.trending_up, const Color(0xFF22C55E)),
      ],
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(width: 8),
              Text(valor, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(titulo, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Acciones Rápidas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Clientes', Icons.people, '/climas/clientes', const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Productos', Icons.inventory_2, '/climas/productos', const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Técnicos', Icons.engineering, '/climas/tecnicos', const Color(0xFFF59E0B))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Órdenes', Icons.assignment, '/climas/ordenes', const Color(0xFF00D9FF))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Equipos', Icons.ac_unit, '/climas/equipos', const Color(0xFFEC4899))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Tareas', Icons.task_alt, '/climas/tareas', const Color(0xFFF97316))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccionBtnCustom(
                'Solicitudes QR',
                Icons.qr_code_2,
                () => Navigator.pushNamed(context, AppRoutes.climasSolicitudesAdmin),
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccionBtnCustom(
                'Facturas Climas',
                Icons.receipt_long,
                () => Navigator.pushNamed(context, AppRoutes.climasFacturas),
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccionBtnCustom(
                'Cotizador',
                Icons.request_quote,
                _mostrarCotizadorRapido,
                const Color(0xFF22C55E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccionBtnCustom(
                'Tarjetas QR',
                Icons.qr_code_2,
                () => Navigator.pushNamed(context, AppRoutes.climasTarjetasQr),
                const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionBtn(String titulo, IconData icono, String ruta, Color color) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, ruta),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionBtnCustom(String titulo, IconData icono, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<String?> _cargarNegocioActivoId() async {
    try {
      final configRes = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'negocio_activo')
          .maybeSingle();
      if (configRes != null) {
        final valor = configRes['valor'];
        if (valor is Map && valor['id'] != null) {
          return valor['id'].toString();
        }
        if (valor is String && valor.isNotEmpty) {
          return valor;
        }
      }
    } catch (_) {}

    try {
      final negocio = await AppSupabase.client
          .from('negocios')
          .select('id')
          .limit(1)
          .maybeSingle();
      return negocio?['id'];
    } catch (_) {}

    return null;
  }

  Future<void> _mostrarCotizadorRapido() async {
    final negocioId = await _cargarNegocioActivoId();
    if (negocioId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero configura un negocio activo')),
        );
      }
      return;
    }

    List<Map<String, dynamic>> precios = [];
    try {
      final res = await AppSupabase.client
          .from('climas_precios_servicio')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('precio_base');
      precios = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando precios: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (precios.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay precios configurados para cotizar.')),
        );
      }
      return;
    }

    if (!mounted) return;

    String? seleccionadoId = precios.first['id']?.toString();
    final cantidadCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final seleccionado = precios.firstWhere(
            (p) => p['id']?.toString() == seleccionadoId,
            orElse: () => precios.first,
          );
          final precioBase = (seleccionado['precio_base'] ?? 0).toDouble();

          double calcularTotal() {
            final qty = int.tryParse(cantidadCtrl.text) ?? 1;
            return precioBase * qty;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cotizador rápido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: seleccionadoId,
                  decoration: _inputDecoration('Servicio'),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: precios.map<DropdownMenuItem<String>>((p) {
                    final id = p['id']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('${p['nombre']} - \$${(p['precio_base'] ?? 0)}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setModalState(() {
                      seleccionadoId = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Cantidad'),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total estimado', style: TextStyle(color: Colors.white70)),
                      Text(
                        '\$${calcularTotal().toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.climasCotizaciones),
                    icon: const Icon(Icons.request_quote),
                    label: const Text('Ir a cotizaciones'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      filled: true,
      fillColor: const Color(0xFF16213E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D9FF)),
      ),
    );
  }

  Widget _buildOrdenesRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Órdenes Recientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.climasOrdenes),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ordenesRecientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No hay órdenes registradas', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...(_ordenesRecientes.map((orden) => _buildOrdenCard(orden))),
      ],
    );
  }

  Widget _buildOrdenCard(ClimasOrdenServicioModel orden) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment, color: Color(0xFF00B4D8)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orden.numeroOrden ?? 'Sin número',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  orden.clienteNombre ?? 'Cliente',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                Text(
                  orden.tipoServicioDisplay,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getColorEstado(orden.estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  orden.estadoDisplay,
                  style: TextStyle(color: _getColorEstado(orden.estado), fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${orden.costoTotal.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFFBBF24);
      case 'en_proceso': return const Color(0xFF00D9FF);
      case 'completado': return const Color(0xFF10B981);
      case 'cancelado': return const Color(0xFFEF4444);
      default: return Colors.white54;
    }
  }
}

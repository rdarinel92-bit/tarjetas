// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../../data/models/purificadora_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DASHBOARD MÓDULO PURIFICADORA - Robert Darin Platform
/// Gestión de producción, rutas, entregas y garrafones
/// ═══════════════════════════════════════════════════════════════════════════════
class PurificadoraDashboardScreen extends StatefulWidget {
  const PurificadoraDashboardScreen({super.key});
  @override
  State<PurificadoraDashboardScreen> createState() => _PurificadoraDashboardScreenState();
}

class _PurificadoraDashboardScreenState extends State<PurificadoraDashboardScreen> {
  bool _isLoading = true;
  int _clientesTotal = 0;
  int _repartidoresActivos = 0;
  int _rutasActivas = 0;
  int _entregasHoy = 0;
  int _entregasPendientes = 0;
  int _garrafonesDisponibles = 0;
  int _garrafonesEnRuta = 0;
  double _cobranzaHoy = 0;
  List<PurificadoraEntregaModel> _entregasRecientes = [];
  List<PurificadoraRutaModel> _rutas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final clientesRes = await AppSupabase.client.from('purificadora_clientes').select('id').eq('activo', true);
      final repartidoresRes = await AppSupabase.client.from('purificadora_repartidores').select('id').eq('activo', true);
      final rutasRes = await AppSupabase.client.from('purificadora_rutas').select('*, purificadora_repartidores(nombre)').eq('activo', true);
      
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final entregasHoyRes = await AppSupabase.client
          .from('purificadora_entregas')
          .select('id, monto, pagado')
          .eq('fecha', hoy);
      
      final entregasPendientesRes = await AppSupabase.client
          .from('purificadora_entregas')
          .select('id')
          .eq('estado', 'pendiente');

      // Entregas recientes
      final entregasRes = await AppSupabase.client
          .from('purificadora_entregas')
          .select('*, purificadora_clientes(nombre, direccion), purificadora_repartidores(nombre), purificadora_rutas(nombre)')
          .order('created_at', ascending: false)
          .limit(5);

      // Calcular cobranza
      double cobranza = 0;
      for (var e in (entregasHoyRes as List)) {
        if (e['pagado'] == true) cobranza += (e['monto'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _clientesTotal = (clientesRes as List).length;
          _repartidoresActivos = (repartidoresRes as List).length;
          _rutasActivas = (rutasRes as List).length;
          _entregasHoy = (entregasHoyRes).length;
          _entregasPendientes = (entregasPendientesRes as List).length;
          _cobranzaHoy = cobranza;
          _rutas = (rutasRes).map((e) => PurificadoraRutaModel.fromMap(e)).toList();
          _entregasRecientes = (entregasRes as List)
              .map((e) => PurificadoraEntregaModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos purificadora: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Módulo Purificadora',
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
                    _buildResumenDia(),
                    const SizedBox(height: 24),
                    _buildKPIs(),
                    const SizedBox(height: 24),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    _buildRutasActivas(),
                    const SizedBox(height: 24),
                    _buildEntregasRecientes(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/purificadora/entregas/nueva'),
        backgroundColor: const Color(0xFF06B6D4),
        icon: const Icon(Icons.local_shipping, color: Colors.white),
        label: const Text('Nueva Entrega', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
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
            child: const Icon(Icons.water_drop, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Purificadora',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Producción, rutas y entregas',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDia() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF06B6D4), size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen de Hoy',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.local_shipping, color: Color(0xFF22C55E), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '$_entregasHoy',
                      style: const TextStyle(color: Color(0xFF22C55E), fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Text('Entregas', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white.withOpacity(0.1)),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.attach_money, color: Color(0xFF00D9FF), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_cobranzaHoy.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Text('Cobranza', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white.withOpacity(0.1)),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.pending_actions, color: Color(0xFFFBBF24), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '$_entregasPendientes',
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Text('Pendientes', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        _buildKPICard('Clientes', '$_clientesTotal', Icons.people, const Color(0xFF10B981)),
        _buildKPICard('Repartidores', '$_repartidoresActivos', Icons.delivery_dining, const Color(0xFF8B5CF6)),
        _buildKPICard('Rutas', '$_rutasActivas', Icons.route, const Color(0xFFF59E0B)),
        _buildKPICard('En Planta', '$_garrafonesDisponibles', Icons.water_drop, const Color(0xFF06B6D4)),
        _buildKPICard('En Ruta', '$_garrafonesEnRuta', Icons.local_shipping, const Color(0xFFEC4899)),
        _buildKPICard('Producción', '0', Icons.factory, const Color(0xFF22C55E)),
      ],
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(titulo, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestión', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Clientes', Icons.people, '/purificadora/clientes', const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Repartidores', Icons.delivery_dining, '/purificadora/repartidores', const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Rutas', Icons.route, '/purificadora/rutas', const Color(0xFFF59E0B))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildAccionBtn('Entregas', Icons.local_shipping, '/purificadora/entregas', const Color(0xFF06B6D4))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Producción', Icons.factory, '/purificadora/produccion', const Color(0xFF22C55E))),
            const SizedBox(width: 12),
            Expanded(child: _buildAccionBtn('Cortes', Icons.receipt_long, '/purificadora/cortes', const Color(0xFFEC4899))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccionBtn('Tarjetas QR', Icons.qr_code_2, AppRoutes.purificadoraTarjetasQr, const Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccionBtn('Facturas Agua', Icons.receipt_long, AppRoutes.purificadoraFacturas, const Color(0xFF3B82F6)),
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

  Widget _buildRutasActivas() {
    if (_rutas.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Rutas Activas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/purificadora/rutas'),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF06B6D4))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _rutas.length,
            itemBuilder: (context, index) {
              final ruta = _rutas[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06B6D4).withOpacity(0.2),
                      const Color(0xFF0891B2).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.route, color: Color(0xFF06B6D4), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ruta.nombre,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ruta.repartidorNombre ?? 'Sin asignar',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                    Text(
                      '${ruta.clientesTotal} clientes',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntregasRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Entregas Recientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/purificadora/entregas'),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF06B6D4))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_entregasRecientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No hay entregas registradas', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...(_entregasRecientes.map((entrega) => _buildEntregaCard(entrega))),
      ],
    );
  }

  Widget _buildEntregaCard(PurificadoraEntregaModel entrega) {
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
              color: const Color(0xFF06B6D4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrega.clienteNombre ?? 'Cliente',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  entrega.clienteDireccion ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.arrow_upward, color: const Color(0xFF22C55E), size: 14),
                    Text(' ${entrega.garrafonesEntregados}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_downward, color: const Color(0xFF06B6D4), size: 14),
                    Text(' ${entrega.garrafonesRecogidos}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
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
                  color: _getColorEstado(entrega.estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entrega.estadoDisplay,
                  style: TextStyle(color: _getColorEstado(entrega.estado), fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${entrega.monto.toStringAsFixed(0)}',
                style: TextStyle(
                  color: entrega.pagado ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
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
      case 'en_camino': return const Color(0xFF06B6D4);
      case 'entregado': return const Color(0xFF10B981);
      case 'no_entregado': return const Color(0xFFEF4444);
      case 'reagendado': return const Color(0xFF8B5CF6);
      default: return Colors.white54;
    }
  }
}

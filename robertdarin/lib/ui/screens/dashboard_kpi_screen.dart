// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class DashboardKpiScreen extends StatefulWidget {
  const DashboardKpiScreen({super.key});

  @override
  State<DashboardKpiScreen> createState() => _DashboardKpiScreenState();
}

class _DashboardKpiScreenState extends State<DashboardKpiScreen> {
  bool _isLoading = true;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  // KPIs
  int _totalClientes = 0;
  int _clientesActivos = 0;
  int _prestamosActivos = 0;
  int _prestamosMora = 0;
  int _tandasActivas = 0;
  int _totalEmpleados = 0;
  int _pagosMes = 0;
  double _montoColocadoMes = 0;
  double _montoRecuperadoMes = 0;
  double _carteraTotal = 0;
  double _carteraVencida = 0;
  int _sucursalesActivas = 0;
  
  @override
  void initState() {
    super.initState();
    _cargarKPIs();
  }

  Future<void> _cargarKPIs() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1).toIso8601String();
      
      // Clientes
      final clientesRes = await AppSupabase.client.from('clientes').select('id, activo');
      _totalClientes = clientesRes.length;
      _clientesActivos = (clientesRes as List).where((c) => c['activo'] == true).length;
      
      // Préstamos
      final prestamosRes = await AppSupabase.client.from('prestamos').select('id, estado, monto, saldo_pendiente');
      _prestamosActivos = (prestamosRes as List).where((p) => p['estado'] == 'activo').length;
      _prestamosMora = (prestamosRes).where((p) => p['estado'] == 'mora' || p['estado'] == 'vencido').length;
      
      // Cartera
      _carteraTotal = 0;
      _carteraVencida = 0;
      for (var p in prestamosRes) {
        if (p['estado'] == 'activo' || p['estado'] == 'mora') {
          _carteraTotal += (p['saldo_pendiente'] ?? 0).toDouble();
        }
        if (p['estado'] == 'mora' || p['estado'] == 'vencido') {
          _carteraVencida += (p['saldo_pendiente'] ?? 0).toDouble();
        }
      }
      
      // Tandas
      final tandasRes = await AppSupabase.client.from('tandas').select('id').eq('estado', 'activa');
      _tandasActivas = tandasRes.length;
      
      // Empleados
      final empleadosRes = await AppSupabase.client.from('empleados').select('id').eq('estado', 'activo');
      _totalEmpleados = empleadosRes.length;
      
      // Sucursales
      final sucursalesRes = await AppSupabase.client.from('sucursales').select('id').eq('activa', true);
      _sucursalesActivas = sucursalesRes.length;
      
      // Pagos del mes
      final pagosRes = await AppSupabase.client
          .from('pagos')
          .select('id, monto')
          .gte('fecha', inicioMes);
      _pagosMes = pagosRes.length;
      _montoRecuperadoMes = 0;
      for (var p in pagosRes) {
        _montoRecuperadoMes += (p['monto'] ?? 0).toDouble();
      }
      
      // Préstamos otorgados este mes
      final prestMesRes = await AppSupabase.client
          .from('prestamos')
          .select('monto')
          .gte('fecha_inicio', inicioMes);
      _montoColocadoMes = 0;
      for (var p in prestMesRes) {
        _montoColocadoMes += (p['monto'] ?? 0).toDouble();
      }
      
    } catch (e) {
      debugPrint('Error cargando KPIs: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tasaRecuperacion = _carteraTotal > 0 
        ? ((_carteraTotal - _carteraVencida) / _carteraTotal * 100) 
        : 100.0;
    final tasaMora = _prestamosActivos + _prestamosMora > 0
        ? (_prestamosMora / (_prestamosActivos + _prestamosMora) * 100)
        : 0.0;

    return PremiumScaffold(
      title: 'Dashboard KPIs',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarKPIs,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _cargarKPIs,
              color: Colors.cyanAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indicadores principales
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMainIndicator('Tasa Recuperación', '${tasaRecuperacion.toStringAsFixed(1)}%', 
                              tasaRecuperacion >= 80 ? Colors.greenAccent : Colors.orangeAccent),
                          Container(width: 1, height: 50, color: Colors.white24),
                          _buildMainIndicator('Tasa Mora', '${tasaMora.toStringAsFixed(1)}%',
                              tasaMora <= 10 ? Colors.greenAccent : Colors.redAccent),
                          Container(width: 1, height: 50, color: Colors.white24),
                          _buildMainIndicator('Eficiencia', '${(_montoRecuperadoMes / (_montoColocadoMes > 0 ? _montoColocadoMes : 1) * 100).toStringAsFixed(0)}%',
                              Colors.cyanAccent),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    // Cartera
                    _buildSectionTitle('💰 Cartera'),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Cartera Total', _currencyFormat.format(_carteraTotal), Colors.greenAccent, Icons.account_balance_wallet)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Cartera Vencida', _currencyFormat.format(_carteraVencida), Colors.redAccent, Icons.warning_amber)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Colocado (Mes)', _currencyFormat.format(_montoColocadoMes), Colors.blueAccent, Icons.trending_up)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Recuperado (Mes)', _currencyFormat.format(_montoRecuperadoMes), Colors.tealAccent, Icons.trending_down)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('👥 Clientes'),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Total Clientes', _totalClientes.toString(), Colors.purpleAccent, Icons.people)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Activos', _clientesActivos.toString(), Colors.greenAccent, Icons.person_pin)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('📋 Préstamos'),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Activos', _prestamosActivos.toString(), Colors.blueAccent, Icons.attach_money)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('En Mora', _prestamosMora.toString(), Colors.orangeAccent, Icons.schedule)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('📊 Operaciones'),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Pagos (Mes)', _pagosMes.toString(), Colors.cyanAccent, Icons.payment)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Tandas Activas', _tandasActivas.toString(), Colors.amberAccent, Icons.group_work)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('🏢 Estructura'),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Empleados', _totalEmpleados.toString(), Colors.indigoAccent, Icons.badge)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Sucursales', _sucursalesActivas.toString(), Colors.pinkAccent, Icons.store)),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainIndicator(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

class DashboardAvanzadoScreen extends StatefulWidget {
  const DashboardAvanzadoScreen({super.key});

  @override
  State<DashboardAvanzadoScreen> createState() => _DashboardAvanzadoScreenState();
}

class _DashboardAvanzadoScreenState extends State<DashboardAvanzadoScreen> {
  bool _cargando = true;
  
  // KPIs
  int _totalClientes = 0;
  int _clientesNuevosMes = 0;
  int _totalPrestamos = 0;
  int _prestamosActivos = 0;
  double _capitalPrestado = 0;
  double _capitalRecuperado = 0;
  double _saldoPendiente = 0;
  int _totalTandas = 0;
  int _tandasActivas = 0;
  double _volumenTandas = 0;
  
  // Tendencias
  double _crecimientoClientes = 0;
  double _tasaRecuperacion = 0;
  double _morosidad = 0;

  @override
  void initState() {
    super.initState();
    _cargarKPIs();
  }

  Future<void> _cargarKPIs() async {
    setState(() => _cargando = true);
    
    try {
      // Formateador de moneda para uso en el módulo
      // ignore: unused_local_variable
      final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final mesAnterior = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
      
      // Clientes
      final clientes = await AppSupabase.client.from('clientes').select('id, created_at, activo');
      final listaClientes = List<Map<String, dynamic>>.from(clientes);
      _totalClientes = listaClientes.length;
      _clientesNuevosMes = listaClientes.where((c) {
        final fecha = DateTime.tryParse(c['created_at'] ?? '');
        return fecha != null && fecha.isAfter(inicioMes);
      }).length;
      
      final clientesMesAnterior = listaClientes.where((c) {
        final fecha = DateTime.tryParse(c['created_at'] ?? '');
        return fecha != null && fecha.isAfter(mesAnterior) && fecha.isBefore(inicioMes);
      }).length;
      
      if (clientesMesAnterior > 0) {
        _crecimientoClientes = ((_clientesNuevosMes - clientesMesAnterior) / clientesMesAnterior * 100);
      }
      
      // Préstamos
      final prestamos = await AppSupabase.client.from('prestamos').select('monto_principal, monto_total, saldo_pendiente, estado');
      final listaPrestamos = List<Map<String, dynamic>>.from(prestamos);
      _totalPrestamos = listaPrestamos.length;
      _prestamosActivos = listaPrestamos.where((p) => p['estado'] == 'activo').length;
      
      for (var p in listaPrestamos) {
        _capitalPrestado += (p['monto_principal'] ?? 0).toDouble();
        _saldoPendiente += (p['saldo_pendiente'] ?? 0).toDouble();
      }
      _capitalRecuperado = _capitalPrestado - _saldoPendiente;
      
      if (_capitalPrestado > 0) {
        _tasaRecuperacion = (_capitalRecuperado / _capitalPrestado * 100);
      }
      
      // Morosidad (préstamos vencidos)
      final vencidos = listaPrestamos.where((p) => p['estado'] == 'vencido').length;
      if (_totalPrestamos > 0) {
        _morosidad = (vencidos / _totalPrestamos * 100);
      }
      
      // Tandas
      final tandas = await AppSupabase.client.from('tandas').select('monto_por_persona, numero_participantes, estado');
      final listaTandas = List<Map<String, dynamic>>.from(tandas);
      _totalTandas = listaTandas.length;
      _tandasActivas = listaTandas.where((t) => t['estado'] == 'activa').length;
      
      for (var t in listaTandas) {
        _volumenTandas += (t['monto_por_persona'] ?? 0).toDouble() * (t['numero_participantes'] ?? 0);
      }
      
    } catch (e) {
      debugPrint('Error cargando KPIs: $e');
    }
    
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    return PremiumScaffold(
      title: "Dashboard KPIs",
      subtitle: "Indicadores clave de rendimiento",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarKPIs,
        ),
      ],
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _cargarKPIs,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen rápido
                  Row(
                    children: [
                      Expanded(child: _buildKPICard("Clientes", _totalClientes.toString(), Icons.people, Colors.blueAccent, 
                        subtitle: "+$_clientesNuevosMes este mes")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKPICard("Préstamos", _prestamosActivos.toString(), Icons.attach_money, Colors.greenAccent,
                        subtitle: "de $_totalPrestamos totales")),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildKPICard("Tandas", _tandasActivas.toString(), Icons.group_work, Colors.orangeAccent,
                        subtitle: "activas de $_totalTandas")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKPICard("Volumen", nf.format(_volumenTandas), Icons.savings, Colors.purpleAccent,
                        subtitle: "en tandas")),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // Métricas financieras
                  const Text("Métricas Financieras", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  
                  PremiumCard(
                    child: Column(
                      children: [
                        _buildMetricaRow("Capital Prestado", nf.format(_capitalPrestado), Colors.blueAccent),
                        const Divider(color: Colors.white12),
                        _buildMetricaRow("Capital Recuperado", nf.format(_capitalRecuperado), Colors.greenAccent),
                        const Divider(color: Colors.white12),
                        _buildMetricaRow("Saldo Pendiente", nf.format(_saldoPendiente), Colors.orangeAccent),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // Indicadores de salud
                  const Text("Indicadores de Salud", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(child: _buildIndicadorSalud("Tasa Recuperación", _tasaRecuperacion, Colors.greenAccent)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildIndicadorSalud("Morosidad", _morosidad, Colors.redAccent, invertido: true)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildIndicadorSalud("Crecimiento Clientes", _crecimientoClientes, Colors.blueAccent),
                  
                  const SizedBox(height: 25),
                  
                  // Gráfica simulada
                  const Text("Tendencia Mensual", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  
                  PremiumCard(
                    child: SizedBox(
                      height: 150,
                      child: _buildGraficaSimulada(),
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // Acciones rápidas
                  const Text("Acciones Rápidas", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildAccionRapida("Ver Clientes", Icons.people, () => Navigator.pushNamed(context, '/clientes')),
                      _buildAccionRapida("Ver Préstamos", Icons.attach_money, () => Navigator.pushNamed(context, '/prestamos')),
                      _buildAccionRapida("Ver Tandas", Icons.group_work, () => Navigator.pushNamed(context, '/tandas')),
                      _buildAccionRapida("Reportes", Icons.analytics, () => Navigator.pushNamed(context, '/reportes')),
                    ],
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icon, Color color, {String? subtitle}) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(valor, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMetricaRow(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildIndicadorSalud(String titulo, double porcentaje, Color color, {bool invertido = false}) {
    final esPositivo = invertido ? porcentaje < 10 : porcentaje > 50;
    
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (porcentaje / 100).clamp(0, 1),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "${porcentaje.toStringAsFixed(1)}%",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Icon(
                esPositivo ? Icons.trending_up : Icons.trending_down,
                color: esPositivo ? Colors.greenAccent : Colors.redAccent,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaSimulada() {
    return CustomPaint(
      size: const Size(double.infinity, 150),
      painter: _GraficaPainter(),
    );
  }

  Widget _buildAccionRapida(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.blueAccent),
      label: Text(label),
      backgroundColor: Colors.blueAccent.withOpacity(0.1),
      labelStyle: const TextStyle(color: Colors.blueAccent),
      onPressed: onTap,
    );
  }
}

class _GraficaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Datos simulados
    final datos = [0.3, 0.5, 0.4, 0.6, 0.8, 0.7, 0.9, 0.85, 0.75, 0.95, 0.88, 1.0];
    
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < datos.length; i++) {
      final x = (i / (datos.length - 1)) * size.width;
      final y = size.height - (datos[i] * size.height * 0.8) - 10;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint..color = Colors.greenAccent);
    
    // Línea de meta
    final metaPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), metaPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// Panel de Inversión Global
/// Vista consolidada de todas las inversiones y rendimientos del sistema
class SuperadminInversionGlobalScreen extends StatefulWidget {
  const SuperadminInversionGlobalScreen({super.key});

  @override
  State<SuperadminInversionGlobalScreen> createState() => _SuperadminInversionGlobalScreenState();
}

class _SuperadminInversionGlobalScreenState extends State<SuperadminInversionGlobalScreen> {
  bool _isLoading = true;
  final _formatoCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  // Estadísticas globales
  double _totalCapitalActivo = 0;
  double _totalRendimientosMes = 0;
  double _totalPrestamosActivos = 0;
  double _totalCobranzaMes = 0;
  int _totalInversionistas = 0;
  int _totalPrestamosCount = 0;
  
  List<Map<String, dynamic>> _inversionistas = [];
  List<Map<String, dynamic>> _rendimientosPorMes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar colaboradores inversionistas
      final inversionistasData = await AppSupabase.client
          .from('colaboradores')
          .select('*, usuario:usuarios(nombre_completo, email)')
          .eq('tipo_colaborador', 'inversionista')
          .eq('activo', true);
      
      // Cargar capital invertido
      final inversionesData = await AppSupabase.client
          .from('colaborador_inversiones')
          .select('monto, porcentaje_acordado, colaborador_id')
          .eq('estado', 'activa');
      
      // Cargar préstamos activos
      final prestamosData = await AppSupabase.client
          .from('prestamos')
          .select('monto, interes, estado')
          .inFilter('estado', ['activo', 'al_dia']);
      
      // Cargar pagos del mes actual
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final pagosData = await AppSupabase.client
          .from('pagos')
          .select('monto')
          .gte('fecha_pago', inicioMes.toIso8601String());
      
      if (mounted) {
        setState(() {
          _inversionistas = List<Map<String, dynamic>>.from(inversionistasData);
          _totalInversionistas = _inversionistas.length;
          
          // Calcular capital total
          _totalCapitalActivo = 0;
          for (var inv in inversionesData) {
            _totalCapitalActivo += (inv['monto'] ?? 0).toDouble();
          }
          
          // Calcular préstamos
          _totalPrestamosCount = prestamosData.length;
          _totalPrestamosActivos = 0;
          for (var p in prestamosData) {
            _totalPrestamosActivos += (p['monto'] ?? 0).toDouble();
          }
          
          // Calcular cobranza del mes
          _totalCobranzaMes = 0;
          for (var pago in pagosData) {
            _totalCobranzaMes += (pago['monto'] ?? 0).toDouble();
          }
          
          // Rendimientos estimados (10% del total recaudado)
          _totalRendimientosMes = _totalCobranzaMes * 0.10;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos inversión: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📊 Inversión Global',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() => _isLoading = true);
            _cargarDatos();
          },
        ),
      ],
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
                    _buildResumenCards(),
                    const SizedBox(height: 24),
                    _buildTablaInversionistas(),
                    const SizedBox(height: 24),
                    _buildGraficoRendimientos(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResumenCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          '💰 Capital Activo',
          _formatoCurrency.format(_totalCapitalActivo),
          Colors.green,
          Icons.account_balance_wallet,
        ),
        _buildStatCard(
          '📈 Rendimiento Mes',
          _formatoCurrency.format(_totalRendimientosMes),
          Colors.blue,
          Icons.trending_up,
        ),
        _buildStatCard(
          '💳 Préstamos Activos',
          '$_totalPrestamosCount',
          Colors.orange,
          Icons.credit_card,
        ),
        _buildStatCard(
          '👥 Inversionistas',
          '$_totalInversionistas',
          Colors.purple,
          Icons.people,
        ),
        _buildStatCard(
          '💵 Cobranza Mes',
          _formatoCurrency.format(_totalCobranzaMes),
          Colors.teal,
          Icons.payments,
        ),
        _buildStatCard(
          '📊 Cartera Total',
          _formatoCurrency.format(_totalPrestamosActivos),
          Colors.indigo,
          Icons.analytics,
        ),
      ],
    );
  }

  Widget _buildStatCard(String titulo, String valor, Color color, IconData icono) {
    return PremiumCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaInversionistas() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '👥 Inversionistas Activos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_inversionistas.length} total',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_inversionistas.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'No hay inversionistas registrados',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _inversionistas.length,
              separatorBuilder: (_, __) => Divider(color: Colors.grey[800]),
              itemBuilder: (context, index) {
                final inv = _inversionistas[index];
                final usuario = inv['usuario'] as Map<String, dynamic>?;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.purple),
                  ),
                  title: Text(
                    usuario?['nombre_completo'] ?? 'Sin nombre',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    usuario?['email'] ?? '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inv['porcentaje_participacion'] != null
                            ? '${inv['porcentaje_participacion']}%'
                            : '--',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Participación',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGraficoRendimientos() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Proyección de Rendimientos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.blue.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Rendimiento estimado: ${_formatoCurrency.format(_totalRendimientosMes)}/mes',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anualizado: ${_formatoCurrency.format(_totalRendimientosMes * 12)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE ESTADO DE CUENTA DEL INVERSIONISTA
// Vista completa de movimientos, rendimientos y balance
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class EstadoCuentaInversionistaScreen extends StatefulWidget {
  final String? colaboradorId;
  
  const EstadoCuentaInversionistaScreen({super.key, this.colaboradorId});
  
  @override
  State<EstadoCuentaInversionistaScreen> createState() => _EstadoCuentaInversionistaScreenState();
}

class _EstadoCuentaInversionistaScreenState extends State<EstadoCuentaInversionistaScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _colaborador;
  List<Map<String, dynamic>> _movimientos = [];
  
  double _totalAportaciones = 0;
  double _totalRetiros = 0;
  double _totalRendimientos = 0;
  double _rendimientosPendientes = 0;
  double _saldoActual = 0;

  final _moneyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      String colaboradorId = widget.colaboradorId ?? '';
      
      // Si no se proporciona ID, buscar el colaborador actual
      if (colaboradorId.isEmpty) {
        final user = AppSupabase.client.auth.currentUser;
        if (user != null) {
          final colabRes = await AppSupabase.client
              .from('colaboradores')
              .select()
              .eq('auth_uid', user.id)
              .maybeSingle();
          
          if (colabRes != null) {
            colaboradorId = colabRes['id'];
          }
        }
      }

      if (colaboradorId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Cargar datos del colaborador
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('id', colaboradorId)
          .single();
      
      _colaborador = colabRes;

      // Cargar inversiones
      final invRes = await AppSupabase.client
          .from('colaborador_inversiones')
          .select()
          .eq('colaborador_id', colaboradorId)
          .order('fecha', ascending: false);

      // Cargar rendimientos
      final rendRes = await AppSupabase.client
          .from('colaborador_rendimientos')
          .select()
          .eq('colaborador_id', colaboradorId)
          .order('periodo_fin', ascending: false);

      // Combinar y ordenar
      _movimientos = [];
      
      for (var inv in invRes) {
        _movimientos.add({
          'tipo': inv['tipo'] == 'aportacion' ? 'aportacion' : 'retiro',
          'fecha': inv['fecha'],
          'monto': (inv['monto'] as num).toDouble(),
          'concepto': inv['concepto'] ?? (inv['tipo'] == 'aportacion' ? 'Aportación de capital' : 'Retiro de capital'),
          'estado': inv['estado'],
        });
        
        if (inv['tipo'] == 'aportacion' && inv['estado'] == 'confirmado') {
          _totalAportaciones += (inv['monto'] as num).toDouble();
        } else if (inv['tipo'] == 'retiro' && inv['estado'] == 'confirmado') {
          _totalRetiros += (inv['monto'] as num).toDouble();
        }
      }

      for (var rend in rendRes) {
        final monto = (rend['monto_rendimiento'] as num?)?.toDouble() ?? 0;
        _movimientos.add({
          'tipo': 'rendimiento',
          'fecha': rend['periodo_fin'],
          'monto': monto,
          'concepto': 'Rendimiento del periodo',
          'estado': rend['estado'],
          'tasa': rend['tasa_aplicada'],
        });
        
        if (rend['estado'] == 'pagado') {
          _totalRendimientos += monto;
        } else if (rend['estado'] == 'pendiente') {
          _rendimientosPendientes += monto;
        }
      }

      // Ordenar por fecha descendente
      _movimientos.sort((a, b) {
        final fechaA = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime(1900);
        final fechaB = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime(1900);
        return fechaB.compareTo(fechaA);
      });

      // Calcular saldo
      _saldoActual = _totalAportaciones - _totalRetiros + _totalRendimientos;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar estado de cuenta: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '📊 Estado de Cuenta',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          onPressed: _exportarPDF,
          tooltip: 'Exportar PDF',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _colaborador == null
              ? _buildNoAcceso()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeaderBalance(),
                        _buildResumenCards(),
                        _buildMovimientos(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoAcceso() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No tienes acceso a esta información',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBalance() {
    final participacion = (_colaborador?['porcentaje_participacion'] as num?)?.toDouble() ?? 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _getIniciales(_colaborador?['nombre'] ?? ''),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _colaborador?['nombre'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Inversionista • ${participacion.toStringAsFixed(2)}% participación',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'SALDO ACTUAL',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _moneyFormat.format(_saldoActual),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
                if (_rendimientosPendientes > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+ ${_moneyFormat.format(_rendimientosPendientes)} por cobrar',
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Corte al ${_dateFormat.format(DateTime.now())}',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniCard(
              'Aportaciones',
              _moneyFormat.format(_totalAportaciones),
              Icons.arrow_downward,
              const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMiniCard(
              'Retiros',
              _moneyFormat.format(_totalRetiros),
              Icons.arrow_upward,
              const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMiniCard(
              'Rendimientos',
              _moneyFormat.format(_totalRendimientos),
              Icons.trending_up,
              const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientos() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white54),
                const SizedBox(width: 12),
                const Text(
                  'Detalle de Movimientos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${_movimientos.length} registros',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          
          if (_movimientos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      'Sin movimientos',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._movimientos.asMap().entries.map((entry) {
              final index = entry.key;
              final mov = entry.value;
              final esUltimo = index == _movimientos.length - 1;
              
              return _buildMovimientoItem(mov, esUltimo);
            }),
        ],
      ),
    );
  }

  Widget _buildMovimientoItem(Map<String, dynamic> mov, bool esUltimo) {
    final tipo = mov['tipo'] as String;
    final monto = (mov['monto'] as num).toDouble();
    final fecha = DateTime.tryParse(mov['fecha'] ?? '');
    final concepto = mov['concepto'] as String?;
    final estado = mov['estado'] as String?;
    
    Color color;
    IconData icono;
    String signo;
    
    switch (tipo) {
      case 'aportacion':
        color = const Color(0xFF10B981);
        icono = Icons.arrow_downward;
        signo = '+';
        break;
      case 'retiro':
        color = const Color(0xFFEF4444);
        icono = Icons.arrow_upward;
        signo = '-';
        break;
      case 'rendimiento':
        color = const Color(0xFF3B82F6);
        icono = Icons.trending_up;
        signo = '+';
        break;
      default:
        color = Colors.grey;
        icono = Icons.circle;
        signo = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: esUltimo 
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concepto ?? tipo,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (fecha != null)
                      Text(
                        _dateFormat.format(fecha),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                    if (estado != null && estado != 'confirmado' && estado != 'pagado') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          estado.toUpperCase(),
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$signo ${_moneyFormat.format(monto)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getIniciales(String nombre) {
    final partes = nombre.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    } else if (partes.isNotEmpty) {
      return partes[0].substring(0, 2).toUpperCase();
    }
    return '?';
  }

  void _exportarPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF... (próximamente)'),
        backgroundColor: Color(0xFF3B82F6),
      ),
    );
    // TODO: Implementar exportación PDF con el paquete printing
  }
}

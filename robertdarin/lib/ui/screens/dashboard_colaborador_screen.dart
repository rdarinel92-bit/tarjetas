// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/colaboradores_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PARA COLABORADORES
// Cada tipo de colaborador ve su dashboard personalizado
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardColaboradorScreen extends StatefulWidget {
  const DashboardColaboradorScreen({super.key});
  
  @override
  State<DashboardColaboradorScreen> createState() => _DashboardColaboradorScreenState();
}

class _DashboardColaboradorScreenState extends State<DashboardColaboradorScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  bool _isLoading = true;
  ColaboradorModel? _colaborador;
  ColaboradorTipoModel? _tipoColaborador;
  String? _negocioNombre;
  
  // Stats según tipo
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Buscar colaborador por auth_uid
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (colabRes == null) {
        // No es colaborador, redirigir a login normal
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      _colaborador = ColaboradorModel.fromMap(colabRes);

      // Obtener tipo
      if (_colaborador!.tipoId != null) {
        final tipoRes = await AppSupabase.client
            .from('colaborador_tipos')
            .select()
            .eq('id', _colaborador!.tipoId!)
            .single();
        _tipoColaborador = ColaboradorTipoModel.fromMap(tipoRes);
      }

      // Obtener nombre del negocio
      final negocioRes = await AppSupabase.client
          .from('negocios')
          .select('nombre')
          .eq('id', _colaborador!.negocioId)
          .single();
      _negocioNombre = negocioRes['nombre'];

      // Cargar stats según tipo
      await _cargarStatsPorTipo();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar datos colaborador: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarStatsPorTipo() async {
    if (_colaborador == null) return;

    switch (_colaborador!.tipoCodigo) {
      case 'co_superadmin':
      case 'socio_operativo':
        await _cargarStatsOperativos();
        break;
      case 'socio_inversionista':
        await _cargarStatsInversionista();
        break;
      case 'contador':
        await _cargarStatsContador();
        break;
      case 'facturador':
        await _cargarStatsFacturador();
        break;
      default:
        await _cargarStatsBasicos();
    }
  }

  Future<void> _cargarStatsOperativos() async {
    try {
      final negocioId = _colaborador!.negocioId;
      
      // Préstamos activos
      final prestamosRes = await AppSupabase.client
          .from('prestamos')
          .select('id, monto_total')
          .eq('negocio_id', negocioId)
          .eq('estado', 'activo');
      
      double totalPrestamos = 0;
      for (var p in prestamosRes) {
        totalPrestamos += (p['monto_total'] ?? 0).toDouble();
      }

      // Clientes
      final clientesRes = await AppSupabase.client
          .from('clientes')
          .select('id')
          .eq('negocio_id', negocioId);

      // Cobros pendientes hoy
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final cobrosRes = await AppSupabase.client
          .from('amortizaciones')
          .select('id, monto')
          .eq('estado', 'pendiente')
          .lte('fecha_vencimiento', hoy);

      double cobrosPendientes = 0;
      for (var c in cobrosRes) {
        cobrosPendientes += (c['monto'] ?? 0).toDouble();
      }

      _stats = {
        'prestamos_activos': prestamosRes.length,
        'cartera_total': totalPrestamos,
        'clientes': clientesRes.length,
        'cobros_pendientes': cobrosPendientes,
      };
    } catch (e) {
      debugPrint('Error stats operativos: $e');
    }
  }

  Future<void> _cargarStatsInversionista() async {
    try {
      // Stats de inversión
      final inversionesRes = await AppSupabase.client
          .from('colaborador_inversiones')
          .select()
          .eq('colaborador_id', _colaborador!.id);

      double aportaciones = 0;
      double retiros = 0;
      double rendimientos = 0;

      for (var inv in inversionesRes) {
        final monto = (inv['monto'] ?? 0).toDouble();
        switch (inv['tipo']) {
          case 'aportacion':
            aportaciones += monto;
            break;
          case 'retiro':
            retiros += monto;
            break;
          case 'rendimiento':
            rendimientos += monto;
            break;
        }
      }

      _stats = {
        'capital_invertido': _colaborador!.montoInvertido,
        'participacion': _colaborador!.porcentajeParticipacion,
        'rendimiento_pactado': _colaborador!.rendimientoPactado ?? 0,
        'aportaciones': aportaciones,
        'retiros': retiros,
        'rendimientos_pagados': rendimientos,
        'balance_actual': aportaciones - retiros + rendimientos,
      };
    } catch (e) {
      debugPrint('Error stats inversionista: $e');
    }
  }

  Future<void> _cargarStatsContador() async {
    try {
      final negocioId = _colaborador!.negocioId;
      
      // Facturas del mes
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final facturasRes = await AppSupabase.client
          .from('facturas')
          .select('id, total, estado')
          .eq('negocio_id', negocioId)
          .gte('fecha_emision', inicioMes.toIso8601String());

      double facturado = 0;
      int timbradas = 0;
      int pendientes = 0;

      for (var f in facturasRes) {
        if (f['estado'] == 'timbrada') {
          timbradas++;
          facturado += (f['total'] ?? 0).toDouble();
        } else if (f['estado'] == 'borrador' || f['estado'] == 'pendiente') {
          pendientes++;
        }
      }

      // Ingresos del mes (pagos)
      final pagosRes = await AppSupabase.client
          .from('pagos')
          .select('monto')
          .eq('negocio_id', negocioId)
          .eq('estado', 'confirmado')
          .gte('fecha_pago', inicioMes.toIso8601String());

      double ingresos = 0;
      for (var p in pagosRes) {
        ingresos += (p['monto'] ?? 0).toDouble();
      }

      _stats = {
        'facturas_mes': facturasRes.length,
        'facturas_timbradas': timbradas,
        'facturas_pendientes': pendientes,
        'total_facturado': facturado,
        'ingresos_mes': ingresos,
      };
    } catch (e) {
      debugPrint('Error stats contador: $e');
    }
  }

  Future<void> _cargarStatsFacturador() async {
    try {
      // Facturas emitidas por este usuario
      final user = AppSupabase.client.auth.currentUser;
      final facturasRes = await AppSupabase.client
          .from('facturas')
          .select('id, total, estado')
          .eq('created_by', user!.id);

      int emitidas = 0;
      double totalFacturado = 0;

      for (var f in facturasRes) {
        if (f['estado'] == 'timbrada') {
          emitidas++;
          totalFacturado += (f['total'] ?? 0).toDouble();
        }
      }

      _stats = {
        'facturas_emitidas': emitidas,
        'total_facturado': totalFacturado,
      };
    } catch (e) {
      debugPrint('Error stats facturador: $e');
    }
  }

  Future<void> _cargarStatsBasicos() async {
    _stats = {
      'bienvenida': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D14),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PremiumScaffold(
      title: _getTituloPorTipo(),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _cerrarSesion,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildContentPorTipo(),
            ],
          ),
        ),
      ),
    );
  }

  String _getTituloPorTipo() {
    switch (_colaborador?.tipoCodigo) {
      case 'co_superadmin':
        return '👑 Panel Co-Admin';
      case 'socio_operativo':
        return '🤝 Panel Socio';
      case 'socio_inversionista':
        return '📈 Mi Inversión';
      case 'contador':
        return '🧮 Panel Contable';
      case 'asesor':
        return '💼 Panel Asesor';
      case 'facturador':
        return '🧾 Facturación';
      default:
        return '👤 Mi Panel';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _tipoColaborador?.color.withOpacity(0.8) ?? const Color(0xFF3B82F6),
            _tipoColaborador?.color ?? const Color(0xFF1E40AF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _colaborador?.iniciales ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, ${_colaborador?.nombre.split(' ').first ?? 'Usuario'}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tipoColaborador?.nombre ?? 'Colaborador',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                Text(
                  _negocioNombre ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPorTipo() {
    switch (_colaborador?.tipoCodigo) {
      case 'co_superadmin':
      case 'socio_operativo':
        return _buildDashboardOperativo();
      case 'socio_inversionista':
        return _buildDashboardInversionista();
      case 'contador':
        return _buildDashboardContador();
      case 'facturador':
        return _buildDashboardFacturador();
      case 'asesor':
        return _buildDashboardAsesor();
      default:
        return _buildDashboardBasico();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD CO-SUPERADMIN / SOCIO OPERATIVO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardOperativo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats principales
        Row(
          children: [
            _buildStatCard(
              '💰 Cartera',
              _currencyFormat.format(_stats['cartera_total'] ?? 0),
              '${_stats['prestamos_activos'] ?? 0} préstamos',
              const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              '👥 Clientes',
              '${_stats['clientes'] ?? 0}',
              'Registrados',
              const Color(0xFF3B82F6),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          '📅 Cobros Hoy',
          _currencyFormat.format(_stats['cobros_pendientes'] ?? 0),
          'Pendientes de cobrar',
          const Color(0xFFFBBF24),
          fullWidth: true,
        ),
        
        const SizedBox(height: 24),
        
        // Accesos rápidos
        const Text(
          'Accesos Rápidos',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAccesoRapido('Clientes', Icons.people, '/clientes'),
            _buildAccesoRapido('Préstamos', Icons.attach_money, '/prestamos'),
            _buildAccesoRapido('Pagos', Icons.payments, '/pagos'),
            _buildAccesoRapido('Cobros', Icons.receipt_long, '/cobrosPendientes'),
            _buildAccesoRapido('Reportes', Icons.analytics, '/reportes'),
            if (_colaborador?.tipoCodigo == 'co_superadmin')
              _buildAccesoRapido('Todo', Icons.dashboard, '/dashboard'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD INVERSIONISTA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardInversionista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capital invertido
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capital Invertido',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(_stats['capital_invertido'] ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_stats['participacion'] ?? 0}% participación',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_stats['rendimiento_pactado'] ?? 0}% anual',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Movimientos
        Row(
          children: [
            _buildStatCard(
              'Aportaciones',
              _currencyFormat.format(_stats['aportaciones'] ?? 0),
              'Total aportado',
              const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Rendimientos',
              _currencyFormat.format(_stats['rendimientos_pagados'] ?? 0),
              'Recibidos',
              const Color(0xFF3B82F6),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        _buildStatCard(
          '💵 Balance Actual',
          _currencyFormat.format(_stats['balance_actual'] ?? 0),
          'Capital + Rendimientos - Retiros',
          const Color(0xFF8B5CF6),
          fullWidth: true,
        ),
        
        const SizedBox(height: 24),
        
        // Accesos
        const Text(
          'Consultas',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAccesoRapido('Estado de Cuenta', Icons.account_balance, '/colaboradores/estado-cuenta'),
            _buildAccesoRapido('Reportes', Icons.analytics, '/reportes'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD CONTADOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardContador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats facturación
        Row(
          children: [
            _buildStatCard(
              '🧾 Facturas',
              '${_stats['facturas_mes'] ?? 0}',
              'Este mes',
              const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              '✅ Timbradas',
              '${_stats['facturas_timbradas'] ?? 0}',
              'Emitidas',
              const Color(0xFF10B981),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            _buildStatCard(
              '💰 Facturado',
              _currencyFormat.format(_stats['total_facturado'] ?? 0),
              'Este mes',
              const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              '📈 Ingresos',
              _currencyFormat.format(_stats['ingresos_mes'] ?? 0),
              'Cobrados',
              const Color(0xFF10B981),
            ),
          ],
        ),
        
        if ((_stats['facturas_pendientes'] ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFFBBF24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_stats['facturas_pendientes']} facturas pendientes de timbrar',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Accesos
        const Text(
          'Accesos Rápidos',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAccesoRapido('Facturación', Icons.receipt_long, '/facturacion'),
            _buildAccesoRapido('Nueva Factura', Icons.add, '/facturacion/nueva'),
            _buildAccesoRapido('Mis Facturas', Icons.list_alt, '/colaboradores/mis-facturas'),
            _buildAccesoRapido('Reportes', Icons.analytics, '/reportes'),
            _buildAccesoRapido('Pagos', Icons.payments, '/pagos'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD FACTURADOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardFacturador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats
        Row(
          children: [
            _buildStatCard(
              '🧾 Mis Facturas',
              '${_stats['facturas_emitidas'] ?? 0}',
              'Emitidas por mí',
              const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              '💰 Total',
              _currencyFormat.format(_stats['total_facturado'] ?? 0),
              'Facturado',
              const Color(0xFF10B981),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Botón principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/facturacion/nueva'),
            icon: const Icon(Icons.add, size: 28),
            label: const Text('Crear Nueva Factura', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Accesos
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAccesoRapido('Mis Facturas', Icons.list_alt, '/colaboradores/mis-facturas'),
            _buildAccesoRapido('Ver Facturas', Icons.folder_open, '/facturacion'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD ASESOR (SOLO CONSULTA)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardAsesor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.visibility, size: 48, color: Color(0xFFFBBF24)),
              const SizedBox(height: 12),
              const Text(
                'Modo Consulta',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tienes acceso de solo lectura a reportes y análisis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        const Text(
          'Consultas Disponibles',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAccesoRapido('Reportes', Icons.analytics, '/reportes'),
            _buildAccesoRapido('Dashboard KPIs', Icons.trending_up, '/dashboardKpi'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD BÁSICO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardBasico() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 64, color: Color(0xFF10B981)),
          const SizedBox(height: 16),
          const Text(
            '¡Bienvenido!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu cuenta está activa. Contacta al administrador para configurar tus permisos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatCard(String titulo, String valor, String subtitulo, Color color, {bool fullWidth = false}) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitulo,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );

    return fullWidth ? card : Expanded(child: card);
  }

  Widget _buildAccesoRapido(String titulo, IconData icono, String? ruta, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? (ruta != null ? () => Navigator.pushNamed(context, ruta) : null),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: const Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// Ver historial de inversión - disponible para uso futuro
  // ignore: unused_element
  void _verHistorialInversion() {
    // TODO: Mostrar historial de movimientos de inversión
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente: Historial de inversión')),
    );
  }

  Future<void> _cerrarSesion() async {
    await AppSupabase.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}

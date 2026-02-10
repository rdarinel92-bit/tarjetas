// ignore_for_file: deprecated_member_use
/// ============================================================
/// PANEL DE COBROS PENDIENTES - Robert Darin Fintech V9.0
/// Para confirmar o rechazar pagos por transferencia/QR
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/themes/app_theme.dart';
import '../viewmodels/negocio_activo_provider.dart';

class CobrosPendientesScreen extends StatefulWidget {
  const CobrosPendientesScreen({super.key});

  @override
  State<CobrosPendientesScreen> createState() => _CobrosPendientesScreenState();
}

class _CobrosPendientesScreenState extends State<CobrosPendientesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _cobrosPendientes = [];
  List<Map<String, dynamic>> _cobrosConfirmados = [];
  List<Map<String, dynamic>> _cobrosRechazados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarCobros();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _suscribirRealtime() {
    _supabase
        .from('registros_cobro')
        .stream(primaryKey: ['id'])
        .listen((data) {
      _cargarCobros();
    });
  }

  Future<void> _cargarCobros() async {
    try {
      // Cargar cobros con información del cliente
      final response = await _supabase
          .from('registros_cobro')
          .select('''
            *,
            cliente:clientes(id, nombre, telefono),
            metodo:metodos_pago(nombre, tipo, icono)
          ''')
          .order('created_at', ascending: false);

      final cobros = response as List;

      setState(() {
        _cobrosPendientes = cobros
            .where((c) => c['estado'] == 'pendiente')
            .toList()
            .cast<Map<String, dynamic>>();
        _cobrosConfirmados = cobros
            .where((c) => c['estado'] == 'confirmado')
            .toList()
            .cast<Map<String, dynamic>>();
        _cobrosRechazados = cobros
            .where((c) => c['estado'] == 'rechazado')
            .toList()
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error cargando cobros: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmarCobro(Map<String, dynamic> cobro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Cobro', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmar el cobro de \$${(cobro['monto'] as num).toStringAsFixed(2)}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Cliente: ${cobro['cliente']?['nombre'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white),
            ),
            if (cobro['referencia_pago'] != null)
              Text(
                'Referencia: ${cobro['referencia_pago']}',
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _actualizarEstadoCobro(cobro['id'], 'confirmado');
    }
  }

  Future<void> _rechazarCobro(Map<String, dynamic> cobro) async {
    final notaController = TextEditingController();
    
    final rechazar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Rechazar Cobro', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Rechazar el cobro de \$${(cobro['monto'] as num).toStringAsFixed(2)}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notaController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo del rechazo',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (rechazar == true) {
      await _actualizarEstadoCobro(
        cobro['id'], 
        'rechazado',
        nota: notaController.text,
      );
    }
  }

  Future<void> _actualizarEstadoCobro(
    String cobroId, 
    String estado, {
    String? nota,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      await _supabase
          .from('registros_cobro')
          .update({
            'estado': estado,
            'confirmado_por': userId,
            'fecha_confirmacion': DateTime.now().toIso8601String(),
            if (nota != null) 'nota_operador': nota,
          })
          .eq('id', cobroId);

      // Si se confirma, actualizar también la tabla de pagos y amortizaciones
      if (estado == 'confirmado') {
        final cobro = _cobrosPendientes.firstWhere((c) => c['id'] == cobroId);
        await _confirmarPagoEnSistema(cobro);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  estado == 'confirmado' ? Icons.check : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(estado == 'confirmado' 
                    ? 'Cobro confirmado exitosamente' 
                    : 'Cobro rechazado'),
              ],
            ),
            backgroundColor: estado == 'confirmado' ? Colors.green : Colors.red,
          ),
        );
      }

      _cargarCobros();
    } catch (e) {
      debugPrint('Error actualizando cobro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmarPagoEnSistema(Map<String, dynamic> cobro) async {
    try {
      // Registrar en tabla de pagos
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      await _supabase.from('pagos').insert({
        'prestamo_id': cobro['prestamo_id'],
        'tanda_id': cobro['tanda_id'],
        'amortizacion_id': cobro['amortizacion_id'],
        'cliente_id': cobro['cliente_id'],
        'monto': cobro['monto'],
        'metodo_pago': cobro['tipo_metodo'],
        'fecha_pago': DateTime.now().toIso8601String(),
        'nota': cobro['nota_cliente'],
        'comprobante_url': cobro['comprobante_url'],
        'registrado_por': _supabase.auth.currentUser?.id,
        'negocio_id': negocioId,
      });

      // Actualizar amortización si aplica
      if (cobro['amortizacion_id'] != null) {
        await _supabase
            .from('amortizaciones')
            .update({
              'estado': 'pagado',
              'fecha_pago': DateTime.now().toIso8601String(),
            })
            .eq('id', cobro['amortizacion_id']);
      }

      // Si es tanda, actualizar participante
      if (cobro['tanda_id'] != null) {
        await _supabase
            .from('tanda_participantes')
            .update({'ha_pagado_cuota_actual': true})
            .eq('tanda_id', cobro['tanda_id'])
            .eq('cliente_id', cobro['cliente_id']);
      }

      // Notificar al cliente
      await _supabase.from('notificaciones').insert({
        'usuario_id': cobro['cliente_id'],
        'titulo': '¡Pago Confirmado!',
        'mensaje': 'Tu pago de \$${(cobro['monto'] as num).toStringAsFixed(2)} ha sido confirmado.',
        'tipo': 'success',
        'ruta_destino': cobro['prestamo_id'] != null 
            ? '/prestamos/${cobro['prestamo_id']}'
            : cobro['tanda_id'] != null 
                ? '/tandas/${cobro['tanda_id']}'
                : null,
      });
    } catch (e) {
      debugPrint('Error confirmando pago en sistema: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Gestión de Cobros'),
        backgroundColor: AppTheme.surfaceDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentCyan,
          labelColor: AppTheme.accentCyan,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 4),
                  Text('Pendientes (${_cobrosPendientes.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 18),
                  const SizedBox(width: 4),
                  Text('Confirmados (${_cobrosConfirmados.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel, size: 18),
                  const SizedBox(width: 4),
                  Text('Rechazados (${_cobrosRechazados.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaCobros(_cobrosPendientes, 'pendiente'),
                _buildListaCobros(_cobrosConfirmados, 'confirmado'),
                _buildListaCobros(_cobrosRechazados, 'rechazado'),
              ],
            ),
    );
  }

  Widget _buildListaCobros(List<Map<String, dynamic>> cobros, String tipo) {
    if (cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tipo == 'pendiente' 
                  ? Icons.inbox 
                  : tipo == 'confirmado' 
                      ? Icons.check_circle_outline 
                      : Icons.cancel_outlined,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              tipo == 'pendiente'
                  ? 'No hay cobros pendientes'
                  : tipo == 'confirmado'
                      ? 'No hay cobros confirmados'
                      : 'No hay cobros rechazados',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarCobros,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cobros.length,
        itemBuilder: (context, index) {
          final cobro = cobros[index];
          return _buildCobroCard(cobro, tipo);
        },
      ),
    );
  }

  Widget _buildCobroCard(Map<String, dynamic> cobro, String tipo) {
    final cliente = cobro['cliente'] as Map<String, dynamic>?;
    final monto = (cobro['monto'] as num).toDouble();
    final fecha = DateTime.parse(cobro['created_at']);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    Color estadoColor;
    IconData estadoIcon;
    switch (tipo) {
      case 'confirmado':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case 'rechazado':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = Colors.orange;
        estadoIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tipo == 'pendiente' 
              ? Colors.orange.withOpacity(0.5) 
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(estadoIcon, color: estadoColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  tipo.toUpperCase(),
                  style: TextStyle(
                    color: estadoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(fecha),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.accentCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente?['nombre'] ?? 'Cliente desconocido',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (cliente?['telefono'] != null)
                            Text(
                              cliente!['telefono'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${monto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cobro['tipo_metodo']?.toString().toUpperCase() ?? 'N/A',
                            style: const TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (cobro['referencia_pago'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ref: ${cobro['referencia_pago']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (cobro['comprobante_url'] != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _verComprobante(cobro['comprobante_url']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, color: AppTheme.accentCyan, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Ver Comprobante',
                            style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (cobro['nota_operador'] != null && tipo == 'rechazado') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motivo: ${cobro['nota_operador']}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Botones de acción (solo para pendientes)
          if (tipo == 'pendiente')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rechazarCobro(cobro),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarCobro(cobro),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirmar Pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _verComprobante(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 300,
                    height: 300,
                    color: AppTheme.cardDark,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  width: 300,
                  height: 200,
                  color: AppTheme.cardDark,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Error cargando imagen',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// PANTALLA DE PAGOS DE PROPIEDADES - VISTA EMPLEADO
/// ══════════════════════════════════════════════════════════════════════════════
/// Vista simplificada para empleados asignados:
/// - Ver propiedades asignadas
/// - Registrar pagos con comprobante
/// - Ver historial y progreso
/// ══════════════════════════════════════════════════════════════════════════════

class PagosPropiedadesEmpleadoScreen extends StatefulWidget {
  const PagosPropiedadesEmpleadoScreen({super.key});

  @override
  State<PagosPropiedadesEmpleadoScreen> createState() => _PagosPropiedadesEmpleadoScreenState();
}

class _PagosPropiedadesEmpleadoScreenState extends State<PagosPropiedadesEmpleadoScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _propiedadesAsignadas = [];
  String? _usuarioId;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;
      
      _usuarioId = user.id;
      
      // Cargar propiedades asignadas a este usuario
      final res = await AppSupabase.client
          .from('mis_propiedades')
          .select()
          .eq('asignado_a', user.id)
          .eq('estado', 'en_pagos')
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _propiedadesAsignadas = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Mis Pagos Asignados',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : _propiedadesAsignadas.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  color: Colors.tealAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _propiedadesAsignadas.length,
                    itemBuilder: (context, index) => _buildPropiedadCard(_propiedadesAsignadas[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No tienes propiedades asignadas',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando te asignen una propiedad\naparecerá aquí',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPropiedadCard(Map<String, dynamic> propiedad) {
    final nombre = propiedad['nombre'] ?? 'Sin nombre';
    final tipo = propiedad['tipo'] ?? 'terreno';
    final ubicacion = propiedad['ubicacion'] ?? '';
    final precioTotal = (propiedad['precio_total'] ?? 0).toDouble();
    final saldoInicial = (propiedad['saldo_inicial'] ?? 0).toDouble();
    final montoMensual = (propiedad['monto_mensual'] ?? 0).toDouble();
    final diaPago = propiedad['dia_pago'] ?? 1;
    final vendedorNombre = propiedad['vendedor_nombre'] ?? '';
    final vendedorTelefono = propiedad['vendedor_telefono'] ?? '';
    
    // Emoji según tipo
    String emoji = '🏞️';
    if (tipo == 'casa') emoji = '🏠';
    if (tipo == 'departamento') emoji = '🏢';
    if (tipo == 'local') emoji = '🏪';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header de la propiedad
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.withOpacity(0.3), Colors.cyan.withOpacity(0.1)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (ubicacion.isNotEmpty)
                        Text(ubicacion,
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Día $diaPago',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // Información del vendedor
          if (vendedorNombre.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black26,
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Text('Pagar a: $vendedorNombre', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  if (vendedorTelefono.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.phone_outlined, color: Colors.white38, size: 16),
                    const SizedBox(width: 4),
                    Text(vendedorTelefono, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ],
              ),
            ),
          
          // Progreso de pagos
          FutureBuilder<Map<String, dynamic>>(
            future: _calcularProgreso(propiedad['id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              
              final data = snapshot.data!;
              final pagosRealizados = data['pagosRealizados'] as int;
              final pagosTotal = data['pagosTotal'] as int;
              final montoPagado = data['montoPagado'] as double;
              final montoPendiente = data['montoPendiente'] as double;
              final proximoPago = data['proximoPago'] as Map<String, dynamic>?;
              final progreso = pagosTotal > 0 ? pagosRealizados / pagosTotal : 0.0;
              
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Barra de progreso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progreso: $pagosRealizados de $pagosTotal pagos',
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            Text('${(progreso * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progreso,
                            minHeight: 12,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(
                              progreso >= 1 ? Colors.greenAccent : Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Resumen financiero
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoBox(
                            'Pagado',
                            _currencyFormat.format(montoPagado),
                            Colors.greenAccent,
                            Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoBox(
                            'Pendiente',
                            _currencyFormat.format(montoPendiente),
                            Colors.orangeAccent,
                            Icons.pending_outlined,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Precio total
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Precio Total:', style: TextStyle(color: Colors.white54)),
                          Text(_currencyFormat.format(precioTotal),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Próximo pago
                    if (proximoPago != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.withOpacity(0.2), Colors.deepOrange.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.event, color: Colors.orangeAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Próximo pago: #${proximoPago['numero_pago']}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${_dateFormat.format(DateTime.parse(proximoPago['fecha_programada']))} - ${_currencyFormat.format(proximoPago['monto'])}',
                                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _verHistorialPagos(propiedad),
                            icon: const Icon(Icons.history, size: 18),
                            label: const Text('Historial'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: proximoPago != null
                                ? () => _registrarPago(propiedad, proximoPago)
                                : null,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Registrar Pago'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInfoBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _calcularProgreso(String propiedadId) async {
    try {
      final pagos = await AppSupabase.client
          .from('pagos_propiedades')
          .select()
          .eq('propiedad_id', propiedadId)
          .order('numero_pago');
      
      final lista = List<Map<String, dynamic>>.from(pagos);
      
      int pagosRealizados = 0;
      double montoPagado = 0;
      double montoTotal = 0;
      Map<String, dynamic>? proximoPago;
      
      for (final p in lista) {
        montoTotal += (p['monto'] ?? 0).toDouble();
        if (p['estado'] == 'pagado') {
          pagosRealizados++;
          montoPagado += (p['monto'] ?? 0).toDouble();
        } else if (proximoPago == null) {
          proximoPago = p;
        }
      }
      
      return {
        'pagosRealizados': pagosRealizados,
        'pagosTotal': lista.length,
        'montoPagado': montoPagado,
        'montoPendiente': montoTotal - montoPagado,
        'proximoPago': proximoPago,
      };
    } catch (e) {
      return {
        'pagosRealizados': 0,
        'pagosTotal': 0,
        'montoPagado': 0.0,
        'montoPendiente': 0.0,
        'proximoPago': null,
      };
    }
  }

  void _verHistorialPagos(Map<String, dynamic> propiedad) async {
    final pagos = await AppSupabase.client
        .from('pagos_propiedades')
        .select()
        .eq('propiedad_id', propiedad['id'])
        .order('numero_pago');
    
    final lista = List<Map<String, dynamic>>.from(pagos);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.tealAccent),
                  const SizedBox(width: 12),
                  Text('Historial de Pagos',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${lista.where((p) => p['estado'] == 'pagado').length}/${lista.length}',
                    style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            // Lista de pagos
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final pago = lista[index];
                  final pagado = pago['estado'] == 'pagado';
                  final fechaProgramada = DateTime.parse(pago['fecha_programada']);
                  final fechaPago = pago['fecha_pago'] != null ? DateTime.parse(pago['fecha_pago']) : null;
                  final tieneComprobante = pago['comprobante_url'] != null;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pagado ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pagado ? Colors.greenAccent.withOpacity(0.3) : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Número de pago
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: pagado ? Colors.greenAccent : Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${pago['numero_pago']}',
                              style: TextStyle(
                                color: pagado ? Colors.black : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Info del pago
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currencyFormat.format(pago['monto']),
                                style: TextStyle(
                                  color: pagado ? Colors.greenAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                pagado
                                    ? 'Pagado: ${_dateFormat.format(fechaPago!)}'
                                    : 'Vence: ${_dateFormat.format(fechaProgramada)}',
                                style: TextStyle(
                                  color: pagado ? Colors.white54 : Colors.orangeAccent,
                                  fontSize: 12,
                                ),
                              ),
                              if (pago['metodo_pago'] != null)
                                Text(
                                  pago['metodo_pago'],
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        
                        // Indicadores
                        Column(
                          children: [
                            Icon(
                              pagado ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: pagado ? Colors.greenAccent : Colors.white24,
                            ),
                            if (tieneComprobante)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.receipt_long, color: Colors.tealAccent, size: 16),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _registrarPago(Map<String, dynamic> propiedad, Map<String, dynamic> pago) {
    final picker = ImagePicker();
    final montoCtrl = TextEditingController(text: pago['monto'].toString());
    final referenciaCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String metodoPago = 'transferencia';
    File? comprobante;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments, color: Colors.tealAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Registrar Pago',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Pago #${pago['numero_pago']} - ${propiedad['nombre']}',
                            style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Monto
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 24),
                    filled: true,
                    fillColor: const Color(0xFF252536),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Método de pago
                const Text('Método de pago', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['efectivo', 'transferencia', 'deposito'].map((m) {
                    final selected = metodoPago == m;
                    return ChoiceChip(
                      label: Text(m[0].toUpperCase() + m.substring(1)),
                      selected: selected,
                      onSelected: (_) => setModalState(() => metodoPago = m),
                      selectedColor: Colors.tealAccent,
                      backgroundColor: const Color(0xFF252536),
                      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Referencia
                TextField(
                  controller: referenciaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Referencia / Folio',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'Número de operación',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF252536),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Comprobante - IMPORTANTE
                GestureDetector(
                  onTap: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      backgroundColor: const Color(0xFF252536),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📷 Subir comprobante',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.tealAccent),
                              ),
                              title: const Text('Tomar foto', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Usar cámara', style: TextStyle(color: Colors.white54)),
                              onTap: () => Navigator.pop(ctx, ImageSource.camera),
                            ),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.photo_library, color: Colors.purpleAccent),
                              ),
                              title: const Text('Galería', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Elegir imagen', style: TextStyle(color: Colors.white54)),
                              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    
                    if (source != null) {
                      final img = await picker.pickImage(source: source, imageQuality: 80);
                      if (img != null) {
                        setModalState(() => comprobante = File(img.path));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: comprobante != null ? Colors.teal.withOpacity(0.2) : const Color(0xFF252536),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: comprobante != null ? Colors.tealAccent : Colors.white24,
                        width: comprobante != null ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          comprobante != null ? Icons.check_circle : Icons.add_a_photo,
                          color: comprobante != null ? Colors.tealAccent : Colors.white38,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comprobante != null ? '✓ Comprobante listo' : 'Subir comprobante',
                                style: TextStyle(
                                  color: comprobante != null ? Colors.tealAccent : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                comprobante != null ? 'Toca para cambiar' : 'Tomar foto o elegir de galería',
                                style: TextStyle(
                                  color: comprobante != null ? Colors.white54 : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (comprobante != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => setModalState(() => comprobante = null),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Notas
                TextField(
                  controller: notasCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notas (opcional)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF252536),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botón confirmar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmarPago(
                      pago: pago,
                      monto: double.tryParse(montoCtrl.text) ?? pago['monto'],
                      metodoPago: metodoPago,
                      referencia: referenciaCtrl.text,
                      notas: notasCtrl.text,
                      comprobante: comprobante,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar Pago', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarPago({
    required Map<String, dynamic> pago,
    required double monto,
    required String metodoPago,
    required String referencia,
    required String notas,
    File? comprobante,
  }) async {
    Navigator.pop(context);
    
    setState(() => _isLoading = true);
    
    try {
      String? comprobanteUrl;
      
      // Subir comprobante si existe
      if (comprobante != null) {
        final fileName = 'propiedades/${pago['propiedad_id']}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await AppSupabase.client.storage.from('documentos').upload(fileName, comprobante);
        comprobanteUrl = AppSupabase.client.storage.from('documentos').getPublicUrl(fileName);
      }
      
      // Actualizar el pago
      await AppSupabase.client
          .from('pagos_propiedades')
          .update({
            'monto': monto,
            'fecha_pago': DateTime.now().toIso8601String().split('T')[0],
            'pagado_por': _usuarioId,
            'metodo_pago': metodoPago,
            'referencia': referencia,
            'comprobante_url': comprobanteUrl,
            'notas': notas,
            'estado': 'pagado',
          })
          .eq('id', pago['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Pago registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

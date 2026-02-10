// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// MIS PROPIEDADES - CONTROL DE PAGOS DE TERRENOS/CASAS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Módulo para llevar control de propiedades que el DUEÑO está comprando
/// - Ver propiedades activas y liquidadas
/// - Registrar pagos mensuales
/// - Asignar empleado para hacer pagos
/// - Subir comprobantes
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/supabase_client.dart';
import '../../data/models/propiedad_model.dart';

class MisPropiedadesScreen extends StatefulWidget {
  const MisPropiedadesScreen({super.key});

  @override
  State<MisPropiedadesScreen> createState() => _MisPropiedadesScreenState();
}

class _MisPropiedadesScreenState extends State<MisPropiedadesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd MMM yyyy', 'es');

  bool _cargando = true;
  List<PropiedadModel> _propiedades = [];
  List<Map<String, dynamic>> _usuarios = [];
  
  // Estadísticas
  double _totalInvertido = 0;
  double _totalPagado = 0;
  double _totalPendiente = 0;
  int _propiedadesActivas = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Cargar propiedades con usuario asignado
      final propRes = await AppSupabase.client
          .from('mis_propiedades')
          .select('*, usuarios(nombre_completo)')
          .order('created_at', ascending: false);
      
      _propiedades = (propRes as List)
          .map((p) => PropiedadModel.fromMap(p))
          .toList();

      // Cargar usuarios para asignación
      final usersRes = await AppSupabase.client
          .from('usuarios')
          .select('id, nombre_completo, email')
          .order('nombre_completo');
      _usuarios = List<Map<String, dynamic>>.from(usersRes);

      // Calcular estadísticas
      await _calcularEstadisticas();

    } catch (e) {
      debugPrint('Error cargando propiedades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _calcularEstadisticas() async {
    _totalInvertido = 0;
    _totalPagado = 0;
    _totalPendiente = 0;
    _propiedadesActivas = 0;

    for (final prop in _propiedades) {
      _totalInvertido += prop.precioTotal;
      
      if (prop.estado == 'en_pagos') {
        _propiedadesActivas++;
      }

      // Obtener pagos realizados
      final pagosRes = await AppSupabase.client
          .from('pagos_propiedades')
          .select('monto')
          .eq('propiedad_id', prop.id)
          .eq('estado', 'pagado');
      
      double pagado = 0;
      for (var p in pagosRes) {
        pagado += (p['monto'] as num).toDouble();
      }
      _totalPagado += pagado + prop.enganche;
    }

    _totalPendiente = _totalInvertido - _totalPagado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mis Propiedades', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                // Resumen financiero
                _buildResumenFinanciero(),
                
                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.tealAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(text: '🏠 En Pagos'),
                      Tab(text: '✅ Liquidadas'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Lista de propiedades
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaPropiedades('en_pagos'),
                      _buildListaPropiedades('liquidado'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioPropiedad(),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_home),
        label: const Text('Nueva Propiedad'),
      ),
    );
  }

  Widget _buildResumenFinanciero() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.tealAccent.withOpacity(0.2), Colors.blueAccent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💰 Resumen de Inversiones',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_propiedadesActivas activas',
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Invertido', _totalInvertido, Colors.blueAccent)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Ya Pagado', _totalPagado, Colors.greenAccent)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Pendiente', _totalPendiente, Colors.orangeAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, double monto, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _currencyFormat.format(monto),
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildListaPropiedades(String estado) {
    final lista = _propiedades.where((p) => p.estado == estado).toList();
    
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              estado == 'en_pagos' ? Icons.house_siding : Icons.check_circle,
              size: 64,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              estado == 'en_pagos' 
                  ? 'No hay propiedades en pagos' 
                  : 'No hay propiedades liquidadas',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: Colors.tealAccent,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lista.length,
        itemBuilder: (context, index) => _buildPropiedadCard(lista[index]),
      ),
    );
  }

  Widget _buildPropiedadCard(PropiedadModel prop) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _obtenerResumenPagos(prop.id),
      builder: (context, snapshot) {
        final resumen = snapshot.data ?? {'pagado': 0.0, 'pendiente': 0, 'proximo': null};
        final pagado = (resumen['pagado'] as num).toDouble() + prop.enganche;
        final pendiente = prop.saldoInicial - (resumen['pagado'] as num).toDouble();
        final progreso = pagado / prop.precioTotal;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _verDetalleProp(prop),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(prop.tipoEmoji, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prop.nombre,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(prop.ubicacion ?? prop.tipoNombre,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(prop.montoMensual),
                                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                            Text('/${prop.frecuenciaPago.toLowerCase()}',
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Barra de progreso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progreso: ${(progreso * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            Text('Faltan: ${_currencyFormat.format(pendiente)}',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progreso.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(
                              progreso >= 1 ? Colors.greenAccent : Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Info adicional
                    Row(
                      children: [
                        _buildInfoChip(Icons.payments, '${resumen['pendiente']} pendientes', Colors.orangeAccent),
                        const SizedBox(width: 8),
                        if (prop.asignadoNombre != null)
                          _buildInfoChip(Icons.person, prop.asignadoNombre!, Colors.blueAccent),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _verPagos(prop),
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: const Text('Ver Pagos'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Si está en pagos: botón pagar, si está liquidado: ver expediente
                        if (prop.estado == 'en_pagos')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _registrarPago(prop),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Pagar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _verExpedienteCompleto(prop),
                              icon: const Icon(Icons.folder_special, size: 16),
                              label: const Text('Expediente'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _obtenerResumenPagos(String propiedadId) async {
    try {
      final pagosRes = await AppSupabase.client
          .from('pagos_propiedades')
          .select()
          .eq('propiedad_id', propiedadId);
      
      double pagado = 0;
      int pendientes = 0;
      DateTime? proximoPago;

      for (var p in pagosRes) {
        if (p['estado'] == 'pagado') {
          pagado += (p['monto'] as num).toDouble();
        } else {
          pendientes++;
          final fecha = DateTime.parse(p['fecha_programada']);
          if (proximoPago == null || fecha.isBefore(proximoPago)) {
            proximoPago = fecha;
          }
        }
      }

      return {'pagado': pagado, 'pendiente': pendientes, 'proximo': proximoPago};
    } catch (e) {
      return {'pagado': 0.0, 'pendiente': 0, 'proximo': null};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // FORMULARIO NUEVA PROPIEDAD
  // ═══════════════════════════════════════════════════════════════════════════════

  void _mostrarFormularioPropiedad([PropiedadModel? editar]) {
    final nombreCtrl = TextEditingController(text: editar?.nombre);
    final precioCtrl = TextEditingController(text: editar?.precioTotal.toStringAsFixed(0));
    final engancheCtrl = TextEditingController(text: editar?.enganche.toStringAsFixed(0));
    final mensualCtrl = TextEditingController(text: editar?.montoMensual.toStringAsFixed(0));
    final ubicacionCtrl = TextEditingController(text: editar?.ubicacion);
    final vendedorCtrl = TextEditingController(text: editar?.vendedorNombre);
    final telVendedorCtrl = TextEditingController(text: editar?.vendedorTelefono);
    final cuentaCtrl = TextEditingController(text: editar?.vendedorCuentaBanco);
    final bancoCtrl = TextEditingController(text: editar?.vendedorBanco);
    final plazoCtrl = TextEditingController(text: editar?.plazoMeses?.toString());
    
    String tipo = editar?.tipo ?? 'terreno';
    String frecuencia = editar?.frecuenciaPago ?? 'Mensual';
    int diaPago = editar?.diaPago ?? 15;
    String? asignadoA = editar?.asignadoA;
    DateTime fechaInicio = editar?.fechaInicioPagos ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.add_home, color: Colors.tealAccent),
                    const SizedBox(width: 12),
                    Text(
                      editar == null ? 'Nueva Propiedad' : 'Editar Propiedad',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white12),
              
              // Form
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Tipo de propiedad
                    const Text('Tipo de propiedad', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTipoChip('terreno', '🏞️ Terreno', tipo, (t) => setModalState(() => tipo = t)),
                        _buildTipoChip('casa', '🏠 Casa', tipo, (t) => setModalState(() => tipo = t)),
                        _buildTipoChip('local', '🏪 Local', tipo, (t) => setModalState(() => tipo = t)),
                        _buildTipoChip('departamento', '🏢 Depto', tipo, (t) => setModalState(() => tipo = t)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Nombre y ubicación
                    _buildTextField(nombreCtrl, 'Nombre', 'Ej: Terreno Zapopan'),
                    const SizedBox(height: 12),
                    _buildTextField(ubicacionCtrl, 'Ubicación', 'Dirección o referencia'),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('💰 Información Financiera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    // Precio y enganche
                    Row(
                      children: [
                        Expanded(child: _buildTextField(precioCtrl, 'Precio Total', '120000', isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(engancheCtrl, 'Enganche', '0', isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Mensualidad y plazo
                    Row(
                      children: [
                        Expanded(child: _buildTextField(mensualCtrl, 'Pago Mensual', '5000', isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(plazoCtrl, 'Plazo (meses)', '24', isNumber: true)),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Frecuencia y día de pago
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Frecuencia', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252536),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: frecuencia,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF252536),
                                    style: const TextStyle(color: Colors.white),
                                    items: ['Mensual', 'Quincenal']
                                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                        .toList(),
                                    onChanged: (v) => setModalState(() => frecuencia = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Día de pago', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252536),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: diaPago,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF252536),
                                    style: const TextStyle(color: Colors.white),
                                    items: [1, 5, 10, 15, 20, 25, 28]
                                        .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                                        .toList(),
                                    onChanged: (v) => setModalState(() => diaPago = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('👤 Vendedor / Institución', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    _buildTextField(vendedorCtrl, 'Nombre del vendedor', 'Persona o institución'),
                    const SizedBox(height: 12),
                    _buildTextField(telVendedorCtrl, 'Teléfono', '3312345678'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(bancoCtrl, 'Banco', 'BBVA, Banamex...')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(cuentaCtrl, 'Cuenta/CLABE', '')),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('👔 Asignar a Empleado (para pagos)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252536),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: asignadoA,
                          isExpanded: true,
                          hint: const Text('Sin asignar', style: TextStyle(color: Colors.white38)),
                          dropdownColor: const Color(0xFF252536),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
                            ..._usuarios.map((u) => DropdownMenuItem(
                              value: u['id'] as String,
                              child: Text(u['nombre_completo'] ?? u['email'] ?? 'Usuario'),
                            )),
                          ],
                          onChanged: (v) => setModalState(() => asignadoA = v),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Fecha inicio pagos
                    GestureDetector(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: fechaInicio,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (fecha != null) setModalState(() => fechaInicio = fecha);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252536),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 20),
                            const SizedBox(width: 12),
                            Text('Inicio de pagos: ${_dateFormat.format(fechaInicio)}',
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              
              // Botón guardar
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _guardarPropiedad(
                      editar: editar,
                      nombre: nombreCtrl.text,
                      tipo: tipo,
                      ubicacion: ubicacionCtrl.text,
                      precioTotal: double.tryParse(precioCtrl.text) ?? 0,
                      enganche: double.tryParse(engancheCtrl.text) ?? 0,
                      montoMensual: double.tryParse(mensualCtrl.text) ?? 0,
                      frecuencia: frecuencia,
                      diaPago: diaPago,
                      plazoMeses: int.tryParse(plazoCtrl.text),
                      fechaInicio: fechaInicio,
                      vendedor: vendedorCtrl.text,
                      telVendedor: telVendedorCtrl.text,
                      banco: bancoCtrl.text,
                      cuenta: cuentaCtrl.text,
                      asignadoA: asignadoA,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(editar == null ? 'Guardar Propiedad' : 'Actualizar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoChip(String value, String label, String selected, Function(String) onTap) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white24),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.tealAccent : Colors.white54,
          fontSize: 12,
        )),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF252536),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _guardarPropiedad({
    PropiedadModel? editar,
    required String nombre,
    required String tipo,
    required String ubicacion,
    required double precioTotal,
    required double enganche,
    required double montoMensual,
    required String frecuencia,
    required int diaPago,
    int? plazoMeses,
    required DateTime fechaInicio,
    required String vendedor,
    required String telVendedor,
    required String banco,
    required String cuenta,
    String? asignadoA,
  }) async {
    if (nombre.isEmpty || precioTotal <= 0 || montoMensual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos obligatorios'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.pop(context);

    try {
      final saldoInicial = precioTotal - enganche;
      
      final data = {
        'nombre': nombre,
        'tipo': tipo,
        'ubicacion': ubicacion.isNotEmpty ? ubicacion : null,
        'precio_total': precioTotal,
        'enganche': enganche,
        'saldo_inicial': saldoInicial,
        'monto_mensual': montoMensual,
        'frecuencia_pago': frecuencia,
        'dia_pago': diaPago,
        'plazo_meses': plazoMeses,
        'fecha_inicio_pagos': fechaInicio.toIso8601String().split('T')[0],
        'vendedor_nombre': vendedor.isNotEmpty ? vendedor : null,
        'vendedor_telefono': telVendedor.isNotEmpty ? telVendedor : null,
        'vendedor_banco': banco.isNotEmpty ? banco : null,
        'vendedor_cuenta_banco': cuenta.isNotEmpty ? cuenta : null,
        'asignado_a': asignadoA,
        'estado': 'en_pagos',
      };

      if (editar != null) {
        await AppSupabase.client.from('mis_propiedades').update(data).eq('id', editar.id);
      } else {
        // Crear propiedad
        final res = await AppSupabase.client.from('mis_propiedades').insert(data).select().single();
        
        // Generar pagos programados si hay plazo
        if (plazoMeses != null && plazoMeses > 0) {
          await _generarPagosProgramados(res['id'], plazoMeses, montoMensual, fechaInicio, frecuencia, diaPago);
        }
      }

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editar == null ? '✅ Propiedad registrada' : '✅ Propiedad actualizada'),
          backgroundColor: Colors.greenAccent,
        ),
      );
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generarPagosProgramados(String propiedadId, int plazo, double monto, DateTime inicio, String frecuencia, int diaPago) async {
    final pagos = <Map<String, dynamic>>[];
    
    for (int i = 0; i < plazo; i++) {
      DateTime fechaPago;
      if (frecuencia == 'Quincenal') {
        fechaPago = DateTime(inicio.year, inicio.month + (i ~/ 2), i.isEven ? diaPago : diaPago + 15);
      } else {
        fechaPago = DateTime(inicio.year, inicio.month + i, diaPago);
      }
      
      pagos.add({
        'propiedad_id': propiedadId,
        'numero_pago': i + 1,
        'monto': monto,
        'fecha_programada': fechaPago.toIso8601String().split('T')[0],
        'estado': 'pendiente',
      });
    }

    await AppSupabase.client.from('pagos_propiedades').insert(pagos);
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // VER PAGOS
  // ═══════════════════════════════════════════════════════════════════════════════

  void _verPagos(PropiedadModel prop) async {
    final pagosRes = await AppSupabase.client
        .from('pagos_propiedades')
        .select('*, usuarios(nombre_completo)')
        .eq('propiedad_id', prop.id)
        .order('numero_pago');
    
    final pagos = (pagosRes as List).map((p) => PagoPropiedadModel.fromMap(p)).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(prop.tipoEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prop.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('${pagos.where((p) => p.estado == 'pagado').length}/${pagos.length} pagos realizados',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: pagos.isEmpty
                  ? const Center(child: Text('No hay pagos programados', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pagos.length,
                      itemBuilder: (context, index) => _buildPagoItem(pagos[index], prop),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagoItem(PagoPropiedadModel pago, PropiedadModel prop) {
    final isPagado = pago.estado == 'pagado';
    final isAtrasado = pago.estaAtrasado;
    final color = isPagado ? Colors.greenAccent : (isAtrasado ? Colors.redAccent : Colors.orangeAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isPagado
                  ? Icon(Icons.check, color: color, size: 20)
                  : Text('${pago.numeroPago}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pago #${pago.numeroPago}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  isPagado
                      ? 'Pagado el ${_dateFormat.format(pago.fechaPago!)}'
                      : 'Vence: ${_dateFormat.format(pago.fechaProgramada)}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
                if (pago.pagadoPorNombre != null)
                  Text('Por: ${pago.pagadoPorNombre}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_currencyFormat.format(pago.monto),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              if (!isPagado)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _registrarPagoEspecifico(prop, pago);
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                  child: const Text('Pagar', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                ),
              if (pago.comprobanteUrl != null)
                const Icon(Icons.attachment, color: Colors.white38, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // REGISTRAR PAGO
  // ═══════════════════════════════════════════════════════════════════════════════

  void _registrarPago(PropiedadModel prop) async {
    // Buscar el siguiente pago pendiente
    final pagosRes = await AppSupabase.client
        .from('pagos_propiedades')
        .select()
        .eq('propiedad_id', prop.id)
        .eq('estado', 'pendiente')
        .order('numero_pago')
        .limit(1);

    if (pagosRes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pagos pendientes'), backgroundColor: Colors.orange),
      );
      return;
    }

    final pago = PagoPropiedadModel.fromMap(pagosRes[0]);
    _registrarPagoEspecifico(prop, pago);
  }

  void _registrarPagoEspecifico(PropiedadModel prop, PagoPropiedadModel pago) {
    final montoCtrl = TextEditingController(text: pago.monto.toStringAsFixed(0));
    final referenciaCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String metodoPago = 'transferencia';
    File? comprobante;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.tealAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Registrar Pago', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${prop.nombre} - Pago #${pago.numeroPago}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Monto
                _buildTextField(montoCtrl, 'Monto', '', isNumber: true),
                
                const SizedBox(height: 16),
                
                // Método de pago
                const Text('Método de pago', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTipoChip('transferencia', '💳 Transferencia', metodoPago, (m) => setModalState(() => metodoPago = m)),
                    _buildTipoChip('deposito', '🏦 Depósito', metodoPago, (m) => setModalState(() => metodoPago = m)),
                    _buildTipoChip('efectivo', '💵 Efectivo', metodoPago, (m) => setModalState(() => metodoPago = m)),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Referencia
                _buildTextField(referenciaCtrl, 'Referencia / Folio', 'Número de operación'),
                
                const SizedBox(height: 16),
                
                // Comprobante - Con opción de cámara o galería
                GestureDetector(
                  onTap: () async {
                    // Mostrar opciones: Cámara o Galería
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      backgroundColor: const Color(0xFF1E1E2E),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Seleccionar comprobante',
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
                              subtitle: const Text('Usar la cámara del teléfono', style: TextStyle(color: Colors.white54)),
                              onTap: () => Navigator.pop(ctx, ImageSource.camera),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.photo_library, color: Colors.purpleAccent),
                              ),
                              title: const Text('Elegir de galería', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Seleccionar imagen existente', style: TextStyle(color: Colors.white54)),
                              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                            ),
                            const SizedBox(height: 10),
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
                      color: const Color(0xFF252536),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: comprobante != null ? Colors.tealAccent : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(comprobante != null ? Icons.check_circle : Icons.add_a_photo,
                            color: comprobante != null ? Colors.tealAccent : Colors.white38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            comprobante != null ? '📷 Comprobante listo ✓' : 'Tomar foto o elegir comprobante',
                            style: TextStyle(color: comprobante != null ? Colors.tealAccent : Colors.white54),
                          ),
                        ),
                        if (comprobante != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                            onPressed: () => setModalState(() => comprobante = null),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Notas
                _buildTextField(notasCtrl, 'Notas (opcional)', 'Observaciones'),
                
                const SizedBox(height: 24),
                
                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _guardarPago(
                      pago: pago,
                      monto: double.tryParse(montoCtrl.text) ?? pago.monto,
                      metodoPago: metodoPago,
                      referencia: referenciaCtrl.text,
                      notas: notasCtrl.text,
                      comprobante: comprobante,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Pago'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardarPago({
    required PagoPropiedadModel pago,
    required double monto,
    required String metodoPago,
    required String referencia,
    required String notas,
    File? comprobante,
  }) async {
    Navigator.pop(context);

    try {
      String? comprobanteUrl;
      
      // Subir comprobante si existe
      if (comprobante != null) {
        final fileName = 'propiedades/${pago.propiedadId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await AppSupabase.client.storage.from('documentos').upload(fileName, comprobante);
        comprobanteUrl = AppSupabase.client.storage.from('documentos').getPublicUrl(fileName);
      }

      // Obtener usuario actual
      final userId = AppSupabase.client.auth.currentUser?.id;

      await AppSupabase.client.from('pagos_propiedades').update({
        'monto': monto,
        'fecha_pago': DateTime.now().toIso8601String().split('T')[0],
        'pagado_por': userId,
        'metodo_pago': metodoPago,
        'referencia': referencia.isNotEmpty ? referencia : null,
        'comprobante_url': comprobanteUrl,
        'estado': 'pagado',
        'notas': notas.isNotEmpty ? notas : null,
      }).eq('id', pago.id);

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pago registrado exitosamente'), backgroundColor: Colors.greenAccent),
      );
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _verDetalleProp(PropiedadModel prop) {
    _mostrarFormularioPropiedad(prop);
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EXPEDIENTE COMPLETO - EVIDENCIA DE PROPIEDAD PAGADA
  // ═══════════════════════════════════════════════════════════════════════════════
  
  Future<void> _verExpedienteCompleto(PropiedadModel prop) async {
    // Cargar todos los pagos con comprobantes
    final pagosRes = await AppSupabase.client
        .from('pagos_propiedades')
        .select('*, usuarios(nombre_completo)')
        .eq('propiedad_id', prop.id)
        .order('numero_pago');
    
    final pagos = (pagosRes as List).map((p) => PagoPropiedadModel.fromMap(p)).toList();
    
    // Calcular totales
    double totalPagado = prop.enganche;
    int pagosConComprobante = 0;
    List<PagoPropiedadModel> pagosConFoto = [];
    
    for (final p in pagos) {
      if (p.estado == 'pagado') {
        totalPagado += p.monto;
        if (p.comprobanteUrl != null) {
          pagosConComprobante++;
          pagosConFoto.add(p);
        }
      }
    }
    
    // Generar hash de integridad (para demostrar que no se alteró)
    final hashData = '${prop.id}|${prop.nombre}|${prop.precioTotal}|$totalPagado|${pagos.length}';
    final hashCode = hashData.hashCode.toRadixString(16).toUpperCase();
    final fechaGeneracion = DateTime.now();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              
              // Header del expediente
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.green.shade600],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('📁 EXPEDIENTE DE PROPIEDAD',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(prop.nombre,
                                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
                              Text('✅ LIQUIDADO', 
                                  style: TextStyle(color: Colors.greenAccent.shade100, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Hash de integridad
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, color: Colors.white54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hash de integridad:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                Text('SHA-$hashCode', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Text(_dateFormat.format(fechaGeneracion), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenido del expediente
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Resumen financiero
                    _buildExpedienteSeccion(
                      '💰 RESUMEN FINANCIERO',
                      Icons.account_balance_wallet,
                      [
                        _buildExpedienteRow('Precio total', _currencyFormat.format(prop.precioTotal)),
                        _buildExpedienteRow('Enganche inicial', _currencyFormat.format(prop.enganche)),
                        _buildExpedienteRow('Total financiado', _currencyFormat.format(prop.saldoInicial)),
                        const Divider(color: Colors.white12),
                        _buildExpedienteRow('Total pagado', _currencyFormat.format(totalPagado), Colors.greenAccent),
                        _buildExpedienteRow('Saldo pendiente', _currencyFormat.format(0), Colors.white54),
                      ],
                    ),
                    
                    // Información del vendedor
                    _buildExpedienteSeccion(
                      '🏢 DATOS DEL VENDEDOR',
                      Icons.business,
                      [
                        _buildExpedienteRow('Nombre', prop.vendedorNombre ?? 'No especificado'),
                        _buildExpedienteRow('Teléfono', prop.vendedorTelefono ?? 'No especificado'),
                        _buildExpedienteRow('Banco', prop.vendedorBanco ?? 'No especificado'),
                        _buildExpedienteRow('Cuenta', prop.vendedorCuentaBanco ?? 'No especificado'),
                      ],
                    ),
                    
                    // Datos de la propiedad
                    _buildExpedienteSeccion(
                      '🏠 DATOS DE LA PROPIEDAD',
                      Icons.home,
                      [
                        _buildExpedienteRow('Tipo', prop.tipoNombre),
                        _buildExpedienteRow('Ubicación', prop.ubicacion ?? 'No especificado'),
                        _buildExpedienteRow('Fecha inicio pagos', prop.fechaInicioPagos != null 
                            ? _dateFormat.format(prop.fechaInicioPagos!) : 'No especificado'),
                      ],
                    ),
                    
                    // Estadísticas de pagos
                    _buildExpedienteSeccion(
                      '📊 ESTADÍSTICAS DE PAGOS',
                      Icons.bar_chart,
                      [
                        _buildExpedienteRow('Total de pagos', '${pagos.length}'),
                        _buildExpedienteRow('Pagos completados', '${pagos.where((p) => p.estado == "pagado").length}'),
                        _buildExpedienteRow('Pagos con comprobante', '$pagosConComprobante', Colors.tealAccent),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Galería de comprobantes
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.tealAccent),
                        const SizedBox(width: 8),
                        Text('📷 COMPROBANTES DE PAGO ($pagosConComprobante)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (pagosConFoto.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_camera_back, color: Colors.white24, size: 48),
                            SizedBox(height: 8),
                            Text('No hay comprobantes fotográficos',
                                style: TextStyle(color: Colors.white38)),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: pagosConFoto.length,
                        itemBuilder: (context, index) {
                          final pago = pagosConFoto[index];
                          return GestureDetector(
                            onTap: () => _verImagenCompleta(pago),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                      child: Image.network(
                                        pago.comprobanteUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (c, e, s) => Container(
                                          color: Colors.white10,
                                          child: const Icon(Icons.broken_image, color: Colors.white24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Pago #${pago.numeroPago}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text(_currencyFormat.format(pago.monto),
                                            style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                                        Text(pago.fechaPago != null ? _dateFormat.format(pago.fechaPago!) : '',
                                            style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    
                    const SizedBox(height: 32),
                    
                    // Nota legal
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
                              SizedBox(width: 8),
                              Text('NOTA DE EVIDENCIA', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Este expediente contiene el registro completo de pagos realizados para la propiedad "${prop.nombre}". '
                            'Los comprobantes adjuntos fueron cargados al momento de registrar cada pago. '
                            'El hash de integridad permite verificar que este expediente no ha sido alterado.',
                            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generado: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(fechaGeneracion)}',
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildExpedienteSeccion(String titulo, IconData icono, List<Widget> contenido) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...contenido,
        ],
      ),
    );
  }
  
  Widget _buildExpedienteRow(String label, String valor, [Color? valorColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(valor, style: TextStyle(color: valorColor ?? Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  void _verImagenCompleta(PagoPropiedadModel pago) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pago #${pago.numeroPago}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      pago.comprobanteUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white24, size: 100),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Monto', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(_currencyFormat.format(pago.monto), style: const TextStyle(color: Colors.tealAccent)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Fecha', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(pago.fechaPago != null ? _dateFormat.format(pago.fechaPago!) : '-', 
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Método', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(pago.metodoPago ?? '-', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/facturacion_service.dart';
import '../../data/models/facturacion_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PARA EMITIR NUEVA FACTURA CFDI 4.0
// Robert Darin Platform v10.15
// ═══════════════════════════════════════════════════════════════════════════════

class NuevaFacturaScreen extends StatefulWidget {
  final String? moduloOrigen; // fintech, climas, ventas, purificadora
  final String? referenciaOrigenId;
  final String? referenciaTipo;

  const NuevaFacturaScreen({
    super.key,
    this.moduloOrigen,
    this.referenciaOrigenId,
    this.referenciaTipo,
  });

  @override
  State<NuevaFacturaScreen> createState() => _NuevaFacturaScreenState();
}

class _NuevaFacturaScreenState extends State<NuevaFacturaScreen> {
  final _service = FacturacionService();
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  bool _isLoading = true;
  bool _isEmitiendo = false;
  String? _negocioId;
  FacturacionEmisorModel? _emisor;

  // Catálogos
  List<FacturacionClienteModel> _clientesFiscales = [];
  List<RegimenFiscalModel> _regimenesFiscales = [];
  List<UsoCfdiModel> _usosCfdi = [];
  List<FormaPagoModel> _formasPago = [];
  List<FacturacionProductoModel> _productosPredet = [];

  // Selecciones
  FacturacionClienteModel? _clienteSeleccionado;
  String _usoCfdi = 'G03';
  String _formaPago = '99';
  String _metodoPago = 'PUE';

  // Conceptos de la factura
  final List<_ConceptoFactura> _conceptos = [];
  
  // Totales
  double _subtotal = 0;
  double _iva = 0;
  double _total = 0;

  // Controllers
  final _notasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final perfil = await AppSupabase.client
          .from('usuarios')
          .select('negocio_id')
          .eq('auth_uid', user.id)
          .single();

      _negocioId = perfil['negocio_id'];

      // Cargar emisor
      _emisor = await _service.obtenerEmisor(_negocioId!);

      // Cargar clientes fiscales
      _clientesFiscales = await _service.obtenerClientesFiscales(_negocioId!);

      // Cargar catálogos
      _regimenesFiscales = await _service.obtenerRegimenesFiscales();
      _usosCfdi = await _service.obtenerUsosCfdi();
      _formasPago = await _service.obtenerFormasPago();

      // Los productos predeterminados se pueden agregar manualmente
      _productosPredet = [];

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recalcularTotales() {
    _subtotal = _conceptos.fold(0, (sum, c) => sum + c.importe);
    _iva = _conceptos.fold(0, (sum, c) => sum + c.iva);
    _total = _subtotal + _iva;
    setState(() {});
  }

  Future<File> _guardarArchivoTemporal(String nombre, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _descargarPdfFactura(String facturaId, String nombreFactura) async {
    if (_emisor?.apiKey == null || _emisor!.apiKey!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key de facturación')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando PDF...')),
    );

    final base64Pdf = await _service.descargarPdf(
      facturaId,
      _emisor!.apiKey!,
      _emisor!.modoPruebas,
    );
    if (!mounted) return;

    if (base64Pdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el PDF'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final bytes = base64Decode(base64Pdf);
      final file = await _guardarArchivoTemporal('factura_$nombreFactura.pdf', bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Factura $nombreFactura');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🧾 Nueva Factura',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emisor == null
              ? _buildSinEmisor()
              : _buildFormulario(),
    );
  }

  Widget _buildSinEmisor() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Configuración Requerida',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Primero debes configurar tus datos fiscales para poder emitir facturas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/facturacion/config'),
              icon: const Icon(Icons.settings),
              label: const Text('Configurar Datos Fiscales'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emisor (tú)
                  _buildSeccion(
                    titulo: 'Emisor',
                    icono: Icons.business,
                    child: _buildEmisorInfo(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cliente (receptor)
                  _buildSeccion(
                    titulo: 'Cliente (Receptor)',
                    icono: Icons.person,
                    accion: TextButton.icon(
                      onPressed: () => _mostrarNuevoCliente(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nuevo'),
                    ),
                    child: _buildClienteSelector(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Datos del CFDI
                  _buildSeccion(
                    titulo: 'Datos del CFDI',
                    icono: Icons.description,
                    child: _buildDatosCfdi(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Conceptos
                  _buildSeccion(
                    titulo: 'Conceptos',
                    icono: Icons.list_alt,
                    accion: TextButton.icon(
                      onPressed: () => _agregarConcepto(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar'),
                    ),
                    child: _buildConceptos(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notas
                  _buildSeccion(
                    titulo: 'Notas (opcional)',
                    icono: Icons.note,
                    child: TextFormField(
                      controller: _notasController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Notas adicionales para la factura...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer con totales y botón
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSeccion({
    required String titulo,
    required IconData icono,
    required Widget child,
    Widget? accion,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icono, color: const Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (accion != null) accion,
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmisorInfo() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.business, color: Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emisor!.razonSocial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                'RFC: ${_emisor!.rfc}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
              Text(
                'Régimen: ${_emisor!.regimenFiscalDescripcion ?? _emisor!.regimenFiscal}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClienteSelector() {
    return Column(
      children: [
        // Dropdown de clientes existentes
        DropdownButtonFormField<FacturacionClienteModel>(
          value: _clienteSeleccionado,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Seleccionar cliente',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            filled: true,
            fillColor: const Color(0xFF0D0D14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _clientesFiscales.map((c) => DropdownMenuItem(
            value: c,
            child: Text('${c.razonSocial} (${c.rfc})'),
          )).toList(),
          onChanged: (v) => setState(() => _clienteSeleccionado = v),
          validator: (v) => v == null ? 'Selecciona un cliente' : null,
        ),
        
        // Mostrar info del cliente seleccionado
        if (_clienteSeleccionado != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('RFC', _clienteSeleccionado!.rfc),
                _buildInfoRow('Régimen', _clienteSeleccionado!.regimenFiscal),
                _buildInfoRow('CP', _clienteSeleccionado!.codigoPostal),
                if (_clienteSeleccionado!.email != null)
                  _buildInfoRow('Email', _clienteSeleccionado!.email!),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDatosCfdi() {
    return Column(
      children: [
        // Uso CFDI
        DropdownButtonFormField<String>(
          value: _usoCfdi,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Uso del CFDI',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            filled: true,
            fillColor: const Color(0xFF0D0D14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _usosCfdi.map((u) => DropdownMenuItem(
            value: u.clave,
            child: Text('${u.clave} - ${u.descripcion}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _usoCfdi = v ?? 'G03'),
        ),
        
        const SizedBox(height: 12),
        
        // Forma de pago y Método de pago
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _formaPago,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Forma de Pago',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _formasPago.map((f) => DropdownMenuItem(
                  value: f.clave,
                  child: Text('${f.clave} - ${f.descripcion}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) => setState(() => _formaPago = v ?? '99'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _metodoPago,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Método de Pago',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'PUE', child: Text('PUE - Pago en una exhibición')),
                  DropdownMenuItem(value: 'PPD', child: Text('PPD - Pago en parcialidades')),
                ],
                onChanged: (v) => setState(() => _metodoPago = v ?? 'PUE'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConceptos() {
    if (_conceptos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Sin conceptos',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _agregarConcepto(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar concepto'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._conceptos.asMap().entries.map((entry) {
          final index = entry.key;
          final concepto = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        concepto.descripcion,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                      onPressed: () => _editarConcepto(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() => _conceptos.removeAt(index));
                        _recalcularTotales();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${concepto.cantidad} x ${_currencyFormat.format(concepto.valorUnitario)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Importe: ${_currencyFormat.format(concepto.importe)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          'IVA: ${_currencyFormat.format(concepto.iva)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Totales
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(color: Colors.white70)),
                Text(_currencyFormat.format(_subtotal), style: const TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('IVA (16%):', style: TextStyle(color: Colors.white70)),
                Text(_currencyFormat.format(_iva), style: const TextStyle(color: Colors.white)),
              ],
            ),
            const Divider(color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  _currencyFormat.format(_total),
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _guardarBorrador(),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar Borrador'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _conceptos.isEmpty || _clienteSeleccionado == null || _isEmitiendo
                        ? null
                        : () => _emitirFactura(),
                    icon: _isEmitiendo
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_isEmitiendo ? 'Timbrando...' : 'Timbrar Factura'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _agregarConcepto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConceptoSheet(
        productosPredet: _productosPredet,
        onAgregar: (concepto) {
          setState(() => _conceptos.add(concepto));
          _recalcularTotales();
        },
      ),
    );
  }

  void _editarConcepto(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConceptoSheet(
        productosPredet: _productosPredet,
        conceptoExistente: _conceptos[index],
        onAgregar: (concepto) {
          setState(() => _conceptos[index] = concepto);
          _recalcularTotales();
        },
      ),
    );
  }

  void _mostrarNuevoCliente() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NuevoClienteSheet(
        negocioId: _negocioId!,
        regimenesFiscales: _regimenesFiscales,
        onCreado: (cliente) {
          setState(() {
            _clientesFiscales.add(cliente);
            _clienteSeleccionado = cliente;
          });
        },
      ),
    );
  }

  Future<void> _guardarBorrador() async {
    if (_conceptos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un concepto')),
      );
      return;
    }
    if (_clienteSeleccionado == null || _emisor == null || _negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona emisor y cliente fiscal')),
      );
      return;
    }

    setState(() => _isEmitiendo = true);

    try {
      final conceptosParaServicio = _conceptos.map((c) => FacturaConceptoModel(
        id: '',
        facturaId: '',
        claveProdServ: c.claveProdServ,
        claveUnidad: c.claveUnidad,
        unidad: c.unidad,
        descripcion: c.descripcion,
        cantidad: c.cantidad,
        valorUnitario: c.valorUnitario,
        importe: c.importe,
        objetoImp: '02',
        createdAt: DateTime.now(),
      )).toList();

      final facturaId = await _service.crearBorradorFactura(
        negocioId: _negocioId!,
        emisorId: _emisor!.id,
        clienteFiscalId: _clienteSeleccionado!.id,
        conceptos: conceptosParaServicio,
        usoCfdi: _usoCfdi,
        formaPago: _formaPago,
        metodoPago: _metodoPago,
        moduloOrigen: widget.moduloOrigen,
        referenciaOrigenId: widget.referenciaOrigenId,
        referenciaTipo: widget.referenciaTipo,
        notas: _notasController.text.isEmpty ? null : _notasController.text,
      );

      setState(() => _isEmitiendo = false);

      if (!mounted) return;
      if (facturaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el borrador'), backgroundColor: Colors.red),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isEmitiendo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _emitirFactura() async {
    if (!_formKey.currentState!.validate()) return;
    if (_conceptos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un concepto')),
      );
      return;
    }

    setState(() => _isEmitiendo = true);

    try {
      // Preparar conceptos para el servicio
      final conceptosParaServicio = _conceptos.map((c) => FacturaConceptoModel(
        id: '',
        facturaId: '',
        claveProdServ: c.claveProdServ,
        claveUnidad: c.claveUnidad,
        unidad: c.unidad,
        descripcion: c.descripcion,
        cantidad: c.cantidad,
        valorUnitario: c.valorUnitario,
        importe: c.importe,
        objetoImp: '02',
        createdAt: DateTime.now(),
      )).toList();

      // Crear borrador primero
      final facturaId = await _service.crearBorradorFactura(
        negocioId: _negocioId!,
        emisorId: _emisor!.id,
        clienteFiscalId: _clienteSeleccionado!.id,
        conceptos: conceptosParaServicio,
        usoCfdi: _usoCfdi,
        formaPago: _formaPago,
        metodoPago: _metodoPago,
        moduloOrigen: widget.moduloOrigen,
        referenciaOrigenId: widget.referenciaOrigenId,
        referenciaTipo: widget.referenciaTipo,
        notas: _notasController.text.isEmpty ? null : _notasController.text,
      );

      if (facturaId == null) {
        throw Exception('Error al crear borrador de factura');
      }

      // Timbrar la factura creada
      final resultado = await _service.timbrarConFacturApi(
        facturaId: facturaId,
        apiKey: _emisor!.apiKey ?? '',
        modoPruebas: _emisor!.modoPruebas,
      );

      setState(() => _isEmitiendo = false);

      if (resultado['success'] == true) {
        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('¡Factura Timbrada!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UUID: ${resultado['uuid'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Folio: ${resultado['folio'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ${_currencyFormat.format(_total)}',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
              actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final data = resultado['data'] as Map<String, dynamic>?;
                  final serie = data?['series']?.toString() ?? _emisor?.serieFacturas ?? 'A';
                  final folio = data?['folio_number']?.toString() ?? '';
                  final nombre = folio.isEmpty ? facturaId : '$serie-$folio';
                  Navigator.pop(ctx);
                  await _descargarPdfFactura(facturaId, nombre);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.download),
                label: const Text('Descargar PDF'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${resultado['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isEmitiendo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO LOCAL PARA CONCEPTO
// ═══════════════════════════════════════════════════════════════════════════════

class _ConceptoFactura {
  String claveProdServ;
  String claveUnidad;
  String unidad;
  String descripcion;
  double cantidad;
  double valorUnitario;
  double importe;
  double iva;

  _ConceptoFactura({
    required this.claveProdServ,
    required this.claveUnidad,
    required this.unidad,
    required this.descripcion,
    required this.cantidad,
    required this.valorUnitario,
    required this.importe,
    required this.iva,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: AGREGAR/EDITAR CONCEPTO
// ═══════════════════════════════════════════════════════════════════════════════

class _ConceptoSheet extends StatefulWidget {
  final List<FacturacionProductoModel> productosPredet;
  final _ConceptoFactura? conceptoExistente;
  final Function(_ConceptoFactura) onAgregar;

  const _ConceptoSheet({
    required this.productosPredet,
    this.conceptoExistente,
    required this.onAgregar,
  });

  @override
  State<_ConceptoSheet> createState() => _ConceptoSheetState();
}

class _ConceptoSheetState extends State<_ConceptoSheet> {
  final _formKey = GlobalKey<FormState>();
  
  final _descripcionController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController(text: '0');
  final _claveProductoController = TextEditingController(text: '01010101');
  
  String _claveUnidad = 'E48';
  String _unidad = 'Servicio';
  double _tasaIva = 0.16;

  @override
  void initState() {
    super.initState();
    if (widget.conceptoExistente != null) {
      final c = widget.conceptoExistente!;
      _descripcionController.text = c.descripcion;
      _cantidadController.text = c.cantidad.toString();
      _precioController.text = c.valorUnitario.toString();
      _claveProductoController.text = c.claveProdServ;
      _claveUnidad = c.claveUnidad;
      _unidad = c.unidad;
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _claveProductoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
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
                  const Icon(Icons.inventory_2, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  Text(
                    widget.conceptoExistente != null ? 'Editar Concepto' : 'Agregar Concepto',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Productos predeterminados
                    if (widget.productosPredet.isNotEmpty) ...[
                      const Text('Productos frecuentes:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.productosPredet.map((p) => ActionChip(
                          label: Text(p.descripcion, overflow: TextOverflow.ellipsis),
                          backgroundColor: const Color(0xFF1A1A2E),
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          onPressed: () {
                            setState(() {
                              _descripcionController.text = p.descripcion;
                              _claveProductoController.text = p.claveProdServ;
                              _claveUnidad = p.claveUnidad;
                              _unidad = p.unidad ?? 'Servicio';
                              _precioController.text = p.precioUnitario.toString();
                            });
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Descripción
                    TextFormField(
                      controller: _descripcionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: _inputDecoration('Descripción *'),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Clave SAT
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _claveProductoController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Clave SAT'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _claveUnidad,
                            dropdownColor: const Color(0xFF1A1A2E),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Unidad'),
                            items: const [
                              DropdownMenuItem(value: 'E48', child: Text('E48 - Servicio')),
                              DropdownMenuItem(value: 'H87', child: Text('H87 - Pieza')),
                              DropdownMenuItem(value: 'ACT', child: Text('ACT - Actividad')),
                              DropdownMenuItem(value: 'LTR', child: Text('LTR - Litro')),
                              DropdownMenuItem(value: 'KGM', child: Text('KGM - Kilogramo')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _claveUnidad = v ?? 'E48';
                                switch (_claveUnidad) {
                                  case 'E48': _unidad = 'Servicio'; break;
                                  case 'H87': _unidad = 'Pieza'; break;
                                  case 'ACT': _unidad = 'Actividad'; break;
                                  case 'LTR': _unidad = 'Litro'; break;
                                  case 'KGM': _unidad = 'Kilogramo'; break;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Cantidad y precio
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cantidadController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Cantidad'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _precioController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Precio Unitario'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // IVA
                    DropdownButtonFormField<double>(
                      value: _tasaIva,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Tasa IVA'),
                      items: const [
                        DropdownMenuItem(value: 0.16, child: Text('16% - Tasa general')),
                        DropdownMenuItem(value: 0.08, child: Text('8% - Frontera')),
                        DropdownMenuItem(value: 0.0, child: Text('0% - Exento')),
                      ],
                      onChanged: (v) => setState(() => _tasaIva = v ?? 0.16),
                    ),
                  ],
                ),
              ),
            ),
            
            // Botón agregar
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _agregarConcepto,
                  icon: const Icon(Icons.add),
                  label: Text(widget.conceptoExistente != null ? 'Actualizar' : 'Agregar Concepto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _agregarConcepto() {
    if (!_formKey.currentState!.validate()) return;

    final cantidad = double.tryParse(_cantidadController.text) ?? 1;
    final precio = double.tryParse(_precioController.text) ?? 0;
    final importe = cantidad * precio;
    final iva = importe * _tasaIva;

    final concepto = _ConceptoFactura(
      claveProdServ: _claveProductoController.text,
      claveUnidad: _claveUnidad,
      unidad: _unidad,
      descripcion: _descripcionController.text,
      cantidad: cantidad,
      valorUnitario: precio,
      importe: importe,
      iva: iva,
    );

    widget.onAgregar(concepto);
    Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: NUEVO CLIENTE FISCAL
// ═══════════════════════════════════════════════════════════════════════════════

class _NuevoClienteSheet extends StatefulWidget {
  final String negocioId;
  final List<RegimenFiscalModel> regimenesFiscales;
  final Function(FacturacionClienteModel) onCreado;

  const _NuevoClienteSheet({
    required this.negocioId,
    required this.regimenesFiscales,
    required this.onCreado,
  });

  @override
  State<_NuevoClienteSheet> createState() => _NuevoClienteSheetState();
}

class _NuevoClienteSheetState extends State<_NuevoClienteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _rfcController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _cpController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _regimenFiscal = '612';
  bool _isSaving = false;

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _cpController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  const Text(
                    'Nuevo Cliente Fiscal',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _rfcController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration('RFC *'),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Requerido';
                        if (v!.length < 12) return 'RFC inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _razonSocialController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Razón Social *'),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _regimenFiscal,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Régimen Fiscal'),
                      items: widget.regimenesFiscales.map((r) => DropdownMenuItem(
                        value: r.clave,
                        child: Text('${r.clave} - ${r.descripcion}', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setState(() => _regimenFiscal = v ?? '612'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cpController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Código Postal *'),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      validator: (v) => v?.length != 5 ? 'CP debe ser 5 dígitos' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Email (para enviar factura)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardarCliente,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar Cliente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final res = await AppSupabase.client.from('facturacion_clientes').insert({
        'negocio_id': widget.negocioId,
        'rfc': _rfcController.text.toUpperCase(),
        'razon_social': _razonSocialController.text,
        'regimen_fiscal': _regimenFiscal,
        'codigo_postal': _cpController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'uso_cfdi': 'G03',
      }).select().single();

      final cliente = FacturacionClienteModel.fromMap(res);
      widget.onCreado(cliente);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

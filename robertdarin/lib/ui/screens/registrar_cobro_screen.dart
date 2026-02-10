// ignore_for_file: deprecated_member_use
/// ============================================================
/// SISTEMA DE COBROS PROFESIONAL - Robert Darin Fintech V9.0
/// Pantalla completa para registrar y confirmar cobros
/// Con QR, datos bancarios, comprobantes y geolocalización
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../data/models/metodo_pago_model.dart';
import '../../core/themes/app_theme.dart';
import '../viewmodels/negocio_activo_provider.dart';

class RegistrarCobroScreen extends StatefulWidget {
  final String? prestamoId;
  final String? tandaId;
  final String? amortizacionId;
  final String clienteId;
  final String clienteNombre;
  final double montoEsperado;
  final int? numeroCuota;

  const RegistrarCobroScreen({
    super.key,
    this.prestamoId,
    this.tandaId,
    this.amortizacionId,
    required this.clienteId,
    required this.clienteNombre,
    required this.montoEsperado,
    this.numeroCuota,
  });

  @override
  State<RegistrarCobroScreen> createState() => _RegistrarCobroScreenState();
}

class _RegistrarCobroScreenState extends State<RegistrarCobroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _notaController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<MetodoPagoModel> _metodosPago = [];
  MetodoPagoModel? _metodoSeleccionado;
  String _tipoCobroSeleccionado = 'efectivo';
  File? _comprobanteFile;
  bool _loading = true;
  bool _guardando = false;
  bool _tarjetasDigitalesActivas = false;

  final List<Map<String, dynamic>> _tiposCobro = [
    {'tipo': 'efectivo', 'nombre': 'Efectivo', 'icono': Icons.payments},
    {'tipo': 'transferencia', 'nombre': 'Transferencia', 'icono': Icons.account_balance},
    {'tipo': 'tarjeta', 'nombre': 'Tarjeta', 'icono': Icons.credit_card},
    {'tipo': 'oxxo', 'nombre': 'OXXO/Tienda', 'icono': Icons.store},
    {'tipo': 'qr', 'nombre': 'Código QR', 'icono': Icons.qr_code},
    {'tipo': 'tarjeta_digital', 'nombre': 'Tarjeta Digital', 'icono': Icons.contactless},
  ];

  @override
  void initState() {
    super.initState();
    _montoController.text = widget.montoEsperado.toStringAsFixed(2);
    _cargarMetodosPago();
    _verificarTarjetasDigitales();
  }

  Future<void> _verificarTarjetasDigitales() async {
    try {
      final config = await _supabase
          .from('configuracion_apis')
          .select('activo')
          .eq('servicio', 'tarjetas_digitales')
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _tarjetasDigitalesActivas = config?['activo'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error verificando tarjetas digitales: $e');
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _referenciaController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _cargarMetodosPago() async {
    try {
      final response = await _supabase
          .from('metodos_pago')
          .select()
          .eq('activo', true)
          .order('principal', ascending: false)
          .order('orden');

      setState(() {
        _metodosPago = (response as List)
            .map((e) => MetodoPagoModel.fromMap(e))
            .toList();
        // Seleccionar el método principal por defecto
        _metodoSeleccionado = _metodosPago.isNotEmpty 
            ? _metodosPago.firstWhere(
                (m) => m.principal, 
                orElse: () => _metodosPago.first,
              )
            : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error cargando métodos de pago: $e');
    }
  }

  Future<void> _seleccionarComprobante() async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleccionar Comprobante',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOpcionImagen(
                  icono: Icons.camera_alt,
                  label: 'Cámara',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                _buildOpcionImagen(
                  icono: Icons.photo_library,
                  label: 'Galería',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _comprobanteFile = File(picked.path));
      }
    }
  }

  Widget _buildOpcionImagen({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icono, size: 40, color: AppTheme.accentCyan),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Future<String?> _subirComprobante() async {
    if (_comprobanteFile == null) return null;

    try {
      final fileName = 'comprobantes/${DateTime.now().millisecondsSinceEpoch}_${widget.clienteId}.jpg';
      final bytes = await _comprobanteFile!.readAsBytes();
      
      await _supabase.storage
          .from('comprobantes')
          .uploadBinary(fileName, bytes);
      
      return _supabase.storage.from('comprobantes').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error subiendo comprobante: $e');
      return null;
    }
  }

  Future<void> _registrarCobro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      // Subir comprobante si existe
      String? comprobanteUrl;
      if (_comprobanteFile != null) {
        comprobanteUrl = await _subirComprobante();
      }

      final monto = double.parse(_montoController.text);
      final userId = _supabase.auth.currentUser?.id;

      // Crear registro de cobro
      final cobroData = {
        'prestamo_id': widget.prestamoId,
        'tanda_id': widget.tandaId,
        'amortizacion_id': widget.amortizacionId,
        'cliente_id': widget.clienteId,
        'monto': monto,
        'metodo_pago_id': _metodoSeleccionado?.id,
        'tipo_metodo': _tipoCobroSeleccionado,
        'estado': _tipoCobroSeleccionado == 'efectivo' ? 'confirmado' : 'pendiente',
        'referencia_pago': _referenciaController.text.isNotEmpty 
            ? _referenciaController.text 
            : null,
        'comprobante_url': comprobanteUrl,
        'nota_cliente': _notaController.text.isNotEmpty 
            ? _notaController.text 
            : null,
        'registrado_por': userId,
        'fecha_registro': DateTime.now().toIso8601String(),
        // Si es efectivo, confirmar automáticamente
        'confirmado_por': _tipoCobroSeleccionado == 'efectivo' ? userId : null,
        'fecha_confirmacion': _tipoCobroSeleccionado == 'efectivo' 
            ? DateTime.now().toIso8601String() 
            : null,
      };

      await _supabase.from('registros_cobro').insert(cobroData);

      // Si es efectivo o ya está confirmado, actualizar el pago/amortización
      if (_tipoCobroSeleccionado == 'efectivo') {
        await _confirmarPagoEnSistema(monto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _tipoCobroSeleccionado == 'efectivo' 
                      ? Icons.check_circle 
                      : Icons.schedule,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tipoCobroSeleccionado == 'efectivo'
                        ? '¡Cobro registrado y confirmado!'
                        : 'Cobro registrado. Pendiente de confirmación.',
                  ),
                ),
              ],
            ),
            backgroundColor: _tipoCobroSeleccionado == 'efectivo' 
                ? Colors.green 
                : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error registrando cobro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarPagoEnSistema(double monto) async {
    try {
      // Registrar en tabla de pagos
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      await _supabase.from('pagos').insert({
        'prestamo_id': widget.prestamoId,
        'tanda_id': widget.tandaId,
        'amortizacion_id': widget.amortizacionId,
        'cliente_id': widget.clienteId,
        'monto': monto,
        'metodo_pago': _tipoCobroSeleccionado,
        'fecha_pago': DateTime.now().toIso8601String(),
        'nota': _notaController.text,
        'comprobante_url': _comprobanteFile != null ? 'pendiente' : null,
        'registrado_por': _supabase.auth.currentUser?.id,
        'negocio_id': negocioId,
      });

      // V10.55: Actualizar amortización con validación de monto
      if (widget.amortizacionId != null) {
        // Determinar estado según monto pagado vs esperado
        final estadoAmortizacion = monto >= widget.montoEsperado ? 'pagado' : 'parcial';
        
        await _supabase
            .from('amortizaciones')
            .update({
              'estado': estadoAmortizacion,
              'fecha_pago': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.amortizacionId!);
        
        // V10.55: Verificar si todas las amortizaciones están pagadas para actualizar préstamo
        if (widget.prestamoId != null && estadoAmortizacion == 'pagado') {
          await _verificarYActualizarEstadoPrestamo(widget.prestamoId!);
        }
      }

      // Si es tanda, actualizar participante
      if (widget.tandaId != null) {
        await _supabase
            .from('tanda_participantes')
            .update({'ha_pagado_cuota_actual': true})
            .eq('tanda_id', widget.tandaId!)
            .eq('cliente_id', widget.clienteId);
      }
    } catch (e) {
      debugPrint('Error confirmando pago en sistema: $e');
    }
  }

  /// V10.55: Verifica si todas las amortizaciones están pagadas y actualiza el préstamo
  Future<void> _verificarYActualizarEstadoPrestamo(String prestamoId) async {
    try {
      final amortizaciones = await _supabase
          .from('amortizaciones')
          .select('estado')
          .eq('prestamo_id', prestamoId);
      
      final todasPagadas = (amortizaciones as List).every(
        (a) => a['estado'] == 'pagado' || a['estado'] == 'pagada'
      );
      
      if (todasPagadas) {
        await _supabase
            .from('prestamos')
            .update({'estado': 'pagado'})
            .eq('id', prestamoId);
        debugPrint('✅ Préstamo $prestamoId actualizado a PAGADO');
      }
    } catch (e) {
      debugPrint('Error verificando estado préstamo: $e');
    }
  }

  void _copiarAlPortapapeles(String texto, String label) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copiado'),
          ],
        ),
        backgroundColor: AppTheme.accentCyan,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Registrar Cobro'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          if (!_loading && _metodosPago.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurar Métodos de Pago',
              onPressed: () => _mostrarConfiguracionMetodos(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Información del cliente y monto
                  _buildInfoClienteCard(),
                  const SizedBox(height: 20),

                  // Selección de tipo de cobro
                  _buildTipoCobroSelector(),
                  const SizedBox(height: 20),

                  // Si es transferencia, mostrar datos bancarios
                  if (_tipoCobroSeleccionado == 'transferencia')
                    _buildDatosBancariosCard(),

                  // Si es QR, mostrar código QR
                  if (_tipoCobroSeleccionado == 'qr')
                    _buildQRCard(),

                  // Si es tarjeta digital, mostrar opciones de tarjeta
                  if (_tipoCobroSeleccionado == 'tarjeta_digital')
                    _buildTarjetaDigitalCard(),

                  // Campos del formulario
                  _buildFormularioCobro(),
                  const SizedBox(height: 20),

                  // Botón de confirmar
                  _buildBotonConfirmar(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoClienteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCyan.withOpacity(0.2),
            AppTheme.surfaceDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppTheme.accentCyan, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clienteNombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.numeroCuota != null)
                      Text(
                        'Cuota #${widget.numeroCuota}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monto a cobrar:',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '\$${widget.montoEsperado.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoCobroSelector() {
    // Filtrar tipos de cobro según disponibilidad
    final tiposDisponibles = _tiposCobro.where((tipo) {
      // Si es tarjeta digital, solo mostrar si está activo el módulo
      if (tipo['tipo'] == 'tarjeta_digital') {
        return _tarjetasDigitalesActivas;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de Pago',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tiposDisponibles.length,
            itemBuilder: (context, index) {
              final tipo = tiposDisponibles[index];
              final isSelected = _tipoCobroSeleccionado == tipo['tipo'];
              final esTarjetaDigital = tipo['tipo'] == 'tarjeta_digital';
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => setState(() {
                    _tipoCobroSeleccionado = tipo['tipo'];
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: esTarjetaDigital && isSelected
                          ? LinearGradient(
                              colors: [Colors.purple.shade600, Colors.blue.shade600],
                            )
                          : null,
                      color: isSelected && !esTarjetaDigital
                          ? AppTheme.accentCyan.withOpacity(0.2)
                          : esTarjetaDigital
                              ? Colors.purple.withOpacity(0.1)
                              : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? (esTarjetaDigital ? Colors.purple : AppTheme.accentCyan)
                            : (esTarjetaDigital ? Colors.purple.withOpacity(0.3) : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tipo['icono'],
                          color: isSelected 
                              ? (esTarjetaDigital ? Colors.white : AppTheme.accentCyan)
                              : (esTarjetaDigital ? Colors.purple : Colors.white70),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tipo['nombre'],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected 
                                ? (esTarjetaDigital ? Colors.white : AppTheme.accentCyan)
                                : (esTarjetaDigital ? Colors.purple : Colors.white70),
                            fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatosBancariosCard() {
    // Buscar método de transferencia activo
    final metodoTransferencia = _metodosPago.where(
      (m) => m.tipo == 'transferencia' && m.activo,
    ).toList();

    if (metodoTransferencia.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No hay datos bancarios configurados',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _mostrarConfiguracionMetodos(),
              icon: const Icon(Icons.add),
              label: const Text('Configurar ahora'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: AppTheme.accentCyan),
                const SizedBox(width: 12),
                const Text(
                  'Datos para Transferencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share, color: AppTheme.accentCyan),
                  onPressed: () => _compartirDatosBancarios(metodoTransferencia.first),
                  tooltip: 'Compartir datos',
                ),
              ],
            ),
          ),
          ...metodoTransferencia.map((metodo) => _buildDatoBancarioItem(metodo)),
        ],
      ),
    );
  }

  Widget _buildDatoBancarioItem(MetodoPagoModel metodo) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metodo.banco != null) ...[
            _buildDatoRow('Banco', metodo.banco!, Icons.business),
            const Divider(color: Colors.white12),
          ],
          if (metodo.titular != null) ...[
            _buildDatoRow('Titular', metodo.titular!, Icons.person),
            const Divider(color: Colors.white12),
          ],
          if (metodo.clabe != null)
            _buildDatoCopiable('CLABE', metodo.clabe!),
          if (metodo.numeroCuenta != null) ...[
            const Divider(color: Colors.white12),
            _buildDatoCopiable('No. Cuenta', metodo.numeroCuenta!),
          ],
          if (metodo.instrucciones != null) ...[
            const Divider(color: Colors.white12),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                metodo.instrucciones!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatoCopiable(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copiarAlPortapapeles(value, label),
            icon: const Icon(Icons.copy, color: AppTheme.accentCyan),
            tooltip: 'Copiar $label',
          ),
        ],
      ),
    );
  }

  Widget _buildQRCard() {
    // Buscar QR configurado
    final metodoQR = _metodosPago.where(
      (m) => m.qrUrl != null && m.activo,
    ).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, color: AppTheme.accentCyan, size: 28),
              SizedBox(width: 12),
              Text(
                'Escanear para Pagar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (metodoQR.isNotEmpty && metodoQR.first.qrUrl != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                metodoQR.first.qrUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.qr_code, size: 100, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'QR no configurado',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Monto: \$${widget.montoEsperado.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para cobro con tarjeta digital del cliente
  Widget _buildTarjetaDigitalCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.5),
            Colors.blue.shade900.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.contactless, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarjeta Digital',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Cargo automático a la tarjeta',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Tarjeta visual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ROBERT DARIN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Icon(Icons.wifi, color: Colors.white.withOpacity(0.7)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '•••• •••• •••• ••••',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.clienteNombre.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.white70, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'DIGITAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Monto a cobrar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.attach_money, color: Colors.greenAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  widget.montoEsperado.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MXN',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Info de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El cargo se realizará de forma segura a la tarjeta digital del cliente',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nota sobre el proceso
          const Text(
            'Al confirmar, se descontará automáticamente del saldo disponible en la tarjeta digital del cliente.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioCobro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalles del Cobro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Monto
          TextFormField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Monto Recibido',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.attach_money, color: AppTheme.accentCyan),
              prefixText: '\$ ',
              prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 18),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese el monto';
              }
              final monto = double.tryParse(value);
              if (monto == null || monto <= 0) {
                return 'Monto inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Referencia (para transferencias)
          if (_tipoCobroSeleccionado != 'efectivo') ...[
            TextFormField(
              controller: _referenciaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Referencia / No. Transacción',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.tag, color: AppTheme.accentCyan),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentCyan),
                ),
                hintText: 'Ej: 123456789',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Nota
          TextFormField(
            controller: _notaController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Nota (opcional)',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.note, color: AppTheme.accentCyan),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Comprobante
          const Text(
            'Comprobante de Pago',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _seleccionarComprobante,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _comprobanteFile != null 
                      ? Colors.green 
                      : Colors.white24,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: _comprobanteFile != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _comprobanteFile!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 16,
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () => setState(() => _comprobanteFile = null),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tomar o seleccionar foto',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonConfirmar() {
    final esEfectivo = _tipoCobroSeleccionado == 'efectivo';
    
    return ElevatedButton(
      onPressed: _guardando ? null : _registrarCobro,
      style: ElevatedButton.styleFrom(
        backgroundColor: esEfectivo ? Colors.green : AppTheme.accentCyan,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      child: _guardando
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(esEfectivo ? Icons.check_circle : Icons.schedule),
                const SizedBox(width: 12),
                Text(
                  esEfectivo 
                      ? 'Confirmar Cobro en Efectivo' 
                      : 'Registrar (Pendiente de Confirmación)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  void _compartirDatosBancarios(MetodoPagoModel metodo) {
    final texto = '''
💰 DATOS PARA TRANSFERENCIA
${metodo.banco != null ? '\n🏦 Banco: ${metodo.banco}' : ''}
${metodo.titular != null ? '\n👤 Titular: ${metodo.titular}' : ''}
${metodo.clabe != null ? '\n📋 CLABE: ${metodo.clabe}' : ''}
${metodo.numeroCuenta != null ? '\n💳 Cuenta: ${metodo.numeroCuenta}' : ''}

💵 Monto: \$${widget.montoEsperado.toStringAsFixed(2)}

📝 Referencia: ${widget.clienteNombre}
''';
    
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text('Datos copiados. ¡Listos para compartir!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarConfiguracionMetodos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfigurarMetodosPagoScreen(),
      ),
    ).then((_) => _cargarMetodosPago());
  }
}

/// ============================================================
/// PANTALLA DE CONFIGURACIÓN DE MÉTODOS DE PAGO
/// ============================================================

class ConfigurarMetodosPagoScreen extends StatefulWidget {
  const ConfigurarMetodosPagoScreen({super.key});

  @override
  State<ConfigurarMetodosPagoScreen> createState() => _ConfigurarMetodosPagoScreenState();
}

class _ConfigurarMetodosPagoScreenState extends State<ConfigurarMetodosPagoScreen> {
  final _supabase = Supabase.instance.client;
  List<MetodoPagoModel> _metodos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarMetodos();
  }

  Future<void> _cargarMetodos() async {
    try {
      final response = await _supabase
          .from('metodos_pago')
          .select()
          .order('orden');

      setState(() {
        _metodos = (response as List)
            .map((e) => MetodoPagoModel.fromMap(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Métodos de Pago'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioMetodo(null),
        backgroundColor: AppTheme.accentCyan,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Método'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _metodos.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _metodos.length,
                  itemBuilder: (context, index) {
                    final metodo = _metodos[index];
                    return _buildMetodoCard(metodo);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay métodos de pago configurados',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioMetodo(null),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Método de Pago'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoCard(MetodoPagoModel metodo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: metodo.principal
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: metodo.activo 
                ? AppTheme.accentCyan.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            metodo.icono,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Row(
          children: [
            Text(
              metodo.nombre,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (metodo.principal) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRINCIPAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              metodo.tipo.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            if (metodo.banco != null)
              Text(
                metodo.banco!,
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: metodo.activo,
              onChanged: (value) => _toggleActivo(metodo, value),
              activeColor: AppTheme.accentCyan,
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.accentCyan),
              onPressed: () => _mostrarFormularioMetodo(metodo),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActivo(MetodoPagoModel metodo, bool activo) async {
    try {
      await _supabase
          .from('metodos_pago')
          .update({'activo': activo})
          .eq('id', metodo.id);
      _cargarMetodos();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _mostrarFormularioMetodo(MetodoPagoModel? metodo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormularioMetodoPago(
        metodo: metodo,
        onGuardado: () {
          Navigator.pop(context);
          _cargarMetodos();
        },
      ),
    );
  }
}

/// ============================================================
/// FORMULARIO PARA AGREGAR/EDITAR MÉTODO DE PAGO
/// ============================================================

class FormularioMetodoPago extends StatefulWidget {
  final MetodoPagoModel? metodo;
  final VoidCallback onGuardado;

  const FormularioMetodoPago({
    super.key,
    this.metodo,
    required this.onGuardado,
  });

  @override
  State<FormularioMetodoPago> createState() => _FormularioMetodoPagoState();
}

class _FormularioMetodoPagoState extends State<FormularioMetodoPago> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  late TextEditingController _nombreController;
  late TextEditingController _bancoController;
  late TextEditingController _titularController;
  late TextEditingController _clabeController;
  late TextEditingController _cuentaController;
  late TextEditingController _instruccionesController;
  
  String _tipoSeleccionado = 'transferencia';
  bool _principal = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.metodo?.nombre ?? '');
    _bancoController = TextEditingController(text: widget.metodo?.banco ?? '');
    _titularController = TextEditingController(text: widget.metodo?.titular ?? '');
    _clabeController = TextEditingController(text: widget.metodo?.clabe ?? '');
    _cuentaController = TextEditingController(text: widget.metodo?.numeroCuenta ?? '');
    _instruccionesController = TextEditingController(text: widget.metodo?.instrucciones ?? '');
    _tipoSeleccionado = widget.metodo?.tipo ?? 'transferencia';
    _principal = widget.metodo?.principal ?? false;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _bancoController.dispose();
    _titularController.dispose();
    _clabeController.dispose();
    _cuentaController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final data = {
        'tipo': _tipoSeleccionado,
        'nombre': _nombreController.text,
        'banco': _bancoController.text.isNotEmpty ? _bancoController.text : null,
        'titular': _titularController.text.isNotEmpty ? _titularController.text : null,
        'clabe': _clabeController.text.isNotEmpty ? _clabeController.text : null,
        'numero_cuenta': _cuentaController.text.isNotEmpty ? _cuentaController.text : null,
        'instrucciones': _instruccionesController.text.isNotEmpty 
            ? _instruccionesController.text 
            : null,
        'principal': _principal,
        'activo': true,
      };

      if (widget.metodo != null) {
        await _supabase
            .from('metodos_pago')
            .update(data)
            .eq('id', widget.metodo!.id);
      } else {
        await _supabase.from('metodos_pago').insert(data);
      }

      // Si es principal, quitar principal a los demás
      if (_principal) {
        await _supabase
            .from('metodos_pago')
            .update({'principal': false})
            .neq('id', widget.metodo?.id ?? '');
      }

      widget.onGuardado();
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.metodo != null ? 'Editar Método' : 'Nuevo Método de Pago',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Tipo
            DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              decoration: _inputDecoration('Tipo de Método'),
              dropdownColor: AppTheme.surfaceDark,
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'transferencia', child: Text('🏦 Transferencia Bancaria')),
                DropdownMenuItem(value: 'efectivo', child: Text('💵 Efectivo')),
                DropdownMenuItem(value: 'tarjeta', child: Text('💳 Tarjeta')),
                DropdownMenuItem(value: 'oxxo', child: Text('🏪 OXXO/Tienda')),
                DropdownMenuItem(value: 'paypal', child: Text('🅿️ PayPal')),
                DropdownMenuItem(value: 'mercadopago', child: Text('💙 Mercado Pago')),
              ],
              onChanged: (value) => setState(() => _tipoSeleccionado = value!),
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Nombre (Ej: "BBVA Empresarial")'),
              validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            if (_tipoSeleccionado == 'transferencia') ...[
              TextFormField(
                controller: _bancoController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Banco'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titularController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Titular de la Cuenta'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clabeController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('CLABE Interbancaria'),
                keyboardType: TextInputType.number,
                maxLength: 18,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cuentaController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Número de Cuenta'),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),

            TextFormField(
              controller: _instruccionesController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Instrucciones (opcional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Principal
            SwitchListTile(
              title: const Text(
                'Método Principal',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Se mostrará como opción por defecto',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              value: _principal,
              onChanged: (v) => setState(() => _principal = v),
              activeColor: AppTheme.accentCyan,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: AppTheme.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentCyan),
      ),
    );
  }
}

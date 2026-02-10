// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/facturacion_service.dart';
import '../../data/models/facturacion_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE CONFIGURACIÓN DE FACTURACIÓN - MIS DATOS FISCALES
// Robert Darin Platform v10.14
// ═══════════════════════════════════════════════════════════════════════════════

class FacturacionConfigScreen extends StatefulWidget {
  const FacturacionConfigScreen({super.key});

  @override
  State<FacturacionConfigScreen> createState() => _FacturacionConfigScreenState();
}

class _FacturacionConfigScreenState extends State<FacturacionConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FacturacionService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  FacturacionEmisorModel? _emisor;
  List<RegimenFiscalModel> _regimenes = [];
  String? _negocioId;
  
  // Controllers - Datos Fiscales
  final _rfcController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _nombreComercialController = TextEditingController();
  final _calleController = TextEditingController();
  final _numExtController = TextEditingController();
  final _numIntController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _cpController = TextEditingController();
  final _municipioController = TextEditingController();
  final _estadoController = TextEditingController();
  
  // Controllers - API
  final _apiKeyController = TextEditingController();
  final _serieController = TextEditingController(text: 'A');
  
  // Controllers - Certificados
  final _certificadoPasswordController = TextEditingController();
  
  String _regimenSeleccionado = '612';
  String _proveedorApi = 'facturapi';
  bool _modoPruebas = true;
  bool _enviarEmailAuto = true;
  
  // Archivos de certificados
  String? _cerFileName;
  String? _keyFileName;
  String? _cerBase64;
  String? _keyBase64;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _nombreComercialController.dispose();
    _calleController.dispose();
    _numExtController.dispose();
    _numIntController.dispose();
    _coloniaController.dispose();
    _cpController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    _apiKeyController.dispose();
    _serieController.dispose();
    _certificadoPasswordController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Obtener negocio_id del usuario
      final empleado = await AppSupabase.client
          .from('empleados')
          .select('negocio_id')
          .eq('usuario_id', user.id)
          .maybeSingle();
      _negocioId = empleado?['negocio_id'];

      if (_negocioId == null) {
        final acceso = await AppSupabase.client
            .from('usuarios_negocios')
            .select('negocio_id')
            .eq('usuario_id', user.id)
            .eq('activo', true)
            .limit(1)
            .maybeSingle();
        _negocioId = acceso?['negocio_id'];
      }

      if (_negocioId == null) {
        final negocio = await AppSupabase.client
            .from('negocios')
            .select('id')
            .limit(1)
            .maybeSingle();
        _negocioId = negocio?['id'];
      }

      if (_negocioId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Cargar regímenes fiscales
      _regimenes = await _service.obtenerRegimenesFiscales();

      // Cargar configuración existente
      _emisor = await _service.obtenerEmisor(_negocioId!);

      if (_emisor != null) {
        _rfcController.text = _emisor!.rfc;
        _razonSocialController.text = _emisor!.razonSocial;
        _nombreComercialController.text = _emisor!.nombreComercial ?? '';
        _calleController.text = _emisor!.calle ?? '';
        _numExtController.text = _emisor!.numeroExterior ?? '';
        _numIntController.text = _emisor!.numeroInterior ?? '';
        _coloniaController.text = _emisor!.colonia ?? '';
        _cpController.text = _emisor!.codigoPostal;
        _municipioController.text = _emisor!.municipio ?? '';
        _estadoController.text = _emisor!.estado ?? '';
        _apiKeyController.text = _emisor!.apiKey ?? '';
        _serieController.text = _emisor!.serieFacturas;
        _regimenSeleccionado = _emisor!.regimenFiscal;
        _proveedorApi = _emisor!.proveedorApi;
        _modoPruebas = _emisor!.modoPruebas;
        _enviarEmailAuto = _emisor!.enviarEmailAutomatico;
        
        // Si ya tiene certificados
        if (_emisor!.certificadoNumero != null) {
          _cerFileName = 'Certificado cargado ✓';
          _keyFileName = 'Llave cargada ✓';
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarCertificadoCer() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cer', 'CER'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _cerFileName = result.files.single.name;
          _cerBase64 = base64Encode(bytes);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Certificado cargado: $_cerFileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al seleccionar .cer: $e');
    }
  }

  Future<void> _seleccionarCertificadoKey() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['key', 'KEY'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _keyFileName = result.files.single.name;
          _keyBase64 = base64Encode(bytes);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Llave privada cargada: $_keyFileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al seleccionar .key: $e');
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar RFC
    if (!_service.validarRfc(_rfcController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ RFC inválido. Verifica el formato.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final regimen = _regimenes.firstWhere(
        (r) => r.clave == _regimenSeleccionado,
        orElse: () => _regimenes.first,
      );

      // Preparar datos del emisor
      final emisorData = {
        'negocio_id': _negocioId,
        'rfc': _rfcController.text.toUpperCase().trim(),
        'razon_social': _razonSocialController.text.trim(),
        'nombre_comercial': _nombreComercialController.text.isEmpty 
            ? null 
            : _nombreComercialController.text.trim(),
        'regimen_fiscal': _regimenSeleccionado,
        'regimen_fiscal_descripcion': regimen.descripcion,
        'calle': _calleController.text.isEmpty ? null : _calleController.text.trim(),
        'numero_exterior': _numExtController.text.isEmpty ? null : _numExtController.text.trim(),
        'numero_interior': _numIntController.text.isEmpty ? null : _numIntController.text.trim(),
        'colonia': _coloniaController.text.isEmpty ? null : _coloniaController.text.trim(),
        'codigo_postal': _cpController.text.trim(),
        'municipio': _municipioController.text.isEmpty ? null : _municipioController.text.trim(),
        'estado': _estadoController.text.isEmpty ? null : _estadoController.text.trim(),
        'pais': 'México',
        'proveedor_api': _proveedorApi,
        'api_key': _apiKeyController.text.isEmpty ? null : _apiKeyController.text.trim(),
        'modo_pruebas': _modoPruebas,
        'serie_facturas': _serieController.text.trim(),
        'enviar_email_automatico': _enviarEmailAuto,
        'incluir_pdf': true,
        'activo': true,
      };

      // Agregar certificados si se cargaron nuevos
      if (_cerBase64 != null) {
        emisorData['certificado_cer'] = _cerBase64;
      }
      if (_keyBase64 != null) {
        emisorData['certificado_key'] = _keyBase64;
      }
      if (_certificadoPasswordController.text.isNotEmpty) {
        emisorData['certificado_password'] = _certificadoPasswordController.text;
      }

      // Verificar si ya existe
      final existente = await AppSupabase.client
          .from('facturacion_emisores')
          .select('id')
          .eq('negocio_id', _negocioId!)
          .maybeSingle();

      if (existente != null) {
        // Actualizar
        await AppSupabase.client
            .from('facturacion_emisores')
            .update(emisorData)
            .eq('id', existente['id']);
      } else {
        // Crear
        await AppSupabase.client
            .from('facturacion_emisores')
            .insert(emisorData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos fiscales guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Mis Datos Fiscales',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Principal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(16),
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
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Facturación CFDI 4.0',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _modoPruebas ? '🧪 Modo Pruebas (Sin validez fiscal)' : '🟢 Modo Producción',
                            style: TextStyle(
                              color: _modoPruebas ? Colors.orange.shade200 : Colors.green.shade200,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tus datos fiscales se usarán como EMISOR en todas las facturas de todos los módulos (Fintech, Climas, Ventas, Purificadora).',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Datos Fiscales
          _buildSectionHeader('📋 Mis Datos Fiscales', Icons.business),
          const SizedBox(height: 12),
          _buildCard([
            TextFormField(
              controller: _rfcController,
              decoration: _inputDecoration('RFC *', Icons.badge, 
                hint: 'Ej: XAXX010101000'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v?.isEmpty ?? true ? 'Ingresa tu RFC' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _razonSocialController,
              decoration: _inputDecoration('Razón Social / Nombre Completo *', Icons.person,
                hint: 'Como aparece en tu Constancia de Situación Fiscal'),
              validator: (v) => v?.isEmpty ?? true ? 'Ingresa tu razón social' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreComercialController,
              decoration: _inputDecoration('Nombre Comercial (opcional)', Icons.store,
                hint: 'Nombre de tu negocio'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _regimenSeleccionado,
              decoration: _inputDecoration('Régimen Fiscal *', Icons.account_balance),
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              items: _regimenes.map((r) => DropdownMenuItem(
                value: r.clave,
                child: Text(
                  '${r.clave} - ${r.descripcion}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              )).toList(),
              onChanged: (v) => setState(() => _regimenSeleccionado = v!),
            ),
          ]),

          const SizedBox(height: 24),

          // Dirección Fiscal
          _buildSectionHeader('📍 Domicilio Fiscal', Icons.location_on),
          const SizedBox(height: 12),
          _buildCard([
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _calleController,
                    decoration: _inputDecoration('Calle', Icons.signpost),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _numExtController,
                    decoration: _inputDecoration('No. Ext', Icons.home),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _numIntController,
                    decoration: _inputDecoration('Int', Icons.door_front_door),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _coloniaController,
                    decoration: _inputDecoration('Colonia', Icons.location_city),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cpController,
                    decoration: _inputDecoration('C.P. *', Icons.pin_drop,
                      hint: '5 dígitos'),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _municipioController,
                    decoration: _inputDecoration('Municipio/Alcaldía', Icons.map),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _estadoController,
                    decoration: _inputDecoration('Estado', Icons.public),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // Certificados CSD
          _buildSectionHeader('🔐 Certificados de Sello Digital (CSD)', Icons.security),
          const SizedBox(height: 12),
          _buildCard([
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los CSD son diferentes a tu e.firma (FIEL). Los obtienes en el portal del SAT en la sección de Certificados de Sello Digital.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Botón para cargar .cer
            _buildFileButton(
              label: 'Certificado (.cer)',
              fileName: _cerFileName,
              icon: Icons.verified_user,
              onPressed: _seleccionarCertificadoCer,
            ),
            const SizedBox(height: 12),
            
            // Botón para cargar .key
            _buildFileButton(
              label: 'Llave Privada (.key)',
              fileName: _keyFileName,
              icon: Icons.key,
              onPressed: _seleccionarCertificadoKey,
            ),
            const SizedBox(height: 16),
            
            // Password del certificado
            TextFormField(
              controller: _certificadoPasswordController,
              decoration: _inputDecoration('Contraseña del CSD', Icons.lock,
                hint: 'La que usaste al generar el CSD'),
              obscureText: true,
            ),
          ]),

          const SizedBox(height: 24),

          // Proveedor de Timbrado
          _buildSectionHeader('🔌 Proveedor de Timbrado (PAC)', Icons.cloud),
          const SizedBox(height: 12),
          _buildCard([
            DropdownButtonFormField<String>(
              value: _proveedorApi,
              decoration: _inputDecoration('Proveedor', Icons.business_center),
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'facturapi', child: Text('FacturAPI (~\$1.50/factura)')),
                DropdownMenuItem(value: 'facturama', child: Text('Facturama (~\$1.20/factura)')),
                DropdownMenuItem(value: 'fiscoclic', child: Text('FiscoClic (~\$0.90/factura)')),
              ],
              onChanged: (v) => setState(() => _proveedorApi = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: _inputDecoration('API Key del Proveedor', Icons.vpn_key,
                hint: 'La obtienes al registrarte en el proveedor'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Modo Pruebas (Sandbox)', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _modoPruebas 
                    ? '⚠️ Las facturas NO tienen validez fiscal' 
                    : '✅ Las facturas tienen VALIDEZ FISCAL',
                style: TextStyle(
                  color: _modoPruebas ? Colors.orange : Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: _modoPruebas,
              onChanged: (v) {
                if (!v) {
                  // Advertencia al cambiar a producción
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A2E),
                      title: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('¿Activar Producción?', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      content: const Text(
                        'Al activar el modo producción, todas las facturas generadas tendrán VALIDEZ FISCAL y se reportarán al SAT.\n\n'
                        'Asegúrate de tener:\n'
                        '• Certificados CSD válidos\n'
                        '• API Key de producción del proveedor\n'
                        '• Datos fiscales correctos',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() => _modoPruebas = false);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Sí, activar'),
                        ),
                      ],
                    ),
                  );
                } else {
                  setState(() => _modoPruebas = true);
                }
              },
              activeColor: Colors.green,
            ),
          ]),

          const SizedBox(height: 24),

          // Opciones de Facturación
          _buildSectionHeader('⚙️ Opciones de Facturación', Icons.settings),
          const SizedBox(height: 12),
          _buildCard([
            TextFormField(
              controller: _serieController,
              decoration: _inputDecoration('Serie de Facturas', Icons.tag,
                hint: 'Ej: A, B, FAC'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enviar factura por email automáticamente', 
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Envía PDF y XML al cliente después de timbrar',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              value: _enviarEmailAuto,
              onChanged: (v) => setState(() => _enviarEmailAuto = v),
              activeColor: Colors.cyan,
            ),
          ]),

          const SizedBox(height: 24),

          // Información del proveedor seleccionado
          _buildProviderInfo(),

          const SizedBox(height: 32),

          // Botón guardar
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardar,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Mis Datos Fiscales'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyan, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: Colors.cyan, size: 20),
      filled: true,
      fillColor: const Color(0xFF0D0D14),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyan),
      ),
    );
  }

  Widget _buildFileButton({
    required String label,
    String? fileName,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final isLoaded = fileName != null;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLoaded ? Colors.green.withOpacity(0.1) : const Color(0xFF0D0D14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLoaded ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLoaded ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    fileName ?? 'Toca para seleccionar archivo',
                    style: TextStyle(
                      color: isLoaded ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isLoaded ? Icons.check_circle : Icons.upload_file,
              color: isLoaded ? Colors.green : Colors.cyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderInfo() {
    Map<String, Map<String, String>> providerInfo = {
      'facturapi': {
        'name': 'FacturAPI',
        'url': 'https://www.facturapi.io',
        'price': '~\$1.50 MXN por factura',
        'desc': 'API moderna y fácil de usar. Excelente documentación. Recomendado para empezar.',
        'steps': '1. Regístrate gratis\n2. Crea tu organización\n3. Copia tu API Key de pruebas',
      },
      'facturama': {
        'name': 'Facturama',
        'url': 'https://www.facturama.mx',
        'price': '~\$1.20 MXN por factura',
        'desc': 'Popular en México. Buen soporte técnico en español.',
        'steps': '1. Crea tu cuenta\n2. Activa modo sandbox\n3. Genera tus credenciales API',
      },
      'fiscoclic': {
        'name': 'FiscoClic',
        'url': 'https://www.fiscoclic.mx',
        'price': '~\$0.90 MXN por factura',
        'desc': 'Opción más económica. Funcionalidad básica pero suficiente.',
        'steps': '1. Registro en portal\n2. Solicita acceso API\n3. Configura credenciales',
      },
    };

    final info = providerInfo[_proveedorApi]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cómo obtener tu API Key de ${info['name']}',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            info['desc']!,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              info['steps']!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Costo: ${info['price']}',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
              Text(
                info['url']!,
                style: const TextStyle(color: Colors.cyan, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

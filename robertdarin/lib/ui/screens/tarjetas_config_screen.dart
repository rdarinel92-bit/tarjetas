// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/tarjetas_service.dart';
import '../../data/models/tarjetas_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE CONFIGURACIÓN DE TARJETAS VIRTUALES
// Robert Darin Platform v10.14
// ═══════════════════════════════════════════════════════════════════════════════

class TarjetasConfigScreen extends StatefulWidget {
  const TarjetasConfigScreen({super.key});

  @override
  State<TarjetasConfigScreen> createState() => _TarjetasConfigScreenState();
}

class _TarjetasConfigScreenState extends State<TarjetasConfigScreen> {
  final _service = TarjetasService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVerifying = false;
  String? _negocioId;
  TarjetasConfigModel? _config;

  // Controllers
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _accountIdController = TextEditingController();
  final _programIdController = TextEditingController();
  final _nombreProgramaController = TextEditingController(text: 'Robert Darin Cards');
  final _limiteDiarioController = TextEditingController(text: '10000');
  final _limiteMensualController = TextEditingController(text: '50000');
  final _limiteTransaccionController = TextEditingController(text: '5000');

  String _proveedorSeleccionado = 'pomelo';
  String _redDefault = 'visa';
  bool _modoPruebas = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _webhookSecretController.dispose();
    _accountIdController.dispose();
    _programIdController.dispose();
    _nombreProgramaController.dispose();
    _limiteDiarioController.dispose();
    _limiteMensualController.dispose();
    _limiteTransaccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final perfil = await AppSupabase.client
          .from('usuarios')
          .select('negocio_id')
          .eq('auth_uid', user.id)
          .single();

      _negocioId = perfil['negocio_id'];

      _config = await _service.obtenerConfiguracion(_negocioId!);

      if (_config != null) {
        _proveedorSeleccionado = _config!.proveedor;
        _apiKeyController.text = _config!.apiKey ?? '';
        _apiSecretController.text = _config!.apiSecret ?? '';
        _webhookSecretController.text = _config!.webhookSecret ?? '';
        _accountIdController.text = _config!.accountId ?? '';
        _programIdController.text = _config!.programId ?? '';
        _nombreProgramaController.text = _config!.nombrePrograma;
        _limiteDiarioController.text = _config!.limiteDiarioDefault.toStringAsFixed(0);
        _limiteMensualController.text = _config!.limiteMensualDefault.toStringAsFixed(0);
        _limiteTransaccionController.text = _config!.limiteTransaccionDefault.toStringAsFixed(0);
        _redDefault = _config!.redDefault;
        _modoPruebas = _config!.modoPruebas;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar configuración: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '⚙️ Configuración de Tarjetas',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withOpacity(0.2),
                            const Color(0xFF1E3A8A).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Configura tu proveedor de emisión de tarjetas para poder crear tarjetas virtuales reales para tus usuarios.',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Proveedor
                    _buildSeccionTitulo('1. Seleccionar Proveedor', Icons.business),
                    const SizedBox(height: 12),
                    _buildSelectorProveedor(),
                    
                    const SizedBox(height: 24),
                    
                    // Modo
                    _buildSeccionTitulo('2. Modo de Operación', Icons.toggle_on),
                    const SizedBox(height: 12),
                    _buildSelectorModo(),
                    
                    const SizedBox(height: 24),
                    
                    // Credenciales
                    _buildSeccionTitulo('3. Credenciales API', Icons.key),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _apiKeyController,
                      label: 'API Key *',
                      hint: 'pk_live_xxxxx o pk_test_xxxxx',
                      esPassword: true,
                    ),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _apiSecretController,
                      label: 'API Secret',
                      hint: 'sk_live_xxxxx o sk_test_xxxxx',
                      esPassword: true,
                    ),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _webhookSecretController,
                      label: 'Webhook Secret',
                      hint: 'whsec_xxxxx',
                      esPassword: true,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // IDs de programa
                    _buildSeccionTitulo('4. IDs del Programa', Icons.badge),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _accountIdController,
                      label: 'Account ID',
                      hint: 'ID de tu cuenta en el proveedor',
                    ),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _programIdController,
                      label: 'Program ID / Affinity Group ID',
                      hint: 'ID del programa de tarjetas',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Configuración de tarjetas
                    _buildSeccionTitulo('5. Configuración Default', Icons.credit_card),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _nombreProgramaController,
                      label: 'Nombre del Programa',
                      hint: 'Nombre que aparecerá en las tarjetas',
                    ),
                    const SizedBox(height: 12),
                    
                    // Red default
                    const Text('Red Default', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildRedOption('VISA', 'visa')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRedOption('Mastercard', 'mastercard')),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Límites default
                    _buildSeccionTitulo('6. Límites Default', Icons.speed),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoTexto(
                            controller: _limiteDiarioController,
                            label: 'Límite Diario',
                            hint: '10000',
                            esNumero: true,
                            prefijo: '\$',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCampoTexto(
                            controller: _limiteMensualController,
                            label: 'Límite Mensual',
                            hint: '50000',
                            esNumero: true,
                            prefijo: '\$',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCampoTexto(
                      controller: _limiteTransaccionController,
                      label: 'Límite por Transacción',
                      hint: '5000',
                      esNumero: true,
                      prefijo: '\$',
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isVerifying ? null : _verificarCredenciales,
                            icon: _isVerifying 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.verified_user),
                            label: Text(_isVerifying ? 'Verificando...' : 'Verificar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF3B82F6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _guardarConfiguracion,
                            icon: _isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuración'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Guía del proveedor
                    _buildGuiaProveedor(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono) {
    return Row(
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
      ],
    );
  }

  Widget _buildSelectorProveedor() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildProveedorCard('pomelo', 'Pomelo', '🟣', 'LATAM'),
        _buildProveedorCard('rapyd', 'Rapyd', '🔵', 'Global'),
        _buildProveedorCard('stripe', 'Stripe Issuing', '🟪', 'USA/EU'),
        _buildProveedorCard('galileo', 'Galileo', '🟢', 'Enterprise'),
      ],
    );
  }

  Widget _buildProveedorCard(String value, String nombre, String emoji, String region) {
    final selected = _proveedorSeleccionado == value;
    return GestureDetector(
      onTap: () => setState(() => _proveedorSeleccionado = value),
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              nombre,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              region,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorModo() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _modoPruebas = true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _modoPruebas ? Colors.amber.withOpacity(0.2) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _modoPruebas ? Colors.amber : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.science,
                    color: _modoPruebas ? Colors.amber : Colors.white54,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sandbox',
                    style: TextStyle(
                      color: _modoPruebas ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Pruebas',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _confirmarModoProduccion(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !_modoPruebas ? Colors.green.withOpacity(0.2) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_modoPruebas ? Colors.green : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rocket_launch,
                    color: !_modoPruebas ? Colors.green : Colors.white54,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Producción',
                    style: TextStyle(
                      color: !_modoPruebas ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmarModoProduccion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Modo Producción', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '⚠️ En modo producción las tarjetas serán REALES y las transacciones tendrán costo real.\n\n'
          '¿Estás seguro de cambiar a modo producción?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _modoPruebas = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sí, activar producción'),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool esPassword = false,
    bool esNumero = false,
    String? prefijo,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: esPassword,
      keyboardType: esNumero ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefijo,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildRedOption(String label, String value) {
    final selected = _redDefault == value;
    return GestureDetector(
      onTap: () => setState(() => _redDefault = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuiaProveedor() {
    String guia;
    String url;
    
    switch (_proveedorSeleccionado) {
      case 'pomelo':
        guia = '''
📋 PASOS PARA POMELO:

1. Crear cuenta en pomelo.la
2. Completar proceso KYB (verificación de negocio)
3. Obtener API Keys del dashboard
4. Crear un "Affinity Group" (programa de tarjetas)
5. Configurar webhooks para notificaciones
6. Probar en sandbox antes de producción
        ''';
        url = 'https://pomelo.la/developers';
        break;
      case 'rapyd':
        guia = '''
📋 PASOS PARA RAPYD:

1. Registrarse en rapyd.net
2. Solicitar acceso a "Card Issuing"
3. Completar verificación de negocio
4. Obtener API keys del dashboard
5. Configurar programa de tarjetas
6. Integrar webhooks
        ''';
        url = 'https://docs.rapyd.net/en/card-issuing.html';
        break;
      case 'stripe':
        guia = '''
📋 PASOS PARA STRIPE ISSUING:

1. Tener cuenta Stripe activa
2. Solicitar acceso a Stripe Issuing
3. Completar verificación adicional
4. Configurar programa desde dashboard
5. Usar API keys existentes de Stripe
6. Configurar webhooks específicos
        ''';
        url = 'https://stripe.com/docs/issuing';
        break;
      case 'galileo':
        guia = '''
📋 PASOS PARA GALILEO:

1. Contactar equipo comercial de Galileo
2. Firmar contrato enterprise
3. Completar integración técnica guiada
4. Certificar integración
5. Lanzar en producción
        ''';
        url = 'https://www.galileo-ft.com';
        break;
      default:
        guia = '';
        url = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Guía para ${_proveedorSeleccionado.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            guia,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              final uri = Uri.parse(url);
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ver documentación'),
          ),
        ],
      ),
    );
  }

  Future<void> _verificarCredenciales() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la API Key primero')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    final configTemp = TarjetasConfigModel(
      id: _config?.id ?? '',
      negocioId: _negocioId!,
      proveedor: _proveedorSeleccionado,
      apiKey: _apiKeyController.text,
      apiSecret: _apiSecretController.text,
      modoPruebas: _modoPruebas,
      createdAt: _config?.createdAt ?? DateTime.now(),
    );

    final resultado = await _service.verificarCredenciales(configTemp);

    setState(() => _isVerifying = false);

    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Conexión exitosa'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${resultado['error'] ?? resultado['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _isSaving = true);

    final config = TarjetasConfigModel(
      id: _config?.id ?? '',
      negocioId: _negocioId!,
      proveedor: _proveedorSeleccionado,
      apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
      apiSecret: _apiSecretController.text.isEmpty ? null : _apiSecretController.text,
      webhookSecret: _webhookSecretController.text.isEmpty ? null : _webhookSecretController.text,
      accountId: _accountIdController.text.isEmpty ? null : _accountIdController.text,
      programId: _programIdController.text.isEmpty ? null : _programIdController.text,
      modoPruebas: _modoPruebas,
      limiteDiarioDefault: double.tryParse(_limiteDiarioController.text) ?? 10000,
      limiteMensualDefault: double.tryParse(_limiteMensualController.text) ?? 50000,
      limiteTransaccionDefault: double.tryParse(_limiteTransaccionController.text) ?? 5000,
      redDefault: _redDefault,
      nombrePrograma: _nombreProgramaController.text,
      activo: _apiKeyController.text.isNotEmpty,
      createdAt: _config?.createdAt ?? DateTime.now(),
    );

    final exito = await _service.guardarConfiguracion(config);

    setState(() => _isSaving = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error al guardar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

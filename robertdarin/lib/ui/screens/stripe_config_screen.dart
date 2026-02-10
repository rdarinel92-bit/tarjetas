// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA: Configuración Stripe
/// Robert Darin Fintech V10.6
/// ═══════════════════════════════════════════════════════════════════════════════
/// Permite configurar las API keys de Stripe por negocio
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/stripe_config_model.dart';
import '../../services/stripe_integration_service.dart';

class StripeConfigScreen extends StatefulWidget {
  const StripeConfigScreen({super.key});

  @override
  State<StripeConfigScreen> createState() => _StripeConfigScreenState();
}

class _StripeConfigScreenState extends State<StripeConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stripeService = StripeIntegrationService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _negocios = [];
  String? _negocioSeleccionado;
  StripeConfigModel? _configActual;

  // Controllers
  final _stripePublicKeyController = TextEditingController();
  final _stripeSecretKeyController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  
  // Toggles
  bool _modoProduccion = false;
  bool _linkPagoHabilitado = true;
  bool _domiciliacionHabilitada = false;
  bool _oxxoHabilitado = false;
  bool _speiHabilitado = false;
  String _comisionManejo = 'absorber';

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  @override
  void dispose() {
    _stripePublicKeyController.dispose();
    _stripeSecretKeyController.dispose();
    _webhookSecretController.dispose();
    super.dispose();
  }

  Future<void> _cargarNegocios() async {
    try {
      final res = await AppSupabase.client
          .from('negocios')
          .select('id, nombre')
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _negocios = List<Map<String, dynamic>>.from(res);
          if (_negocios.isNotEmpty) {
            _negocioSeleccionado = _negocios.first['id'];
            _cargarConfiguracion();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando negocios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarConfiguracion() async {
    if (_negocioSeleccionado == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final config = await _stripeService.getStripeConfig(_negocioSeleccionado!);
      
      if (mounted) {
        setState(() {
          _configActual = config;
          if (config != null) {
            _stripePublicKeyController.text = config.stripePublicKey ?? '';
            _stripeSecretKeyController.text = config.stripeSecretKey ?? '';
            _webhookSecretController.text = config.webhookSecret ?? '';
            _modoProduccion = config.modoProduccion;
            _linkPagoHabilitado = config.linkPagoHabilitado;
            _domiciliacionHabilitada = config.domiciliacionHabilitada;
            _oxxoHabilitado = config.oxxoHabilitado;
            _speiHabilitado = config.speiHabilitado;
            _comisionManejo = config.comisionManejo;
          } else {
            _limpiarFormulario();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _limpiarFormulario() {
    _stripePublicKeyController.clear();
    _stripeSecretKeyController.clear();
    _webhookSecretController.clear();
    _modoProduccion = false;
    _linkPagoHabilitado = true;
    _domiciliacionHabilitada = false;
    _oxxoHabilitado = false;
    _speiHabilitado = false;
    _comisionManejo = 'absorber';
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_negocioSeleccionado == null) return;

    setState(() => _isSaving = true);

    try {
      final config = StripeConfigModel(
        id: _configActual?.id ?? '',
        negocioId: _negocioSeleccionado!,
        stripePublicKey: _stripePublicKeyController.text.trim(),
        stripeSecretKey: _stripeSecretKeyController.text.trim(),
        webhookSecret: _webhookSecretController.text.trim(),
        modoProduccion: _modoProduccion,
        linkPagoHabilitado: _linkPagoHabilitado,
        domiciliacionHabilitada: _domiciliacionHabilitada,
        oxxoHabilitado: _oxxoHabilitado,
        speiHabilitado: _speiHabilitado,
        comisionManejo: _comisionManejo,
        activo: true,
        createdAt: _configActual?.createdAt ?? DateTime.now(),
      );

      final success = await _stripeService.saveStripeConfig(config);

      if (mounted) {
        setState(() => _isSaving = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '✅ Configuración guardada correctamente' 
                : '❌ Error al guardar'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          _cargarConfiguracion();
        }
      }
    } catch (e) {
      debugPrint('Error guardando: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Configuración Stripe',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _negocios.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No hay negocios registrados',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con ícono Stripe
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Selector de negocio
            _buildNegocioSelector(),
            const SizedBox(height: 24),
            
            // API Keys
            _buildApiKeysSection(),
            const SizedBox(height: 24),
            
            // Métodos de pago habilitados
            _buildMetodosPagoSection(),
            const SizedBox(height: 24),
            
            // Manejo de comisiones
            _buildComisionesSection(),
            const SizedBox(height: 24),
            
            // Webhook info
            _buildWebhookSection(),
            const SizedBox(height: 32),
            
            // Botón guardar
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.3),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/b/ba/Stripe_Logo%2C_revised_2016.svg',
              width: 60,
              height: 30,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.credit_card,
                color: Color(0xFF6366F1),
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Integración Stripe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acepta pagos con tarjeta, links y domiciliación',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          if (_configActual != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _modoProduccion ? Colors.green : Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _modoProduccion ? 'PRODUCCIÓN' : 'PRUEBAS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNegocioSelector() {
    return _buildCard(
      title: 'Negocio',
      icon: Icons.store,
      child: DropdownButtonFormField<String>(
        value: _negocioSeleccionado,
        decoration: _inputDecoration('Seleccionar negocio'),
        dropdownColor: const Color(0xFF1A1A2E),
        style: const TextStyle(color: Colors.white),
        items: _negocios.map((n) {
          return DropdownMenuItem<String>(
            value: n['id'],
            child: Text(n['nombre'] ?? 'Sin nombre'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _negocioSeleccionado = value);
          _cargarConfiguracion();
        },
      ),
    );
  }

  Widget _buildApiKeysSection() {
    return _buildCard(
      title: 'API Keys',
      icon: Icons.key,
      child: Column(
        children: [
          TextFormField(
            controller: _stripePublicKeyController,
            decoration: _inputDecoration('Public Key (pk_live_... o pk_test_...)'),
            style: const TextStyle(color: Colors.white),
            validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stripeSecretKeyController,
            decoration: _inputDecoration('Secret Key (sk_live_... o sk_test_...)').copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.visibility_off, color: Colors.white38),
                onPressed: () {},
              ),
            ),
            style: const TextStyle(color: Colors.white),
            obscureText: true,
            validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo Producción', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _modoProduccion 
                  ? '⚠️ Transacciones reales activas' 
                  : 'Usando claves de prueba',
              style: TextStyle(
                color: _modoProduccion ? Colors.amber : Colors.white54,
                fontSize: 12,
              ),
            ),
            value: _modoProduccion,
            activeColor: Colors.green,
            onChanged: (v) => setState(() => _modoProduccion = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodosPagoSection() {
    return _buildCard(
      title: 'Métodos de Pago',
      icon: Icons.payment,
      child: Column(
        children: [
          _buildMetodoToggle(
            'Links de Pago (WhatsApp)',
            'Genera links para enviar por mensaje',
            Icons.link,
            _linkPagoHabilitado,
            (v) => setState(() => _linkPagoHabilitado = v),
          ),
          const Divider(color: Colors.white12),
          _buildMetodoToggle(
            'Domiciliación Automática',
            'Cobros recurrentes en fecha de vencimiento',
            Icons.autorenew,
            _domiciliacionHabilitada,
            (v) => setState(() => _domiciliacionHabilitada = v),
          ),
          const Divider(color: Colors.white12),
          _buildMetodoToggle(
            'Pago en OXXO',
            'Genera fichas de pago para OXXO',
            Icons.store,
            _oxxoHabilitado,
            (v) => setState(() => _oxxoHabilitado = v),
          ),
          const Divider(color: Colors.white12),
          _buildMetodoToggle(
            'SPEI / Transferencia',
            'Referencia bancaria para transferir',
            Icons.account_balance,
            _speiHabilitado,
            (v) => setState(() => _speiHabilitado = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoToggle(
    String titulo,
    String subtitulo,
    IconData icono,
    bool valor,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: valor ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: valor ? const Color(0xFF6366F1) : Colors.white38),
      ),
      title: Text(titulo, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      value: valor,
      activeColor: const Color(0xFF6366F1),
      onChanged: onChanged,
    );
  }

  Widget _buildComisionesSection() {
    return _buildCard(
      title: 'Manejo de Comisiones',
      icon: Icons.percent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Quién paga la comisión de Stripe? (~3.6%)',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Absorber comisión', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Tú pagas la comisión', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: 'absorber',
            groupValue: _comisionManejo,
            activeColor: const Color(0xFF00D9FF),
            onChanged: (v) => setState(() => _comisionManejo = v!),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Agregar al cliente', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Cliente paga el monto + comisión', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: 'agregar_cliente',
            groupValue: _comisionManejo,
            activeColor: const Color(0xFF00D9FF),
            onChanged: (v) => setState(() => _comisionManejo = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildWebhookSection() {
    final webhookUrl = 'https://tu-supabase-url.supabase.co/functions/v1/stripe-webhook';
    
    return _buildCard(
      title: 'Webhook (Notificaciones)',
      icon: Icons.webhook,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configura este URL en tu dashboard de Stripe:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    webhookUrl,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: webhookUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copiado'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _webhookSecretController,
            decoration: _inputDecoration('Webhook Signing Secret (whsec_...)'),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardarConfiguracion,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Guardar Configuración', style: TextStyle(fontSize: 16)),
                ],
              ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00D9FF), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1)),
      ),
    );
  }
}

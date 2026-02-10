// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import '../../data/models/stripe_config_model.dart';
import '../../services/stripe_integration_service.dart';
import 'stripe_config_screen.dart';
import 'tarjetas_screen.dart';
import 'tarjetas_digitales_config_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// CENTRO DE PAGOS Y TARJETAS - Vista Unificada
/// Robert Darin Fintech V10.25
/// ══════════════════════════════════════════════════════════════════════════════
/// Esta pantalla explica claramente las dos funciones principales:
/// 1. COBRAR A CLIENTES (Stripe Payments) - Links de pago, OXXO, SPEI
/// 2. DAR TARJETAS A CLIENTES (Card Issuing) - Tarjetas virtuales/físicas
/// ══════════════════════════════════════════════════════════════════════════════

class CentroPagosTarjetasScreen extends StatefulWidget {
  const CentroPagosTarjetasScreen({super.key});

  @override
  State<CentroPagosTarjetasScreen> createState() => _CentroPagosTarjetasScreenState();
}

class _CentroPagosTarjetasScreenState extends State<CentroPagosTarjetasScreen> {
  bool _isLoading = true;
  
  // Estado de configuraciones
  bool _stripeConfigurado = false;
  bool _moduloTarjetasActivo = false;
  String _proveedorTarjetas = 'No configurado';

  final _stripeService = StripeIntegrationService();
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  // Estadísticas
  int _linksPagoPendientes = 0;
  int _pagosRecibidosMes = 0;
  double _montoRecibidoMes = 0;
  int _tarjetasEmitidas = 0;
  int _tarjetasActivasCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      // Verificar configuración de Stripe
      final stripeConfig = await AppSupabase.client
          .from('stripe_config')
          .select('id')
          .limit(1)
          .maybeSingle();
      _stripeConfigurado = stripeConfig != null;

      // Verificar configuración de tarjetas
      final tarjetasConfig = await AppSupabase.client
          .from('configuracion_apis')
          .select('activo, configuracion')
          .eq('servicio', 'tarjetas_digitales')
          .maybeSingle();
      
      if (tarjetasConfig != null) {
        _moduloTarjetasActivo = tarjetasConfig['activo'] ?? false;
        _proveedorTarjetas = tarjetasConfig['configuracion']?['proveedor'] ?? 'stripe';
      }

      // Cargar estadísticas de links de pago
      final linksPago = await AppSupabase.client
          .from('links_pago')
          .select('id, estado, monto, created_at')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      
      final linksList = List<Map<String, dynamic>>.from(linksPago);
      _linksPagoPendientes = linksList.where((l) => l['estado'] == 'pendiente').length;
      final pagados = linksList.where((l) => l['estado'] == 'pagado').toList();
      _pagosRecibidosMes = pagados.length;
      _montoRecibidoMes = pagados.fold(0.0, (sum, l) => sum + (l['monto'] ?? 0));

      // Cargar estadísticas de tarjetas
      final tarjetas = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('id, estado');
      
      final tarjetasList = List<Map<String, dynamic>>.from(tarjetas);
      _tarjetasEmitidas = tarjetasList.length;
      _tarjetasActivasCount = tarjetasList.where((t) => t['estado'] == 'activa').length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando estado: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Centro de Pagos",
      subtitle: "Cobros y Tarjetas para Clientes",
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarEstado,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // EXPLICACIÓN VISUAL
                    _buildExplicacionVisual(),
                    const SizedBox(height: 25),
                    
                    // SECCIÓN 1: COBRAR A CLIENTES
                    _buildSeccionCobrar(),
                    const SizedBox(height: 20),
                    
                    // SECCIÓN 2: DAR TARJETAS A CLIENTES
                    _buildSeccionTarjetas(),
                    const SizedBox(height: 20),
                    
                    // PREGUNTAS FRECUENTES
                    _buildFAQ(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildExplicacionVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A).withOpacity(0.4),
            const Color(0xFF7C3AED).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amberAccent, size: 24),
              SizedBox(width: 10),
              Text("¿Cómo Funciona?", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Diagrama visual
          Row(
            children: [
              // COBRAR
              Expanded(
                child: _buildDiagramaCard(
                  "💰",
                  "COBRAR",
                  "El cliente te paga",
                  Colors.greenAccent,
                  [
                    "Links por WhatsApp",
                    "Pago en OXXO",
                    "Transferencia SPEI",
                    "Tarjeta de crédito",
                  ],
                ),
              ),
              
              // Flecha central
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text("VS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              // DAR TARJETAS
              Expanded(
                child: _buildDiagramaCard(
                  "💳",
                  "DAR TARJETA",
                  "El cliente puede gastar",
                  Colors.cyanAccent,
                  [
                    "Tarjeta virtual",
                    "Compras en línea",
                    "Límites que tú defines",
                    "Bloqueo instantáneo",
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagramaCard(String emoji, String titulo, String subtitulo, Color color, List<String> puntos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 10),
          ...puntos.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: color, size: 12),
                const SizedBox(width: 4),
                Flexible(child: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 9))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSeccionCobrar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.attach_money, color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cobrar a tus Clientes", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Recibe pagos de préstamos y tandas", 
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        
        // Estado actual
        PremiumCard(
          child: Column(
            children: [
              _buildEstadoItem(
                "Stripe Configurado",
                _stripeConfigurado ? "✅ Listo para cobrar" : "❌ Sin configurar",
                _stripeConfigurado ? Colors.greenAccent : Colors.redAccent,
              ),
              const Divider(color: Colors.white12),
              
              // Estadísticas
              Row(
                children: [
                  Expanded(child: _buildStatChip("Links Pendientes", "$_linksPagoPendientes", Colors.orangeAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatChip("Pagos del Mes", "$_pagosRecibidosMes", Colors.greenAccent)),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, 
                        MaterialPageRoute(builder: (_) => const StripeConfigScreen())),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(_stripeConfigurado ? "Ver Config" : "Configurar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_stripeConfigurado) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _crearLinkPago,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text("Nuevo Link"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tarjeta explicativa
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("¿Para qué sirve?", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(height: 4),
                    Text(
                      "Cuando un cliente debe pagar su préstamo, le envías un link por WhatsApp. "
                      "El cliente hace clic, paga con su tarjeta o en OXXO, y tú recibes el dinero automáticamente.",
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionTarjetas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card, color: Colors.cyanAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tarjetas para tus Clientes", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Emite tarjetas virtuales que pueden usar", 
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        
        // Estado actual
        PremiumCard(
          child: Column(
            children: [
              _buildEstadoItem(
                "Módulo de Tarjetas",
                _moduloTarjetasActivo ? "✅ Activo ($_proveedorTarjetas)" : "❌ Inactivo",
                _moduloTarjetasActivo ? Colors.cyanAccent : Colors.redAccent,
              ),
              const Divider(color: Colors.white12),
              
              // Estadísticas
              Row(
                children: [
                  Expanded(child: _buildStatChip("Emitidas", "$_tarjetasEmitidas", Colors.purpleAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatChip("Activas", "$_tarjetasActivasCount", Colors.cyanAccent)),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, 
                        MaterialPageRoute(builder: (_) => const TarjetasDigitalesConfigScreen())),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(_moduloTarjetasActivo ? "Ver Config" : "Configurar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_moduloTarjetasActivo) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _emitirTarjeta,
                        icon: const Icon(Icons.add_card, size: 18),
                        label: const Text("Emitir"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tarjeta explicativa con ejemplo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 10),
                  Text("¿Para qué sirve?", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Le das una tarjeta virtual a tu cliente. Él puede usarla para comprar en internet "
                "o en tiendas físicas (si es física). Tú controlas cuánto puede gastar y puedes bloquearla en cualquier momento.",
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 12),
              
              // Ejemplo visual de tarjeta
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Robert Darin", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Text("VISA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text("4242 •••• •••• 1234", 
                      style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2, fontFamily: 'monospace')),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("JUAN PÉREZ", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text("12/28", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text("Así se ve la tarjeta del cliente en su app", 
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoItem(String titulo, String estado, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70)),
          Text(estado, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.amberAccent, size: 20),
            SizedBox(width: 8),
            Text("Preguntas Frecuentes", 
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 15),
        
        _buildFAQItem(
          "¿Necesito activar ambos?",
          "No. Son independientes. Puedes usar solo links de pago para cobrar, "
          "o solo tarjetas para darle a clientes, o ambos.",
          Icons.swap_horiz,
        ),
        _buildFAQItem(
          "¿Los clientes ven su tarjeta en la app?",
          "Sí. Cuando activas el módulo de tarjetas y le emites una al cliente, "
          "él verá su tarjeta virtual en su perfil de la app con todos los datos.",
          Icons.visibility,
        ),
        _buildFAQItem(
          "¿Cuánto cuesta?",
          "Stripe cobra comisiones por transacción (aprox. 3.6% + \$3 MXN). "
          "Las tarjetas tienen costos según el proveedor que elijas.",
          Icons.payments,
        ),
        _buildFAQItem(
          "¿Puedo probar antes de activar?",
          "Sí. Ambos módulos tienen 'Modo Prueba' donde puedes hacer transacciones "
          "de prueba sin cobrar dinero real.",
          Icons.science,
        ),
      ],
    );
  }

  Widget _buildFAQItem(String pregunta, String respuesta, IconData icono) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(pregunta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(respuesta, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarClientesDisponibles() async {
    try {
      final res = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, telefono, email, negocio_id')
          .order('nombre');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
      return [];
    }
  }

  Future<void> _crearLinkPago() async {
    final clientes = await _cargarClientesDisponibles();
    if (!mounted) return;

    if (clientes.isEmpty) {
      _mostrarError("No hay clientes disponibles para cobrar");
      return;
    }

    String? selectedClienteId;
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text("Nuevo Link de Pago", style: TextStyle(color: Colors.white)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedClienteId,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      items: clientes.map((c) {
                        final nombre = c['nombre'] ?? 'Cliente';
                        final telefono = (c['telefono'] ?? '').toString();
                        final subtitle = telefono.isNotEmpty ? ' - $telefono' : '';
                        return DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text('$nombre$subtitle'),
                        );
                      }).toList(),
                      onChanged: (value) => setDialogState(() => selectedClienteId = value),
                      validator: (value) => value == null ? 'Selecciona un cliente' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: conceptoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Concepto',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Cuota del prestamo, Pago de tanda',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final monto = double.tryParse((value ?? '').replaceAll(',', ''));
                        if (monto == null || monto <= 0) {
                          return 'Ingresa un monto valido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              child: const Text("Crear Link"),
            ),
          ],
        );
      },
    );

    final concepto = conceptoCtrl.text.trim().isEmpty ? 'Pago' : conceptoCtrl.text.trim();
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '').trim()) ?? 0;
    conceptoCtrl.dispose();
    montoCtrl.dispose();

    if (confirmado != true || selectedClienteId == null) return;

    final cliente = clientes.firstWhere(
      (c) => c['id'] == selectedClienteId,
      orElse: () => {},
    );
    if (cliente.isEmpty) {
      _mostrarError("Cliente no encontrado");
      return;
    }

    final negocioId = (cliente['negocio_id'] ?? '').toString();
    if (negocioId.isEmpty) {
      _mostrarError("El cliente no tiene negocio asociado");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final link = await _stripeService.crearLinkPago(
        negocioId: negocioId,
        clienteId: selectedClienteId!,
        concepto: concepto,
        monto: monto,
        creadoPor: AppSupabase.client.auth.currentUser?.id,
      );

      if (mounted) Navigator.pop(context);

      if (link == null) {
        _mostrarError("No se pudo crear el link de pago");
        return;
      }

      await _cargarEstado();
      _mostrarLinkGenerado(link, cliente, concepto, monto);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarError("Error: $e");
    }
  }

  void _mostrarLinkGenerado(LinkPagoModel link, Map<String, dynamic> cliente, String concepto, double monto) {
    final url = link.url ?? '';
    final nombre = (cliente['nombre'] ?? 'Cliente').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
            ),
            const SizedBox(height: 12),
            const Text("Link de Pago Creado!", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(nombre, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(concepto, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 6),
            Text(_currencyFormat.format(monto), 
              style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (url.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirLink(url);
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text("Abrir Link"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: url.isNotEmpty ? () {
                      Navigator.pop(context);
                      _compartirLink(url, concepto, monto, nombre);
                    } : null,
                    icon: const Icon(Icons.share),
                    label: const Text("Compartir"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: url.isNotEmpty ? () {
                      Navigator.pop(context);
                      _copiarLink(url);
                    } : null,
                    icon: const Icon(Icons.copy),
                    label: const Text("Copiar"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
              if (url.isEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                "El link se creo, pero no hay URL disponible.\n"
                "Verifica la configuracion de Stripe.",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _mostrarError("No se pudo abrir el link");
    }
  }

  void _copiarLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Link copiado al portapapeles"),
        backgroundColor: Colors.greenAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _compartirLink(String url, String concepto, double monto, String cliente) {
    Share.share(
      "Hola $cliente! Aqui esta tu link de pago:\n\n"
      "Concepto: $concepto\n"
      "Monto: ${_currencyFormat.format(monto)}\n\n"
      "URL: $url\n\n"
      "Gracias.",
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }

  void _emitirTarjeta() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TarjetasScreen(abrirNuevaTarjeta: true),
      ),
    );
  }
}

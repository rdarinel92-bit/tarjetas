// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/prestamo_model.dart';
import '../../../../data/models/aval_model.dart';
import '../../../../data/models/amortizacion_model.dart';
import '../../../../data/repositories/amortizaciones_repository.dart';
import '../../../clientes/controllers/usuarios_controller.dart';
import '../controllers/prestamos_controller.dart';
import '../../avales/controllers/avales_controller.dart';
import '../../../../core/supabase_client.dart';
import '../../../../ui/viewmodels/negocio_activo_provider.dart';
import 'package:intl/intl.dart';

class NuevoPrestamoView extends StatefulWidget {
  final PrestamosController controller;
  final UsuariosController usuariosController;
  final AvalesController avalesController;

  const NuevoPrestamoView({
    super.key,
    required this.controller,
    required this.usuariosController,
    required this.avalesController,
  });

  @override
  State<NuevoPrestamoView> createState() => _NuevoPrestamoViewState();
}

class _NuevoPrestamoViewState extends State<NuevoPrestamoView> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AmortizacionesRepository _amortizacionesRepo = AmortizacionesRepository();
  
  final TextEditingController montoCtrl = TextEditingController();
  final TextEditingController interesCtrl = TextEditingController();
  final TextEditingController plazoCtrl = TextEditingController();
  final TextEditingController cuotaManualCtrl = TextEditingController();

  // AVAL 1 - Principal (Requerido)
  final TextEditingController nombreAval1Ctrl = TextEditingController();
  final TextEditingController emailAval1Ctrl = TextEditingController();
  final TextEditingController telefonoAval1Ctrl = TextEditingController();
  final TextEditingController direccionAval1Ctrl = TextEditingController();
  final TextEditingController identificacionAval1Ctrl = TextEditingController();
  final TextEditingController relacionAval1Ctrl = TextEditingController();
  final TextEditingController passwordAval1Ctrl = TextEditingController();

  // AVAL 2 - Secundario (Opcional)
  final TextEditingController nombreAval2Ctrl = TextEditingController();
  final TextEditingController emailAval2Ctrl = TextEditingController();
  final TextEditingController telefonoAval2Ctrl = TextEditingController();
  final TextEditingController direccionAval2Ctrl = TextEditingController();
  final TextEditingController identificacionAval2Ctrl = TextEditingController();
  final TextEditingController relacionAval2Ctrl = TextEditingController();
  final TextEditingController passwordAval2Ctrl = TextEditingController();

  String? clienteSeleccionado;
  String _frecuenciaPago = 'Mensual';
  String _tipoPrestamo = 'normal'; // normal, diario, arquilado
  String _varianteArquilado = 'clasico'; // clasico, renovable, acumulado, mixto
  DateTime _fechaSeleccionada = DateTime.now();
  bool _guardando = false;
  bool _mostrarSeccionAval = true; // Por defecto expandido ya que es requisito
  bool _mostrarAval2 = false; // Control para segundo aval
  bool _esModoManual = false;
  bool _mostrarPreviewCard = true; // Control para ocultar/mostrar preview
  
  // Campos específicos para arquilado
  final TextEditingController interesDiarioCtrl = TextEditingController();
  int _diasPrestamo = 30; // Por defecto 30 días para préstamos diarios

  double _cuotaCalculada = 0.0;
  double _interesTotal = 0.0;
  double _totalARecibir = 0.0;
  int _numeroPagos = 0;

  late AnimationController _cardAnimController;
  late Animation<double> _cardAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Future cacheado para evitar rebuilds
  late Future<List<Map<String, dynamic>>> _clientesFuture;

  // Montos predefinidos
  final List<double> _montosSugeridos = [1000, 2500, 5000, 10000, 25000, 50000];
  // Plazos predefinidos
  final List<int> _plazosSugeridos = [1, 3, 6, 12, 18, 24];

  @override
  void initState() {
    super.initState();
    
    // Cargar clientes una sola vez
    _clientesFuture = _cargarClientes();
    
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutBack,
    );
    _cardAnimController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    montoCtrl.addListener(_actualizarCalculos);
    interesCtrl.addListener(() { if (!_esModoManual) _actualizarCalculos(); });
    plazoCtrl.addListener(_actualizarCalculos);
    cuotaManualCtrl.addListener(() { if (_esModoManual) _actualizarDesdeCuota(); });
    
    // Cargar datos del cotizador si vienen como argumentos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosCotizador();
    });
  }
  
  void _cargarDatosCotizador() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! Map<String, dynamic>) return;
    
    // Obtener valores del cotizador
    final monto = args['monto'];
    final plazoMeses = args['plazoMeses'] ?? args['plazo'];
    final numeroCuotas = args['numeroCuotas'] ?? args['cuotas'];
    final interes = args['interes'];
    final frecuencia = args['frecuencia'];
    
    // Aplicar valores si existen
    if (monto != null) {
      montoCtrl.text = monto.toStringAsFixed(0);
    }
    if (interes != null) {
      interesCtrl.text = interes.toStringAsFixed(2);
    }
    if (plazoMeses != null) {
      plazoCtrl.text = plazoMeses.toString();
    } else if (numeroCuotas != null) {
      // Compatibilidad: si solo viene numero de cuotas, usarlo como plazo (comportamiento anterior)
      plazoCtrl.text = numeroCuotas.toString();
    }
    if (frecuencia != null && frecuencia is String) {
      setState(() => _frecuenciaPago = frecuencia);
    }
    
    // Recalcular con los nuevos valores
    _actualizarCalculos();
    
    // Mostrar mensaje de confirmacion
    if (monto != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Datos del cotizador cargados: \$${monto.toStringAsFixed(0)}'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _pulseController.dispose();
    montoCtrl.dispose();
    interesCtrl.dispose();
    plazoCtrl.dispose();
    cuotaManualCtrl.dispose();
    // Aval 1
    nombreAval1Ctrl.dispose();
    emailAval1Ctrl.dispose();
    telefonoAval1Ctrl.dispose();
    direccionAval1Ctrl.dispose();
    identificacionAval1Ctrl.dispose();
    relacionAval1Ctrl.dispose();
    passwordAval1Ctrl.dispose();
    // Aval 2
    nombreAval2Ctrl.dispose();
    emailAval2Ctrl.dispose();
    telefonoAval2Ctrl.dispose();
    direccionAval2Ctrl.dispose();
    identificacionAval2Ctrl.dispose();
    relacionAval2Ctrl.dispose();
    passwordAval2Ctrl.dispose();
    interesDiarioCtrl.dispose();
    super.dispose();
  }

  void _actualizarCalculos() {
    final double monto = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    final double tasaInteres = double.tryParse(interesCtrl.text) ?? 0.0;
    final int meses = int.tryParse(plazoCtrl.text) ?? 0;
    final double interesDiario = double.tryParse(interesDiarioCtrl.text) ?? 0.0;

    if (monto > 0 && meses > 0) {
      setState(() {
        switch (_tipoPrestamo) {
          case 'diario':
            // Préstamo diario: pago diario = (monto + interés total) / días
            _diasPrestamo = meses * 30; // Convertir meses a días
            _interesTotal = monto * (tasaInteres / 100) * meses;
            _totalARecibir = monto + _interesTotal;
            _numeroPagos = _diasPrestamo;
            _cuotaCalculada = _totalARecibir / _numeroPagos;
            _frecuenciaPago = 'Diario'; // Forzar frecuencia diaria
            break;
            
          case 'arquilado':
            // Arquilado: pago = solo interés cada período, capital al final
            // interesDiario es el % que se cobra por día/semana
            _calcularNumeroPagos(meses);
            _interesTotal = monto * (interesDiario / 100) * _numeroPagos;
            _totalARecibir = monto + _interesTotal;
            _cuotaCalculada = monto * (interesDiario / 100); // Solo interés
            // Nota: La última cuota incluirá el capital
            break;
            
          default: // normal
            _interesTotal = monto * (tasaInteres / 100) * meses;
            _totalARecibir = monto + _interesTotal;
            _calcularNumeroPagos(meses);
            _cuotaCalculada = _numeroPagos > 0 ? _totalARecibir / _numeroPagos : 0.0;
        }
        
        if (!_esModoManual) cuotaManualCtrl.text = _cuotaCalculada.toStringAsFixed(2);
      });
    } else {
      setState(() {
        _cuotaCalculada = 0.0;
        _interesTotal = 0.0;
        _totalARecibir = 0.0;
        _numeroPagos = 0;
      });
    }
  }

  void _actualizarDesdeCuota() {
    final double cuota = double.tryParse(cuotaManualCtrl.text) ?? 0.0;
    final double monto = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    final int meses = int.tryParse(plazoCtrl.text) ?? 0;

    if (cuota > 0 && monto > 0 && meses > 0) {
      setState(() {
        _calcularNumeroPagos(meses);
        _totalARecibir = cuota * _numeroPagos;
        _interesTotal = _totalARecibir - monto;
        double tasaMensual = ((_totalARecibir / monto) - 1) / meses * 100;
        interesCtrl.text = tasaMensual.toStringAsFixed(2);
        _cuotaCalculada = cuota;
      });
    }
  }

  void _calcularNumeroPagos(int meses) {
    switch (_frecuenciaPago) {
      case 'Diario': _numeroPagos = meses * 30; break;
      case 'Semanal': _numeroPagos = meses * 4; break;
      case 'Quincenal': _numeroPagos = meses * 2; break;
      default: _numeroPagos = meses;
    }
  }

  Future<List<Map<String, dynamic>>> _cargarClientes() async {
    try {
      debugPrint('🔄 [NuevoPrestamoView] Iniciando carga de clientes...');
      final response = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, telefono, email')
          .order('nombre');
      debugPrint('✅ [NuevoPrestamoView] Clientes cargados: ${response.length}');
      for (var c in response) {
        debugPrint('   - ${c['nombre']} (${c['id']})');
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      debugPrint('❌ [NuevoPrestamoView] Error cargando clientes: $e');
      debugPrint('📍 Stack: $stackTrace');
      rethrow;
    }
  }

  void _recargarClientes() {
    setState(() {
      _clientesFuture = _cargarClientes();
    });
  }

  void _seleccionarMontoRapido(double monto) {
    HapticFeedback.lightImpact();
    montoCtrl.text = monto.toStringAsFixed(0);
    _actualizarCalculos();
  }

  void _seleccionarPlazoRapido(int plazo) {
    HapticFeedback.lightImpact();
    plazoCtrl.text = plazo.toString();
    _actualizarCalculos();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nuevo Préstamo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline, size: 18, color: Colors.blueAccent),
            ),
            onPressed: _mostrarAyuda,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text('Cargando clientes...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Error al cargar clientes',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _recargarClientes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final clientes = snapshot.data ?? [];

          return Stack(
            children: [
              // Fondo con gradiente sutil
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blueAccent.withOpacity(0.05),
                        Colors.transparent,
                        Colors.purpleAccent.withOpacity(0.03),
                      ],
                    ),
                  ),
                ),
              ),
              
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TARJETA DE VISTA PREVIA DEL PRÉSTAMO (deslizable)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                        child: _mostrarPreviewCard
                            ? GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  // Deslizar a la derecha para ocultar
                                  if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                                    setState(() => _mostrarPreviewCard = false);
                                    HapticFeedback.lightImpact();
                                  }
                                },
                                child: ScaleTransition(
                                  scale: _cardAnimation,
                                  child: _buildPreviewCard(currencyFormat),
                                ),
                              )
                            : _buildMiniPreviewBar(currencyFormat),
                      ),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN: CLIENTE
                      _buildSectionHeader('👤', 'Selecciona el Cliente', Colors.blueAccent),
                      const SizedBox(height: 12),
                      _buildClienteSelector(clientes),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN: TIPO DE PRÉSTAMO
                      _buildSectionHeader('📋', 'Tipo de Préstamo', Colors.tealAccent),
                      const SizedBox(height: 12),
                      _buildTipoPrestamoSelector(),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN: MONTO
                      _buildSectionHeader('💰', 'Monto del Préstamo', Colors.greenAccent),
                      const SizedBox(height: 12),
                      _buildMontoField(),
                      const SizedBox(height: 12),
                      _buildMontosRapidos(),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN: CUOTAS Y FRECUENCIA
                      _buildSectionHeader('📅', _tipoPrestamo == 'diario' ? 'Plazo (meses)' : 'Plazo y Frecuencia', Colors.orangeAccent),
                      const SizedBox(height: 12),
                      _buildPlazoFrequenciaRow(),
                      const SizedBox(height: 12),
                      if (_tipoPrestamo != 'diario') _buildPlazosRapidos(),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN: INTERÉS Y CUOTA (o Interés Diario para arquilado)
                      _buildSectionHeader('📊', _tipoPrestamo == 'arquilado' ? 'Interés por Periodo' : 'Interés y Cuota', Colors.purpleAccent),
                      const SizedBox(height: 12),
                      _tipoPrestamo == 'arquilado' ? _buildInteresArquilado() : _buildInteresYCuota(),
                      
                      const SizedBox(height: 25),
                      
                      // RESUMEN DETALLADO
                      _buildResumenDetallado(currencyFormat),
                      
                      const SizedBox(height: 25),
                      
                      // FECHA DE DESEMBOLSO
                      _buildFechaDesembolso(),
                      
                      const SizedBox(height: 25),
                      
                      // SECCIÓN AVAL (EXPANDIBLE)
                      _buildSeccionAval(),
                      
                      const SizedBox(height: 30),
                      
                      // BOTÓN GUARDAR
                      _buildBotonGuardar(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(NumberFormat f) {
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: monto > 0 ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: monto > 0
                    ? [const Color(0xFF1A5CFF), const Color(0xFF7B2FFF)]
                    : [Colors.grey.shade800, Colors.grey.shade700],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (monto > 0 ? Colors.blueAccent : Colors.grey).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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
                      'PRÉSTAMO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _frecuenciaPago.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  monto > 0 ? f.format(monto) : '\$0.00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Monto a prestar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPreviewStat('Cuota', f.format(_cuotaCalculada)),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildPreviewStat('Pagos', '$_numeroPagos'),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildPreviewStat('Total', f.format(_totalARecibir)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPreviewBar(NumberFormat f) {
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    
    return GestureDetector(
      onTap: () {
        setState(() => _mostrarPreviewCard = true);
        HapticFeedback.lightImpact();
      },
      onHorizontalDragEnd: (details) {
        // Deslizar a la izquierda para mostrar
        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
          setState(() => _mostrarPreviewCard = true);
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        key: const ValueKey('mini_preview'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: monto > 0
                ? [const Color(0xFF1A5CFF).withOpacity(0.8), const Color(0xFF7B2FFF).withOpacity(0.8)]
                : [Colors.grey.shade800, Colors.grey.shade700],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  monto > 0 ? f.format(monto) : 'Préstamo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (_totalARecibir > 0) ...[
                  Text(
                    'Total: ${f.format(_totalARecibir)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_left,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String title, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildClienteSelector(List<Map<String, dynamic>> clientes) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: clienteSeleccionado != null 
              ? Colors.blueAccent.withOpacity(0.5) 
              : Colors.white12,
        ),
      ),
      child: clientes.isEmpty
          ? Container(
              padding: const EdgeInsets.all(20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text(
                    'No hay clientes registrados',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                ],
              ),
            )
          : DropdownButtonFormField<String>(
              value: clienteSeleccionado,
              dropdownColor: const Color(0xFF252536),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: Colors.blueAccent, size: 20),
                ),
                hintText: 'Selecciona un cliente',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
              items: clientes.map((c) => DropdownMenuItem<String>(
                value: c['id']?.toString(),
                child: Text(
                  c['nombre'] ?? c['email'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white),
                ),
              )).toList(),
              onChanged: (v) => setState(() => clienteSeleccionado = v),
              validator: (v) => v == null ? 'Seleccione un cliente' : null,
            ),
    );
  }

  Widget _buildMontoField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: montoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 15),
            child: const Text(
              '\$',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          hintText: '0.00',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.white38),
            onPressed: () {
              montoCtrl.clear();
              _actualizarCalculos();
            },
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Ingresa el monto';
          final monto = double.tryParse(v.replaceAll(',', '')) ?? 0;
          if (monto <= 0) return 'El monto debe ser mayor a 0';
          if (monto < 100) return 'Monto mínimo: \$100';
          if (monto > 1000000) return 'Monto máximo: \$1,000,000';
          return null;
        },
      ),
    );
  }

  Widget _buildMontosRapidos() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _montosSugeridos.map((monto) {
        final seleccionado = montoCtrl.text == monto.toStringAsFixed(0);
        return InkWell(
          onTap: () => _seleccionarMontoRapido(monto),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: seleccionado ? Colors.greenAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: seleccionado ? Colors.greenAccent : Colors.white12,
              ),
            ),
            child: Text(
              '\$${NumberFormat('#,###').format(monto)}',
              style: TextStyle(
                color: seleccionado ? Colors.black : Colors.white70,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlazoFrequenciaRow() {
    final plazoField = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: plazoCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelText: 'Meses',
          labelStyle: const TextStyle(color: Colors.white54),
          suffixText: 'meses',
          suffixStyle: TextStyle(color: Colors.orangeAccent.withOpacity(0.7), fontSize: 12),
        ),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    );

    if (_tipoPrestamo == 'diario') {
      return Column(
        children: [
          plazoField,
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.orangeAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Frecuencia: Diario',
                  style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: plazoField),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: DropdownButtonFormField<String>(
              value: _frecuenciaPago,
              dropdownColor: const Color(0xFF252536),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.orangeAccent, size: 20),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                labelText: 'Frecuencia',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              items: ['Diario', 'Semanal', 'Quincenal', 'Mensual']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _frecuenciaPago = v!;
                  _actualizarCalculos();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlazosRapidos() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _plazosSugeridos.map((plazo) {
        final seleccionado = plazoCtrl.text == plazo.toString();
        return InkWell(
          onTap: () => _seleccionarPlazoRapido(plazo),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: seleccionado ? Colors.orangeAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: seleccionado ? Colors.orangeAccent : Colors.white12,
              ),
            ),
            child: Text(
              '$plazo ${plazo == 1 ? 'mes' : 'meses'}',
              style: TextStyle(
                color: seleccionado ? Colors.black : Colors.white70,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInteresYCuota() {
    return Column(
      children: [
        // Toggle modo manual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _esModoManual ? Icons.edit : Icons.calculate,
                    color: Colors.purpleAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _esModoManual ? 'Definir cuota manual' : 'Calcular automático',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Switch(
                value: _esModoManual,
                onChanged: (val) => setState(() => _esModoManual = val),
                activeColor: Colors.purpleAccent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Interés
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: !_esModoManual 
                        ? Colors.purpleAccent.withOpacity(0.5) 
                        : Colors.white12,
                  ),
                ),
                child: TextFormField(
                  controller: interesCtrl,
                  enabled: !_esModoManual,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: !_esModoManual ? Colors.white : Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    labelText: 'Interés',
                    labelStyle: const TextStyle(color: Colors.white54),
                    suffixText: '%',
                    suffixStyle: TextStyle(
                      color: !_esModoManual ? Colors.purpleAccent : Colors.white38,
                      fontSize: 16,
                    ),
                    filled: _esModoManual,
                    fillColor: Colors.black12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Cuota
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _esModoManual 
                        ? Colors.purpleAccent.withOpacity(0.5) 
                        : Colors.white12,
                  ),
                ),
                child: TextFormField(
                  controller: cuotaManualCtrl,
                  enabled: _esModoManual,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: _esModoManual ? Colors.white : Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    labelText: 'Cuota',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(
                      color: _esModoManual ? Colors.greenAccent : Colors.white38,
                      fontSize: 16,
                    ),
                    filled: !_esModoManual,
                    fillColor: Colors.black12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Chip para seleccionar variante de arquilado
  Widget _buildVarianteChip(String value, String label, String hint) {
    final isSelected = _varianteArquilado == value;
    return Tooltip(
      message: hint,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _varianteArquilado = value;
          });
        },
        selectedColor: Colors.greenAccent.withOpacity(0.3),
        checkmarkColor: Colors.greenAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.greenAccent : Colors.white70,
          fontSize: 12,
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        side: BorderSide(
          color: isSelected ? Colors.greenAccent : Colors.white24,
        ),
      ),
    );
  }

  /// Descripción de la variante seleccionada
  String _getDescripcionVariante() {
    switch (_varianteArquilado) {
      case 'clasico':
        return 'Arquilado Clásico: Paga solo interés cada período. Al final devuelve capital + último interés.';
      case 'renovable':
        return 'Arquilado Renovable: Al terminar, puede renovar automáticamente sin pagar capital. Ideal para clientes frecuentes.';
      case 'acumulado':
        return 'Arquilado Acumulado: Si no paga interés de un período, se suma al siguiente. Mayor riesgo.';
      case 'mixto':
        return 'Arquilado Mixto: Puede hacer abonos a capital cuando quiera. El interés se calcula sobre el saldo restante.';
      default:
        return 'Selecciona un tipo de arquilado.';
    }
  }

  /// Selector de tipo de préstamo (Normal, Diario, Arquilado)
  Widget _buildTipoPrestamoSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildTipoPrestamoOption(
            'normal',
            'Normal',
            'Cuotas iguales (capital + interés)',
            Icons.account_balance_wallet,
            Colors.blueAccent,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildTipoPrestamoOption(
            'diario',
            'Préstamo Diario',
            'Pagos diarios durante X días',
            Icons.today,
            Colors.orangeAccent,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildTipoPrestamoOption(
            'arquilado',
            'Arquilado',
            'Solo interés por periodo, capital al final',
            Icons.trending_up,
            Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildTipoPrestamoOption(String tipo, String titulo, String descripcion, IconData icon, Color color) {
    final seleccionado = _tipoPrestamo == tipo;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _tipoPrestamo = tipo;
          // Ajustar frecuencia según tipo
          if (tipo == 'diario') {
            _frecuenciaPago = 'Diario';
          } else if (tipo == 'arquilado') {
            if (_frecuenciaPago == 'Diario') {
              _frecuenciaPago = 'Semanal';
            }
          } else {
            if (_frecuenciaPago == 'Diario') {
              _frecuenciaPago = 'Mensual';
            }
          }
          _actualizarCalculos();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: seleccionado ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: seleccionado ? color : Colors.white54, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(
                      color: seleccionado ? color : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: seleccionado ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: seleccionado ? color : Colors.white24, width: 2),
              ),
              child: seleccionado
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : const SizedBox(width: 16, height: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget específico para interés de préstamo arquilado
  Widget _buildInteresArquilado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de variante de arquilado
          const Text(
            '📋 Tipo de Arquilado',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVarianteChip('clasico', 'Clásico', 'Solo interés, capital al final'),
              _buildVarianteChip('renovable', 'Renovable', 'Puede renovar sin pagar capital'),
              _buildVarianteChip('acumulado', 'Acumulado', 'Interés se acumula si no paga'),
              _buildVarianteChip('mixto', 'Mixto', 'Permite abonos a capital'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getDescripcionVariante(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: interesDiarioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Interés por período',
              labelStyle: const TextStyle(color: Colors.white54),
              suffixText: '%',
              suffixStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.greenAccent),
              ),
              filled: true,
              fillColor: Colors.black12,
            ),
            onChanged: (_) => _actualizarCalculos(),
            validator: (v) {
              if (_tipoPrestamo == 'arquilado' && (v == null || v.isEmpty)) {
                return 'Ingresa el interés por período';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Preview del cálculo
          if (_cuotaCalculada > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pago por período (solo interés):',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '\$${_cuotaCalculada.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Último pago (capital + interés):',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '\$${((double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0) + _cuotaCalculada).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a recibir:',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '\$${_totalARecibir.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenDetallado(NumberFormat f) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.15),
            Colors.purpleAccent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text(
                'Resumen del Préstamo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildResumenRow('Monto a prestar', f.format(double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0), Colors.white),
          _buildResumenRow('Interés total', f.format(_interesTotal), Colors.orangeAccent),
          const Divider(color: Colors.white24, height: 30),
          _buildResumenRow('Total a recibir', f.format(_totalARecibir), Colors.greenAccent, isBold: true),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Text(
                  '$_numeroPagos pagos de ${f.format(_cuotaCalculada)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: isBold ? 20 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFechaDesembolso() {
    return InkWell(
      onTap: _seleccionarFecha,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today, color: Colors.blueAccent),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fecha de Desembolso',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'es').format(_fechaSeleccionada),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionAval() {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _mostrarSeccionAval = !_mostrarSeccionAval),
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _mostrarSeccionAval
                    ? [Colors.orangeAccent.withOpacity(0.2), Colors.deepOrange.withOpacity(0.1)]
                    : [Colors.orangeAccent.withOpacity(0.1), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _mostrarSeccionAval 
                    ? Colors.orangeAccent.withOpacity(0.5) 
                    : Colors.orangeAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield, color: Colors.orangeAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avales del Préstamo',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Requisito: Agregar al menos 1 aval (máx. 2)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _mostrarSeccionAval ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.expand_more, color: Colors.orangeAccent),
                ),
              ],
            ),
          ),
        ),
        
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === AVAL 1 (REQUERIDO) ===
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 6),
                      Text('Aval Principal (Requerido)', 
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(nombreAval1Ctrl, 'Nombre Completo *', Icons.person_outline, required: true),
                _buildTextField(identificacionAval1Ctrl, 'DNI / Identificación *', Icons.badge, required: true),
                Row(
                  children: [
                    Expanded(child: _buildTextField(telefonoAval1Ctrl, 'Teléfono *', Icons.phone, required: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(emailAval1Ctrl, 'Email *', Icons.email, required: true)),
                  ],
                ),
                _buildTextField(direccionAval1Ctrl, 'Dirección', Icons.home),
                _buildTextField(relacionAval1Ctrl, 'Relación con el cliente', Icons.group),
                
                // Sección Acceso a la App
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phonelink_lock, color: Colors.purpleAccent, size: 16),
                          SizedBox(width: 8),
                          Text('Acceso a la App (Opcional)',
                            style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Si agregas contraseña, el aval podrá acceder a su panel',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(height: 10),
                      _buildTextField(passwordAval1Ctrl, 'Contraseña de acceso', Icons.lock, obscure: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                
                // === BOTÓN AGREGAR SEGUNDO AVAL ===
                if (!_mostrarAval2)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _mostrarAval2 = true),
                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                      label: const Text('Agregar segundo aval (opcional)', 
                        style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ),
                
                // === AVAL 2 (OPCIONAL) ===
                if (_mostrarAval2) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, color: Colors.blueAccent, size: 16),
                            SizedBox(width: 6),
                            Text('Segundo Aval (Opcional)', 
                              style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _mostrarAval2 = false;
                          nombreAval2Ctrl.clear();
                          identificacionAval2Ctrl.clear();
                          telefonoAval2Ctrl.clear();
                          emailAval2Ctrl.clear();
                          direccionAval2Ctrl.clear();
                          relacionAval2Ctrl.clear();
                          passwordAval2Ctrl.clear();
                        }),
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                        tooltip: 'Quitar segundo aval',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(nombreAval2Ctrl, 'Nombre Completo', Icons.person_outline),
                  _buildTextField(identificacionAval2Ctrl, 'DNI / Identificación', Icons.badge),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(telefonoAval2Ctrl, 'Teléfono', Icons.phone)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(emailAval2Ctrl, 'Email', Icons.email)),
                    ],
                  ),
                  _buildTextField(direccionAval2Ctrl, 'Dirección', Icons.home),
                  _buildTextField(relacionAval2Ctrl, 'Relación con el cliente', Icons.group),
                  
                  // Sección Acceso a la App - Aval 2
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.phonelink_lock, color: Colors.purpleAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Acceso a la App (Opcional)',
                              style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(passwordAval2Ctrl, 'Contraseña de acceso', Icons.lock, obscure: true),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _mostrarSeccionAval 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orangeAccent),
          ),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildBotonGuardar() {
    // Validar aval principal (requerido) - ahora incluye email
    final tieneAvalPrincipal = nombreAval1Ctrl.text.isNotEmpty &&
        identificacionAval1Ctrl.text.isNotEmpty &&
        telefonoAval1Ctrl.text.isNotEmpty &&
        emailAval1Ctrl.text.isNotEmpty;
    
    final isValid = clienteSeleccionado != null &&
        montoCtrl.text.isNotEmpty &&
        plazoCtrl.text.isNotEmpty &&
        _cuotaCalculada > 0 &&
        tieneAvalPrincipal; // Aval es requisito

    // Mensaje de error si falta aval
    String? mensajeError;
    if (clienteSeleccionado != null && 
        montoCtrl.text.isNotEmpty && 
        plazoCtrl.text.isNotEmpty && 
        !tieneAvalPrincipal) {
      mensajeError = 'Completa los datos del aval principal';
    }

    return Column(
      children: [
        if (mensajeError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.redAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(mensajeError, 
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: isValid
                ? const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent])
                : null,
            color: isValid ? null : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isValid
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (_guardando || !isValid) ? null : _guardarTodo,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                if (_guardando)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle,
                    color: isValid ? Colors.white : Colors.white38,
                  ),
                const SizedBox(width: 12),
                Text(
                  _guardando ? 'Guardando...' : 'REGISTRAR PRÉSTAMO',
                  style: TextStyle(
                    color: isValid ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarAyuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.yellowAccent),
                SizedBox(width: 10),
                Text('Guía Rápida', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _buildAyudaItem('💰', 'Monto', 'Selecciona uno rápido o escribe tu cantidad'),
            _buildAyudaItem('📅', 'Plazo', 'Duración del préstamo en meses'),
            _buildAyudaItem('📊', 'Interés', 'Porcentaje mensual a cobrar'),
            _buildAyudaItem('🔄', 'Modo Manual', 'Define la cuota y calcula el interés'),
            _buildAyudaItem('🛡️', 'Aval', 'Requisito - Al menos 1 garante'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildAyudaItem(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF1E1E2C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _fechaSeleccionada = d);
  }

  Future<void> _guardarTodo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);
    HapticFeedback.mediumImpact();
    
    try {
      final monto = double.parse(montoCtrl.text.replaceAll(',', ''));
      final interes = double.tryParse(interesCtrl.text) ?? 0.0;
      final numeroCuotas = int.parse(plazoCtrl.text);
      final interesDiario = double.tryParse(interesDiarioCtrl.text) ?? 0.0;
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      final p = PrestamoModel(
        id: '',
        clienteId: clienteSeleccionado!,
        negocioId: negocioId,
        monto: monto,
        interes: interes,
        plazoMeses: numeroCuotas,
        frecuenciaPago: _frecuenciaPago,
        fechaCreacion: _fechaSeleccionada,
        estado: 'activo',
        tipoPrestamo: _tipoPrestamo,
        interesDiario: interesDiario,
        capitalAlFinal: _tipoPrestamo == 'arquilado',
        varianteArquilado: _tipoPrestamo == 'arquilado' ? _varianteArquilado : null,
      );
      
      // Usar crearPrestamoConId para obtener el ID y crear amortizaciones
      final prestamoId = await widget.controller.crearPrestamoConId(p);
      final exitoP = prestamoId != null;
      
      // ════════════════════════════════════════════════════════════════════
      // GENERAR AMORTIZACIONES AUTOMÁTICAMENTE
      // ════════════════════════════════════════════════════════════════════
      if (exitoP) {
        await _generarAmortizaciones(prestamoId, monto, interes, numeroCuotas, interesDiario);
      }
      
      // V10.55: Guardar Aval 1 (requerido) y VINCULARLO con el préstamo
      if (exitoP && nombreAval1Ctrl.text.isNotEmpty) {
        final aval1 = AvalModel(
          id: '',
          nombre: nombreAval1Ctrl.text,
          email: emailAval1Ctrl.text,
          telefono: telefonoAval1Ctrl.text,
          direccion: direccionAval1Ctrl.text,
          relacion: relacionAval1Ctrl.text,
          clienteId: clienteSeleccionado!,
          identificacion: identificacionAval1Ctrl.text,
        );
        
        // Crear aval y vincularlo con el préstamo (orden 1 = principal)
        await widget.avalesController.crearAvalYVincular(
          aval: aval1,
          prestamoId: prestamoId,
          orden: 1,
          password: passwordAval1Ctrl.text.isNotEmpty ? passwordAval1Ctrl.text : null,
        );
      }
      
      // V10.55: Guardar Aval 2 (opcional) y VINCULARLO con el préstamo
      if (exitoP && _mostrarAval2 && nombreAval2Ctrl.text.isNotEmpty) {
        final aval2 = AvalModel(
          id: '',
          nombre: nombreAval2Ctrl.text,
          email: emailAval2Ctrl.text,
          telefono: telefonoAval2Ctrl.text,
          direccion: direccionAval2Ctrl.text,
          relacion: relacionAval2Ctrl.text,
          clienteId: clienteSeleccionado!,
          identificacion: identificacionAval2Ctrl.text,
        );
        
        // Crear aval y vincularlo con el préstamo (orden 2 = secundario)
        await widget.avalesController.crearAvalYVincular(
          aval: aval2,
          prestamoId: prestamoId,
          orden: 2,
          password: passwordAval2Ctrl.text.isNotEmpty ? passwordAval2Ctrl.text : null,
        );
      }
      
      if (mounted && exitoP) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('¡Préstamo registrado exitosamente!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted && !exitoP) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al registrar el préstamo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// ════════════════════════════════════════════════════════════════════════════
  /// GENERADOR DE AMORTIZACIONES - Calcula y crea el plan de pagos
  /// ════════════════════════════════════════════════════════════════════════════
  Future<void> _generarAmortizaciones(
    String prestamoId, 
    double monto, 
    double interesMensual, 
    int numeroCuotas,
    double interesDiario,
  ) async {
    try {
      final List<AmortizacionModel> amortizaciones = [];
      DateTime fechaBase = _fechaSeleccionada;
      
      // Calcular montos según tipo de préstamo
      double totalConInteres;
      double capitalPorCuota;
      double interesPorCuota;
      
      switch (_tipoPrestamo) {
        case 'diario':
          // Préstamo diario: interés simple, pagos iguales
          final mesesEquivalentes = numeroCuotas / 30; // días a meses
          totalConInteres = monto * (1 + (interesMensual / 100) * mesesEquivalentes);
          capitalPorCuota = monto / numeroCuotas;
          interesPorCuota = (totalConInteres - monto) / numeroCuotas;
          break;
          
        case 'arquilado':
          // Arquilado: interés periódico, capital al final
          // Cada cuota = solo interés (excepto la última que incluye capital)
          interesPorCuota = monto * (interesDiario / 100);
          capitalPorCuota = 0; // Solo la última cuota tiene capital
          totalConInteres = monto + (interesPorCuota * numeroCuotas);
          break;
          
        default: // normal
          // Préstamo normal con interés simple
          final mesesDuracion = _calcularMesesDuracion(numeroCuotas);
          totalConInteres = monto * (1 + (interesMensual / 100) * mesesDuracion);
          capitalPorCuota = monto / numeroCuotas;
          interesPorCuota = (totalConInteres - monto) / numeroCuotas;
      }
      
      double saldoRestante = monto;
      
      for (int i = 1; i <= numeroCuotas; i++) {
        // Calcular fecha de vencimiento según frecuencia
        final fechaVencimiento = _calcularFechaVencimiento(fechaBase, i);
        
        double cuotaCapital = capitalPorCuota;
        double cuotaInteres = interesPorCuota;
        
        // Para arquilado: última cuota incluye capital
        if (_tipoPrestamo == 'arquilado' && i == numeroCuotas) {
          cuotaCapital = monto;
        }
        
        saldoRestante -= cuotaCapital;
        if (saldoRestante < 0) saldoRestante = 0;
        
        amortizaciones.add(AmortizacionModel(
          id: '',
          prestamoId: prestamoId,
          numeroCuota: i,
          fechaVencimiento: fechaVencimiento,
          monto: cuotaCapital + cuotaInteres,
          capital: cuotaCapital,
          interes: cuotaInteres,
          estado: 'pendiente',
        ));
      }
      
      // Insertar todas las amortizaciones en lote
      await _amortizacionesRepo.crearAmortizacionesEnLote(amortizaciones);
      debugPrint('✅ Generadas $numeroCuotas amortizaciones para préstamo $prestamoId');
      
    } catch (e) {
      debugPrint('❌ Error generando amortizaciones: $e');
      // No lanzamos excepción para no bloquear la creación del préstamo
    }
  }

  /// Calcula meses equivalentes según frecuencia de pago
  double _calcularMesesDuracion(int numeroCuotas) {
    switch (_frecuenciaPago) {
      case 'Diario': return numeroCuotas / 30;
      case 'Semanal': return numeroCuotas / 4;
      case 'Quincenal': return numeroCuotas / 2;
      default: return numeroCuotas.toDouble(); // Mensual
    }
  }

  /// Calcula fecha de vencimiento de cada cuota según frecuencia
  DateTime _calcularFechaVencimiento(DateTime fechaBase, int numeroCuota) {
    switch (_frecuenciaPago) {
      case 'Diario':
        return fechaBase.add(Duration(days: numeroCuota));
      case 'Semanal':
        return fechaBase.add(Duration(days: numeroCuota * 7));
      case 'Quincenal':
        return fechaBase.add(Duration(days: numeroCuota * 15));
      default: // Mensual
        return DateTime(
          fechaBase.year,
          fechaBase.month + numeroCuota,
          fechaBase.day,
        );
    }
  }
}

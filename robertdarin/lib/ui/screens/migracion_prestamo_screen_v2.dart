// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// MIGRACIÓN DE PRÉSTAMO EXISTENTE - Robert Darin Fintech V10.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Diseño elegante para importar préstamos activos con:
/// - Selección visual de cliente
/// - Cálculo automático de amortizaciones
/// - Selección individual de cuotas pagadas
/// - Opción de agregar aval
/// - Preview interactivo
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/prestamo_model.dart';
import '../../data/models/amortizacion_model.dart';
import '../../data/repositories/amortizaciones_repository.dart';
import '../../modules/clientes/controllers/usuarios_controller.dart';
import '../../modules/finanzas/prestamos/controllers/prestamos_controller.dart';
import '../../core/supabase_client.dart';

class MigracionPrestamoScreenV2 extends StatefulWidget {
  const MigracionPrestamoScreenV2({super.key});

  @override
  State<MigracionPrestamoScreenV2> createState() => _MigracionPrestamoScreenV2State();
}

class _MigracionPrestamoScreenV2State extends State<MigracionPrestamoScreenV2>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AmortizacionesRepository _amortizacionesRepo = AmortizacionesRepository();
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Controllers
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _interesCtrl = TextEditingController(text: '10');
  final TextEditingController _cuotasCtrl = TextEditingController();
  final TextEditingController _notasCtrl = TextEditingController();

  // Estado
  Map<String, dynamic>? _clienteSeleccionado;
  Map<String, dynamic>? _avalSeleccionado;
  String _frecuencia = 'Semanal';
  String _tipoPrestamo = 'normal'; // normal, diario, arquilado
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  bool _guardando = false;
  bool _mostrarAval = false;
  int _pasoActual = 0;
  
  // Campos específicos para arquilado
  final TextEditingController _interesDiarioCtrl = TextEditingController();

  // Preview de amortizaciones
  List<_CuotaPreview> _cuotasPreview = [];
  Set<int> _cuotasPagadas = {};
  double _totalAPagar = 0;
  double _totalPagado = 0;

  // Datos cargados
  List<dynamic> _usuarios = [];
  bool _cargandoUsuarios = true;
  String? _errorCarga;

  // Animaciones
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Montos rápidos
  final List<double> _montosRapidos = [5000, 10000, 15000, 20000, 30000, 50000];
  final List<int> _cuotasRapidas = [4, 6, 8, 10, 12, 24];
  final List<double> _interesesRapidos = [5, 10, 15, 20, 25];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    _montoCtrl.addListener(_recalcular);
    _interesCtrl.addListener(_recalcular);
    _cuotasCtrl.addListener(_recalcular);

    // Cargar usuarios al iniciar
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargandoUsuarios = true;
      _errorCarga = null;
    });

    try {
      final usuariosCtrl = Provider.of<UsuariosController>(context, listen: false);
      // Usar obtenerUsuariosClientes para excluir superadmin/admin
      final usuarios = await usuariosCtrl.obtenerUsuariosClientes();
      if (mounted) {
        setState(() {
          _usuarios = usuarios;
          _cargandoUsuarios = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
      if (mounted) {
        setState(() {
          _errorCarga = 'Error al cargar clientes: $e';
          _cargandoUsuarios = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _montoCtrl.dispose();
    _interesCtrl.dispose();
    _cuotasCtrl.dispose();
    _notasCtrl.dispose();
    _interesDiarioCtrl.dispose();
    super.dispose();
  }

  void _recalcular() {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    final interes = double.tryParse(_interesCtrl.text) ?? 0;
    final cuotas = int.tryParse(_cuotasCtrl.text) ?? 0;
    final interesDiario = double.tryParse(_interesDiarioCtrl.text) ?? 0;

    if (monto <= 0 || cuotas <= 0) {
      setState(() {
        _cuotasPreview = [];
        _totalAPagar = 0;
        _totalPagado = 0;
      });
      return;
    }

    int diasEntreCuotas = _getDiasEntreCuotas();
    List<_CuotaPreview> previews = [];
    double montoConInteres;
    double montoCuota;

    switch (_tipoPrestamo) {
      case 'diario':
        // Préstamo diario: cada día se paga una parte igual
        montoConInteres = monto * (1 + interes / 100);
        montoCuota = montoConInteres / cuotas;
        diasEntreCuotas = 1; // Forzar diario
        for (int i = 0; i < cuotas; i++) {
          final fechaVenc = _fechaInicio.add(Duration(days: i + 1));
          previews.add(_CuotaPreview(
            numero: i + 1,
            monto: montoCuota,
            fechaVencimiento: fechaVenc,
            esCapitalFinal: false,
          ));
        }
        break;
        
      case 'arquilado':
        // Arquilado: cada cuota es solo interés, última cuota incluye capital
        final interesTotal = monto * (interesDiario / 100);
        montoConInteres = monto + (interesTotal * cuotas);
        for (int i = 0; i < cuotas; i++) {
          final fechaVenc = _fechaInicio.add(Duration(days: diasEntreCuotas * (i + 1)));
          final esUltima = i == cuotas - 1;
          previews.add(_CuotaPreview(
            numero: i + 1,
            monto: esUltima ? interesTotal + monto : interesTotal, // Última incluye capital
            fechaVencimiento: fechaVenc,
            esCapitalFinal: esUltima,
          ));
        }
        break;
        
      default: // normal
        montoConInteres = monto * (1 + interes / 100);
        montoCuota = montoConInteres / cuotas;
        for (int i = 0; i < cuotas; i++) {
          final fechaVenc = _fechaInicio.add(Duration(days: diasEntreCuotas * (i + 1)));
          previews.add(_CuotaPreview(
            numero: i + 1,
            monto: montoCuota,
            fechaVencimiento: fechaVenc,
            esCapitalFinal: false,
          ));
        }
    }

    double pagado = 0;
    for (var num in _cuotasPagadas) {
      if (num <= cuotas && num <= previews.length) {
        pagado += previews[num - 1].monto;
      }
    }

    setState(() {
      _cuotasPreview = previews;
      _totalAPagar = _tipoPrestamo == 'arquilado' ? montoConInteres : (monto * (1 + interes / 100));
      _totalPagado = pagado;
    });
  }

  int _getDiasEntreCuotas() {
    switch (_frecuencia) {
      case 'Diario': return 1;
      case 'Semanal': return 7;
      case 'Quincenal': return 15;
      case 'Mensual': return 30;
      default: return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        children: [
          // Fondo con gradiente
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.orange.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Contenido principal
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildProgressBar(),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: _buildCurrentStep(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_pasoActual > 0) {
                setState(() => _pasoActual--);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _pasoActual > 0 ? Icons.arrow_back : Icons.close,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Migrar Préstamo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getTitulosPaso()[_pasoActual],
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.deepOrange.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.upload_file, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  List<String> _getTitulosPaso() => [
    'Selecciona el cliente',
    'Datos del préstamo',
    'Selecciona cuotas pagadas',
    'Confirmar migración',
  ];

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _pasoActual;
          // ignore: unused_local_variable
          final isCompleted = index < _pasoActual;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive
                    ? LinearGradient(
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                      )
                    : null,
                color: isActive ? null : Colors.white.withValues(alpha: 0.1),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_pasoActual) {
      case 0:
        return _buildPaso1SeleccionCliente();
      case 1:
        return _buildPaso2DatosPrestamo();
      case 2:
        return _buildPaso3CuotasPagadas();
      case 3:
        return _buildPaso4Confirmacion();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 1: SELECCIÓN DE CLIENTE
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso1SeleccionCliente() {
    if (_cargandoUsuarios) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Cargando clientes...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_errorCarga != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_errorCarga!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarUsuarios,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      );
    }

    if (_usuarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            const Text('No hay clientes registrados', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Buscador
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente...',
                    hintStyle: TextStyle(color: Colors.white38),
                    icon: Icon(Icons.search, color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Lista de clientes
              ..._usuarios.map((u) => _buildClienteCard(u)).toList(),
            ],
          ),
        ),
        
        // Botón continuar
        if (_clienteSeleccionado != null)
          _buildBotonContinuar(() => setState(() => _pasoActual = 1)),
      ],
    );
  }

  Widget _buildClienteCard(dynamic usuario) {
    final isSelected = _clienteSeleccionado?['id'] == usuario.id;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _clienteSeleccionado = {
            'id': usuario.id,
            'nombre': usuario.nombreCompleto ?? usuario.email,
            'email': usuario.email,
            'telefono': usuario.telefono,
          };
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.orange.withOpacity(0.2), Colors.deepOrange.withOpacity(0.1)],
                )
              : null,
          color: isSelected ? null : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isSelected ? Colors.orange : Colors.white.withOpacity(0.1),
              child: Text(
                (usuario.nombreCompleto ?? usuario.email ?? 'C')[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombreCompleto ?? usuario.email ?? 'Sin nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (usuario.telefono != null)
                    Text(
                      usuario.telefono!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 2: DATOS DEL PRÉSTAMO
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso2DatosPrestamo() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cliente seleccionado
              _buildClienteSeleccionadoCard(),
              const SizedBox(height: 20),
              
              // Tipo de préstamo (NUEVO)
              _buildSeccionTitulo('Tipo de Préstamo', Icons.category),
              const SizedBox(height: 12),
              _buildTipoPrestamoSelector(),
              const SizedBox(height: 20),

              // Monto
              _buildSeccionTitulo('Monto del Préstamo', Icons.attach_money),
              const SizedBox(height: 12),
              _buildMontoInput(),
              const SizedBox(height: 12),
              _buildChipsRapidos(
                items: _montosRapidos,
                selected: double.tryParse(_montoCtrl.text),
                format: (v) => '\$${NumberFormat('#,###').format(v)}',
                onSelect: (v) {
                  _montoCtrl.text = v.toStringAsFixed(0);
                  HapticFeedback.selectionClick();
                },
              ),

              const SizedBox(height: 24),

              // Interés - Solo mostrar si NO es arquilado
              if (_tipoPrestamo != 'arquilado') ...[
                _buildSeccionTitulo('Interés (%)', Icons.percent),
                const SizedBox(height: 12),
                _buildInteresInput(),
                const SizedBox(height: 12),
                _buildChipsRapidos(
                  items: _interesesRapidos,
                  selected: double.tryParse(_interesCtrl.text),
                  format: (v) => '${v.toStringAsFixed(0)}%',
                  onSelect: (v) {
                    _interesCtrl.text = v.toStringAsFixed(0);
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 24),
              ],
              
              // Interés por periodo - Solo para arquilado
              if (_tipoPrestamo == 'arquilado') ...[
                _buildSeccionTitulo('Interés por Periodo (%)', Icons.trending_up),
                const SizedBox(height: 12),
                _buildInteresDiarioInput(),
                const SizedBox(height: 8),
                Text(
                  'Porcentaje que se cobra en cada pago (solo interés). El capital se paga al final.',
                  style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 11),
                ),
                const SizedBox(height: 24),
              ],

              // Cuotas y frecuencia
              _buildSeccionTitulo(_tipoPrestamo == 'diario' ? 'Días del Préstamo' : 'Plan de Pagos', Icons.calendar_month),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCuotasInput()),
                  const SizedBox(width: 12),
                  if (_tipoPrestamo != 'diario')
                    Expanded(child: _buildFrecuenciaDropdown()),
                ],
              ),
              const SizedBox(height: 12),
              if (_tipoPrestamo != 'diario')
                _buildChipsRapidos(
                  items: _cuotasRapidas.map((e) => e.toDouble()).toList(),
                  selected: double.tryParse(_cuotasCtrl.text),
                  format: (v) => '${v.toInt()} cuotas',
                  onSelect: (v) {
                    _cuotasCtrl.text = v.toInt().toString();
                    HapticFeedback.selectionClick();
                  },
                ),

              const SizedBox(height: 24),

              // Fecha de inicio
              _buildSeccionTitulo('Fecha de Inicio', Icons.event),
              const SizedBox(height: 12),
              _buildFechaSelector(),

              const SizedBox(height: 24),

              // Aval (opcional)
              _buildAvalSection(),

              const SizedBox(height: 24),

              // Notas
              _buildSeccionTitulo('Notas (Opcional)', Icons.note),
              const SizedBox(height: 12),
              _buildNotasInput(),

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Preview y botón
        if (_cuotasPreview.isNotEmpty) _buildPreviewResumen(),
        _buildBotonContinuar(
          () {
            if (_formKey.currentState!.validate() && _montoCtrl.text.isNotEmpty && _cuotasCtrl.text.isNotEmpty) {
              setState(() => _pasoActual = 2);
            }
          },
          enabled: _cuotasPreview.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildClienteSeleccionadoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(0.15), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange,
            child: Text(
              (_clienteSeleccionado?['nombre'] ?? 'C')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _clienteSeleccionado?['nombre'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Cliente seleccionado',
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _pasoActual = 0),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildMontoInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: _montoCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          prefixText: '\$ ',
          prefixStyle: TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
          hintText: '0',
          hintStyle: TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
        ),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildInteresInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: _interesCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          suffixText: '%',
          suffixStyle: TextStyle(color: Colors.orange, fontSize: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCuotasInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: _cuotasCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          hintText: 'Cuotas',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildFrecuenciaDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _frecuencia,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          items: ['Diario', 'Semanal', 'Quincenal', 'Mensual']
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) {
            setState(() => _frecuencia = v!);
            _recalcular();
          },
        ),
      ),
    );
  }

  /// Selector visual de tipo de préstamo
  Widget _buildTipoPrestamoSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTipoOpcion(
            tipo: 'normal',
            titulo: 'Normal',
            descripcion: 'Cuotas iguales (capital + interés)',
            icon: Icons.account_balance_wallet,
            color: Colors.blue,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildTipoOpcion(
            tipo: 'diario',
            titulo: 'Préstamo Diario',
            descripcion: 'Pagos diarios durante X días',
            icon: Icons.today,
            color: Colors.orange,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildTipoOpcion(
            tipo: 'arquilado',
            titulo: 'Arquilado',
            descripcion: 'Solo interés por periodo, capital al final',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTipoOpcion({
    required String tipo,
    required String titulo,
    required String descripcion,
    required IconData icon,
    required Color color,
  }) {
    final seleccionado = _tipoPrestamo == tipo;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _tipoPrestamo = tipo;
          if (tipo == 'diario') {
            _frecuencia = 'Diario';
          } else if (tipo == 'arquilado') {
            _frecuencia = 'Semanal';
          }
        });
        _recalcular();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: seleccionado ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: seleccionado ? color : Colors.white54, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    descripcion,
                    style: TextStyle(color: seleccionado ? color.withOpacity(0.8) : Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: seleccionado ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: seleccionado ? color : Colors.white24, width: 2),
              ),
              child: seleccionado
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox(width: 14, height: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Input para interés por periodo (arquilado)
  Widget _buildInteresDiarioInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: _interesDiarioCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        onChanged: (_) => _recalcular(),
        decoration: InputDecoration(
          suffixText: '%',
          suffixStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 20),
          hintText: '0',
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (v) {
          if (_tipoPrestamo == 'arquilado' && (v == null || v.isEmpty)) {
            return 'Requerido';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFechaSelector() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _fechaInicio,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (d != null) {
          setState(() => _fechaInicio = d);
          _recalcular();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.orange),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMMM yyyy', 'es').format(_fechaInicio),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.edit, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAvalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Aval (Opcional)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            Switch(
              value: _mostrarAval,
              onChanged: (v) => setState(() => _mostrarAval = v),
              activeColor: Colors.blue,
            ),
          ],
        ),
        if (_mostrarAval) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _seleccionarAval(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _avalSeleccionado != null ? Colors.blue : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _avalSeleccionado != null ? Icons.person : Icons.person_add,
                    color: _avalSeleccionado != null ? Colors.blue : Colors.white38,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _avalSeleccionado?['nombre'] ?? 'Seleccionar aval...',
                    style: TextStyle(
                      color: _avalSeleccionado != null ? Colors.white : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _seleccionarAval() async {
    final usuariosCtrl = Provider.of<UsuariosController>(context, listen: false);
    // Usar obtenerUsuariosClientes para excluir superadmin/admin
    final usuarios = await usuariosCtrl.obtenerUsuariosClientes();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar Aval',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView(
                children: usuarios.where((u) => u.id != _clienteSeleccionado?['id']).map((u) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      child: Text(
                        (u.nombreCompleto ?? u.email)[0].toUpperCase(),
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    title: Text(u.nombreCompleto ?? u.email, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        _avalSeleccionado = {
                          'id': u.id,
                          'nombre': u.nombreCompleto ?? u.email,
                        };
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotasInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: _notasCtrl,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Observaciones sobre el préstamo...',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildChipsRapidos<T>({
    required List<T> items,
    required T? selected,
    required String Function(T) format,
    required void Function(T) onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = selected == item;
          return GestureDetector(
            onTap: () => onSelect(item),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [Colors.orange.shade600, Colors.deepOrange.shade700])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                format(item),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviewResumen() {
    final cuotasPendientes = _cuotasPreview.length - _cuotasPagadas.length;
    final montoCuota = _cuotasPreview.isNotEmpty ? _cuotasPreview.first.monto : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), Colors.orange.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumenItem('Total', _currencyFormat.format(_totalAPagar), Colors.white),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildResumenItem('Cuota', _currencyFormat.format(montoCuota), Colors.orange),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildResumenItem('Pendientes', '$cuotasPendientes', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 3: SELECCIÓN DE CUOTAS PAGADAS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso3CuotasPagadas() {
    return Column(
      children: [
        // Info
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toca las cuotas que ya fueron pagadas (${_cuotasPagadas.length} seleccionadas)',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Grid de cuotas
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.9,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _cuotasPreview.length,
            itemBuilder: (context, index) {
              final cuota = _cuotasPreview[index];
              final isPagada = _cuotasPagadas.contains(cuota.numero);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isPagada) {
                      _cuotasPagadas.remove(cuota.numero);
                    } else {
                      _cuotasPagadas.add(cuota.numero);
                    }
                    _recalcular();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isPagada
                        ? LinearGradient(colors: [Colors.green.shade600, Colors.green.shade800])
                        : null,
                    color: isPagada ? null : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPagada ? Colors.green : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${cuota.numero}',
                        style: TextStyle(
                          color: isPagada ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM').format(cuota.fechaVencimiento),
                        style: TextStyle(
                          color: isPagada ? Colors.white70 : Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isPagada ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isPagada ? Colors.white : Colors.white24,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResumenItem('Pagadas', '${_cuotasPagadas.length}', Colors.green),
              _buildResumenItem('Pendientes', '${_cuotasPreview.length - _cuotasPagadas.length}', Colors.orange),
              _buildResumenItem('Total Pagado', _currencyFormat.format(_totalPagado), Colors.green),
            ],
          ),
        ),

        _buildBotonContinuar(() => setState(() => _pasoActual = 3)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 4: CONFIRMACIÓN
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso4Confirmacion() {
    final saldoPendiente = _totalAPagar - _totalPagado;
    final montoCuota = _cuotasPreview.isNotEmpty ? _cuotasPreview.first.monto : 0.0;
    
    // Nombre legible del tipo de préstamo
    String tipoPrestamoNombre;
    Color tipoColor;
    switch (_tipoPrestamo) {
      case 'diario':
        tipoPrestamoNombre = 'DIARIO';
        tipoColor = Colors.orange;
        break;
      case 'arquilado':
        tipoPrestamoNombre = 'ARQUILADO';
        tipoColor = Colors.green;
        break;
      default:
        tipoPrestamoNombre = 'NORMAL';
        tipoColor = Colors.blue;
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Preview Card tipo tarjeta
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade700, Colors.deepOrange.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
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
                        Row(
                          children: [
                            const Text(
                              'PRÉSTAMO A MIGRAR',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tipoColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tipoPrestamoNombre,
                                style: TextStyle(color: tipoColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.upload_file, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _currencyFormat.format(_totalAPagar),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tipoPrestamo == 'arquilado'
                          ? '${_cuotasPreview.length - 1} pagos de interés + pago final con capital'
                          : '${_cuotasPreview.length} cuotas de ${_currencyFormat.format(montoCuota)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _clienteSeleccionado?['nombre']?.toUpperCase() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          _frecuencia.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Detalles
              _buildDetalleRow('Cliente', _clienteSeleccionado?['nombre'] ?? ''),
              _buildDetalleRow('Monto Original', _currencyFormat.format(double.tryParse(_montoCtrl.text) ?? 0)),
              _buildDetalleRow('Interés', '${_interesCtrl.text}%'),
              _buildDetalleRow('Total a Pagar', _currencyFormat.format(_totalAPagar)),
              _buildDetalleRow('Cuotas', '${_cuotasPreview.length} $_frecuencia'),
              _buildDetalleRow('Cuotas Pagadas', '${_cuotasPagadas.length}', color: Colors.green),
              _buildDetalleRow('Saldo Pendiente', _currencyFormat.format(saldoPendiente), color: Colors.orange),
              _buildDetalleRow('Fecha Inicio', DateFormat('dd/MM/yyyy').format(_fechaInicio)),
              if (_avalSeleccionado != null)
                _buildDetalleRow('Aval', _avalSeleccionado!['nombre'], color: Colors.blue),
              if (_notasCtrl.text.isNotEmpty)
                _buildDetalleRow('Notas', _notasCtrl.text),

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Botón migrar
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _guardando ? null : _migrarPrestamo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _guardando
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 12),
                      Text(
                        'MIGRAR PRÉSTAMO',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetalleRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonContinuar(VoidCallback onTap, {bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.1),
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Future<void> _migrarPrestamo() async {
    setState(() => _guardando = true);

    try {
      final prestamosCtrl = Provider.of<PrestamosController>(context, listen: false);

      final monto = double.parse(_montoCtrl.text);
      final interes = double.tryParse(_interesCtrl.text) ?? 0;
      final interesDiario = double.tryParse(_interesDiarioCtrl.text) ?? 0;

      // Crear préstamo con los nuevos campos de tipo
      final prestamo = PrestamoModel(
        id: '',
        clienteId: _clienteSeleccionado!['id'],
        monto: monto,
        interes: interes,
        plazoMeses: _cuotasPreview.length,
        frecuenciaPago: _frecuencia,
        fechaCreacion: _fechaInicio,
        estado: 'activo',
        tipoPrestamo: _tipoPrestamo,
        interesDiario: _tipoPrestamo == 'arquilado' ? interesDiario : 0,
        capitalAlFinal: _tipoPrestamo == 'arquilado',
      );

      final prestamoId = await prestamosCtrl.crearPrestamoConId(prestamo);

      if (prestamoId == null) throw Exception('No se pudo crear el préstamo');

      // Crear amortizaciones con cálculo preciso de capital e interés
      final montoConInteres = monto * (1 + interes / 100);
      final numCuotas = _cuotasPreview.length;
      final capitalPorCuota = monto / numCuotas;
      final interesPorCuota = (montoConInteres - monto) / numCuotas;
      
      final amortizaciones = _cuotasPreview.map((c) {
        return AmortizacionModel(
          id: '',
          prestamoId: prestamoId,
          numeroCuota: c.numero,
          fechaVencimiento: c.fechaVencimiento,
          monto: c.monto,
          capital: capitalPorCuota,
          interes: interesPorCuota,
          estado: _cuotasPagadas.contains(c.numero) ? 'pagado' : 'pendiente',
          fechaPago: _cuotasPagadas.contains(c.numero) ? c.fechaVencimiento : null,
        );
      }).toList();

      await _amortizacionesRepo.crearAmortizacionesEnLote(amortizaciones);

      // Crear aval si existe
      if (_avalSeleccionado != null) {
        await AppSupabase.client.from('avales').insert({
          'prestamo_id': prestamoId,
          'usuario_id': _avalSeleccionado!['id'],
          'nombre': _avalSeleccionado!['nombre'],
          'estado': 'activo',
        });
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('¡Préstamo migrado! ${_cuotasPagadas.length} cuotas marcadas como pagadas'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
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
}

class _CuotaPreview {
  final int numero;
  final double monto;
  final DateTime fechaVencimiento;
  final bool esCapitalFinal; // Para arquilado

  _CuotaPreview({
    required this.numero,
    required this.monto,
    required this.fechaVencimiento,
    this.esCapitalFinal = false,
  });
}

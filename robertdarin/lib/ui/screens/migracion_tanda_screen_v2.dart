// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// MIGRACIÓN DE TANDA EXISTENTE - Robert Darin Fintech V10.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Diseño elegante para importar tandas activas con:
/// - Gestión visual de participantes
/// - Drag & drop para reordenar turnos
/// - Timeline visual del progreso
/// - Selección de turnos ya pagados
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/tanda_model.dart';
import '../../data/repositories/tandas_repository.dart';
import '../../modules/clientes/controllers/usuarios_controller.dart';
import '../../core/supabase_client.dart';

class MigracionTandaScreenV2 extends StatefulWidget {
  const MigracionTandaScreenV2({super.key});

  @override
  State<MigracionTandaScreenV2> createState() => _MigracionTandaScreenV2State();
}

class _MigracionTandaScreenV2State extends State<MigracionTandaScreenV2>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TandasRepository _tandasRepo = TandasRepository();
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Controllers
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _notasCtrl = TextEditingController();

  // Estado
  String _frecuencia = 'Semanal';
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 60));
  int _turnoActual = 1;
  bool _guardando = false;
  int _pasoActual = 0;

  // Participantes
  List<_Participante> _participantes = [];

  // Animaciones
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Montos rápidos
  final List<double> _montosRapidos = [500, 1000, 1500, 2000, 3000, 5000];

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
  }

  @override
  void dispose() {
    _animController.dispose();
    _nombreCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        children: [
          // Fondo con gradiente púrpura
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
                    Colors.purple.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
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
                  'Migrar Tanda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getTitulosPaso()[_pasoActual],
                  style: TextStyle(
                    color: Colors.purple.shade300,
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
                colors: [Colors.purple.shade600, Colors.deepPurple.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  List<String> _getTitulosPaso() => [
    'Información básica',
    'Agregar participantes',
    'Orden de turnos',
    'Confirmar migración',
  ];

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _pasoActual;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive
                    ? LinearGradient(
                        colors: [Colors.purple.shade400, Colors.deepPurple.shade600],
                      )
                    : null,
                color: isActive ? null : Colors.white.withOpacity(0.1),
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
        return _buildPaso1InfoBasica();
      case 1:
        return _buildPaso2Participantes();
      case 2:
        return _buildPaso3OrdenTurnos();
      case 3:
        return _buildPaso4Confirmacion();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 1: INFORMACIÓN BÁSICA
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso1InfoBasica() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Nombre de la tanda
              _buildSeccionTitulo('Nombre de la Tanda', Icons.label),
              const SizedBox(height: 12),
              _buildNombreInput(),

              const SizedBox(height: 24),

              // Monto por participante
              _buildSeccionTitulo('Aportación por Persona', Icons.attach_money),
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

              // Frecuencia
              _buildSeccionTitulo('Frecuencia de Pago', Icons.repeat),
              const SizedBox(height: 12),
              _buildFrecuenciaSelector(),

              const SizedBox(height: 24),

              // Fecha de inicio
              _buildSeccionTitulo('Fecha de Inicio', Icons.event),
              const SizedBox(height: 12),
              _buildFechaSelector(),

              const SizedBox(height: 24),

              // Turno actual
              _buildSeccionTitulo('Turno Actual', Icons.flag),
              const SizedBox(height: 12),
              _buildTurnoActualSelector(),

              const SizedBox(height: 100),
            ],
          ),
        ),

        _buildBotonContinuar(
          () {
            if (_formKey.currentState!.validate() && 
                _nombreCtrl.text.isNotEmpty && 
                _montoCtrl.text.isNotEmpty) {
              setState(() => _pasoActual = 1);
            }
          },
          enabled: _nombreCtrl.text.isNotEmpty && _montoCtrl.text.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
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

  Widget _buildNombreInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: _nombreCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: const InputDecoration(
          hintText: 'Ej: Tanda Familia, Tanda Trabajo...',
          hintStyle: TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
        ),
        onChanged: (_) => setState(() {}),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
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
        onChanged: (_) => setState(() {}),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildFrecuenciaSelector() {
    final frecuencias = ['Diario', 'Semanal', 'Quincenal', 'Mensual'];
    return Row(
      children: frecuencias.map((f) {
        final isSelected = _frecuencia == f;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _frecuencia = f);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [Colors.purple.shade600, Colors.deepPurple.shade700])
                    : null,
                color: isSelected ? null : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                f,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
        if (d != null) setState(() => _fechaInicio = d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.purple),
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

  Widget _buildTurnoActualSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _turnoActual > 1 
                ? () => setState(() => _turnoActual--) 
                : null,
            icon: const Icon(Icons.remove_circle, size: 32),
            color: Colors.purple,
            disabledColor: Colors.white24,
          ),
          const SizedBox(width: 24),
          Column(
            children: [
              Text(
                'Turno',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              Text(
                '$_turnoActual',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () => setState(() => _turnoActual++),
            icon: const Icon(Icons.add_circle, size: 32),
            color: Colors.purple,
          ),
        ],
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
                    ? LinearGradient(colors: [Colors.purple.shade600, Colors.deepPurple.shade700])
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

  // ═══════════════════════════════════════════════════════════════════════════════
  // PASO 2: AGREGAR PARTICIPANTES
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso2Participantes() {
    final usuariosCtrl = Provider.of<UsuariosController>(context);

    return Column(
      children: [
        // Info
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selecciona ${_turnoActual > 0 ? "al menos $_turnoActual" : "los"} participantes (${_participantes.length} seleccionados)',
                  style: const TextStyle(color: Colors.purple, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Lista de usuarios
        Expanded(
          child: FutureBuilder(
            // Usar obtenerUsuariosClientes para excluir superadmin/admin
            future: usuariosCtrl.obtenerUsuariosClientes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.purple));
              }

              final usuarios = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Buscador
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar participante...',
                        hintStyle: TextStyle(color: Colors.white38),
                        icon: Icon(Icons.search, color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // Usuarios
                  ...usuarios.map((u) {
                    final isSelected = _participantes.any((p) => p.usuarioId == u.id);
                    return _buildUsuarioCard(u, isSelected);
                  }).toList(),
                ],
              );
            },
          ),
        ),

        // Preview participantes seleccionados
        if (_participantes.isNotEmpty)
          Container(
            height: 70,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _participantes.length,
              itemBuilder: (context, index) {
                final p = _participantes[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.purple.withOpacity(0.3),
                        child: Text(
                          p.nombre[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _participantes.removeWhere((x) => x.usuarioId == p.usuarioId);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        _buildBotonContinuar(
          () {
            if (_participantes.length >= 2) {
              setState(() => _pasoActual = 2);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agrega al menos 2 participantes'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          enabled: _participantes.length >= 2,
        ),
      ],
    );
  }

  Widget _buildUsuarioCard(dynamic usuario, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isSelected) {
            _participantes.removeWhere((p) => p.usuarioId == usuario.id);
          } else {
            _participantes.add(_Participante(
              usuarioId: usuario.id,
              nombre: usuario.nombreCompleto ?? usuario.email ?? 'Sin nombre',
              turno: _participantes.length + 1,
              yaCobro: false,
            ));
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.purple.withOpacity(0.2), Colors.deepPurple.withOpacity(0.1)],
                )
              : null,
          color: isSelected ? null : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isSelected ? Colors.purple : Colors.white.withOpacity(0.1),
              child: Text(
                (usuario.nombreCompleto ?? usuario.email ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                usuario.nombreCompleto ?? usuario.email ?? 'Sin nombre',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.purple,
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
  // PASO 3: ORDEN DE TURNOS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso3OrdenTurnos() {
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
            children: const [
              Icon(Icons.swap_vert, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Arrastra para reordenar. Toca las 💰 para marcar quienes ya cobraron.',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Lista reordenable
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _participantes.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _participantes.removeAt(oldIndex);
                _participantes.insert(newIndex, item);
                // Actualizar números de turno
                for (int i = 0; i < _participantes.length; i++) {
                  _participantes[i] = _participantes[i].copyWith(turno: i + 1);
                }
              });
            },
            itemBuilder: (context, index) {
              final p = _participantes[index];
              final esActual = p.turno == _turnoActual;
              final yaPaso = p.turno < _turnoActual;

              return Container(
                key: ValueKey(p.usuarioId),
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: esActual
                          ? LinearGradient(
                              colors: [Colors.purple.withOpacity(0.3), Colors.deepPurple.withOpacity(0.2)],
                            )
                          : null,
                      color: esActual ? null : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: esActual
                          ? Border.all(color: Colors.purple, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Número de turno
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: yaPaso || p.yaCobro
                                ? LinearGradient(colors: [Colors.green.shade600, Colors.green.shade800])
                                : esActual
                                    ? LinearGradient(colors: [Colors.purple.shade600, Colors.purple.shade800])
                                    : null,
                            color: !yaPaso && !p.yaCobro && !esActual 
                                ? Colors.white.withOpacity(0.1) 
                                : null,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: yaPaso || p.yaCobro
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : Text(
                                    '${p.turno}',
                                    style: TextStyle(
                                      color: esActual ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Nombre
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                esActual 
                                    ? '⭐ Turno actual' 
                                    : yaPaso || p.yaCobro
                                        ? '✓ Ya cobró'
                                        : 'Pendiente',
                                style: TextStyle(
                                  color: esActual
                                      ? Colors.purple.shade300
                                      : yaPaso || p.yaCobro
                                          ? Colors.green.shade300
                                          : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botón marcar como cobrado
                        if (!yaPaso)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _participantes[index] = p.copyWith(yaCobro: !p.yaCobro);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: p.yaCobro 
                                    ? Colors.green.withOpacity(0.2) 
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: p.yaCobro ? Colors.green : Colors.white24,
                                ),
                              ),
                              child: Text(
                                p.yaCobro ? '💰 Cobrado' : '💰',
                                style: TextStyle(
                                  color: p.yaCobro ? Colors.green : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                        // Handle para drag
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle, color: Colors.white24),
                      ],
                    ),
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
              _buildResumenItem(
                'Ya Cobraron', 
                '${_participantes.where((p) => p.yaCobro || p.turno < _turnoActual).length}', 
                Colors.green,
              ),
              _buildResumenItem(
                'Pendientes', 
                '${_participantes.where((p) => !p.yaCobro && p.turno >= _turnoActual).length}', 
                Colors.purple,
              ),
              _buildResumenItem(
                'Total Tanda', 
                _currencyFormat.format((double.tryParse(_montoCtrl.text) ?? 0) * _participantes.length), 
                Colors.white,
              ),
            ],
          ),
        ),

        _buildBotonContinuar(() => setState(() => _pasoActual = 3)),
      ],
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
  // PASO 4: CONFIRMACIÓN
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPaso4Confirmacion() {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    final montoTotal = monto * _participantes.length;
    final yaCobraron = _participantes.where((p) => p.yaCobro || p.turno < _turnoActual).length;

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
                    colors: [Colors.purple.shade700, Colors.deepPurple.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
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
                          'TANDA A MIGRAR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const Icon(Icons.groups, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nombreCtrl.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_participantes.length} participantes • ${_currencyFormat.format(monto)}/persona',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TURNO $_turnoActual DE ${_participantes.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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

              // Timeline de participantes
              const Text(
                'Orden de Turnos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              ...List.generate(_participantes.length, (index) {
                final p = _participantes[index];
                final esActual = p.turno == _turnoActual;
                final yaPaso = p.yaCobro || p.turno < _turnoActual;

                return Row(
                  children: [
                    // Línea del timeline
                    Column(
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          color: index == 0 ? Colors.transparent : Colors.white24,
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: yaPaso 
                                ? Colors.green 
                                : esActual 
                                    ? Colors.purple 
                                    : Colors.white24,
                          ),
                          child: yaPaso
                              ? const Icon(Icons.check, color: Colors.white, size: 12)
                              : Center(
                                  child: Text(
                                    '${p.turno}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          color: index == _participantes.length - 1 ? Colors.transparent : Colors.white24,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: esActual 
                              ? Colors.purple.withOpacity(0.15) 
                              : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: esActual 
                              ? Border.all(color: Colors.purple.withOpacity(0.5)) 
                              : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              p.nombre,
                              style: TextStyle(
                                color: yaPaso ? Colors.green : Colors.white,
                                fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (esActual) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ACTUAL',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            if (yaPaso) ...[
                              const Spacer(),
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 24),

              // Detalles
              _buildDetalleRow('Nombre', _nombreCtrl.text),
              _buildDetalleRow('Aportación', _currencyFormat.format(monto)),
              _buildDetalleRow('Monto Total Tanda', _currencyFormat.format(montoTotal)),
              _buildDetalleRow('Participantes', '${_participantes.length}'),
              _buildDetalleRow('Frecuencia', _frecuencia),
              _buildDetalleRow('Turno Actual', '$_turnoActual de ${_participantes.length}'),
              _buildDetalleRow('Ya Cobraron', '$yaCobraron', color: Colors.green),
              _buildDetalleRow('Fecha Inicio', DateFormat('dd/MM/yyyy').format(_fechaInicio)),

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Botón migrar
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _guardando ? null : _migrarTanda,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
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
                        'MIGRAR TANDA',
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
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.w600,
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
          backgroundColor: Colors.purple,
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

  Future<void> _migrarTanda() async {
    setState(() => _guardando = true);

    try {
      final monto = double.parse(_montoCtrl.text);

      // Crear tanda
      final tanda = TandaModel(
        id: '',
        nombre: _nombreCtrl.text,
        montoPorPersona: monto,
        numeroParticipantes: _participantes.length,
        frecuencia: _frecuencia.toLowerCase(),
        fechaInicio: _fechaInicio,
        turnoActual: _turnoActual,
        estado: 'activa',
      );

      final tandaId = await _tandasRepo.crearTandaConId(tanda);

      if (tandaId == null) throw Exception('No se pudo crear la tanda');

      // Crear participantes
      for (var p in _participantes) {
        await AppSupabase.client.from('tanda_participantes').insert({
          'tanda_id': tandaId,
          'cliente_id': p.usuarioId, // Corregido: la tabla usa cliente_id
          'numero_turno': p.turno,   // Corregido: la tabla usa numero_turno
          'ha_recibido_bolsa': p.yaCobro || p.turno < _turnoActual,
          'ha_pagado_cuota_actual': false,
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
                Text('¡Tanda "${_nombreCtrl.text}" migrada con ${_participantes.length} participantes!'),
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

class _Participante {
  final String usuarioId;
  final String nombre;
  final int turno;
  final bool yaCobro;

  _Participante({
    required this.usuarioId,
    required this.nombre,
    required this.turno,
    required this.yaCobro,
  });

  _Participante copyWith({
    String? usuarioId,
    String? nombre,
    int? turno,
    bool? yaCobro,
  }) {
    return _Participante(
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      turno: turno ?? this.turno,
      yaCobro: yaCobro ?? this.yaCobro,
    );
  }
}

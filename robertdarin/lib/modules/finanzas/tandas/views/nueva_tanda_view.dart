// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/tanda_model.dart';
import '../../../../core/supabase_client.dart';
import '../controllers/tandas_controller.dart';
import '../../../../ui/viewmodels/negocio_activo_provider.dart';
import 'package:intl/intl.dart';

class NuevaTandaView extends StatefulWidget {
  final TandasController controller;

  const NuevaTandaView({super.key, required this.controller});

  @override
  State<NuevaTandaView> createState() => _NuevaTandaViewState();
}

class _NuevaTandaViewState extends State<NuevaTandaView>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController montoCtrl = TextEditingController();
  final TextEditingController participantesCtrl = TextEditingController();
  final TextEditingController comisionCtrl = TextEditingController(text: '5');

  late Future<List<Map<String, dynamic>>> _clientesFuture;
  final List<Map<String, dynamic>> _participantesSeleccionados = [];
  String _busquedaParticipantes = '';

  DateTime _fechaSeleccionada = DateTime.now();
  String _frecuencia = 'semanal';
  bool _guardando = false;
  bool _mostrarPreview = true;

  late AnimationController _cardController;
  late Animation<double> _cardAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Montos y participantes sugeridos
  final List<double> _montosSugeridos = [100, 200, 500, 1000, 2000, 5000];
  final List<int> _participantesSugeridos = [5, 10, 12, 15, 20, 25];

  // Calculos en tiempo real
  int get _participantes => int.tryParse(participantesCtrl.text) ?? 0;
  double get _montoPorPersona => double.tryParse(montoCtrl.text) ?? 0;
  double get _comisionPct => double.tryParse(comisionCtrl.text) ?? 5;
  double get _potTotal => _montoPorPersona * _participantes;
  double get _comisionMonto => _potTotal * (_comisionPct / 100);
  double get _entregaNeta => _potTotal - _comisionMonto;
  int get _duracionSemanas {
    switch (_frecuencia) {
      case 'semanal':
        return _participantes;
      case 'quincenal':
        return _participantes * 2;
      case 'mensual':
        return _participantes * 4;
      default:
        return _participantes;
    }
  }

  double get _progreso {
    double p = 0;
    if (nombreCtrl.text.isNotEmpty) p += 0.25;
    if (_participantes >= 2) p += 0.25;
    if (_montoPorPersona > 0) p += 0.25;
    if (_fechaSeleccionada
        .isAfter(DateTime.now().subtract(const Duration(days: 1)))) p += 0.25;
    return p;
  }

  @override
  void initState() {
    super.initState();

    _clientesFuture = _cargarClientes();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );
    _cardController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    nombreCtrl.addListener(() => setState(() {}));
    montoCtrl.addListener(() => setState(() {}));
    participantesCtrl.addListener(_onParticipantesChanged);
    comisionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cardController.dispose();
    _pulseController.dispose();
    nombreCtrl.dispose();
    montoCtrl.dispose();
    participantesCtrl.dispose();
    comisionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

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
        title: const Text('Nueva Tanda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline,
                  size: 18, color: Colors.orangeAccent),
            ),
            onPressed: _mostrarAyuda,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Fondo con gradiente
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Colors.orangeAccent.withOpacity(0.08),
                    Colors.transparent,
                    Colors.amber.withOpacity(0.05),
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
                  // PREVIEW CARD DESLIZABLE
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      );
                    },
                    child: _mostrarPreview
                        ? GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity != null &&
                                  details.primaryVelocity! > 200) {
                                setState(() => _mostrarPreview = false);
                                HapticFeedback.lightImpact();
                              }
                            },
                            child: ScaleTransition(
                                scale: _cardAnimation,
                                child: _buildPreviewCard(nf)),
                          )
                        : _buildMiniPreviewBar(nf),
                  ),

                  const SizedBox(height: 20),
                  _buildProgressBar(),
                  const SizedBox(height: 25),

                  // NOMBRE
                  _buildSectionHeader(
                      '🎯', 'Nombre de la Tanda', Colors.orangeAccent),
                  const SizedBox(height: 12),
                  _buildNombreField(),

                  const SizedBox(height: 25),

                  // PARTICIPANTES
                  _buildSectionHeader('👥', 'Participantes', Colors.blueAccent),
                  const SizedBox(height: 12),
                  _buildParticipantesField(),
                  const SizedBox(height: 12),
                  _buildParticipantesRapidos(),
                  const SizedBox(height: 12),
                  _buildParticipantesSelector(),

                  const SizedBox(height: 25),

                  // APORTACIÓN
                  _buildSectionHeader(
                      '💰', 'Aportación por Ronda', Colors.greenAccent),
                  const SizedBox(height: 12),
                  _buildMontoField(),
                  const SizedBox(height: 12),
                  _buildMontosRapidos(),

                  const SizedBox(height: 25),

                  // CONFIGURACIÓN
                  _buildSectionHeader(
                      '⚙️', 'Configuración', Colors.purpleAccent),
                  const SizedBox(height: 12),
                  _buildConfiguracionRow(),

                  const SizedBox(height: 25),

                  // RESUMEN
                  if (_participantes >= 2 && _montoPorPersona > 0)
                    _buildResumenDetallado(nf),

                  const SizedBox(height: 25),
                  _buildBotonCrear(),

                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.white.withOpacity(0.4), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Puedes seleccionar participantes aqui o agregarlos despues',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(NumberFormat nf) {
    final bool tieneData = _participantes >= 2 && _montoPorPersona > 0;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: tieneData ? _pulseAnimation.value : 1.0,
          child: Container(
            key: const ValueKey('preview_full'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tieneData
                    ? [const Color(0xFFFF8C00), const Color(0xFFFF6B35)]
                    : [Colors.grey.shade800, Colors.grey.shade700],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (tieneData ? Colors.orangeAccent : Colors.grey)
                      .withOpacity(0.3),
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.group_work,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreCtrl.text.isEmpty
                                  ? 'Nueva Tanda'
                                  : nombreCtrl.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$_participantes participantes • $_frecuencia',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withOpacity(0.5), size: 24),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Text(
                        tieneData ? nf.format(_entregaNeta) : '\$0',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1),
                      ),
                      Text('Entrega neta por turno',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPreviewStat('Aportación',
                          tieneData ? nf.format(_montoPorPersona) : '-'),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildPreviewStat(
                          'Pot Total', tieneData ? nf.format(_potTotal) : '-'),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildPreviewStat('Duración',
                          tieneData ? '$_duracionSemanas sem' : '-'),
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
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
      ],
    );
  }

  Widget _buildMiniPreviewBar(NumberFormat nf) {
    final tieneData = _participantes >= 2 && _montoPorPersona > 0;
    return GestureDetector(
      onTap: () {
        setState(() => _mostrarPreview = true);
        HapticFeedback.lightImpact();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -200) {
          setState(() => _mostrarPreview = true);
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        key: const ValueKey('mini_preview'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: tieneData
                ? [
                    const Color(0xFFFF8C00).withOpacity(0.8),
                    const Color(0xFFFF6B35).withOpacity(0.8)
                  ]
                : [Colors.grey.shade800, Colors.grey.shade700],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.group_work, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(nombreCtrl.text.isEmpty ? 'Nueva Tanda' : nombreCtrl.text,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              children: [
                if (tieneData)
                  Text('Entrega: ${nf.format(_entregaNeta)}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left,
                    color: Colors.white.withOpacity(0.6), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progreso del formulario',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 12)),
            Text('${(_progreso * 100).toInt()}%',
                style: TextStyle(
                    color: _progreso >= 1
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progreso,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(
                _progreso >= 1 ? Colors.greenAccent : Colors.orangeAccent),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String emoji, String title, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildNombreField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: nombreCtrl.text.isNotEmpty
                ? Colors.orangeAccent.withOpacity(0.5)
                : Colors.white12),
      ),
      child: TextFormField(
        controller: nombreCtrl,
        textCapitalization: TextCapitalization.words,
        validator: (v) => v!.isEmpty ? 'Nombre requerido' : null,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Ej: Tanda Navideña 2026',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(Icons.edit_note,
              color: nombreCtrl.text.isNotEmpty
                  ? Colors.orangeAccent
                  : Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
          suffixIcon: nombreCtrl.text.isNotEmpty
              ? Icon(Icons.check_circle,
                  color: Colors.greenAccent.withOpacity(0.8), size: 20)
              : null,
        ),
      ),
    );
  }

  Widget _buildParticipantesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _participantes >= 2
                ? Colors.blueAccent.withOpacity(0.5)
                : Colors.white12),
      ),
      child: TextFormField(
        controller: participantesCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) => (int.tryParse(v ?? '') ?? 0) < 2 ? 'Mínimo 2' : null,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          prefixIcon: Icon(Icons.people,
              color: _participantes >= 2 ? Colors.blueAccent : Colors.white38),
          suffixText: 'personas',
          suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildParticipantesRapidos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _participantesSugeridos.map((num) {
          final sel = _participantes == num;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _limpiarSeleccionParticipantes();
                  participantesCtrl.text = num.toString();
                },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      sel ? Colors.blueAccent : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.blueAccent : Colors.white12),
                ),
                child: Text('$num',
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParticipantesSelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _clientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildClientesBox(
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Cargando clientes...',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildClientesBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error al cargar clientes',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _recargarClientes,
                  icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                  label: const Text('Reintentar',
                      style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
          );
        }

        final clientes = snapshot.data ?? [];
        if (clientes.isEmpty) {
          return _buildClientesBox(
            child: const Text('No hay clientes registrados',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          );
        }

        final filtrados = _filtrarClientes(clientes);

        return _buildClientesBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_search,
                      color: Colors.blueAccent.withOpacity(0.8), size: 16),
                  const SizedBox(width: 8),
                  const Text('Clientes registrados (opcional)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    '${_participantesSeleccionados.length}/${clientes.length}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                onChanged: (v) {
                  setState(() => _busquedaParticipantes = v);
                },
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, telefono o email',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_participantesSeleccionados.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Seleccionados',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11)),
                    const Spacer(),
                    TextButton(
                      onPressed: _limpiarSeleccionParticipantes,
                      child: const Text('Limpiar seleccion',
                          style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _participantesSeleccionados.map((c) {
                    final nombre = (c['nombre'] ?? 'Sin nombre').toString();
                    return Chip(
                      label: Text(nombre,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      backgroundColor: Colors.blueAccent.withOpacity(0.25),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _toggleParticipante(c),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Si eliges clientes aqui, el numero de participantes se ajusta automaticamente.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: filtrados.isEmpty
                    ? const Center(
                        child: Text('Sin resultados',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.white.withOpacity(0.08)),
                        itemBuilder: (context, index) {
                          final c = filtrados[index];
                          final id = c['id'];
                          final nombre = (c['nombre'] ?? 'Sin nombre').toString();
                          final telefono = (c['telefono'] ?? '').toString();
                          final email = (c['email'] ?? '').toString();
                          final detalles = [
                            if (telefono.trim().isNotEmpty) telefono.trim(),
                            if (email.trim().isNotEmpty) email.trim(),
                          ].join(' | ');
                          final seleccionado = _participantesSeleccionados
                              .any((p) => p['id'] == id);
                          final inicial = nombre.trim().isNotEmpty
                              ? nombre.trim()[0].toUpperCase()
                              : '?';
                          return InkWell(
                            onTap: () => _toggleParticipante(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 6),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: seleccionado
                                        ? Colors.blueAccent
                                        : Colors.white.withOpacity(0.12),
                                    child: Text(inicial,
                                        style: TextStyle(
                                            color: seleccionado
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        if (detalles.isNotEmpty)
                                          Text(detalles,
                                              style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                  fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    seleccionado
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: seleccionado
                                        ? Colors.blueAccent
                                        : Colors.white24,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientesBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _buildMontoField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _montoPorPersona > 0
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.white12),
      ),
      child: TextFormField(
        controller: montoCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final monto = double.tryParse(v ?? '') ?? 0;
          if (monto <= 0) return 'Ingresa el monto';
          if (monto < 50) return 'Monto mínimo: \$50';
          if (monto > 100000) return 'Monto máximo: \$100,000';
          return null;
        },
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Text('\$',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent))),
          prefixIconConstraints: const BoxConstraints(minWidth: 50),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildMontosRapidos() {
    final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _montosSugeridos.map((monto) {
          final sel = _montoPorPersona == monto;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                montoCtrl.text = monto.toStringAsFixed(0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      sel ? Colors.greenAccent : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.greenAccent : Colors.white12),
                ),
                child: Text(nf.format(monto),
                    style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfiguracionRow() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Frecuencia de pago',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ),
              Row(children: [
                _buildFrecuenciaChip('semanal', '📅 Semanal'),
                _buildFrecuenciaChip('quincenal', '📆 Quincenal'),
                _buildFrecuenciaChip('mensual', '🗓️ Mensual'),
              ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _seleccionarFecha,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.calendar_today,
                            color: Colors.orangeAccent.withOpacity(0.8),
                            size: 16),
                        const SizedBox(width: 8),
                        Text('Fecha inicio',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          DateFormat('dd MMM yyyy', 'es')
                              .format(_fechaSeleccionada),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.percent,
                          color: Colors.redAccent.withOpacity(0.8), size: 16),
                      const SizedBox(width: 8),
                      Text('Comisión',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11)),
                    ]),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: comisionCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixText: '%',
                        suffixStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrecuenciaChip(String value, String label) {
    final sel = _frecuencia == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _frecuencia = value);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                sel ? Colors.purpleAccent.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: sel ? Colors.white : Colors.white54,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildResumenDetallado(NumberFormat nf) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orangeAccent.withOpacity(0.15),
            Colors.amber.withOpacity(0.08)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.calculate,
                  color: Colors.orangeAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Resumen de la Tanda',
                style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _buildResumenItem('Participantes', '$_participantes',
                    Icons.people, Colors.blueAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildResumenItem(
                    'Aportación',
                    nf.format(_montoPorPersona),
                    Icons.payment,
                    Colors.greenAccent)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _buildResumenItem('Pot Total', nf.format(_potTotal),
                    Icons.account_balance_wallet, Colors.amber)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildResumenItem('Comisión', nf.format(_comisionMonto),
                    Icons.remove_circle_outline, Colors.redAccent)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _buildResumenItem('Entrega Neta',
                    nf.format(_entregaNeta), Icons.stars, Colors.greenAccent,
                    destacado: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildResumenItem('Duración', '$_duracionSemanas sem',
                    Icons.timelapse, Colors.purpleAccent)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                'Cada participante aporta ${nf.format(_montoPorPersona)} por ronda y recibe ${nf.format(_entregaNeta)} cuando le toque.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(
      String label, String value, IconData icon, Color color,
      {bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: destacado
            ? color.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: destacado ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: destacado ? color : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: destacado ? 16 : 14)),
      ]),
    );
  }

  Widget _buildBotonCrear() {
    final puedeCrear = _progreso >= 1.0;
    return GestureDetector(
      onTap: puedeCrear && !_guardando ? _guardarTanda : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: puedeCrear
              ? const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF6B35)])
              : LinearGradient(
                  colors: [Colors.grey.shade700, Colors.grey.shade600]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: puedeCrear
              ? [
                  BoxShadow(
                      color: Colors.orangeAccent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]
              : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_guardando)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
          else
            Icon(puedeCrear ? Icons.rocket_launch : Icons.lock_outline,
                color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Text(
            _guardando
                ? 'Creando tanda...'
                : puedeCrear
                    ? '¡CREAR TANDA!'
                    : 'Completa el formulario',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5),
          ),
        ]),
      ),
    );
  }

  void _mostrarAyuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A25),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.help_outline, color: Colors.orangeAccent),
                SizedBox(width: 12),
                Text('¿Cómo funcionan las tandas?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              _buildAyudaItem('1',
                  'Cada participante aporta una cantidad fija cada periodo'),
              _buildAyudaItem(
                  '2', 'El pot total se entrega a un participante por turno'),
              _buildAyudaItem(
                  '3', 'Todos reciben el pot una vez durante la duración'),
              _buildAyudaItem(
                  '4', 'La comisión se descuenta del pot antes de entregar'),
              const SizedBox(height: 20),
            ]),
      ),
    );
  }

  Widget _buildAyudaItem(String num, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(texto,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 14))),
      ]),
    );
  }

  void _onParticipantesChanged() {
    final actual = int.tryParse(participantesCtrl.text) ?? 0;
    if (_participantesSeleccionados.isNotEmpty &&
        actual != _participantesSeleccionados.length) {
      _participantesSeleccionados.clear();
    }
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _cargarClientes() async {
    try {
      final response = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, telefono, email')
          .order('nombre');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  void _recargarClientes() {
    setState(() {
      _clientesFuture = _cargarClientes();
    });
  }

  List<Map<String, dynamic>> _filtrarClientes(
      List<Map<String, dynamic>> clientes) {
    final query = _busquedaParticipantes.trim().toLowerCase();
    if (query.isEmpty) return clientes;
    return clientes.where((c) {
      final nombre = (c['nombre'] ?? '').toString().toLowerCase();
      final telefono = (c['telefono'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      return nombre.contains(query) ||
          telefono.contains(query) ||
          email.contains(query);
    }).toList();
  }

  void _toggleParticipante(Map<String, dynamic> cliente) {
    final id = cliente['id'];
    final index = _participantesSeleccionados
        .indexWhere((element) => element['id'] == id);
    setState(() {
      if (index >= 0) {
        _participantesSeleccionados.removeAt(index);
      } else {
        _participantesSeleccionados.add(cliente);
      }
      participantesCtrl.text = _participantesSeleccionados.length.toString();
    });
    HapticFeedback.lightImpact();
  }

  void _limpiarSeleccionParticipantes() {
    if (_participantesSeleccionados.isEmpty) return;
    setState(() {
      _participantesSeleccionados.clear();
    });
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: Colors.orangeAccent, surface: Color(0xFF1A1A25))),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _fechaSeleccionada)
      setState(() => _fechaSeleccionada = picked);
  }

  Future<void> _guardarTanda() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    HapticFeedback.mediumImpact();

    try {
      final totalParticipantes = _participantesSeleccionados.isNotEmpty
          ? _participantesSeleccionados.length
          : _participantes;
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      final tanda = TandaModel(
        id: '',
        nombre: nombreCtrl.text.trim(),
        montoPorPersona: _montoPorPersona,
        numeroParticipantes: totalParticipantes,
        turnoActual: 1,
        frecuencia: _frecuencia,
        fechaInicio: _fechaSeleccionada,
        estado: 'activa',
        negocioId: negocioId,
      );

      final tandaId = await widget.controller.crearTandaConId(tanda);
      final exito = tandaId != null;

      if (exito && _participantesSeleccionados.isNotEmpty) {
        try {
          final data = <Map<String, dynamic>>[];
          for (var i = 0; i < _participantesSeleccionados.length; i++) {
            final c = _participantesSeleccionados[i];
            data.add({
              'tanda_id': tandaId,
              'cliente_id': c['id'],
              'numero_turno': i + 1,
              'ha_recibido_bolsa': false,
              'ha_pagado_cuota_actual': false,
            });
          }
          await AppSupabase.client.from('tanda_participantes').insert(data);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Tanda creada, pero no se pudieron agregar participantes'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (mounted) {
        if (exito) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('¡Tanda "${nombreCtrl.text}" creada!'),
              ]),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

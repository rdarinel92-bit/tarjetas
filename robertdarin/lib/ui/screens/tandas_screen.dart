// ignore_for_file: dangling_library_doc_comments
/// ═══════════════════════════════════════════════════════════════════════════════
/// GESTIÓN DE TANDAS PROFESIONAL - Robert Darin Fintech V10.5
/// ═══════════════════════════════════════════════════════════════════════════════
/// - KPIs: Tandas activas, completadas, dinero circulando
/// - Indicador de próximo turno
/// - Alertas de morosos (quién no ha pagado cuota)
/// - Soporte para nuevas tandas y migración de existentes
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../viewmodels/negocio_activo_provider.dart';

class TandasScreen extends StatefulWidget {
  const TandasScreen({super.key});

  @override
  State<TandasScreen> createState() => _TandasScreenState();
}

class _TandasScreenState extends State<TandasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tandas = [];
  List<Map<String, dynamic>> _tandasFiltradas = [];
  
  // Filtros
  String _filtroEstado = 'todos';
  
  // KPIs
  int _tandasActivas = 0;
  int _tandasCompletadas = 0;
  double _dineroCirculando = 0;
  int _participantesTotales = 0;

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // V10.55: Obtener negocio activo para filtrar
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      // Cargar tandas con participantes
      var query = AppSupabase.client
          .from('tandas')
          .select('''
            *,
            tanda_participantes(id, numero_turno, ha_pagado_cuota_actual, ha_recibido_bolsa, cliente:clientes(nombre))
          ''');
      
      // Filtrar por negocio si hay uno activo
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      
      final tandasRes = await query.order('created_at', ascending: false);

      final tandas = List<Map<String, dynamic>>.from(tandasRes);

      // Calcular KPIs
      int activas = 0;
      int completadas = 0;
      double dineroCirculando = 0;
      int participantes = 0;

      for (var t in tandas) {
        final estado = t['estado'] ?? 'activa';
        final monto = (t['monto_por_persona'] as num?)?.toDouble() ?? 0;
        final numParticipantes = t['numero_participantes'] ?? 0;
        final participantesList = t['tanda_participantes'] as List? ?? [];
        
        if (estado == 'activa') {
          activas++;
          dineroCirculando += monto * numParticipantes;
        } else if (estado == 'completada') {
          completadas++;
        }
        
        participantes += participantesList.length;
      }

      if (mounted) {
        setState(() {
          _tandas = tandas;
          _tandasActivas = activas;
          _tandasCompletadas = completadas;
          _dineroCirculando = dineroCirculando;
          _participantesTotales = participantes;
          _isLoading = false;
        });
        _aplicarFiltros();
      }
    } catch (e) {
      debugPrint('Error cargando tandas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_tandas);

    if (_filtroEstado != 'todos') {
      resultado = resultado.where((t) => t['estado'] == _filtroEstado).toList();
    }

    setState(() => _tandasFiltradas = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Gestión de Tandas",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: Colors.orangeAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPIs
                    _buildKPIsSection(),
                    const SizedBox(height: 20),

                    // BOTONES DE ACCION
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: PremiumButton(
                                text: "Nueva Tanda",
                                icon: Icons.add,
                                onPressed: () async {
                                  await Navigator.pushNamed(context, AppRoutes.formularioTanda);
                                  _cargarDatos();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PremiumButton(
                                text: "Migrar Existente",
                                icon: Icons.history,
                                color: Colors.orangeAccent,
                                onPressed: () async {
                                  await Navigator.pushNamed(context, AppRoutes.formularioTandaExistente);
                                  _cargarDatos();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        PremiumButton(
                          text: "Agregar Participante",
                          icon: Icons.person_add,
                          color: Colors.blueAccent,
                          onPressed: _mostrarSelectorAgregarParticipante,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),


                    // FILTROS
                    _buildFiltros(),
                    const SizedBox(height: 20),

                    // TÍTULO + CONTADOR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Lista de Tandas", 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("${_tandasFiltradas.length} tandas",
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LISTA DE TANDAS
                    if (_tandasFiltradas.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tandasFiltradas.length,
                        itemBuilder: (context, index) => _buildTandaCard(_tandasFiltradas[index]),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKPIsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), Colors.orangeAccent.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("DINERO CIRCULANDO", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(_currencyFormat.format(_dineroCirculando),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("$_participantesTotales participantes en total",
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white24),
              Expanded(
                child: Column(
                  children: [
                    Text(_tandasActivas.toString(),
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                    const Text("Activas", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildKPIChip("✅ Completadas", _tandasCompletadas.toString(), const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildKPIChip("📊 Total", _tandas.length.toString(), Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFiltroChip("Todas", _filtroEstado == 'todos', () {
            setState(() => _filtroEstado = 'todos');
            _aplicarFiltros();
          }),
          _buildFiltroChip("Activas", _filtroEstado == 'activa', () {
            setState(() => _filtroEstado = 'activa');
            _aplicarFiltros();
          }, color: Colors.orangeAccent, icon: Icons.loop),
          _buildFiltroChip("Completadas", _filtroEstado == 'completada', () {
            setState(() => _filtroEstado = 'completada');
            _aplicarFiltros();
          }, color: const Color(0xFF10B981), icon: Icons.check_circle),
          _buildFiltroChip("Canceladas", _filtroEstado == 'cancelada', () {
            setState(() => _filtroEstado = 'cancelada');
            _aplicarFiltros();
          }, color: Colors.grey, icon: Icons.cancel),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, bool activo, VoidCallback onTap, {Color? color, IconData? icon}) {
    final chipColor = color ?? Colors.orangeAccent;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: activo ? chipColor : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: activo ? chipColor : Colors.white54),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(
                color: activo ? chipColor : Colors.white54,
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTandaCard(Map<String, dynamic> tanda) {
    final nombre = tanda['nombre'] ?? 'Sin nombre';
    final monto = (tanda['monto_por_persona'] as num?)?.toDouble() ?? 0;
    final numParticipantes = tanda['numero_participantes'] ?? 0;
    final turnoActual = tanda['turno'] ?? 1; // V10.55: Corregido de turno_actual a turno
    final estado = tanda['estado'] ?? 'activa';
    final frecuencia = tanda['frecuencia'] ?? 'semanal';
    final participantes = tanda['tanda_participantes'] as List? ?? [];
    
    // Calcular morosos (no han pagado cuota actual)
    int morosos = 0;
    String? proximoTurno;
    
    for (var p in participantes) {
      if (p['ha_pagado_cuota_actual'] == false) {
        morosos++;
      }
      // Encontrar quién tiene el próximo turno
      if (p['numero_turno'] == turnoActual && p['ha_recibido_bolsa'] == false) {
        final cliente = p['cliente'] as Map<String, dynamic>?;
        proximoTurno = cliente?['nombre'] ?? 'Turno $turnoActual';
      }
    }

    // Colores según estado
    Color estadoColor;
    IconData estadoIcon;
    
    switch (estado) {
      case 'completada':
        estadoColor = const Color(0xFF10B981);
        estadoIcon = Icons.check_circle;
        break;
      case 'cancelada':
        estadoColor = Colors.grey;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = Colors.orangeAccent;
        estadoIcon = Icons.loop;
    }

    // Progreso
    final progreso = numParticipantes > 0 ? (turnoActual - 1) / numParticipantes : 0.0;

    return PremiumCard(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.detalleTanda, arguments: tanda['id']),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: estadoColor.withValues(alpha: 0.2),
                        radius: 24,
                        child: Icon(Icons.loop, color: estadoColor, size: 24),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: estadoColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0D0D14), width: 2),
                          ),
                          child: Icon(estadoIcon, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nombre,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: estadoColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(estado.toUpperCase(),
                                style: TextStyle(color: estadoColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(_currencyFormat.format(monto),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            Text("x$numParticipantes",
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(frecuencia.toUpperCase(),
                                style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text("Turno $turnoActual/$numParticipantes",
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            if (proximoTurno != null && estado == 'activa') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text("🎯 Toca: $proximoTurno",
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
              
              // Progress bar y alertas
              if (estado == 'activa') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progreso,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("${((progreso) * 100).toInt()}%",
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (morosos > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 14),
                        const SizedBox(width: 4),
                        Text("$morosos sin pagar cuota",
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarSelectorAgregarParticipante() async {
    final tandasActivas = _tandas.where((t) => (t['estado'] ?? 'activa') == 'activa').toList();
    if (tandasActivas.isEmpty) {
      _mostrarSnack("No hay tandas activas");
      return;
    }

    final disponibles = tandasActivas.where((t) {
      final total = (t['numero_participantes'] as num?)?.toInt() ?? 0;
      final participantes = (t['tanda_participantes'] as List? ?? []).length;
      return participantes < total;
    }).toList();

    if (disponibles.isEmpty) {
      _mostrarSnack("Todas las tandas activas estan completas");
      return;
    }

    if (disponibles.length == 1) {
      await _abrirAgregarParticipante(disponibles.first);
      return;
    }

    String? selectedTandaId;
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text("Agregar Participante", style: TextStyle(color: Colors.white)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Form(
                key: formKey,
                child: DropdownButtonFormField<String>(
                  value: selectedTandaId,
                  decoration: const InputDecoration(
                    labelText: 'Selecciona la tanda',
                    border: OutlineInputBorder(),
                  ),
                  items: disponibles.map((t) {
                    final nombre = t['nombre'] ?? 'Tanda';
                    final total = (t['numero_participantes'] as num?)?.toInt() ?? 0;
                    final participantes = (t['tanda_participantes'] as List? ?? []).length;
                    return DropdownMenuItem(
                      value: t['id'] as String?,
                      child: Text("$nombre ($participantes/$total)"),
                    );
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedTandaId = value),
                  validator: (value) => value == null ? 'Selecciona una tanda' : null,
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
              child: const Text("Continuar"),
            ),
          ],
        );
      },
    );

    if (confirmado == true && selectedTandaId != null) {
      final tanda = disponibles.firstWhere(
        (t) => t['id'] == selectedTandaId,
        orElse: () => {},
      );
      if (tanda.isNotEmpty) {
        await _abrirAgregarParticipante(tanda);
      }
    }
  }

  Future<void> _abrirAgregarParticipante(Map<String, dynamic> tanda) async {
    final tandaId = tanda['id']?.toString();
    if (tandaId == null || tandaId.isEmpty) return;

    await Navigator.pushNamed(
      context,
      AppRoutes.detalleTanda,
      arguments: {
        'tandaId': tandaId,
        'abrirAgregarParticipante': true,
      },
    );
    if (mounted) _cargarDatos();
  }

  void _mostrarSnack(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.orangeAccent),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.loop, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              _filtroEstado != 'todos'
                  ? "No hay tandas con este filtro"
                  : "No hay tandas registradas",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              textAlign: TextAlign.center,
            ),
            if (_filtroEstado != 'todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() => _filtroEstado = 'todos');
                  _aplicarFiltros();
                },
                icon: const Icon(Icons.clear_all, color: Colors.orangeAccent),
                label: const Text("Ver todas", style: TextStyle(color: Colors.orangeAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

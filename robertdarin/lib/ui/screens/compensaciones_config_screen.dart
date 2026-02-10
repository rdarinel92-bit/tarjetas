// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';
import '../../data/models/compensacion_models.dart';
import '../../data/models/colaboradores_models.dart';

/// Pantalla para configurar compensaciones de colaboradores
/// Solo accesible por superadmin
class CompensacionesConfigScreen extends StatefulWidget {
  const CompensacionesConfigScreen({super.key});

  @override
  State<CompensacionesConfigScreen> createState() =>
      _CompensacionesConfigScreenState();
}

class _CompensacionesConfigScreenState
    extends State<CompensacionesConfigScreen> {
  bool _isLoading = true;
  List<ColaboradorModel> _colaboradores = [];
  List<CompensacionTipoModel> _tiposCompensacion = [];
  List<ColaboradorCompensacionModel> _compensaciones = [];
  String? _colaboradorSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final futures = await Future.wait([
        AppSupabase.client
            .from('colaboradores')
            .select('*, colaborador_tipos(*)')
            .eq('activo', true)
            .order('nombre'),
        AppSupabase.client
            .from('compensacion_tipos')
            .select()
            .eq('activo', true)
            .order('nombre'),
        AppSupabase.client
            .from('colaborador_compensaciones')
            .select('*, compensacion_tipos(*)')
            .eq('activo', true),
      ]);

      if (mounted) {
        setState(() {
          _colaboradores = (futures[0] as List)
              .map((e) => ColaboradorModel.fromMap(e))
              .toList();
          _tiposCompensacion = (futures[1] as List)
              .map((e) => CompensacionTipoModel.fromMap(e))
              .toList();
          _compensaciones = (futures[2] as List)
              .map((e) => ColaboradorCompensacionModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando compensaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Compensaciones',
      subtitle: 'Configura cómo ganan tus colaboradores',
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: _mostrarAyuda,
          tooltip: 'Ayuda',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    return Column(
      children: [
        _buildResumen(),
        const SizedBox(height: 16),
        _buildSelectorColaborador(),
        const SizedBox(height: 16),
        Expanded(
          child: _colaboradorSeleccionado == null
              ? _buildListaGeneral()
              : _buildConfiguracionColaborador(),
        ),
      ],
    );
  }

  Widget _buildResumen() {
    final totalColaboradores = _colaboradores.length;
    final conCompensacion =
        _compensaciones.map((c) => c.colaboradorId).toSet().length;
    final sinConfigurar = totalColaboradores - conCompensacion;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalColaboradores.toString(),
              Icons.people,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          Expanded(
            child: _buildStatCard(
              'Configurados',
              conCompensacion.toString(),
              Icons.check_circle,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          Expanded(
            child: _buildStatCard(
              'Pendientes',
              sinConfigurar.toString(),
              Icons.pending,
              color: sinConfigurar > 0 ? Colors.amber : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorColaborador() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _colaboradorSeleccionado,
          isExpanded: true,
          hint: const Text(
            '👤 Selecciona un colaborador para configurar',
            style: TextStyle(color: Colors.white54),
          ),
          dropdownColor: const Color(0xFF1A1A2E),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('📊 Ver todos',
                  style: TextStyle(color: Colors.white)),
            ),
            ..._colaboradores.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: c.colorValue.withOpacity(0.2),
                        child: Icon(c.iconData, size: 14, color: c.colorValue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.nombre,
                                style: const TextStyle(color: Colors.white)),
                            Text(
                              c.tipoNombre ?? '',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (_tieneCompensacion(c.id))
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                    ],
                  ),
                )),
          ],
          onChanged: (v) => setState(() => _colaboradorSeleccionado = v),
        ),
      ),
    );
  }

  bool _tieneCompensacion(String colaboradorId) {
    return _compensaciones.any((c) => c.colaboradorId == colaboradorId);
  }

  Widget _buildListaGeneral() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _colaboradores.length,
      itemBuilder: (context, index) {
        final colaborador = _colaboradores[index];
        final compensaciones = _compensaciones
            .where((c) => c.colaboradorId == colaborador.id)
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: colaborador.colorValue.withOpacity(0.2),
              child: Icon(colaborador.iconData,
                  color: colaborador.colorValue, size: 20),
            ),
            title: Text(
              colaborador.nombre,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              colaborador.tipoNombre ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compensaciones.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${compensaciones.length} esquema(s)',
                      style:
                          const TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sin configurar',
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, color: Colors.white54),
              ],
            ),
            children: [
              if (compensaciones.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Este colaborador no tiene compensación configurada',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _mostrarAgregarCompensacion(colaborador),
                        icon: const Icon(Icons.add),
                        label: const Text('Configurar Compensación'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...compensaciones.map((comp) => _buildCompensacionItem(comp)),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: () => _mostrarAgregarCompensacion(colaborador),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Agregar otro esquema'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompensacionItem(ColaboradorCompensacionModel comp) {
    final tipo = _tiposCompensacion.firstWhere(
      (t) => t.id == comp.tipoCompensacionId,
      orElse: () => CompensacionTipoModel(
          id: '', codigo: '', nombre: comp.tipoNombre ?? 'Desconocido'),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tipo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tipo.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(tipo.iconData, color: tipo.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _descripcionCompensacion(comp),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            comp.valorPrincipal,
            style: TextStyle(
              color: tipo.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'editar',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Editar', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'desactivar',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text('Desactivar', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'editar') {
                _mostrarEditarCompensacion(comp);
              } else if (value == 'desactivar') {
                _desactivarCompensacion(comp);
              }
            },
          ),
        ],
      ),
    );
  }

  String _descripcionCompensacion(ColaboradorCompensacionModel comp) {
    final partes = <String>[];

    if (comp.porcentaje > 0) {
      partes.add('${comp.porcentaje}%');
    }
    if (comp.montoFijo > 0) {
      partes.add('\$${comp.montoFijo.toStringAsFixed(0)} fijos');
    }
    if (comp.montoPorUnidad > 0) {
      partes.add('\$${comp.montoPorUnidad.toStringAsFixed(0)}/unidad');
    }

    partes.add('Pago ${comp.periodoLabel.toLowerCase()}');

    return partes.join(' • ');
  }

  Widget _buildConfiguracionColaborador() {
    final colaborador = _colaboradores.firstWhere(
      (c) => c.id == _colaboradorSeleccionado,
    );
    final compensaciones = _compensaciones
        .where((c) => c.colaboradorId == _colaboradorSeleccionado)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del colaborador
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colaborador.colorValue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colaborador.colorValue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colaborador.colorValue.withOpacity(0.2),
                  child: Icon(colaborador.iconData,
                      color: colaborador.colorValue, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        colaborador.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        colaborador.tipoNombre ?? '',
                        style: TextStyle(color: colaborador.colorValue),
                      ),
                      Text(
                        colaborador.email,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Esquemas de compensación activos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Esquemas de Compensación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _mostrarAgregarCompensacion(colaborador),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (compensaciones.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.payments_outlined, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Sin esquemas configurados',
                    style: TextStyle(color: Colors.white54),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Agrega un esquema de compensación para este colaborador',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...compensaciones.map((comp) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildCompensacionDetallada(comp),
                )),

          const SizedBox(height: 24),

          // Tipos de compensación disponibles
          const Text(
            'Tipos Disponibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tiposCompensacion.map((tipo) {
              final yaConfigurado = compensaciones
                  .any((c) => c.tipoCompensacionId == tipo.id);
              return ActionChip(
                avatar: Icon(tipo.iconData, color: tipo.color, size: 18),
                label: Text(
                  tipo.nombre,
                  style: TextStyle(
                    color: yaConfigurado ? Colors.white38 : Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: yaConfigurado
                    ? Colors.white10
                    : tipo.color.withOpacity(0.2),
                onPressed: yaConfigurado
                    ? null
                    : () => _mostrarAgregarCompensacionTipo(colaborador, tipo),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensacionDetallada(ColaboradorCompensacionModel comp) {
    final tipo = _tiposCompensacion.firstWhere(
      (t) => t.id == comp.tipoCompensacionId,
      orElse: () => CompensacionTipoModel(
          id: '', codigo: '', nombre: comp.tipoNombre ?? ''),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tipo.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tipo.iconData, color: tipo.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tipo.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                comp.valorPrincipal,
                style: TextStyle(
                  color: tipo.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDetalleItem('Período', comp.periodoLabel, Icons.schedule),
              _buildDetalleItem(
                  'Día de pago', 'Día ${comp.diaPago}', Icons.calendar_today),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (comp.topeMinimo > 0)
                _buildDetalleItem('Mínimo garantizado',
                    '\$${comp.topeMinimo.toStringAsFixed(0)}', Icons.arrow_upward),
              if (comp.topeMaximo != null)
                _buildDetalleItem('Tope máximo',
                    '\$${comp.topeMaximo!.toStringAsFixed(0)}', Icons.arrow_downward),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _mostrarEditarCompensacion(comp),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: () => _desactivarCompensacion(comp),
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                label: const Text('Eliminar',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  void _mostrarAgregarCompensacion(ColaboradorModel colaborador) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AgregarCompensacionSheet(
        colaborador: colaborador,
        tipos: _tiposCompensacion,
        onGuardado: _cargarDatos,
      ),
    );
  }

  void _mostrarAgregarCompensacionTipo(
      ColaboradorModel colaborador, CompensacionTipoModel tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AgregarCompensacionSheet(
        colaborador: colaborador,
        tipos: _tiposCompensacion,
        tipoPreseleccionado: tipo,
        onGuardado: _cargarDatos,
      ),
    );
  }

  void _mostrarEditarCompensacion(ColaboradorCompensacionModel comp) {
    // Implementar edición
  }

  Future<void> _desactivarCompensacion(ColaboradorCompensacionModel comp) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Desactivar compensación',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de desactivar este esquema de compensación?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppSupabase.client
            .from('colaborador_compensaciones')
            .update({'activo': false}).eq('id', comp.id);
        _cargarDatos();
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            const Text('Tipos de Compensación',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _tiposCompensacion.map((tipo) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tipo.iconData, color: tipo.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipo.nombre,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            tipo.descripcion ?? '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// SHEET PARA AGREGAR COMPENSACIÓN
// =====================================================
class _AgregarCompensacionSheet extends StatefulWidget {
  final ColaboradorModel colaborador;
  final List<CompensacionTipoModel> tipos;
  final CompensacionTipoModel? tipoPreseleccionado;
  final VoidCallback onGuardado;

  const _AgregarCompensacionSheet({
    required this.colaborador,
    required this.tipos,
    this.tipoPreseleccionado,
    required this.onGuardado,
  });

  @override
  State<_AgregarCompensacionSheet> createState() =>
      _AgregarCompensacionSheetState();
}

class _AgregarCompensacionSheetState
    extends State<_AgregarCompensacionSheet> {
  final _formKey = GlobalKey<FormState>();
  late CompensacionTipoModel? _tipoSeleccionado;
  final _porcentajeCtrl = TextEditingController();
  final _montoFijoCtrl = TextEditingController();
  final _montoPorUnidadCtrl = TextEditingController();
  final _topeMinimoCtrl = TextEditingController();
  final _topeMaximoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _periodoPago = 'mensual';
  int _diaPago = 1;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.tipoPreseleccionado;
  }

  @override
  void dispose() {
    _porcentajeCtrl.dispose();
    _montoFijoCtrl.dispose();
    _montoPorUnidadCtrl.dispose();
    _topeMinimoCtrl.dispose();
    _topeMaximoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        widget.colaborador.colorValue.withOpacity(0.2),
                    child: Icon(widget.colaborador.iconData,
                        color: widget.colaborador.colorValue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configurar Compensación',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.colaborador.nombre,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Selector de tipo
              const Text('Tipo de Compensación',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CompensacionTipoModel>(
                    value: _tipoSeleccionado,
                    isExpanded: true,
                    hint: const Text('Selecciona un tipo',
                        style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A2E),
                    items: widget.tipos
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(t.iconData, color: t.color, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(t.nombre,
                                        style:
                                            const TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _tipoSeleccionado = v),
                  ),
                ),
              ),

              if (_tipoSeleccionado != null) ...[
                const SizedBox(height: 20),
                _buildCamposTipo(),
              ],

              const SizedBox(height: 20),

              // Período de pago
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Período de pago',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _periodoPago,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1A1A2E),
                              items: const [
                                DropdownMenuItem(
                                    value: 'semanal',
                                    child: Text('Semanal',
                                        style: TextStyle(color: Colors.white))),
                                DropdownMenuItem(
                                    value: 'quincenal',
                                    child: Text('Quincenal',
                                        style: TextStyle(color: Colors.white))),
                                DropdownMenuItem(
                                    value: 'mensual',
                                    child: Text('Mensual',
                                        style: TextStyle(color: Colors.white))),
                                DropdownMenuItem(
                                    value: 'trimestral',
                                    child: Text('Trimestral',
                                        style: TextStyle(color: Colors.white))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _periodoPago = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Día de pago',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _diaPago,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1A1A2E),
                              items: List.generate(
                                  28,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('Día ${i + 1}',
                                          style: const TextStyle(
                                              color: Colors.white)))),
                              onChanged: (v) => setState(() => _diaPago = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Notas
              const Text('Notas (opcional)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Condiciones especiales...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar Compensación',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamposTipo() {
    final codigo = _tipoSeleccionado!.codigo;

    switch (codigo) {
      case 'porcentaje_cartera':
      case 'porcentaje_cobranza':
      case 'porcentaje_utilidades':
      case 'rendimiento_inversion':
        return _buildCampoPorcentaje();
      case 'honorarios_fijos':
        return _buildCampoMontoFijo();
      case 'por_factura':
      case 'por_cliente':
        return _buildCampoPorUnidad();
      case 'mixto':
        return _buildCamposMixto();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCampoPorcentaje() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Porcentaje (%)',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _porcentajeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: '5.0',
            hintStyle: const TextStyle(color: Colors.white24),
            suffixText: '%',
            suffixStyle:
                TextStyle(color: _tipoSeleccionado!.color, fontSize: 20),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            final n = double.tryParse(v);
            if (n == null || n <= 0 || n > 100) return 'Entre 0.1 y 100';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCampoMontoFijo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monto Mensual Fijo',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _montoFijoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: '5,000',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixText: '\$ ',
            prefixStyle:
                TextStyle(color: _tipoSeleccionado!.color, fontSize: 20),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            final n = double.tryParse(v.replaceAll(',', ''));
            if (n == null || n <= 0) return 'Monto inválido';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCampoPorUnidad() {
    final label = _tipoSeleccionado!.codigo == 'por_factura'
        ? 'Monto por Factura Emitida'
        : 'Monto por Cliente Captado';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _montoPorUnidadCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: '50',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixText: '\$ ',
            prefixStyle:
                TextStyle(color: _tipoSeleccionado!.color, fontSize: 20),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            final n = double.tryParse(v.replaceAll(',', ''));
            if (n == null || n <= 0) return 'Monto inválido';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCamposMixto() {
    return Column(
      children: [
        _buildCampoMontoFijo(),
        const SizedBox(height: 16),
        _buildCampoPorcentaje(),
      ],
    );
  }

  Future<void> _guardar() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de compensación')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      // Obtener negocio_id del colaborador
      final colaboradorData = await AppSupabase.client
          .from('colaboradores')
          .select('negocio_id')
          .eq('id', widget.colaborador.id)
          .single();

      final data = {
        'colaborador_id': widget.colaborador.id,
        'negocio_id': colaboradorData['negocio_id'],
        'tipo_compensacion_id': _tipoSeleccionado!.id,
        'porcentaje':
            double.tryParse(_porcentajeCtrl.text.replaceAll(',', '')) ?? 0,
        'monto_fijo':
            double.tryParse(_montoFijoCtrl.text.replaceAll(',', '')) ?? 0,
        'monto_por_unidad':
            double.tryParse(_montoPorUnidadCtrl.text.replaceAll(',', '')) ?? 0,
        'tope_minimo':
            double.tryParse(_topeMinimoCtrl.text.replaceAll(',', '')) ?? 0,
        'tope_maximo': _topeMaximoCtrl.text.isNotEmpty
            ? double.tryParse(_topeMaximoCtrl.text.replaceAll(',', ''))
            : null,
        'periodo_pago': _periodoPago,
        'dia_pago': _diaPago,
        'notas': _notasCtrl.text.isNotEmpty ? _notasCtrl.text : null,
        'activo': true,
        'fecha_inicio': DateTime.now().toIso8601String().split('T')[0],
      };

      await AppSupabase.client.from('colaborador_compensaciones').insert(data);

      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Compensación configurada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando: $e');
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

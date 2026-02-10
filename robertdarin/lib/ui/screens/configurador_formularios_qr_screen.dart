// lib/ui/screens/configurador_formularios_qr_screen.dart
// Pantalla para configurar los campos de formularios QR dinámicos
// V10.52 - Robert Darin Platform

import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

class ConfiguradorFormulariosQRScreen extends StatefulWidget {
  final String? negocioId;
  final String? tarjetaId;
  final String modulo;

  const ConfiguradorFormulariosQRScreen({
    super.key,
    this.negocioId,
    this.tarjetaId,
    this.modulo = 'general',
  });

  @override
  State<ConfiguradorFormulariosQRScreen> createState() =>
      _ConfiguradorFormulariosQRScreenState();
}

class _ConfiguradorFormulariosQRScreenState
    extends State<ConfiguradorFormulariosQRScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _configActual;
  List<Map<String, dynamic>> _camposActivos = [];
  List<Map<String, dynamic>> _camposDisponibles = [];
  List<Map<String, dynamic>> _negocios = [];
  String? _negocioSeleccionado;

  // Controllers para edición
  final _tituloController = TextEditingController();
  final _subtituloController = TextEditingController();
  final _mensajeExitoController = TextEditingController();
  String _colorHeader = '#00D9FF';

  // Opciones
  bool _mostrarHorario = true;
  bool _mostrarTelefono = true;
  bool _mostrarDireccion = true;
  bool _mostrarRedes = true;
  bool _permitirFotos = true;
  bool _notificarWhatsapp = true;
  bool _notificarEmail = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _subtituloController.dispose();
    _mensajeExitoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar negocios del usuario
      final negociosRes = await AppSupabase.client
          .from('negocios')
          .select('id, nombre, logo_url')
          .order('nombre');
      
      _negocios = List<Map<String, dynamic>>.from(negociosRes);

      if (_negocios.isNotEmpty) {
        String? preferido = widget.negocioId;
        if (preferido == null) {
          final activoId = await _cargarNegocioActivoId();
          if (activoId != null) preferido = activoId;
        }

        if (preferido != null &&
            !_negocios.any((n) => n['id']?.toString() == preferido)) {
          preferido = null;
        }

        _negocioSeleccionado = preferido ?? _negocios.first['id'];
      } else {
        _negocioSeleccionado = null;
      }

      // Cargar catálogo de campos
      final catalogoRes = await AppSupabase.client
          .from('campos_formulario_catalogo')
          .select()
          .or('modulo.eq.general,modulo.eq.${widget.modulo}')
          .eq('activo', true)
          .order('orden_sugerido');
      
      _camposDisponibles = List<Map<String, dynamic>>.from(catalogoRes);

      // Cargar configuración existente
      await _cargarConfiguracion();

    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<String?> _cargarNegocioActivoId() async {
    try {
      final configRes = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'negocio_activo')
          .maybeSingle();
      if (configRes != null) {
        final valor = configRes['valor'];
        if (valor is Map && valor['id'] != null) {
          return valor['id'].toString();
        }
        if (valor is String && valor.isNotEmpty) {
          return valor;
        }
      }
    } catch (e) {
      debugPrint('Error leyendo negocio_activo: $e');
    }
    return null;
  }

  Future<void> _cargarConfiguracion() async {
    _configActual = null;
    _camposActivos = [];
    if (_negocioSeleccionado == null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      Map<String, dynamic>? config;
      
      // Buscar config específica de la tarjeta
      if (widget.tarjetaId != null) {
        final res = await AppSupabase.client
            .from('formularios_qr_config')
            .select()
            .eq('tarjeta_servicio_id', widget.tarjetaId!)
            .maybeSingle();
        config = res;
      }

      // Si no hay, buscar config del módulo
      if (config == null) {
        final res = await AppSupabase.client
            .from('formularios_qr_config')
            .select()
            .eq('negocio_id', _negocioSeleccionado!)
            .eq('modulo', widget.modulo)
            .isFilter('tarjeta_servicio_id', null)
            .maybeSingle();
        config = res;
      }

      if (config != null) {
        _configActual = config;
        _tituloController.text = config['titulo_header'] ?? '¡Contáctanos!';
        _subtituloController.text = config['subtitulo_header'] ?? '';
        _mensajeExitoController.text = config['mensaje_exito'] ?? '';
        _colorHeader = config['color_header'] ?? '#00D9FF';
        _mostrarHorario = config['mostrar_horario'] ?? true;
        _mostrarTelefono = config['mostrar_telefono_negocio'] ?? true;
        _mostrarDireccion = config['mostrar_direccion_negocio'] ?? true;
        _mostrarRedes = config['mostrar_redes_sociales'] ?? true;
        _permitirFotos = config['permitir_fotos'] ?? true;
        _notificarWhatsapp = config['notificar_whatsapp'] ?? true;
        _notificarEmail = config['notificar_email'] ?? true;

        // Cargar campos activos
        final camposJson = config['campos'];
        if (camposJson != null) {
          _camposActivos = List<Map<String, dynamic>>.from(camposJson);
        }
      } else {
        // Configuración por defecto
        _tituloController.text = '¡Contáctanos!';
        _subtituloController.text = 'Completa el formulario y te contactaremos';
        _mensajeExitoController.text = '¡Gracias! Tu solicitud ha sido enviada.';
        _colorHeader = '#00D9FF';
        _mostrarHorario = true;
        _mostrarTelefono = true;
        _mostrarDireccion = true;
        _mostrarRedes = true;
        _permitirFotos = true;
        _notificarWhatsapp = true;
        _notificarEmail = true;
        
        // Campos por defecto
        _camposActivos = _camposDisponibles
            .where((c) => ['nombre', 'telefono', 'email', 'mensaje'].contains(c['codigo']))
            .map((c) => {
              'id': c['codigo'],
              'tipo': c['tipo'],
              'label': c['label'],
              'placeholder': c['placeholder'],
              'requerido': c['requerido_default'] ?? false,
              'orden': c['orden_sugerido'] ?? 99,
              'activo': true,
              'opciones': c['opciones'] ?? [],
            })
            .toList();
      }
    } catch (e) {
      debugPrint('Error cargando config: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _guardarConfiguracion() async {
    if (_negocioSeleccionado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona un negocio para guardar la configuracion.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      final data = {
        'negocio_id': _negocioSeleccionado,
        'modulo': widget.modulo,
        'tarjeta_servicio_id': widget.tarjetaId,
        'titulo_header': _tituloController.text,
        'subtitulo_header': _subtituloController.text,
        'mensaje_exito': _mensajeExitoController.text,
        'color_header': _colorHeader,
        'campos': _camposActivos,
        'mostrar_horario': _mostrarHorario,
        'mostrar_telefono_negocio': _mostrarTelefono,
        'mostrar_direccion_negocio': _mostrarDireccion,
        'mostrar_redes_sociales': _mostrarRedes,
        'permitir_fotos': _permitirFotos,
        'notificar_whatsapp': _notificarWhatsapp,
        'notificar_email': _notificarEmail,
        'activo': true,
        if (userId != null) 'created_by': userId,
      };

      if (_configActual != null && _configActual!['id'] != null) {
        final updated = await AppSupabase.client
            .from('formularios_qr_config')
            .update(data)
            .eq('id', _configActual!['id'])
            .select()
            .maybeSingle();
        if (updated != null) {
          _configActual = updated;
        }
      } else {
        final inserted = await AppSupabase.client
            .from('formularios_qr_config')
            .insert(data)
            .select()
            .maybeSingle();
        if (inserted != null) {
          _configActual = inserted;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada'),
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
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _agregarCampo(Map<String, dynamic> campo) {
    final yaExiste = _camposActivos.any((c) => c['id'] == campo['codigo']);
    if (yaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este campo ya está agregado')),
      );
      return;
    }

    setState(() {
      _camposActivos.add({
        'id': campo['codigo'],
        'tipo': campo['tipo'],
        'label': campo['label'],
        'placeholder': campo['placeholder'],
        'requerido': campo['requerido_default'] ?? false,
        'orden': _camposActivos.length + 1,
        'activo': true,
        'opciones': campo['opciones'] ?? [],
      });
    });
  }

  void _removerCampo(int index) {
    setState(() {
      _camposActivos.removeAt(index);
      // Reordenar
      for (var i = 0; i < _camposActivos.length; i++) {
        _camposActivos[i]['orden'] = i + 1;
      }
    });
  }

  void _moverCampo(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _camposActivos.removeAt(oldIndex);
      _camposActivos.insert(newIndex, item);
      // Reordenar
      for (var i = 0; i < _camposActivos.length; i++) {
        _camposActivos[i]['orden'] = i + 1;
      }
    });
  }

  void _editarCampo(int index) {
    final campo = _camposActivos[index];
    final labelCtrl = TextEditingController(text: campo['label']);
    final placeholderCtrl = TextEditingController(text: campo['placeholder']);
    bool requerido = campo['requerido'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Editar Campo',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Etiqueta',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00D9FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: placeholderCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Placeholder',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00D9FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDialogState) => SwitchListTile(
                  title: const Text('Campo requerido', 
                      style: TextStyle(color: Colors.white)),
                  value: requerido,
                  activeColor: const Color(0xFF00D9FF),
                  onChanged: (v) => setDialogState(() => requerido = v),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _camposActivos[index]['label'] = labelCtrl.text;
                _camposActivos[index]['placeholder'] = placeholderCtrl.text;
                _camposActivos[index]['requerido'] = requerido;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Configurar Formulario QR'),
        actions: [
          if (!_isLoading && _negocios.isNotEmpty)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _guardarConfiguracion,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _negocios.isEmpty
              ? _buildEmptyNegocios()
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFF1A1A2E),
                        child: TabBar(
                          indicatorColor: const Color(0xFF00D9FF),
                          labelColor: const Color(0xFF00D9FF),
                          unselectedLabelColor: Colors.white70,
                          tabs: const [
                            Tab(icon: Icon(Icons.tune), text: 'General'),
                            Tab(icon: Icon(Icons.list_alt), text: 'Campos'),
                            Tab(icon: Icon(Icons.preview), text: 'Vista Previa'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildConfigGeneral(),
                            _buildConfigCampos(),
                            _buildVistaPrevia(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyNegocios() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No hay negocios registrados',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Para guardar la configuracion del QR necesitas crear un negocio primero.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.superadminNegocios),
              icon: const Icon(Icons.add_business),
              label: const Text('Crear negocio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigGeneral() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selector de negocio
        if (_negocios.isNotEmpty) ...[
          _buildSectionTitle('Negocio'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<String>(
              value: _negocioSeleccionado,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: _negocios.map((n) => DropdownMenuItem(
                value: n['id'] as String,
                child: Text(n['nombre'] ?? 'Sin nombre'),
              )).toList(),
              onChanged: _negocios.length <= 1
                  ? null
                  : (v) {
                      setState(() => _negocioSeleccionado = v);
                      _cargarConfiguracion();
                    },
            ),
          ),
          if (_negocios.length <= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Solo tienes un negocio, se usara por defecto.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
        ],

        // Header del formulario
        _buildSectionTitle('Encabezado del Formulario'),
        _buildTextField(
          controller: _tituloController,
          label: 'Título',
          hint: '¡Contáctanos!',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _subtituloController,
          label: 'Subtítulo',
          hint: 'Completa el formulario...',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        
        // Color selector
        _buildSectionTitle('Color del encabezado'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '#00D9FF', '#8B5CF6', '#10B981', '#F59E0B', 
            '#EF4444', '#EC4899', '#6366F1', '#14B8A6'
          ].map((c) => _buildColorOption(c)).toList(),
        ),
        const SizedBox(height: 24),

        // Mensaje de éxito
        _buildSectionTitle('Mensaje de éxito'),
        _buildTextField(
          controller: _mensajeExitoController,
          label: 'Mensaje al enviar',
          hint: '¡Gracias! Te contactaremos pronto.',
          maxLines: 2,
        ),
        const SizedBox(height: 24),

        // Opciones de visualización
        _buildSectionTitle('Mostrar en el formulario'),
        _buildSwitchTile('Horario de atención', _mostrarHorario, 
            (v) => setState(() => _mostrarHorario = v)),
        _buildSwitchTile('Teléfono del negocio', _mostrarTelefono, 
            (v) => setState(() => _mostrarTelefono = v)),
        _buildSwitchTile('Dirección del negocio', _mostrarDireccion, 
            (v) => setState(() => _mostrarDireccion = v)),
        _buildSwitchTile('Redes sociales', _mostrarRedes, 
            (v) => setState(() => _mostrarRedes = v)),
        _buildSwitchTile('Permitir subir fotos', _permitirFotos, 
            (v) => setState(() => _permitirFotos = v)),
        const SizedBox(height: 24),

        // Notificaciones
        _buildSectionTitle('Notificaciones'),
        _buildSwitchTile('Notificar por WhatsApp', _notificarWhatsapp, 
            (v) => setState(() => _notificarWhatsapp = v)),
        _buildSwitchTile('Notificar por Email', _notificarEmail, 
            (v) => setState(() => _notificarEmail = v)),
      ],
    );
  }

  Widget _buildConfigCampos() {
    return Column(
      children: [
        // Lista de campos activos (reordenables)
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.list, color: Color(0xFF00D9FF)),
                      const SizedBox(width: 8),
                      const Text(
                        'Campos del formulario',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_camposActivos.length} campos',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _camposActivos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, 
                                  size: 48, color: Colors.white30),
                              const SizedBox(height: 8),
                              Text(
                                'Agrega campos desde abajo',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _camposActivos.length,
                          onReorder: _moverCampo,
                          itemBuilder: (ctx, i) {
                            final campo = _camposActivos[i];
                            return _buildCampoActivo(campo, i);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Campos disponibles para agregar
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline, 
                          color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      const Text(
                        'Agregar campos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    children: _camposDisponibles.map((campo) {
                      final yaAgregado = _camposActivos
                          .any((c) => c['id'] == campo['codigo']);
                      return _buildCampoDisponible(campo, yaAgregado);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoActivo(Map<String, dynamic> campo, int index) {
    final tipo = campo['tipo'] ?? 'text';
    final requerido = campo['requerido'] ?? false;

    return Card(
      key: ValueKey(campo['id']),
      color: const Color(0xFF0D0D14),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.white30),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                campo['label'] ?? campo['id'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (requerido)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Requerido',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Text(
          _getTipoLabel(tipo),
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF00D9FF), size: 20),
              onPressed: () => _editarCampo(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _removerCampo(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoDisponible(Map<String, dynamic> campo, bool yaAgregado) {
    return GestureDetector(
      onTap: yaAgregado ? null : () => _agregarCampo(campo),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: yaAgregado 
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: yaAgregado 
                ? Colors.white12 
                : const Color(0xFF00D9FF).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTipoIcon(campo['tipo']),
              color: yaAgregado ? Colors.white30 : const Color(0xFF00D9FF),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              campo['label'] ?? campo['codigo'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: yaAgregado ? Colors.white30 : Colors.white,
                fontSize: 11,
              ),
            ),
            if (yaAgregado)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, 
                    color: Colors.green, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaPrevia() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _parseColor(_colorHeader),
                      _parseColor(_colorHeader).withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.business, 
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tituloController.text.isNotEmpty 
                          ? _tituloController.text 
                          : '¡Contáctanos!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_subtituloController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _subtituloController.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Campos del formulario
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._camposActivos.map((campo) => _buildCampoPreview(campo)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _parseColor(_colorHeader),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Enviar solicitud',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampoPreview(Map<String, dynamic> campo) {
    final tipo = campo['tipo'] ?? 'text';
    final label = campo['label'] ?? campo['id'];
    final placeholder = campo['placeholder'] ?? '';
    final requerido = campo['requerido'] ?? false;
    final opciones = campo['opciones'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (requerido)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 6),
          if (tipo == 'select') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    placeholder.isNotEmpty ? placeholder : 'Seleccionar...',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ] else if (tipo == 'textarea') ...[
            Container(
              height: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.topLeft,
              child: Text(
                placeholder,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ] else if (tipo == 'checkbox' || tipo == 'radio') ...[
            ...opciones.map((op) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    tipo == 'checkbox' 
                        ? Icons.check_box_outline_blank 
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(op['texto'] ?? op['valor'] ?? ''),
                ],
              ),
            )),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                placeholder,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00D9FF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: value,
        activeColor: const Color(0xFF00D9FF),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildColorOption(String hex) {
    final isSelected = _colorHeader == hex;
    return GestureDetector(
      onTap: () => setState(() => _colorHeader = hex),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _parseColor(hex),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _parseColor(hex).withValues(alpha: 0.5),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  IconData _getTipoIcon(String? tipo) {
    switch (tipo) {
      case 'email': return Icons.email;
      case 'tel': return Icons.phone;
      case 'number': return Icons.numbers;
      case 'textarea': return Icons.notes;
      case 'select': return Icons.arrow_drop_down_circle;
      case 'radio': return Icons.radio_button_checked;
      case 'checkbox': return Icons.check_box;
      case 'date': return Icons.calendar_today;
      case 'time': return Icons.access_time;
      case 'file': return Icons.attach_file;
      case 'photo': return Icons.camera_alt;
      case 'location': return Icons.location_on;
      case 'signature': return Icons.draw;
      default: return Icons.text_fields;
    }
  }

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'email': return 'Correo electrónico';
      case 'tel': return 'Teléfono';
      case 'number': return 'Número';
      case 'textarea': return 'Texto largo';
      case 'select': return 'Lista desplegable';
      case 'radio': return 'Opción única';
      case 'checkbox': return 'Casilla de verificación';
      case 'date': return 'Fecha';
      case 'time': return 'Hora';
      case 'file': return 'Archivo';
      case 'photo': return 'Foto';
      case 'location': return 'Ubicación';
      case 'signature': return 'Firma';
      default: return 'Texto';
    }
  }
}

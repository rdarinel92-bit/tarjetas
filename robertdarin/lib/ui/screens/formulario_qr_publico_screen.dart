import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';

class FormularioQrPublicoScreen extends StatefulWidget {
  final String modulo;
  final String? negocioId;
  final String? tarjetaCodigo;

  const FormularioQrPublicoScreen({
    super.key,
    required this.modulo,
    this.negocioId,
    this.tarjetaCodigo,
  });

  @override
  State<FormularioQrPublicoScreen> createState() =>
      _FormularioQrPublicoScreenState();
}

class _FormularioQrPublicoScreenState extends State<FormularioQrPublicoScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSending = false;
  bool _enviado = false;
  String? _error;

  String _modulo = 'general';
  String? _negocioId;
  String? _tarjetaId;
  String? _tarjetaCodigo;

  Map<String, dynamic>? _config;
  Map<String, dynamic>? _tarjetaInfo;
  Map<String, dynamic>? _negocioInfo;
  List<Map<String, dynamic>> _campos = [];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectValues = {};
  final Map<String, List<String>> _multiValues = {};

  @override
  void initState() {
    super.initState();
    _modulo = widget.modulo.toLowerCase().trim();
    _negocioId = widget.negocioId;
    _tarjetaCodigo = widget.tarjetaCodigo;
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_tarjetaCodigo != null && _tarjetaCodigo!.isNotEmpty) {
        final tarjetaRes = await AppSupabase.client
            .from('tarjetas_servicio')
            .select('id, negocio_id, modulo, nombre_tarjeta, nombre_negocio, slogan, telefono_principal, whatsapp, email, color_primario, color_secundario, logo_url')
            .eq('codigo', _tarjetaCodigo!)
            .maybeSingle();

        if (tarjetaRes != null) {
          _tarjetaInfo = Map<String, dynamic>.from(tarjetaRes);
          _tarjetaId = tarjetaRes['id']?.toString();
          _negocioId ??= tarjetaRes['negocio_id']?.toString();
          final moduloTarjeta = tarjetaRes['modulo']?.toString().toLowerCase();
          if (moduloTarjeta != null && moduloTarjeta.isNotEmpty) {
            _modulo = moduloTarjeta;
          }
        }
      }

      if (_negocioId != null) {
        final negocioRes = await AppSupabase.client
            .from('negocios')
            .select('id, nombre, telefono, email, logo_url, color_primario, color_secundario')
            .eq('id', _negocioId!)
            .maybeSingle();
        if (negocioRes != null) {
          _negocioInfo = Map<String, dynamic>.from(negocioRes);
        }
      }

      Map<String, dynamic>? config;

      if (_tarjetaId != null) {
        config = await AppSupabase.client
            .from('formularios_qr_config')
            .select()
            .eq('tarjeta_servicio_id', _tarjetaId!)
            .maybeSingle();
      }

      if (config == null && _negocioId != null) {
        config = await AppSupabase.client
            .from('formularios_qr_config')
            .select()
            .eq('negocio_id', _negocioId!)
            .eq('modulo', _modulo)
            .isFilter('tarjeta_servicio_id', null)
            .maybeSingle();
      }

      if (config == null) {
        config = await _crearConfigPorDefecto();
      }

      _config = config;
      _campos = _extraerCampos(config);
      _inicializarControles();
    } catch (e) {
      _error = 'No se pudo cargar el formulario.';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _crearConfigPorDefecto() async {
    final res = await AppSupabase.client
        .from('campos_formulario_catalogo')
        .select()
        .or('modulo.eq.general,modulo.eq.$_modulo')
        .eq('activo', true)
        .order('orden_sugerido');

    final campos = (res as List)
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

    return {
      'titulo_header': '¡Contáctanos!',
      'subtitulo_header': 'Completa el formulario y te contactaremos',
      'mensaje_exito': '¡Gracias! Tu solicitud ha sido enviada.',
      'color_header': '#00D9FF',
      'campos': campos,
    };
  }

  List<Map<String, dynamic>> _extraerCampos(Map<String, dynamic> config) {
    final raw = config['campos'];
    if (raw is List) {
      final campos = raw
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) => c['activo'] != false)
          .toList();
      campos.sort((a, b) => (a['orden'] ?? 99).compareTo(b['orden'] ?? 99));
      return campos;
    }
    return [];
  }

  void _inicializarControles() {
    _controllers.clear();
    _selectValues.clear();
    _multiValues.clear();

    for (final campo in _campos) {
      final id = (campo['id'] ?? '').toString();
      final tipo = (campo['tipo'] ?? 'text').toString();
      if (id.isEmpty) continue;

      if (_esTexto(tipo)) {
        _controllers[id] = TextEditingController();
      } else if (tipo == 'checkbox') {
        _multiValues[id] = [];
      } else {
        _selectValues[id] = null;
      }
    }
  }

  bool _esTexto(String tipo) {
    return ['text', 'email', 'tel', 'number', 'textarea', 'date', 'time', 'file', 'photo', 'location', 'signature']
        .contains(tipo);
  }

  Future<void> _enviarFormulario() async {
    if (_negocioId == null) {
      _mostrarMensaje('No se encontró un negocio válido.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final datos = <String, dynamic>{};
      for (final campo in _campos) {
        final id = (campo['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final tipo = (campo['tipo'] ?? 'text').toString();

        if (_esTexto(tipo)) {
          datos[id] = _controllers[id]?.text.trim();
        } else if (tipo == 'checkbox') {
          datos[id] = _multiValues[id] ?? [];
        } else {
          datos[id] = _selectValues[id];
        }
      }

      final nombre = _extraerDato(datos, ['nombre', 'nombre_completo']);
      final telefono = _extraerDato(datos, ['telefono', 'celular', 'whatsapp']);
      final email = _extraerDato(datos, ['email', 'correo']);

      await AppSupabase.client.from('formularios_qr_envios').insert({
        'formulario_config_id': _config?['id'],
        'tarjeta_servicio_id': _tarjetaId,
        'negocio_id': _negocioId,
        'modulo': _modulo,
        'datos': datos,
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'origen': 'qr',
      });

      if (!mounted) return;
      setState(() => _enviado = true);
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error al enviar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String? _extraerDato(Map<String, dynamic> datos, List<String> keys) {
    for (final key in keys) {
      final value = datos[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D14),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_enviado) {
      return _buildSuccess();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._campos.map(_buildCampo),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _enviarFormulario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _parseColor(_config?['color_header'] ?? '#00D9FF'),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Enviar solicitud',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final color = _resolveAccentColor();
    final negocioNombre = _resolveNegocioNombre();
    final tituloConfig = (_config?['titulo_header'] ?? '').toString().trim();
    final subtitleConfig = (_config?['subtitulo_header'] ?? '').toString().trim();
    final slogan = (_tarjetaInfo?['slogan'] ?? '').toString().trim();
    final title = (negocioNombre != null && negocioNombre.isNotEmpty)
        ? negocioNombre
        : (tituloConfig.isNotEmpty ? tituloConfig : 'Formulario');
    final subtitle = subtitleConfig.isNotEmpty ? subtitleConfig : slogan;
    final nombreTarjeta = (_tarjetaInfo?['nombre_tarjeta'] ?? '').toString().trim();
    final telefono = (_tarjetaInfo?['telefono_principal'] ?? _negocioInfo?['telefono'] ?? '').toString().trim();
    final whatsapp = (_tarjetaInfo?['whatsapp'] ?? '').toString().trim();
    final email = (_tarjetaInfo?['email'] ?? _negocioInfo?['email'] ?? '').toString().trim();
    final contactos = <Widget>[];

    if (telefono.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.phone_outlined, telefono));
    }
    if (whatsapp.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.chat_bubble_outline, whatsapp));
    }
    if (email.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.mail_outline, email));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  _modulo.toUpperCase(),
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, letterSpacing: 1),
                ),
              ),
            ],
          ),
          if (nombreTarjeta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              nombreTarjeta,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ],
          if (contactos.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...contactos,
          ],
        ],
      ),
    );
  }

  Widget _buildContactoLine(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampo(Map<String, dynamic> campo) {
    final id = (campo['id'] ?? '').toString();
    final tipo = (campo['tipo'] ?? 'text').toString();
    final label = (campo['label'] ?? id).toString();
    final placeholder = (campo['placeholder'] ?? '').toString();
    final requerido = campo['requerido'] == true;
    final opciones = campo['opciones'] is List ? List<Map<String, dynamic>>.from(campo['opciones']) : <Map<String, dynamic>>[];

    if (tipo == 'select') {
      return _buildSelectField(id, label, opciones, placeholder, requerido);
    }

    if (tipo == 'radio') {
      return _buildRadioField(id, label, opciones, requerido);
    }

    if (tipo == 'checkbox') {
      return _buildCheckboxField(id, label, opciones, requerido);
    }

    if (tipo == 'date') {
      return _buildDateField(id, label, placeholder, requerido);
    }

    if (tipo == 'time') {
      return _buildTimeField(id, label, placeholder, requerido);
    }

    final controller = _controllers[id] ?? TextEditingController();
    _controllers[id] = controller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: tipo == 'textarea' ? 4 : 1,
        keyboardType: _keyboardForTipo(tipo),
        inputFormatters: tipo == 'number'
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, placeholder),
        validator: requerido
            ? (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null
            : null,
      ),
    );
  }

  Widget _buildSelectField(
    String id,
    String label,
    List<Map<String, dynamic>> opciones,
    String placeholder,
    bool requerido,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectValues[id],
        dropdownColor: const Color(0xFF1A1A2E),
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, placeholder),
        items: opciones
            .map((o) => DropdownMenuItem(
                  value: o['valor']?.toString(),
                  child: Text(o['texto']?.toString() ?? o['valor']?.toString() ?? ''),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectValues[id] = v),
        validator: requerido ? (v) => v == null || v.isEmpty ? 'Campo requerido' : null : null,
      ),
    );
  }

  Widget _buildRadioField(
    String id,
    String label,
    List<Map<String, dynamic>> opciones,
    bool requerido,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        validator: requerido
            ? (v) => v == null || v.isEmpty ? 'Campo requerido' : null
            : null,
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...opciones.map((o) {
                final value = o['valor']?.toString();
                final text = o['texto']?.toString() ?? value ?? '';
                return RadioListTile<String>(
                  value: value ?? text,
                  groupValue: _selectValues[id],
                  activeColor: Colors.cyanAccent,
                  title: Text(text, style: const TextStyle(color: Colors.white70)),
                  onChanged: (v) {
                    setState(() => _selectValues[id] = v);
                    state.didChange(v);
                  },
                );
              }).toList(),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.errorText ?? '',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCheckboxField(
    String id,
    String label,
    List<Map<String, dynamic>> opciones,
    bool requerido,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<List<String>>(
        validator: requerido
            ? (v) => v == null || v.isEmpty ? 'Selecciona al menos una opción' : null
            : null,
        builder: (state) {
          final selected = _multiValues[id] ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...opciones.map((o) {
                final value = o['valor']?.toString() ?? '';
                final text = o['texto']?.toString() ?? value;
                final isChecked = selected.contains(value);
                return CheckboxListTile(
                  value: isChecked,
                  activeColor: Colors.cyanAccent,
                  title: Text(text, style: const TextStyle(color: Colors.white70)),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selected.add(value);
                      } else {
                        selected.remove(value);
                      }
                      _multiValues[id] = List<String>.from(selected);
                    });
                    state.didChange(_multiValues[id]);
                  },
                );
              }).toList(),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.errorText ?? '',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField(
    String id,
    String label,
    String placeholder,
    bool requerido,
  ) {
    final controller = _controllers[id] ?? TextEditingController();
    _controllers[id] = controller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, placeholder).copyWith(
          suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
            builder: (context, child) => Theme(
              data: ThemeData.dark(),
              child: child!,
            ),
          );
          if (picked != null) {
            controller.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          }
        },
        validator: requerido
            ? (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null
            : null,
      ),
    );
  }

  Widget _buildTimeField(
    String id,
    String label,
    String placeholder,
    bool requerido,
  ) {
    final controller = _controllers[id] ?? TextEditingController();
    _controllers[id] = controller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, placeholder).copyWith(
          suffixIcon: const Icon(Icons.access_time, color: Colors.white54),
        ),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) {
            controller.text = picked.format(context);
          }
        },
        validator: requerido
            ? (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null
            : null,
      ),
    );
  }

  Widget _buildSuccess() {
    final mensaje = _config?['mensaje_exito'] ?? '¡Gracias! Tu solicitud fue enviada.';
    final negocioNombre = _resolveNegocioNombre();
    final telefono = (_tarjetaInfo?['telefono_principal'] ?? _negocioInfo?['telefono'] ?? '').toString().trim();
    final whatsapp = (_tarjetaInfo?['whatsapp'] ?? '').toString().trim();
    final email = (_tarjetaInfo?['email'] ?? _negocioInfo?['email'] ?? '').toString().trim();
    final contactos = <Widget>[];

    if (telefono.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.phone_outlined, telefono));
    }
    if (whatsapp.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.chat_bubble_outline, whatsapp));
    }
    if (email.isNotEmpty) {
      contactos.add(_buildContactoLine(Icons.mail_outline, email));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
              const SizedBox(height: 16),
              if (negocioNombre != null && negocioNombre.isNotEmpty) ...[
                Text(
                  negocioNombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (contactos.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...contactos,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveNegocioNombre() {
    final tarjetaNombre = _tarjetaInfo?['nombre_negocio']?.toString().trim();
    if (tarjetaNombre != null && tarjetaNombre.isNotEmpty) return tarjetaNombre;
    final negocioNombre = _negocioInfo?['nombre']?.toString().trim();
    if (negocioNombre != null && negocioNombre.isNotEmpty) return negocioNombre;
    return null;
  }

  Color _resolveAccentColor() {
    final color = _firstNonEmpty([
      _config?['color_header']?.toString(),
      _tarjetaInfo?['color_primario']?.toString(),
      _negocioInfo?['color_primario']?.toString(),
    ]);
    return _parseColor(color ?? '#00D9FF');
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
    }
    return null;
  }

  TextInputType _keyboardForTipo(String tipo) {
    switch (tipo) {
      case 'email':
        return TextInputType.emailAddress;
      case 'tel':
        return TextInputType.phone;
      case 'number':
        return const TextInputType.numberWithOptions(decimal: true);
      default:
        return TextInputType.text;
    }
  }

  InputDecoration _inputDecoration(String label, String placeholder) {
    final accent = _resolveAccentColor();
    return InputDecoration(
      labelText: label,
      hintText: placeholder,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent),
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}

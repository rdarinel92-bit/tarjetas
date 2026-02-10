// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_qr_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// FORMULARIO PÚBLICO DE SOLICITUD DE SERVICIO - CLIMAS
/// Accesible via QR sin necesidad de login
/// Diseño profesional, amigable y eficiente
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasFormularioPublicoScreen extends StatefulWidget {
  final String? negocioId;
  
  const ClimasFormularioPublicoScreen({
    super.key,
    this.negocioId,
  });

  @override
  State<ClimasFormularioPublicoScreen> createState() => _ClimasFormularioPublicoScreenState();
}

class _ClimasFormularioPublicoScreenState extends State<ClimasFormularioPublicoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  bool _enviado = false;
  String? _tokenSeguimiento;
  ClimasConfigFormularioModel? _config;
  List<ClimasCatalogoServicioModel> _servicios = [];
  
  // Controladores de texto
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _cpController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _problemaController = TextEditingController();
  final _notasController = TextEditingController();
  final _metrosController = TextEditingController();
  
  // Valores seleccionados
  String _tipoServicio = 'cotizacion';
  bool _tieneEquipo = false;
  String? _marcaEquipo;
  String? _antiguedadEquipo;
  String? _tipoEspacio;
  int _cantidadEquipos = 1;
  String? _presupuesto;
  String _horarioContacto = 'cualquier_hora';
  String _medioContacto = 'telefono';
  String? _disponibilidadVisita;
  
  // Lista de marcas populares
  final List<String> _marcasPopulares = [
    'Mirage', 'Mabe', 'Carrier', 'LG', 'Samsung', 
    'Whirlpool', 'Midea', 'Hisense', 'York', 'Otra'
  ];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _coloniaController.dispose();
    _ciudadController.dispose();
    _cpController.dispose();
    _referenciaController.dispose();
    _problemaController.dispose();
    _notasController.dispose();
    _metrosController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      // Cargar configuración del formulario
      final configRes = await AppSupabase.client
          .from('climas_config_formulario_qr')
          .select()
          .eq('negocio_id', widget.negocioId ?? '')
          .maybeSingle();
      
      if (configRes != null) {
        _config = ClimasConfigFormularioModel.fromMap(configRes);
      }
      
      // Cargar catálogo de servicios
      final serviciosRes = await AppSupabase.client
          .from('climas_catalogo_servicios_publico')
          .select()
          .eq('activo', true)
          .order('orden');
      
      if (mounted) {
        setState(() {
          _servicios = (serviciosRes as List)
              .map((e) => ClimasCatalogoServicioModel.fromMap(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando config: $e');
    }
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final solicitud = ClimasSolicitudQrModel(
        id: '',
        negocioId: widget.negocioId,
        nombreCompleto: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        direccion: _direccionController.text.trim(),
        colonia: _coloniaController.text.trim().isEmpty ? null : _coloniaController.text.trim(),
        ciudad: _ciudadController.text.trim().isEmpty ? null : _ciudadController.text.trim(),
        codigoPostal: _cpController.text.trim().isEmpty ? null : _cpController.text.trim(),
        referenciaUbicacion: _referenciaController.text.trim().isEmpty ? null : _referenciaController.text.trim(),
        tipoServicio: _tipoServicio,
        tieneEquipoActual: _tieneEquipo,
        marcaEquipoActual: _marcaEquipo,
        antiguedadEquipo: _antiguedadEquipo,
        problemaReportado: _problemaController.text.trim().isEmpty ? null : _problemaController.text.trim(),
        tipoEspacio: _tipoEspacio,
        metrosCuadrados: double.tryParse(_metrosController.text),
        cantidadEquiposDeseados: _cantidadEquipos,
        presupuestoEstimado: _presupuesto,
        horarioContactoPreferido: _horarioContacto,
        medioContactoPreferido: _medioContacto,
        disponibilidadVisita: _disponibilidadVisita,
        notasCliente: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        fuente: 'qr_tarjeta',
      );
      
      final res = await AppSupabase.client
          .from('climas_solicitudes_qr')
          .insert(solicitud.toMapForInsert())
          .select('token_seguimiento')
          .single();
      
      if (mounted) {
        setState(() {
          _enviado = true;
          _tokenSeguimiento = res['token_seguimiento'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _siguientePaso() {
    if (_currentStep < 3) {
      // Validar paso actual antes de avanzar
      if (_currentStep == 0 && (_nombreController.text.isEmpty || _telefonoController.text.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete los campos obligatorios'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_currentStep == 1 && _direccionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La dirección es obligatoria'), backgroundColor: Colors.orange),
        );
        return;
      }
      
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _pasoAnterior() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enviado) {
      return _buildPantallaExito();
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPaso1DatosPersonales(),
                    _buildPaso2Ubicacion(),
                    _buildPaso3Servicio(),
                    _buildPaso4Confirmacion(),
                  ],
                ),
              ),
              _buildBotonesNavegacion(),
            ],
          ),
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
            const Color(0xFF00D9FF).withOpacity(0.2),
            const Color(0xFF8B5CF6).withOpacity(0.2),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.ac_unit, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solicitud de Servicio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _config?.mensajeBienvenida ?? 'Complete el formulario para recibir atención',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final pasos = ['Datos', 'Ubicación', 'Servicio', 'Confirmar'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(pasos.length, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? const LinearGradient(colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)])
                        : null,
                    color: isActive ? null : Colors.grey[800],
                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Center(
                    child: isActive && index < _currentStep
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                if (index < pasos.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: index < _currentStep ? const Color(0xFF00D9FF) : Colors.grey[800],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPaso1DatosPersonales() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('👤 Datos Personales', 'Para poder contactarte'),
          const SizedBox(height: 20),
          _buildCampoTexto(
            controller: _nombreController,
            label: 'Nombre completo',
            icon: Icons.person_outline,
            requerido: true,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _buildCampoTexto(
            controller: _telefonoController,
            label: 'Teléfono / WhatsApp',
            icon: Icons.phone_android,
            requerido: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            hint: '10 dígitos',
          ),
          const SizedBox(height: 16),
          _buildCampoTexto(
            controller: _emailController,
            label: 'Correo electrónico (opcional)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          _buildSeccionTitulo('📞 ¿Cómo prefieres que te contactemos?', ''),
          const SizedBox(height: 12),
          _buildSelectorContacto(),
          const SizedBox(height: 16),
          _buildSelectorHorario(),
        ],
      ),
    );
  }

  Widget _buildPaso2Ubicacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('📍 Ubicación del Servicio', 'Donde realizaremos el trabajo'),
          const SizedBox(height: 20),
          _buildCampoTexto(
            controller: _direccionController,
            label: 'Dirección completa',
            icon: Icons.location_on_outlined,
            requerido: true,
            maxLines: 2,
            hint: 'Calle, número exterior e interior',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCampoTexto(
                  controller: _coloniaController,
                  label: 'Colonia',
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: _buildCampoTexto(
                  controller: _cpController,
                  label: 'C.P.',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCampoTexto(
            controller: _ciudadController,
            label: 'Ciudad / Municipio',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 16),
          _buildCampoTexto(
            controller: _referenciaController,
            label: 'Referencias para llegar',
            icon: Icons.assistant_direction,
            maxLines: 2,
            hint: 'Ej: Casa azul, esquina con farmacia',
          ),
          const SizedBox(height: 24),
          _buildSeccionTitulo('🏠 Tipo de espacio', ''),
          const SizedBox(height: 12),
          _buildSelectorTipoEspacio(),
          if (_tipoEspacio != null) ...[
            const SizedBox(height: 16),
            _buildCampoTexto(
              controller: _metrosController,
              label: 'Metros cuadrados aproximados',
              icon: Icons.square_foot,
              keyboardType: TextInputType.number,
              hint: 'Opcional',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaso3Servicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('🔧 ¿Qué servicio necesitas?', 'Selecciona el tipo de servicio'),
          const SizedBox(height: 16),
          _buildSelectorServicio(),
          const SizedBox(height: 24),
          
          // Si hay servicios en catálogo, mostrarlos
          if (_servicios.isNotEmpty) ...[
            _buildSeccionTitulo('💰 Nuestros Servicios', 'Precios de referencia'),
            const SizedBox(height: 12),
            _buildCatalogoServicios(),
            const SizedBox(height: 24),
          ],
          
          // Preguntar si tiene equipo existente
          _buildSeccionTitulo('❄️ ¿Ya tienes un equipo instalado?', ''),
          const SizedBox(height: 12),
          _buildSelectorTieneEquipo(),
          
          if (_tieneEquipo) ...[
            const SizedBox(height: 16),
            _buildSelectorMarca(),
            const SizedBox(height: 16),
            _buildSelectorAntiguedad(),
            const SizedBox(height: 16),
            _buildCampoTexto(
              controller: _problemaController,
              label: 'Describe el problema',
              icon: Icons.report_problem_outlined,
              maxLines: 3,
              hint: 'Ej: No enfría, hace ruido, gotea agua...',
            ),
          ],
          
          if (!_tieneEquipo && _tipoServicio == 'instalacion') ...[
            const SizedBox(height: 16),
            _buildSelectorCantidadEquipos(),
            const SizedBox(height: 16),
            _buildSelectorPresupuesto(),
          ],
          
          const SizedBox(height: 24),
          _buildSeccionTitulo('📅 Disponibilidad para visita', ''),
          const SizedBox(height: 12),
          _buildSelectorDisponibilidad(),
        ],
      ),
    );
  }

  Widget _buildPaso4Confirmacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitulo('✅ Confirma tu solicitud', 'Revisa que los datos sean correctos'),
          const SizedBox(height: 20),
          _buildResumenCard(),
          const SizedBox(height: 20),
          _buildCampoTexto(
            controller: _notasController,
            label: 'Notas adicionales (opcional)',
            icon: Icons.note_add_outlined,
            maxLines: 3,
            hint: 'Información extra que quieras compartir',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tus datos están protegidos y solo serán usados para brindarte el servicio.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumenItem('👤 Nombre', _nombreController.text),
          _buildResumenItem('📱 Teléfono', _telefonoController.text),
          if (_emailController.text.isNotEmpty)
            _buildResumenItem('📧 Email', _emailController.text),
          const Divider(color: Colors.white24, height: 24),
          _buildResumenItem('📍 Dirección', _direccionController.text),
          if (_coloniaController.text.isNotEmpty)
            _buildResumenItem('🏘️ Colonia', _coloniaController.text),
          const Divider(color: Colors.white24, height: 24),
          _buildResumenItem('🔧 Servicio', _getTipoServicioDisplay()),
          if (_tieneEquipo)
            _buildResumenItem('❄️ Equipo', '${_marcaEquipo ?? "N/A"} - ${_getAntiguedadDisplay()}'),
          if (!_tieneEquipo && _cantidadEquipos > 1)
            _buildResumenItem('📦 Cantidad', '$_cantidadEquipos equipos'),
          _buildResumenItem('📞 Contacto', _getMedioContactoDisplay()),
          _buildResumenItem('🕐 Horario', _getHorarioDisplay()),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesNavegacion() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pasoAnterior,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: _currentStep < 3
                ? ElevatedButton.icon(
                    onPressed: _siguientePaso,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isLoading ? null : _enviarSolicitud,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Enviando...' : 'Enviar Solicitud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantallaExito() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.3),
                        const Color(0xFF10B981).withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 80),
                ),
                const SizedBox(height: 32),
                const Text(
                  '¡Solicitud Enviada!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hemos recibido tu solicitud. Nos pondremos en contacto contigo muy pronto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                if (_tokenSeguimiento != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long, color: Color(0xFF00D9FF), size: 32),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu código de seguimiento:',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _tokenSeguimiento!,
                          style: const TextStyle(
                            color: Color(0xFF00D9FF),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Guarda este código para consultar el estado de tu solicitud',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _tokenSeguimiento ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D9FF),
                          side: const BorderSide(color: Color(0xFF00D9FF)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.home),
                        label: const Text('Cerrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS HELPER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccionTitulo(String titulo, String subtitulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitulo.isNotEmpty)
          Text(
            subtitulo,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requerido = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: requerido ? '$label *' : label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: const Color(0xFF00D9FF)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: requerido
          ? (value) => value == null || value.isEmpty ? 'Campo requerido' : null
          : null,
    );
  }

  Widget _buildSelectorServicio() {
    final servicios = [
      {'value': 'cotizacion', 'label': 'Cotización', 'icon': Icons.request_quote, 'color': const Color(0xFF00D9FF)},
      {'value': 'instalacion', 'label': 'Instalación', 'icon': Icons.build, 'color': const Color(0xFF10B981)},
      {'value': 'mantenimiento', 'label': 'Mantenimiento', 'icon': Icons.handyman, 'color': const Color(0xFFFBBF24)},
      {'value': 'reparacion', 'label': 'Reparación', 'icon': Icons.construction, 'color': const Color(0xFFEF4444)},
      {'value': 'emergencia', 'label': 'Emergencia 24h', 'icon': Icons.emergency, 'color': const Color(0xFFEF4444)},
    ];
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: servicios.map((s) {
        final isSelected = _tipoServicio == s['value'];
        return GestureDetector(
          onTap: () => setState(() => _tipoServicio = s['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? (s['color'] as Color).withOpacity(0.2) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? s['color'] as Color : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
                const SizedBox(width: 8),
                Text(
                  s['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectorContacto() {
    final opciones = [
      {'value': 'telefono', 'label': 'Llamada', 'icon': Icons.phone},
      {'value': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.chat},
      {'value': 'email', 'label': 'Email', 'icon': Icons.email},
    ];
    
    return Row(
      children: opciones.map((o) {
        final isSelected = _medioContacto == o['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _medioContacto = o['value'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00D9FF).withOpacity(0.2) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(o['icon'] as IconData, color: isSelected ? const Color(0xFF00D9FF) : Colors.white54),
                  const SizedBox(height: 4),
                  Text(
                    o['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectorHorario() {
    final opciones = [
      {'value': 'manana', 'label': '🌅 Mañana (8-12)'},
      {'value': 'tarde', 'label': '☀️ Tarde (12-18)'},
      {'value': 'cualquier_hora', 'label': '🕐 Cualquier hora'},
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((o) {
        final isSelected = _horarioContacto == o['value'];
        return ChoiceChip(
          label: Text(o['label'] as String),
          selected: isSelected,
          onSelected: (_) => setState(() => _horarioContacto = o['value'] as String),
          backgroundColor: const Color(0xFF1A1A2E),
          selectedColor: const Color(0xFF8B5CF6).withOpacity(0.3),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectorTipoEspacio() {
    final opciones = [
      {'value': 'recamara', 'label': '🛏️ Recámara'},
      {'value': 'sala', 'label': '🛋️ Sala'},
      {'value': 'oficina', 'label': '💼 Oficina'},
      {'value': 'local_comercial', 'label': '🏪 Local'},
      {'value': 'bodega', 'label': '🏭 Bodega'},
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((o) {
        final isSelected = _tipoEspacio == o['value'];
        return ChoiceChip(
          label: Text(o['label'] as String),
          selected: isSelected,
          onSelected: (_) => setState(() => _tipoEspacio = isSelected ? null : o['value'] as String),
          backgroundColor: const Color(0xFF1A1A2E),
          selectedColor: const Color(0xFF00D9FF).withOpacity(0.3),
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
          side: BorderSide(
            color: isSelected ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectorTieneEquipo() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tieneEquipo = true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _tieneEquipo ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _tieneEquipo ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: _tieneEquipo ? const Color(0xFF10B981) : Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Text('Sí, tengo equipo', style: TextStyle(color: _tieneEquipo ? Colors.white : Colors.white54)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tieneEquipo = false),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !_tieneEquipo ? const Color(0xFF00D9FF).withOpacity(0.2) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_tieneEquipo ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline, color: !_tieneEquipo ? const Color(0xFF00D9FF) : Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Text('No, necesito uno', style: TextStyle(color: !_tieneEquipo ? Colors.white : Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorMarca() {
    return DropdownButtonFormField<String>(
      value: _marcaEquipo,
      decoration: InputDecoration(
        labelText: 'Marca del equipo',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: const Icon(Icons.branding_watermark, color: Color(0xFF00D9FF)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: const Color(0xFF1A1A2E),
      style: const TextStyle(color: Colors.white),
      items: _marcasPopulares.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
      onChanged: (v) => setState(() => _marcaEquipo = v),
    );
  }

  Widget _buildSelectorAntiguedad() {
    final opciones = [
      {'value': 'menos_1_año', 'label': 'Menos de 1 año'},
      {'value': '1_3_años', 'label': '1-3 años'},
      {'value': '3_5_años', 'label': '3-5 años'},
      {'value': 'mas_5_años', 'label': 'Más de 5 años'},
    ];
    
    return DropdownButtonFormField<String>(
      value: _antiguedadEquipo,
      decoration: InputDecoration(
        labelText: 'Antigüedad del equipo',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF00D9FF)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: const Color(0xFF1A1A2E),
      style: const TextStyle(color: Colors.white),
      items: opciones.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))).toList(),
      onChanged: (v) => setState(() => _antiguedadEquipo = v),
    );
  }

  Widget _buildSelectorCantidadEquipos() {
    return Row(
      children: [
        const Icon(Icons.ac_unit, color: Color(0xFF00D9FF)),
        const SizedBox(width: 12),
        const Text('Cantidad de equipos:', style: TextStyle(color: Colors.white70)),
        const Spacer(),
        IconButton(
          onPressed: _cantidadEquipos > 1 ? () => setState(() => _cantidadEquipos--) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.white54,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$_cantidadEquipos', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          onPressed: _cantidadEquipos < 10 ? () => setState(() => _cantidadEquipos++) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: const Color(0xFF00D9FF),
        ),
      ],
    );
  }

  Widget _buildSelectorPresupuesto() {
    final opciones = [
      {'value': 'bajo', 'label': '💰 Económico', 'desc': 'Hasta \$10,000'},
      {'value': 'medio', 'label': '💰💰 Medio', 'desc': '\$10,000 - \$25,000'},
      {'value': 'alto', 'label': '💰💰💰 Premium', 'desc': '\$25,000+'},
      {'value': 'sin_limite', 'label': '✨ Sin límite', 'desc': 'Lo mejor'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Presupuesto estimado:', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opciones.map((o) {
            final isSelected = _presupuesto == o['value'];
            return GestureDetector(
              onTap: () => setState(() => _presupuesto = o['value']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.2) : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(o['label']!, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13)),
                    Text(o['desc']!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectorDisponibilidad() {
    final opciones = [
      {'value': 'lo_antes_posible', 'label': '🚀 Lo antes posible'},
      {'value': 'esta_semana', 'label': '📅 Esta semana'},
      {'value': 'proxima_semana', 'label': '📆 Próxima semana'},
      {'value': 'solo_fines_semana', 'label': '🗓️ Solo fines de semana'},
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((o) {
        final isSelected = _disponibilidadVisita == o['value'];
        return ChoiceChip(
          label: Text(o['label']!),
          selected: isSelected,
          onSelected: (_) => setState(() => _disponibilidadVisita = o['value']),
          backgroundColor: const Color(0xFF1A1A2E),
          selectedColor: const Color(0xFF10B981).withOpacity(0.3),
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13),
          side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1)),
        );
      }).toList(),
    );
  }

  Widget _buildCatalogoServicios() {
    return Column(
      children: _servicios.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: s.enPromocion
                ? Border.all(color: const Color(0xFFFBBF24))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForService(s.icono),
                  color: const Color(0xFF00D9FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.nombre,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (s.enPromocion) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PROMO',
                              style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (s.descripcion != null)
                      Text(
                        s.descripcion!,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (s.mostrarPrecio)
                    Text(
                      s.rangoPrecio,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (s.tiempoEstimado != null)
                    Text(
                      s.tiempoEstimado!,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForService(String? iconName) {
    switch (iconName) {
      case 'ac_unit': return Icons.ac_unit;
      case 'build': return Icons.build;
      case 'handyman': return Icons.handyman;
      case 'propane_tank': return Icons.propane_tank;
      case 'emergency': return Icons.emergency;
      default: return Icons.miscellaneous_services;
    }
  }

  // Helpers para mostrar valores
  String _getTipoServicioDisplay() {
    switch (_tipoServicio) {
      case 'cotizacion': return 'Cotización';
      case 'instalacion': return 'Instalación';
      case 'mantenimiento': return 'Mantenimiento';
      case 'reparacion': return 'Reparación';
      case 'emergencia': return 'Emergencia 24h';
      default: return _tipoServicio;
    }
  }

  String _getAntiguedadDisplay() {
    switch (_antiguedadEquipo) {
      case 'menos_1_año': return 'Menos de 1 año';
      case '1_3_años': return '1-3 años';
      case '3_5_años': return '3-5 años';
      case 'mas_5_años': return 'Más de 5 años';
      default: return _antiguedadEquipo ?? '';
    }
  }

  String _getMedioContactoDisplay() {
    switch (_medioContacto) {
      case 'telefono': return 'Llamada telefónica';
      case 'whatsapp': return 'WhatsApp';
      case 'email': return 'Correo electrónico';
      default: return _medioContacto;
    }
  }

  String _getHorarioDisplay() {
    switch (_horarioContacto) {
      case 'manana': return 'Mañana (8-12)';
      case 'tarde': return 'Tarde (12-18)';
      case 'cualquier_hora': return 'Cualquier hora';
      default: return _horarioContacto;
    }
  }
}

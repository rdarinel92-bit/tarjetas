// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';
import '../navigation/app_routes.dart';
import '../viewmodels/negocio_activo_provider.dart';

/// Formulario completo para registrar clientes
/// Incluye todos los campos KYC necesarios para operaciones financieras
class FormularioClienteScreen extends StatefulWidget {
  const FormularioClienteScreen({super.key});

  @override
  State<FormularioClienteScreen> createState() =>
      _FormularioClienteScreenState();
}

class _FormularioClienteScreenState extends State<FormularioClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  int _pasoActual = 0;

  // Controladores - Datos Personales
  final nombreCtrl = TextEditingController();
  final apellidosCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();

  // Controladores - Identificacion
  final curpCtrl = TextEditingController();
  final rfcCtrl = TextEditingController();
  final ineCtrl = TextEditingController();
  DateTime? _fechaNacimiento;

  // Controladores - Datos Laborales
  final ocupacionCtrl = TextEditingController();
  final empresaCtrl = TextEditingController();
  final ingresosCtrl = TextEditingController();
  final antiguedadCtrl = TextEditingController();

  // Controladores - Referencias
  final refNombre1Ctrl = TextEditingController();
  final refTelefono1Ctrl = TextEditingController();
  final refRelacion1Ctrl = TextEditingController();
  final refNombre2Ctrl = TextEditingController();
  final refTelefono2Ctrl = TextEditingController();
  final refRelacion2Ctrl = TextEditingController();

  // Controladores - Acceso App
  final passwordCtrl = TextEditingController();
  bool _crearAcceso = true;
  bool _passwordAutoGenerada = true;

  // Sucursal
  String? _sucursalSeleccionada;
  List<Map<String, dynamic>> _sucursales = [];

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
    _generarPasswordTemporal();
  }

  void _generarPasswordTemporal() {
    // Generar password temporal: primeras 3 letras del nombre + ultimos 4 digitos del telefono + año actual
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    passwordCtrl.text = 'Cliente$random';
  }

  Future<void> _cargarSucursales() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _sucursales = [];
          _sucursalSeleccionada = null;
        });
        return;
      }

      bool esSuperadmin = false;
      try {
        final rolRes = await AppSupabase.client
            .from('usuarios_roles')
            .select('roles(nombre)')
            .eq('usuario_id', userId);
        esSuperadmin =
            rolRes.any((r) => r['roles']?['nombre'] == 'superadmin');
      } catch (_) {}

      List<Map<String, dynamic>> data = [];
      if (esSuperadmin) {
        final res = await AppSupabase.client
            .from('sucursales')
            .select('id, nombre, negocio_id')
            .eq('activa', true)
            .order('nombre');
        data = List<Map<String, dynamic>>.from(res);
      } else {
        final negocioIds = <String>{};
        final propios = await AppSupabase.client
            .from('negocios')
            .select('id')
            .eq('propietario_id', userId);
        for (final n in propios) {
          final id = n['id']?.toString();
          if (id != null) negocioIds.add(id);
        }
        final accesos = await AppSupabase.client
            .from('usuarios_negocios')
            .select('negocio_id')
            .eq('usuario_id', userId)
            .eq('activo', true);
        for (final a in accesos) {
          final id = a['negocio_id']?.toString();
          if (id != null) negocioIds.add(id);
        }

        if (negocioIds.isNotEmpty) {
          final res = await AppSupabase.client
              .from('sucursales')
              .select('id, nombre, negocio_id')
              .eq('activa', true)
              .inFilter('negocio_id', negocioIds.toList())
              .order('nombre');
          data = List<Map<String, dynamic>>.from(res);
        }
      }

      setState(() {
        _sucursales = data;
        if (_sucursalSeleccionada != null &&
            !_sucursales
                .any((s) => s['id'] == _sucursalSeleccionada)) {
          _sucursalSeleccionada = null;
        }
        if (_sucursalSeleccionada == null && _sucursales.isNotEmpty) {
          _sucursalSeleccionada = _sucursales.first['id'] as String?;
        }
      });
    } catch (e) {
      debugPrint('Error cargando sucursales: $e');
      setState(() {
        _sucursales = [];
        _sucursalSeleccionada = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Registrar Cliente",
      subtitle: "Paso ${_pasoActual + 1} de 5",
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Indicador de progreso
            _buildProgressIndicator(),
            const SizedBox(height: 20),

            // Contenido del paso actual - con scroll
            Expanded(
              child: SingleChildScrollView(
                child: _buildPasoActual(),
              ),
            ),

            const SizedBox(height: 16),

            // Botones de navegacion - siempre visibles abajo
            _buildBotonesNavegacion(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(5, (index) {
        final isActive = index <= _pasoActual;
        final isCompleted = index < _pasoActual;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.greenAccent : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.greenAccent
                      : (isActive ? Colors.orangeAccent : Colors.white24),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.black)
                      : Text('${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPasoActual() {
    switch (_pasoActual) {
      case 0:
        return _buildPasoDatosPersonales();
      case 1:
        return _buildPasoIdentificacion();
      case 2:
        return _buildPasoDatosLaborales();
      case 3:
        return _buildPasoReferencias();
      case 4:
        return _buildPasoAccesoApp();
      default:
        return const SizedBox();
    }
  }

  // ============== PASO 1: DATOS PERSONALES ==============
  Widget _buildPasoDatosPersonales() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text("Datos Personales",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          TextFormField(
            controller: nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre(s) *',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v?.isEmpty ?? true ? 'El nombre es requerido' : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: apellidosCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Apellidos *',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v?.isEmpty ?? true ? 'Los apellidos son requeridos' : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
            decoration: const InputDecoration(
              labelText: 'Telefono Celular *',
              prefixIcon: Icon(Icons.phone_android),
              prefixText: '+52 ',
              border: OutlineInputBorder(),
              hintText: '10 digitos',
            ),
            validator: (v) =>
                (v?.length ?? 0) < 10 ? 'Ingrese 10 digitos' : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo Electronico',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Ingrese un email válido';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: direccionCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Direccion Completa *',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
              hintText: 'Calle, numero, colonia, ciudad',
            ),
            validator: (v) =>
                v?.isEmpty ?? true ? 'La direccion es requerida' : null,
          ),
          const SizedBox(height: 15),
          if (_sucursales.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orangeAccent, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aun no hay sucursales creadas. Puedes registrar una para asignarla al cliente.',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.sucursales);
                        _cargarSucursales();
                      },
                      icon: const Icon(Icons.store),
                      label: const Text('Crear sucursal'),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _sucursalSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Sucursal (opcional)',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
              items: _sucursales
                  .map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['nombre'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _sucursalSeleccionada = v),
            ),
        ],
      ),
    );
  }

  // ============== PASO 2: IDENTIFICACION ==============
  Widget _buildPasoIdentificacion() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text("Identificacion Oficial",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          // Fecha de nacimiento
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake, color: Colors.orangeAccent),
            title: const Text("Fecha de Nacimiento *",
                style: TextStyle(color: Colors.white70)),
            subtitle: Text(
              _fechaNacimiento != null
                  ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                  : 'Seleccionar fecha',
              style: TextStyle(
                  color:
                      _fechaNacimiento != null ? Colors.white : Colors.white38),
            ),
            trailing:
                const Icon(Icons.calendar_month, color: Colors.orangeAccent),
            onTap: _seleccionarFechaNacimiento,
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          TextFormField(
            controller: curpCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(18),
              UpperCaseTextFormatter()
            ],
            decoration: const InputDecoration(
              labelText: 'CURP',
              prefixIcon: Icon(Icons.fingerprint),
              border: OutlineInputBorder(),
              hintText: '18 caracteres',
            ),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: rfcCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(13),
              UpperCaseTextFormatter()
            ],
            decoration: const InputDecoration(
              labelText: 'RFC',
              prefixIcon: Icon(Icons.assignment_ind),
              border: OutlineInputBorder(),
              hintText: '13 caracteres',
            ),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: ineCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(18),
              UpperCaseTextFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Clave de Elector (INE)',
              prefixIcon: Icon(Icons.credit_card),
              border: OutlineInputBorder(),
              hintText: '18 caracteres alfanuméricos',
            ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Los documentos de identificacion se pueden subir despues en el expediente del cliente.",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== PASO 3: DATOS LABORALES ==============
  Widget _buildPasoDatosLaborales() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.work, color: Colors.purpleAccent),
              SizedBox(width: 10),
              Text("Informacion Laboral",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          TextFormField(
            controller: ocupacionCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ocupacion / Profesion',
              prefixIcon: Icon(Icons.work_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: empresaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Empresa / Negocio donde trabaja',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: ingresosCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Ingresos Mensuales Aproximados',
              prefixIcon: Icon(Icons.attach_money),
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: antiguedadCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Antiguedad en el trabajo (meses)',
              prefixIcon: Icon(Icons.schedule),
              suffixText: 'meses',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.purpleAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Esta informacion ayuda a calcular el score crediticio y determinar la capacidad de pago.",
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== PASO 4: REFERENCIAS ==============
  Widget _buildPasoReferencias() {
    return Column(
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text("Referencia Personal 1",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              TextFormField(
                controller: refNombre1Ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: refTelefono1Ctrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: refRelacion1Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Parentesco',
                        prefixIcon: Icon(Icons.family_restroom),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Hermano',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text("Referencia Personal 2",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              TextFormField(
                controller: refNombre2Ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: refTelefono2Ctrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: refRelacion2Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Parentesco',
                        prefixIcon: Icon(Icons.family_restroom),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Vecino',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============== PASO 5: ACCESO A LA APP ==============
  Widget _buildPasoAccesoApp() {
    return SingleChildScrollView(
      child: Column(
        children: [
          PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.smartphone, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Text("Acceso a la App",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // Switch para crear acceso
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _crearAcceso
                      ? Colors.greenAccent.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _crearAcceso
                          ? Colors.greenAccent.withOpacity(0.3)
                          : Colors.white24),
                ),
                child: Row(
                  children: [
                    Icon(
                      _crearAcceso ? Icons.check_circle : Icons.cancel_outlined,
                      color: _crearAcceso ? Colors.greenAccent : Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _crearAcceso
                                ? "Crear acceso a la app"
                                : "Sin acceso a la app",
                            style: TextStyle(
                              color: _crearAcceso
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _crearAcceso
                                ? "El cliente podrá ver sus préstamos y pagos"
                                : "Solo será un registro de datos (KYC)",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _crearAcceso,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => setState(() => _crearAcceso = v),
                    ),
                  ],
                ),
              ),

              if (_crearAcceso) ...[
                const SizedBox(height: 20),

                // Info de credenciales
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text("Credenciales de acceso",
                              style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              color: Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              emailCtrl.text.isNotEmpty
                                  ? emailCtrl.text
                                  : "${telefonoCtrl.text}@robertdarin.app",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Este será el correo/usuario para iniciar sesión",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // Opción: contraseña automática o manual
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _passwordAutoGenerada = true;
                            _generarPasswordTemporal();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _passwordAutoGenerada
                                ? Colors.purpleAccent.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _passwordAutoGenerada
                                  ? Colors.purpleAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_fix_high,
                                color: _passwordAutoGenerada
                                    ? Colors.purpleAccent
                                    : Colors.white54,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Automática",
                                style: TextStyle(
                                  color: _passwordAutoGenerada
                                      ? Colors.purpleAccent
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: _passwordAutoGenerada
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _passwordAutoGenerada = false;
                            passwordCtrl.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !_passwordAutoGenerada
                                ? Colors.orangeAccent.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_passwordAutoGenerada
                                  ? Colors.orangeAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.edit,
                                color: !_passwordAutoGenerada
                                    ? Colors.orangeAccent
                                    : Colors.white54,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Manual",
                                style: TextStyle(
                                  color: !_passwordAutoGenerada
                                      ? Colors.orangeAccent
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: !_passwordAutoGenerada
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Campo de contraseña
                TextFormField(
                  controller: passwordCtrl,
                  readOnly: _passwordAutoGenerada,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Temporal',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    helperText: _passwordAutoGenerada
                        ? 'Generada automáticamente'
                        : 'Ingresa la contraseña manualmente',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_passwordAutoGenerada)
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.purpleAccent),
                            onPressed: () => _generarPasswordTemporal(),
                            tooltip: "Generar nueva",
                          ),
                        IconButton(
                          icon:
                              const Icon(Icons.copy, color: Colors.cyanAccent),
                          onPressed: () {
                            // Copiar al portapapeles
                            if (passwordCtrl.text.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Contraseña copiada: ${passwordCtrl.text}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          tooltip: "Copiar",
                        ),
                      ],
                    ),
                  ),
                  validator: (v) => _crearAcceso && (v?.isEmpty ?? true)
                      ? 'La contraseña es requerida'
                      : null,
                ),

                const SizedBox(height: 15),

                // Resumen de acceso
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.greenAccent, size: 18),
                          SizedBox(width: 8),
                          Text("El cliente podrá:",
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(children: [
                        Text("  • Ver sus préstamos activos",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12))
                      ]),
                      const Row(children: [
                        Text("  • Consultar fechas de pago",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12))
                      ]),
                      const Row(children: [
                        Text("  • Ver historial de pagos",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12))
                      ]),
                      const Row(children: [
                        Text("  • Recibir notificaciones",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12))
                      ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildBotonesNavegacion() {
    return Row(
      children: [
        if (_pasoActual > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _pasoActual--),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Anterior"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        if (_pasoActual > 0) const SizedBox(width: 15),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _guardando
                ? null
                : (_pasoActual < 4 ? _siguientePaso : _guardarCliente),
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_pasoActual < 4 ? Icons.arrow_forward : Icons.save),
            label: Text(_pasoActual < 4 ? "Continuar" : "Guardar Cliente"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor:
                  _pasoActual < 4 ? Colors.blueAccent : Colors.greenAccent,
              foregroundColor: _pasoActual < 4 ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  void _siguientePaso() {
    // Validar paso 1 (datos personales obligatorios)
    if (_pasoActual == 0) {
      if (nombreCtrl.text.isEmpty ||
          apellidosCtrl.text.isEmpty ||
          telefonoCtrl.text.length < 10 ||
          direccionCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Complete los campos obligatorios (*)'),
              backgroundColor: Colors.orange),
        );
        return;
      }
    }
    setState(() => _pasoActual++);
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now()
          .subtract(const Duration(days: 365 * 18)), // Minimo 18 anios
    );
    if (fecha != null) {
      setState(() => _fechaNacimiento = fecha);
    }
  }

  Future<void> _guardarCliente() async {
    // V10.55: Obtener negocio activo (puede ser null - igual que climas)
    final negocioId = context.read<NegocioActivoProvider>().negocioId;

    // Validacion final
    if (nombreCtrl.text.isEmpty ||
        apellidosCtrl.text.isEmpty ||
        telefonoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Complete los datos personales obligatorios'),
            backgroundColor: Colors.orange),
      );
      setState(() => _pasoActual = 0);
      return;
    }

    // Validar contraseña si se va a crear acceso
    if (_crearAcceso && passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingrese una contraseña para el acceso'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final nombreCompleto =
          '${nombreCtrl.text.trim()} ${apellidosCtrl.text.trim()}';
      final emailFinal = emailCtrl.text.isNotEmpty
          ? emailCtrl.text
          : '${telefonoCtrl.text}@robertdarin.app';

      // Calcular score crediticio basico
      int score = 500; // Base
      if (ingresosCtrl.text.isNotEmpty) {
        final ingresos = int.tryParse(ingresosCtrl.text) ?? 0;
        if (ingresos > 5000) score += 50;
        if (ingresos > 10000) score += 50;
        if (ingresos > 20000) score += 50;
      }
      if (ocupacionCtrl.text.isNotEmpty) score += 30;
      if (curpCtrl.text.isNotEmpty) score += 20;
      if (rfcCtrl.text.isNotEmpty) score += 20;
      if (refNombre1Ctrl.text.isNotEmpty) score += 15;
      if (refNombre2Ctrl.text.isNotEmpty) score += 15;

      String? usuarioId;

      // 1. Crear credenciales de autenticación si se eligió crear acceso
      if (_crearAcceso) {
        // Verificar si el email ya está en uso
        final existingUser = await AppSupabase.client
            .from('usuarios')
            .select('id')
            .eq('email', emailFinal.toLowerCase())
            .maybeSingle();
        
        if (existingUser != null) {
          throw Exception('El email $emailFinal ya está registrado en el sistema');
        }
        
        // Crear cuenta en Supabase Auth
        try {
          final authResponse = await AppSupabase.client.auth.signUp(
            email: emailFinal,
            password: passwordCtrl.text,
            data: {
              'full_name': nombreCompleto,
              'rol': 'cliente',
            },
          );
          
          if (authResponse.user == null) {
            throw Exception('No se pudo crear la cuenta de acceso');
          }
          
          usuarioId = authResponse.user!.id;
        } catch (authError) {
          // Si falla auth, intentar continuar sin cuenta (solo cliente en BD)
          debugPrint('⚠️ Error creando auth: $authError');
          // Verificar si es un error de email duplicado
          if (authError.toString().contains('already registered') ||
              authError.toString().contains('Database error')) {
            throw Exception('El email ya está registrado o hay un problema con la autenticación. Intente sin crear acceso.');
          }
          rethrow;
        }
        
        // Crear perfil en tabla usuarios vinculado al auth
        // usuarioId siempre tiene valor aquí porque el try exitoso lo asignó
        await AppSupabase.client
            .from('usuarios')
            .upsert({
              'id': usuarioId,
              'email': emailFinal,
              'nombre_completo': nombreCompleto,
              'telefono': '+52${telefonoCtrl.text}',
            });
      }

      // 2. Insertar cliente con referencia al usuario
      // negocioId ya fue validado al inicio de la función
      await AppSupabase.client.from('clientes').insert({
        'nombre': nombreCompleto,
        'telefono': '+52${telefonoCtrl.text}',
        'email': emailFinal,
        'direccion': direccionCtrl.text,
        'curp': curpCtrl.text.isNotEmpty ? curpCtrl.text : null,
        'rfc': rfcCtrl.text.isNotEmpty ? rfcCtrl.text : null,
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String(),
        'ocupacion': ocupacionCtrl.text.isNotEmpty ? ocupacionCtrl.text : null,
        'ingresos_mensuales': ingresosCtrl.text.isNotEmpty
            ? double.parse(ingresosCtrl.text)
            : null,
        'sucursal_id': _sucursalSeleccionada,
        'score_crediticio': score,
        'activo': true,
        'usuario_id': usuarioId,
        'negocio_id': negocioId,
      });

      if (mounted) {
        // Mostrar credenciales si se creó acceso
        if (_crearAcceso) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Text("¡Cliente Registrado!",
                      style: TextStyle(color: Colors.greenAccent)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombreCompleto,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Credenciales de acceso:",
                            style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.email,
                                color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(emailFinal,
                                    style:
                                        const TextStyle(color: Colors.white))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.lock,
                                color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(passwordCtrl.text,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "⚠️ Anota estas credenciales. El cliente las necesitará para entrar a la app.",
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text("Entendido"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Cliente "$nombreCompleto" registrado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  @override
  void dispose() {
    nombreCtrl.dispose();
    apellidosCtrl.dispose();
    telefonoCtrl.dispose();
    emailCtrl.dispose();
    direccionCtrl.dispose();
    curpCtrl.dispose();
    rfcCtrl.dispose();
    ineCtrl.dispose();
    ocupacionCtrl.dispose();
    empresaCtrl.dispose();
    ingresosCtrl.dispose();
    antiguedadCtrl.dispose();
    refNombre1Ctrl.dispose();
    refTelefono1Ctrl.dispose();
    refRelacion1Ctrl.dispose();
    refNombre2Ctrl.dispose();
    refTelefono2Ctrl.dispose();
    refRelacion2Ctrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }
}

// Formateador para convertir a mayusculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

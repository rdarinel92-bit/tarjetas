// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// Panel Central de APIs y Servicios Externos
/// Permite configurar todas las integraciones desde el panel sin tocar código
class ConfiguracionApisScreen extends StatefulWidget {
  const ConfiguracionApisScreen({super.key});

  @override
  State<ConfiguracionApisScreen> createState() => _ConfiguracionApisScreenState();
}

class _ConfiguracionApisScreenState extends State<ConfiguracionApisScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _servicios = [];
  
  // Controllers organizados por servicio -> campo -> controller
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  // Lista de servicios disponibles para configurar
  final List<ServicioApi> _serviciosDisponibles = [
    ServicioApi(
      id: 'stripe',
      nombre: 'Stripe',
      descripcion: 'Pagos y tarjetas digitales',
      icono: Icons.credit_card,
      color: Colors.purpleAccent,
      categoria: 'Pagos',
      campos: [
        CampoApi('publishable_key', 'Publishable Key', 'pk_...', false),
        CampoApi('secret_key', 'Secret Key', 'sk_...', true),
        CampoApi('webhook_secret', 'Webhook Secret', 'whsec_...', true),
      ],
    ),
    ServicioApi(
      id: 'twilio',
      nombre: 'Twilio',
      descripcion: 'SMS y WhatsApp',
      icono: Icons.sms,
      color: Colors.redAccent,
      categoria: 'Comunicación',
      campos: [
        CampoApi('account_sid', 'Account SID', 'AC...', false),
        CampoApi('auth_token', 'Auth Token', '', true),
        CampoApi('phone_number', 'Número de Teléfono', '+521...', false),
      ],
    ),
    ServicioApi(
      id: 'firebase',
      nombre: 'Firebase',
      descripcion: 'Push notifications',
      icono: Icons.notifications,
      color: Colors.orangeAccent,
      categoria: 'Comunicación',
      campos: [
        CampoApi('project_id', 'Project ID', '', false),
        CampoApi('server_key', 'Server Key', '', true),
      ],
    ),
    ServicioApi(
      id: 'google_maps',
      nombre: 'Google Maps',
      descripcion: 'Mapas y geolocalización',
      icono: Icons.map,
      color: Colors.greenAccent,
      categoria: 'Ubicación',
      campos: [
        CampoApi('api_key', 'API Key', '', true),
      ],
    ),
    ServicioApi(
      id: 'buro_credito',
      nombre: 'Buró de Crédito',
      descripcion: 'Consulta historial crediticio',
      icono: Icons.assessment,
      color: Colors.blueAccent,
      categoria: 'Verificación',
      campos: [
        CampoApi('usuario', 'Usuario', '', false),
        CampoApi('password', 'Contraseña', '', true),
        CampoApi('endpoint', 'Endpoint', 'https://...', false),
      ],
    ),
    ServicioApi(
      id: 'ine_validacion',
      nombre: 'Validación INE',
      descripcion: 'Verificación de identidad',
      icono: Icons.badge,
      color: Colors.tealAccent,
      categoria: 'Verificación',
      campos: [
        CampoApi('api_key', 'API Key', '', true),
        CampoApi('endpoint', 'Endpoint', '', false),
      ],
    ),
    ServicioApi(
      id: 'facturacion',
      nombre: 'Facturación (CFDI)',
      descripcion: 'Timbrado de facturas',
      icono: Icons.receipt_long,
      color: Colors.amberAccent,
      categoria: 'Fiscal',
      campos: [
        CampoApi('pac_usuario', 'Usuario PAC', '', false),
        CampoApi('pac_password', 'Contraseña PAC', '', true),
        CampoApi('rfc', 'RFC Emisor', '', false),
        CampoApi('certificado', 'Certificado (.cer)', '', false),
        CampoApi('llave_privada', 'Llave Privada (.key)', '', true),
      ],
    ),
    ServicioApi(
      id: 'email',
      nombre: 'Email (SMTP)',
      descripcion: 'Envío de correos',
      icono: Icons.email,
      color: Colors.cyanAccent,
      categoria: 'Comunicación',
      campos: [
        CampoApi('smtp_host', 'Host SMTP', 'smtp.gmail.com', false),
        CampoApi('smtp_port', 'Puerto', '587', false),
        CampoApi('smtp_user', 'Usuario', '', false),
        CampoApi('smtp_password', 'Contraseña', '', true),
      ],
    ),
    ServicioApi(
      id: 'aws_s3',
      nombre: 'AWS S3',
      descripcion: 'Almacenamiento de archivos',
      icono: Icons.cloud_upload,
      color: Colors.orange,
      categoria: 'Almacenamiento',
      campos: [
        CampoApi('access_key', 'Access Key ID', '', false),
        CampoApi('secret_key', 'Secret Access Key', '', true),
        CampoApi('bucket', 'Bucket Name', '', false),
        CampoApi('region', 'Region', 'us-east-1', false),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _inicializarControllers();
    _cargarConfiguraciones();
  }

  @override
  void dispose() {
    // Liberar todos los controllers
    for (var servicioControllers in _controllers.values) {
      for (var controller in servicioControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _inicializarControllers() {
    for (var servicio in _serviciosDisponibles) {
      _controllers[servicio.id] = {};
      for (var campo in servicio.campos) {
        _controllers[servicio.id]![campo.id] = TextEditingController();
      }
    }
  }

  Future<void> _cargarConfiguraciones() async {
    try {
      final res = await AppSupabase.client
          .from('configuracion_apis')
          .select();
      
      _servicios = List<Map<String, dynamic>>.from(res);
      
      // Actualizar controllers con valores de la BD
      for (var config in _servicios) {
        final servicioId = config['servicio'] as String?;
        if (servicioId == null) continue;
        
        // Parsear configuración JSONB
        final configuracion = config['configuracion'];
        Map<String, dynamic> configMap = {};
        if (configuracion != null) {
          if (configuracion is String) {
            configMap = jsonDecode(configuracion);
          } else if (configuracion is Map) {
            configMap = Map<String, dynamic>.from(configuracion);
          }
        }
        
        // También cargar campos directos de la tabla
        configMap['api_key'] = config['api_key'] ?? '';
        configMap['publishable_key'] = config['publishable_key'] ?? '';
        configMap['secret_key'] = config['secret_key'] ?? '';
        configMap['webhook_secret'] = config['webhook_secret'] ?? '';
        
        // Actualizar controllers
        if (_controllers.containsKey(servicioId)) {
          for (var entry in configMap.entries) {
            if (_controllers[servicioId]!.containsKey(entry.key)) {
              final valor = entry.value?.toString() ?? '';
              _controllers[servicioId]![entry.key]!.text = valor;
            }
          }
        }
      }
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando APIs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _obtenerConfigServicio(String servicioId) {
    return _servicios.firstWhere(
      (s) => s['servicio'] == servicioId,
      orElse: () => <String, dynamic>{},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar servicios por categoría
    final categorias = <String, List<ServicioApi>>{};
    for (var servicio in _serviciosDisponibles) {
      categorias.putIfAbsent(servicio.categoria, () => []).add(servicio);
    }

    return PremiumScaffold(
      title: "Configuración de APIs",
      subtitle: "Integraciones y servicios externos",
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarConfiguraciones,
              child: ListView(
                children: [
                  // Aviso importante
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blueAccent),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'Configura tus servicios externos aquí. Los cambios se aplican inmediatamente.',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Servicios por categoría
                  ...categorias.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ...entry.value.map((servicio) => _buildServicioCard(servicio)),
                      const SizedBox(height: 15),
                    ],
                  )),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildServicioCard(ServicioApi servicio) {
    final config = _obtenerConfigServicio(servicio.id);
    final activo = config?['activo'] ?? false;
    final modoTest = config?['modo_test'] ?? true;
    final configurado = config != null && config.isNotEmpty;

    return PremiumCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: servicio.color.withOpacity(activo ? 0.3 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(servicio.icono, color: activo ? servicio.color : Colors.white38),
        ),
        title: Row(
          children: [
            Text(servicio.nombre, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            if (configurado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activo 
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.orangeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  activo ? 'ACTIVO' : 'CONFIGURADO',
                  style: TextStyle(
                    color: activo ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (modoTest && activo) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TEST',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(servicio.descripcion, 
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Switch(
          value: activo,
          onChanged: configurado ? (v) => _toggleServicio(servicio.id, v) : null,
          activeColor: servicio.color,
        ),
        children: [
          // Switch modo test/producción
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: modoTest 
                  ? Colors.yellowAccent.withOpacity(0.1)
                  : Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: modoTest 
                    ? Colors.yellowAccent.withOpacity(0.3)
                    : Colors.greenAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  modoTest ? Icons.science : Icons.verified,
                  color: modoTest ? Colors.yellowAccent : Colors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modoTest ? 'Modo Pruebas (Sandbox)' : 'Modo Producción',
                        style: TextStyle(
                          color: modoTest ? Colors.yellowAccent : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        modoTest 
                            ? 'Los datos no son reales' 
                            : '¡Cuidado! Transacciones reales',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: !modoTest,
                  onChanged: (v) => _toggleModoTest(servicio.id, !v),
                  activeColor: Colors.greenAccent,
                  inactiveThumbColor: Colors.yellowAccent,
                ),
              ],
            ),
          ),
          
          // Campos de configuración
          ...servicio.campos.map((campo) => _buildCampoConfig(servicio.id, campo)),
          
          const SizedBox(height: 15),
          
          // Botón guardar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _guardarConfiguracion(servicio),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: servicio.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _probarConexion(servicio),
                icon: const Icon(Icons.wifi_tethering),
                tooltip: 'Probar conexión',
                color: Colors.white54,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoConfig(String servicioId, CampoApi campo) {
    final controller = _controllers[servicioId]?[campo.id];
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: campo.esSecreto,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: campo.nombre,
          labelStyle: const TextStyle(color: Colors.white54),
          hintText: campo.placeholder,
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: Icon(
            campo.esSecreto ? Icons.lock : Icons.edit,
            color: Colors.white38,
            size: 18,
          ),
          suffixIcon: campo.esSecreto 
              ? IconButton(
                  icon: const Icon(Icons.visibility_off, color: Colors.white38, size: 18),
                  onPressed: () {},
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.orangeAccent),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _toggleServicio(String servicioId, bool activo) async {
    try {
      await AppSupabase.client.from('configuracion_apis').upsert({
        'servicio': servicioId,
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'servicio');

      await _cargarConfiguraciones();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activo ? 'Servicio activado' : 'Servicio desactivado'),
            backgroundColor: activo ? Colors.greenAccent : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleModoTest(String servicioId, bool modoTest) async {
    try {
      await AppSupabase.client.from('configuracion_apis').upsert({
        'servicio': servicioId,
        'modo_test': modoTest,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'servicio');

      await _cargarConfiguraciones();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(modoTest ? 'Modo pruebas activado' : '¡Modo producción activado!'),
            backgroundColor: modoTest ? Colors.yellowAccent : Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _guardarConfiguracion(ServicioApi servicio) async {
    // Validar campos requeridos
    final camposVacios = <String>[];
    for (var campo in servicio.campos) {
      final controller = _controllers[servicio.id]?[campo.id];
      if (controller == null || controller.text.trim().isEmpty) {
        camposVacios.add(campo.nombre);
      }
    }

    if (camposVacios.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campos vacíos: ${camposVacios.join(", ")}'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    try {
      // Recopilar valores de los controllers
      final Map<String, dynamic> configuracionJsonb = {};
      final Map<String, dynamic> camposDirectos = {};
      
      // Campos que van directo en la tabla
      const camposTabla = ['api_key', 'publishable_key', 'secret_key', 'webhook_secret'];
      
      for (var campo in servicio.campos) {
        final valor = _controllers[servicio.id]?[campo.id]?.text.trim() ?? '';
        if (camposTabla.contains(campo.id)) {
          camposDirectos[campo.id] = valor;
        } else {
          configuracionJsonb[campo.id] = valor;
        }
      }

      final configActual = _obtenerConfigServicio(servicio.id);
      
      // Construir objeto para guardar
      final dataToSave = <String, dynamic>{
        'servicio': servicio.id,
        'updated_at': DateTime.now().toIso8601String(),
        ...camposDirectos,
      };
      
      // Combinar configuración JSONB existente con nueva
      Map<String, dynamic> configExistente = {};
      if (configActual?['configuracion'] != null) {
        final conf = configActual!['configuracion'];
        if (conf is String) {
          configExistente = jsonDecode(conf);
        } else if (conf is Map) {
          configExistente = Map<String, dynamic>.from(conf);
        }
      }
      configExistente.addAll(configuracionJsonb);
      dataToSave['configuracion'] = configExistente;

      await AppSupabase.client.from('configuracion_apis').upsert(
        dataToSave,
        onConflict: 'servicio',
      );

      await _cargarConfiguraciones();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada'),
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _probarConexion(ServicioApi servicio) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Probando conexión con ${servicio.nombre}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // TODO: Implementar prueba de conexión real por cada servicio
    await Future.delayed(const Duration(seconds: 2));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Conexión exitosa'),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }
}

// === CLASES DE DATOS ===

class ServicioApi {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String categoria;
  final List<CampoApi> campos;

  ServicioApi({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.categoria,
    required this.campos,
  });
}

class CampoApi {
  final String id;
  final String nombre;
  final String placeholder;
  final bool esSecreto;

  CampoApi(this.id, this.nombre, this.placeholder, this.esSecreto);
}

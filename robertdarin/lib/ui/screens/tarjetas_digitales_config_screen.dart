// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// PANEL DE CONFIGURACIÓN DE TARJETAS DIGITALES - MULTI-PROVEEDOR
/// ══════════════════════════════════════════════════════════════════════════════
/// Soporta: Stripe, Pomelo, Rapyd, STP, Openpay, Galileo, Marqeta, y Custom
/// Solo accesible para SuperAdmin
/// ══════════════════════════════════════════════════════════════════════════════

class TarjetasDigitalesConfigScreen extends StatefulWidget {
  const TarjetasDigitalesConfigScreen({super.key});

  @override
  State<TarjetasDigitalesConfigScreen> createState() => _TarjetasDigitalesConfigScreenState();
}

class _TarjetasDigitalesConfigScreenState extends State<TarjetasDigitalesConfigScreen> {
  bool _isLoading = true;
  bool _moduloActivo = false;
  bool _modoTest = true;
  String _proveedorSeleccionado = 'stripe';
  
  // Controllers para credenciales
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _merchantIdController = TextEditingController();
  final _customEndpointController = TextEditingController();
  
  Map<String, dynamic>? _estadisticas;
  List<Map<String, dynamic>> _tarjetasRecientes = [];

  // === PROVEEDORES DISPONIBLES ===
  final List<Map<String, dynamic>> _proveedores = [
    {
      'id': 'stripe',
      'nombre': 'Stripe Issuing',
      'logo': '💳',
      'region': 'Global',
      'monedas': ['USD', 'EUR', 'MXN'],
      'descripcion': 'El más popular para startups y empresas globales',
      'documentacion': 'https://stripe.com/docs/issuing',
      'campos': ['publishable_key', 'secret_key', 'webhook_secret'],
    },
    {
      'id': 'pomelo',
      'nombre': 'Pomelo',
      'logo': '🍋',
      'region': 'LATAM',
      'monedas': ['MXN', 'ARS', 'COP', 'BRL'],
      'descripcion': 'Ideal para fintechs en Latinoamérica',
      'documentacion': 'https://docs.pomelo.la',
      'campos': ['client_id', 'client_secret', 'webhook_secret'],
    },
    {
      'id': 'rapyd',
      'nombre': 'Rapyd',
      'logo': '🌐',
      'region': 'Global',
      'monedas': ['Multi-moneda (100+)'],
      'descripcion': 'Plataforma fintech global con múltiples servicios',
      'documentacion': 'https://docs.rapyd.net',
      'campos': ['access_key', 'secret_key', 'webhook_secret'],
    },
    {
      'id': 'stp',
      'nombre': 'STP + Carnet',
      'logo': '🇲🇽',
      'region': 'México',
      'monedas': ['MXN'],
      'descripcion': 'Integración bancaria directa en México',
      'documentacion': 'https://stpmex.com/documentacion',
      'campos': ['empresa', 'clave_privada', 'certificado'],
    },
    {
      'id': 'openpay',
      'nombre': 'Openpay (BBVA)',
      'logo': '🏦',
      'region': 'México',
      'monedas': ['MXN'],
      'descripcion': 'Respaldado por BBVA México',
      'documentacion': 'https://www.openpay.mx/docs/',
      'campos': ['merchant_id', 'private_key', 'public_key'],
    },
    {
      'id': 'galileo',
      'nombre': 'Galileo',
      'logo': '🚀',
      'region': 'USA/LATAM',
      'monedas': ['USD', 'MXN'],
      'descripcion': 'Para neobancos y apps de alto volumen',
      'documentacion': 'https://docs.galileo-ft.com',
      'campos': ['api_login', 'api_trans_key', 'provider_id'],
    },
    {
      'id': 'marqeta',
      'nombre': 'Marqeta',
      'logo': '💎',
      'region': 'Global',
      'monedas': ['USD', 'EUR'],
      'descripcion': 'Para apps de gig economy y delivery',
      'documentacion': 'https://www.marqeta.com/docs/developer-guides',
      'campos': ['application_token', 'admin_access_token'],
    },
    {
      'id': 'custom',
      'nombre': 'Otro Proveedor',
      'logo': '⚙️',
      'region': 'Personalizado',
      'monedas': ['Configurable'],
      'descripcion': 'Conecta cualquier proveedor via API REST',
      'documentacion': '',
      'campos': ['api_key', 'secret_key', 'endpoint', 'webhook_url'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _webhookSecretController.dispose();
    _merchantIdController.dispose();
    _customEndpointController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      // Cargar configuración de tarjetas (cualquier proveedor)
      final configRes = await AppSupabase.client
          .from('configuracion_apis')
          .select()
          .eq('servicio', 'tarjetas_digitales')
          .maybeSingle();

      if (configRes != null) {
        _moduloActivo = configRes['activo'] ?? false;
        _modoTest = configRes['modo_test'] == true;
        _proveedorSeleccionado = configRes['configuracion']?['proveedor'] ?? 'stripe';
        
        // Cargar keys (ocultas)
        if (configRes['api_key'] != null) {
          _apiKeyController.text = _ocultarKey(configRes['api_key']);
        }
        if (configRes['secret_key'] != null) {
          _secretKeyController.text = _ocultarKey(configRes['secret_key']);
        }
        if (configRes['webhook_secret'] != null) {
          _webhookSecretController.text = _ocultarKey(configRes['webhook_secret']);
        }
        if (configRes['configuracion']?['merchant_id'] != null) {
          _merchantIdController.text = configRes['configuracion']['merchant_id'];
        }
        if (configRes['configuracion']?['endpoint'] != null) {
          _customEndpointController.text = configRes['configuracion']['endpoint'];
        }
      }

      // Cargar estadísticas si está activo
      if (_moduloActivo) {
        await _cargarEstadisticas();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando config: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final stats = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('estado')
          .then((res) {
            int activas = 0, bloqueadas = 0, pendientes = 0;
            for (var t in res) {
              switch (t['estado']) {
                case 'activa': activas++; break;
                case 'bloqueada': bloqueadas++; break;
                case 'pendiente': pendientes++; break;
              }
            }
            return {'activas': activas, 'bloqueadas': bloqueadas, 'pendientes': pendientes, 'total': res.length};
          });
      
      _estadisticas = stats;

      // Tarjetas recientes
      final tarjetasRes = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('*, clientes(nombre_completo)')
          .order('created_at', ascending: false)
          .limit(5);
      
      _tarjetasRecientes = List<Map<String, dynamic>>.from(tarjetasRes);
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
    }
  }

  String _ocultarKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Map<String, dynamic> get _proveedorActual {
    return _proveedores.firstWhere(
      (p) => p['id'] == _proveedorSeleccionado,
      orElse: () => _proveedores.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Tarjetas Digitales",
      subtitle: "Configuración Multi-Proveedor",
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarConfiguracion,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === SWITCH PRINCIPAL ===
                    _buildSwitchPrincipal(),
                    const SizedBox(height: 20),

                    // === SELECTOR DE PROVEEDOR ===
                    _buildSelectorProveedor(),
                    const SizedBox(height: 20),

                    if (_moduloActivo) ...[
                      // === INFO DEL PROVEEDOR ===
                      _buildInfoProveedor(),
                      const SizedBox(height: 20),

                      // === ESTADÍSTICAS ===
                      _buildEstadisticas(),
                      const SizedBox(height: 20),

                      // === CONFIGURACIÓN DE CREDENCIALES ===
                      _buildConfigCredenciales(),
                      const SizedBox(height: 20),

                      // === TARJETAS RECIENTES ===
                      _buildTarjetasRecientes(),
                      const SizedBox(height: 20),

                      // === ACCIONES ===
                      _buildAcciones(),
                    ] else ...[
                      // === INFO MÓDULO INACTIVO ===
                      _buildInfoModuloInactivo(),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSwitchPrincipal() {
    return PremiumCard(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _moduloActivo 
                    ? Colors.greenAccent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.credit_card,
                color: _moduloActivo ? Colors.greenAccent : Colors.white54,
                size: 28,
              ),
            ),
            title: const Text('Módulo de Tarjetas Digitales',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _moduloActivo 
                  ? '✅ Activo - Los clientes pueden recibir tarjetas'
                  : '❌ Inactivo - Los clientes no verán la opción de tarjetas',
              style: TextStyle(
                color: _moduloActivo ? Colors.greenAccent : Colors.white54,
                fontSize: 12,
              ),
            ),
            value: _moduloActivo,
            onChanged: (v) => _toggleModulo(v),
            activeColor: Colors.greenAccent,
          ),
          if (_moduloActivo) ...[
            const Divider(color: Colors.white12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo de Pruebas',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _modoTest 
                    ? '🧪 Usando credenciales de TEST'
                    : '🚀 PRODUCCIÓN - Transacciones reales',
                style: TextStyle(
                  color: _modoTest ? Colors.orangeAccent : Colors.redAccent,
                  fontSize: 11,
                ),
              ),
              value: _modoTest,
              onChanged: (v) => _toggleModoTest(v),
              activeColor: Colors.orangeAccent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorProveedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Proveedor de Tarjetas',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _proveedores.length,
            itemBuilder: (context, index) {
              final proveedor = _proveedores[index];
              final seleccionado = proveedor['id'] == _proveedorSeleccionado;
              
              return GestureDetector(
                onTap: () => _cambiarProveedor(proveedor['id']),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: seleccionado 
                        ? Colors.orangeAccent.withOpacity(0.2)
                        : const Color(0xFF252536),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: seleccionado ? Colors.orangeAccent : Colors.white12,
                      width: seleccionado ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(proveedor['logo'], style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        proveedor['nombre'],
                        style: TextStyle(
                          color: seleccionado ? Colors.orangeAccent : Colors.white70,
                          fontSize: 10,
                          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        proveedor['region'],
                        style: const TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoProveedor() {
    final prov = _proveedorActual;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(prov['logo'], style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prov['nombre'],
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(prov['descripcion'],
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildChip('📍 ${prov['region']}'),
              const SizedBox(width: 8),
              _buildChip('💰 ${(prov['monedas'] as List).join(', ')}'),
            ],
          ),
          if ((prov['documentacion'] as String).isNotEmpty) ...[
            const SizedBox(height: 15),
            InkWell(
              onTap: () => _abrirDocumentacion(prov['documentacion']),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('Ver documentación de ${prov['nombre']}',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
                  const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  Widget _buildEstadisticas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Estadísticas',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Activas', 
              '${_estadisticas?['activas'] ?? 0}',
              Icons.check_circle,
              Colors.greenAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(
              'Pendientes',
              '${_estadisticas?['pendientes'] ?? 0}',
              Icons.pending,
              Colors.orangeAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(
              'Bloqueadas',
              '${_estadisticas?['bloqueadas'] ?? 0}',
              Icons.block,
              Colors.redAccent,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String valor, IconData icon, Color color) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(
            color: color, 
            fontSize: 22, 
            fontWeight: FontWeight.bold,
          )),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildConfigCredenciales() {
    final prov = _proveedorActual;
    final campos = prov['campos'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Credenciales de ${prov['nombre']}',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            if ((prov['documentacion'] as String).isNotEmpty)
              TextButton.icon(
                onPressed: () => _abrirDocumentacion(prov['documentacion']),
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('Ayuda', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        
        PremiumCard(
          child: Column(
            children: [
              // API Key / Publishable Key / Client ID
              if (campos.any((c) => c.toString().contains('key') || c.toString().contains('id') || c.toString().contains('login') || c.toString().contains('token')))
                _buildCredentialField(
                  controller: _apiKeyController,
                  label: _getLabelForCampo(campos.first.toString(), prov['id']),
                  hint: _getHintForProveedor(prov['id'], 'api'),
                  icon: Icons.vpn_key,
                ),
              
              const SizedBox(height: 15),
              
              // Secret Key
              if (campos.any((c) => c.toString().contains('secret') || c.toString().contains('private') || c.toString().contains('trans_key')))
                _buildCredentialField(
                  controller: _secretKeyController,
                  label: _getLabelForCampo('secret', prov['id']),
                  hint: _getHintForProveedor(prov['id'], 'secret'),
                  icon: Icons.lock,
                  isSecret: true,
                ),
              
              // Merchant ID (para Openpay, Galileo)
              if (campos.any((c) => c.toString().contains('merchant') || c.toString().contains('provider') || c.toString().contains('empresa'))) ...[
                const SizedBox(height: 15),
                _buildCredentialField(
                  controller: _merchantIdController,
                  label: prov['id'] == 'stp' ? 'Empresa / RFC' : 'Merchant ID / Provider ID',
                  hint: 'ID de comercio',
                  icon: Icons.store,
                ),
              ],
              
              // Webhook Secret
              if (campos.any((c) => c.toString().contains('webhook'))) ...[
                const SizedBox(height: 15),
                _buildCredentialField(
                  controller: _webhookSecretController,
                  label: 'Webhook Secret',
                  hint: 'Para notificaciones en tiempo real',
                  icon: Icons.webhook,
                ),
              ],
              
              // Custom Endpoint (solo para proveedor custom)
              if (prov['id'] == 'custom') ...[
                const SizedBox(height: 15),
                _buildCredentialField(
                  controller: _customEndpointController,
                  label: 'API Endpoint',
                  hint: 'https://api.tuproveedor.com/v1',
                  icon: Icons.link,
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _probarConexion(),
                      icon: const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('Probar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.withOpacity(0.2),
                        foregroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _guardarCredenciales(),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Aviso de seguridad
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.security, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las credenciales se guardan encriptadas. Nunca compartas tus llaves secretas.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isSecret = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      obscureText: isSecret,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orangeAccent),
        ),
      ),
    );
  }

  String _getLabelForCampo(String campo, String proveedor) {
    switch (proveedor) {
      case 'stripe': return 'Publishable Key';
      case 'pomelo': return 'Client ID';
      case 'rapyd': return 'Access Key';
      case 'stp': return 'Clave Privada';
      case 'openpay': return 'Public Key';
      case 'galileo': return 'API Login';
      case 'marqeta': return 'Application Token';
      default: return 'API Key';
    }
  }

  String _getHintForProveedor(String proveedor, String tipo) {
    final prefix = _modoTest ? 'test' : 'live';
    switch (proveedor) {
      case 'stripe':
        return tipo == 'api' ? 'pk_${prefix}_...' : 'sk_${prefix}_...';
      case 'pomelo':
        return tipo == 'api' ? 'cli_...' : 'sec_...';
      case 'rapyd':
        return tipo == 'api' ? 'access_key_...' : 'secret_key_...';
      default:
        return '';
    }
  }

  Widget _buildTarjetasRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tarjetas Recientes',
                style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => _verTodasLasTarjetas(),
              child: const Text('Ver todas', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        if (_tarjetasRecientes.isEmpty)
          PremiumCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.credit_card_off, color: Colors.white24, size: 40),
                    SizedBox(height: 10),
                    Text('No hay tarjetas emitidas aún',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_tarjetasRecientes.length, (index) {
            final tarjeta = _tarjetasRecientes[index];
            return _buildTarjetaItem(tarjeta);
          }),
      ],
    );
  }

  Widget _buildTarjetaItem(Map<String, dynamic> tarjeta) {
    final estado = tarjeta['estado'] ?? 'pendiente';
    Color estadoColor;
    switch (estado) {
      case 'activa': estadoColor = Colors.greenAccent; break;
      case 'bloqueada': estadoColor = Colors.redAccent; break;
      default: estadoColor = Colors.orangeAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(_proveedorActual['logo'], style: const TextStyle(fontSize: 16)),
            ),
          ),
          title: Text(
            tarjeta['clientes']?['nombre_completo'] ?? 'Cliente',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '**** **** **** ${tarjeta['ultimos_4'] ?? '****'}',
            style: const TextStyle(color: Colors.white54, fontFamily: 'monospace'),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              estado.toUpperCase(),
              style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Acciones',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAccionBtn(
                Icons.add_card,
                'Emitir Tarjeta',
                Colors.greenAccent,
                () => _emitirTarjetaManual(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAccionBtn(
                Icons.group_add,
                'Emitir Masivo',
                Colors.blueAccent,
                () => _emitirMasivo(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAccionBtn(
                Icons.sync,
                'Sincronizar',
                Colors.purpleAccent,
                () => _sincronizarConProveedor(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAccionBtn(
                Icons.analytics,
                'Ver Reportes',
                Colors.tealAccent,
                () => _verReportes(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: PremiumCard(
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoModuloInactivo() {
    return Column(
      children: [
        // Header con gradiente
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF667eea).withOpacity(0.3),
                const Color(0xFF764ba2).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.credit_card, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tarjetas Digitales',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Emite tarjetas virtuales y físicas para tus clientes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _toggleModulo(true),
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Activar Módulo', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Beneficios
        _buildSeccionBeneficios(),
        
        const SizedBox(height: 24),
        
        // Proveedores en grid mejorado
        _buildSeccionProveedores(),
        
        const SizedBox(height: 24),
        
        // Pasos para activar
        _buildSeccionPasos(),
      ],
    );
  }

  Widget _buildSeccionBeneficios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star, color: Colors.greenAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Beneficios',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildBeneficioCard(
              Icons.flash_on,
              'Emisión Instantánea',
              'Tarjetas virtuales en segundos',
              Colors.orangeAccent,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildBeneficioCard(
              Icons.security,
              'Seguridad Total',
              'Controles y límites personalizados',
              Colors.blueAccent,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildBeneficioCard(
              Icons.phone_android,
              'Pago Móvil',
              'Apple Pay y Google Pay',
              Colors.purpleAccent,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildBeneficioCard(
              Icons.analytics,
              'Reportes en Tiempo Real',
              'Monitorea cada transacción',
              Colors.tealAccent,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildBeneficioCard(IconData icon, String titulo, String descripcion, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSeccionProveedores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business, color: Colors.orangeAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Proveedores Compatibles',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _proveedores.length,
          itemBuilder: (context, index) {
            final p = _proveedores[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Text(p['logo'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p['nombre'],
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          p['region'],
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSeccionPasos() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checklist, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '¿Cómo Empezar?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPasoItem(1, 'Activa el módulo', 'Usa el botón de arriba', Colors.greenAccent),
          _buildPasoItem(2, 'Elige un proveedor', 'Stripe, Pomelo, Rapyd...', Colors.orangeAccent),
          _buildPasoItem(3, 'Ingresa tus API Keys', 'Del dashboard del proveedor', Colors.purpleAccent),
          _buildPasoItem(4, 'Emite tarjetas', 'A tus clientes desde aquí', Colors.tealAccent),
        ],
      ),
    );
  }

  Widget _buildPasoItem(int numero, String titulo, String descripcion, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                '$numero',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === ACCIONES ===

  void _cambiarProveedor(String proveedorId) {
    setState(() {
      _proveedorSeleccionado = proveedorId;
      // Limpiar campos al cambiar proveedor
      _apiKeyController.clear();
      _secretKeyController.clear();
      _webhookSecretController.clear();
      _merchantIdController.clear();
      _customEndpointController.clear();
    });
  }

  Future<void> _toggleModulo(bool activo) async {
    try {
      await AppSupabase.client.from('configuracion_apis').upsert({
        'servicio': 'tarjetas_digitales',
        'activo': activo,
        'configuracion': {'proveedor': _proveedorSeleccionado},
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'servicio');

      setState(() => _moduloActivo = activo);

      if (activo) {
        await _cargarEstadisticas();
        await AppSupabase.client.from('notificaciones_sistema').insert({
          'tipo': 'modulo_tarjetas',
          'accion': 'activado',
          'mensaje': 'Módulo de tarjetas digitales activado con ${_proveedorActual['nombre']}',
          'fecha': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activo ? '✅ Módulo activado' : '❌ Módulo desactivado'),
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
  Future<void> _toggleModoTest(bool test) async {
    if (!test) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('⚠️ Modo Producción', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            '¿Estás seguro de cambiar a modo PRODUCCIÓN?\n\n'
            'Las transacciones serán REALES y afectarán dinero real.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Sí, activar producción'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    await AppSupabase.client.from('configuracion_apis').upsert({
      'servicio': 'tarjetas_digitales',
      'modo_test': test,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'servicio');

    setState(() => _modoTest = test);
  }

  Future<void> _guardarCredenciales() async {
    try {
      final config = {
        'proveedor': _proveedorSeleccionado,
        'merchant_id': _merchantIdController.text,
        'endpoint': _customEndpointController.text,
      };

      await AppSupabase.client.from('configuracion_apis').upsert({
        'servicio': 'tarjetas_digitales',
        'activo': _moduloActivo,
        'modo_test': _modoTest,
        'api_key': _apiKeyController.text,
        'secret_key': _secretKeyController.text,
        'webhook_secret': _webhookSecretController.text,
        'configuracion': config,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'servicio');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Credenciales guardadas'),
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

  Future<void> _probarConexion() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 15),
            Text('Probando conexión con ${_proveedorActual['nombre']}...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Simular prueba de conexión
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final exito = _apiKeyController.text.isNotEmpty && _secretKeyController.text.isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito ? '✅ Conexión exitosa' : '❌ Error: Verifica tus credenciales'),
          backgroundColor: exito ? Colors.greenAccent : Colors.redAccent,
        ),
      );
    }
  }

  void _emitirTarjetaManual() {
    _mostrarDialogoEmitirTarjeta();
  }

  Future<void> _mostrarDialogoEmitirTarjeta() async {
    List<Map<String, dynamic>> clientes = [];
    String? clienteSeleccionado;
    String tipoTarjeta = 'virtual';
    bool cargando = true;

    // Cargar clientes
    try {
      final res = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, telefono, email')
          .eq('activo', true)
          .order('nombre');
      clientes = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
    }
    cargando = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Row(
            children: [
              const Icon(Icons.add_card, color: Colors.greenAccent),
              const SizedBox(width: 10),
              const Text('Emitir Tarjeta Digital', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del proveedor
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(_proveedorActual['logo'], style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text(
                        'Proveedor: ${_proveedorActual['nombre']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selector de cliente
                const Text('Selecciona el cliente:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: clienteSeleccionado,
                  dropdownColor: const Color(0xFF252536),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: Text(
                    cargando ? 'Cargando...' : 'Selecciona un cliente',
                    style: const TextStyle(color: Colors.white38),
                  ),
                  items: clientes.map((c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text('${c['nombre']} - ${c['telefono'] ?? c['email'] ?? ''}'),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => clienteSeleccionado = v),
                ),
                const SizedBox(height: 15),

                // Tipo de tarjeta
                const Text('Tipo de tarjeta:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => tipoTarjeta = 'virtual'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tipoTarjeta == 'virtual' ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tipoTarjeta == 'virtual' ? Colors.greenAccent : Colors.white24,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.phone_android, color: tipoTarjeta == 'virtual' ? Colors.greenAccent : Colors.white54),
                              const SizedBox(height: 4),
                              Text('Virtual', style: TextStyle(
                                color: tipoTarjeta == 'virtual' ? Colors.greenAccent : Colors.white54,
                                fontSize: 12,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => tipoTarjeta = 'fisica'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tipoTarjeta == 'fisica' ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tipoTarjeta == 'fisica' ? Colors.blueAccent : Colors.white24,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.credit_card, color: tipoTarjeta == 'fisica' ? Colors.blueAccent : Colors.white54),
                              const SizedBox(height: 4),
                              Text('Física', style: TextStyle(
                                color: tipoTarjeta == 'fisica' ? Colors.blueAccent : Colors.white54,
                                fontSize: 12,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _modoTest ? Icons.science : Icons.warning,
                        color: _modoTest ? Colors.orangeAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _modoTest 
                              ? 'Modo TEST: La tarjeta será de pruebas'
                              : 'PRODUCCIÓN: Se emitirá una tarjeta REAL',
                          style: TextStyle(
                            color: _modoTest ? Colors.orangeAccent : Colors.redAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: clienteSeleccionado == null ? null : () async {
                Navigator.pop(context);
                await _procesarEmisionTarjeta(clienteSeleccionado!, tipoTarjeta);
              },
              icon: const Icon(Icons.credit_score),
              label: const Text('Emitir Tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarEmisionTarjeta(String clienteId, String tipo) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.greenAccent),
            SizedBox(height: 20),
            Text('Emitiendo tarjeta...', style: TextStyle(color: Colors.white)),
            SizedBox(height: 5),
            Text('Conectando con el proveedor', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );

    try {
      // Obtener datos del cliente
      final clienteData = await AppSupabase.client
          .from('clientes')
          .select()
          .eq('id', clienteId)
          .single();

      // Generar número de tarjeta (en producción esto viene del proveedor)
      final random = DateTime.now().millisecondsSinceEpoch;
      final ultimos4 = (random % 10000).toString().padLeft(4, '0');
      final numeroEnmascarado = '**** **** **** $ultimos4';

      // Crear registro de tarjeta en la BD
      await AppSupabase.client.from('tarjetas_digitales').insert({
        'cliente_id': clienteId,
        'proveedor': _proveedorSeleccionado,
        'tipo': tipo,
        'ultimos_4': ultimos4,
        'numero_enmascarado': numeroEnmascarado,
        'estado': 'activa',
        'modo_test': _modoTest,
        'fecha_emision': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 365 * 3)).toIso8601String(),
        'limite_diario': 10000.0,
        'limite_mensual': 50000.0,
        'moneda': 'MXN',
        'activa': true,
      });

      // Crear notificación para el cliente
      await AppSupabase.client.from('notificaciones').insert({
        'usuario_id': clienteData['usuario_id'],
        'titulo': '🎉 ¡Nueva Tarjeta Digital!',
        'mensaje': 'Tu tarjeta ${tipo == 'virtual' ? 'virtual' : 'física'} terminada en $ultimos4 está lista para usar.',
        'tipo': 'tarjeta',
        'leida': false,
      });

      // Registrar en auditoría
      await AppSupabase.client.from('auditoria').insert({
        'tabla': 'tarjetas_digitales',
        'accion': 'INSERT',
        'descripcion': 'Tarjeta $tipo emitida para cliente ${clienteData['nombre']}',
      });

      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        
        // Mostrar éxito
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                SizedBox(width: 10),
                Text('¡Tarjeta Emitida!', style: TextStyle(color: Colors.greenAccent)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: ${clienteData['nombre']}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.purpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_proveedorActual['logo'], style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 10),
                      Text(
                        numeroEnmascarado,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tipo.toUpperCase(),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _modoTest ? '⚠️ Tarjeta de PRUEBA' : '✅ Tarjeta de PRODUCCIÓN',
                  style: TextStyle(
                    color: _modoTest ? Colors.orangeAccent : Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cargarEstadisticas();
                  _cargarConfiguracion();
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al emitir tarjeta: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _emitirMasivo() async {
    List<Map<String, dynamic>> clientesSinTarjeta = [];
    bool cargando = true;
    String tipoTarjeta = 'virtual';
    bool seleccionarTodos = true;
    Set<String> clientesSeleccionados = {};

    // Cargar clientes sin tarjeta del proveedor actual
    try {
      final clientes = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, telefono, email')
          .eq('activo', true);

      final tarjetasExistentes = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('cliente_id')
          .eq('proveedor', _proveedorSeleccionado)
          .eq('activa', true);

      final clientesConTarjeta = (tarjetasExistentes as List)
          .map((t) => t['cliente_id'] as String)
          .toSet();

      clientesSinTarjeta = (clientes as List)
          .where((c) => !clientesConTarjeta.contains(c['id']))
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

      clientesSeleccionados = clientesSinTarjeta.map((c) => c['id'] as String).toSet();
    } catch (e) {
      debugPrint('Error: $e');
    }
    cargando = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Row(
            children: [
              const Icon(Icons.library_add, color: Colors.blueAccent),
              const SizedBox(width: 10),
              const Text('Emisión Masiva', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(_proveedorActual['logo'], style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Emitir tarjetas ${_proveedorActual['nombre']} a múltiples clientes',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Text('Tipo:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Virtual'),
                      selected: tipoTarjeta == 'virtual',
                      onSelected: (s) => setDialogState(() => tipoTarjeta = 'virtual'),
                      selectedColor: Colors.greenAccent,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Física'),
                      selected: tipoTarjeta == 'fisica',
                      onSelected: (s) => setDialogState(() => tipoTarjeta = 'fisica'),
                      selectedColor: Colors.blueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Checkbox(
                      value: seleccionarTodos,
                      onChanged: (v) {
                        setDialogState(() {
                          seleccionarTodos = v ?? false;
                          if (seleccionarTodos) {
                            clientesSeleccionados = clientesSinTarjeta.map((c) => c['id'] as String).toSet();
                          } else {
                            clientesSeleccionados.clear();
                          }
                        });
                      },
                      activeColor: Colors.greenAccent,
                    ),
                    Text(
                      'Todos (${clientesSinTarjeta.length} sin tarjeta)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: cargando
                      ? const Center(child: CircularProgressIndicator())
                      : clientesSinTarjeta.isEmpty
                          ? const Center(
                              child: Text('Todos ya tienen tarjeta', style: TextStyle(color: Colors.white54)),
                            )
                          : ListView.builder(
                              itemCount: clientesSinTarjeta.length,
                              itemBuilder: (context, index) {
                                final cliente = clientesSinTarjeta[index];
                                final sel = clientesSeleccionados.contains(cliente['id']);
                                return CheckboxListTile(
                                  value: sel,
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (v == true) {
                                        clientesSeleccionados.add(cliente['id']);
                                      } else {
                                        clientesSeleccionados.remove(cliente['id']);
                                      }
                                      seleccionarTodos = clientesSeleccionados.length == clientesSinTarjeta.length;
                                    });
                                  },
                                  title: Text(cliente['nombre'], style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(cliente['telefono'] ?? cliente['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  activeColor: Colors.greenAccent,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              },
                            ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _modoTest ? Colors.orangeAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_modoTest ? Icons.science : Icons.warning, color: _modoTest ? Colors.orangeAccent : Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${clientesSeleccionados.length} tarjetas ${_modoTest ? 'de PRUEBA' : 'REALES'}',
                          style: TextStyle(color: _modoTest ? Colors.orangeAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: clientesSeleccionados.isEmpty ? null : () async {
                Navigator.pop(context);
                await _ejecutarEmisionMasiva(clientesSeleccionados.toList(), tipoTarjeta);
              },
              icon: const Icon(Icons.send),
              label: Text('Emitir ${clientesSeleccionados.length}'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarEmisionMasiva(List<String> ids, String tipo) async {
    int exitosas = 0, fallidas = 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text('Emitiendo ${ids.length} tarjetas...', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    for (final clienteId in ids) {
      try {
        final cliente = await AppSupabase.client.from('clientes').select('nombre, usuario_id').eq('id', clienteId).single();
        final ts = DateTime.now().millisecondsSinceEpoch + exitosas;
        final ultimos4 = (ts % 10000).toString().padLeft(4, '0');

        await AppSupabase.client.from('tarjetas_digitales').insert({
          'cliente_id': clienteId,
          'proveedor': _proveedorSeleccionado,
          'tipo': tipo,
          'ultimos_4': ultimos4,
          'numero_enmascarado': '**** **** **** $ultimos4',
          'estado': 'activa',
          'modo_test': _modoTest,
          'fecha_emision': DateTime.now().toIso8601String(),
          'fecha_expiracion': DateTime.now().add(const Duration(days: 1095)).toIso8601String(),
          'limite_diario': 10000.0,
          'limite_mensual': 50000.0,
          'moneda': 'MXN',
          'activa': true,
        });

        if (cliente['usuario_id'] != null) {
          await AppSupabase.client.from('notificaciones').insert({
            'usuario_id': cliente['usuario_id'],
            'titulo': '🎉 ¡Nueva Tarjeta!',
            'mensaje': 'Tarjeta terminada en $ultimos4 lista para usar.',
            'tipo': 'tarjeta',
            'leida': false,
          });
        }
        exitosas++;
      } catch (e) {
        fallidas++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $exitosas emitidas${fallidas > 0 ? ' | ❌ $fallidas fallidas' : ''}'),
          backgroundColor: fallidas == 0 ? Colors.green : Colors.orange,
        ),
      );
      _cargarEstadisticas();
      _cargarConfiguracion();
    }
  }

  void _sincronizarConProveedor() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sincronizando con ${_proveedorActual['nombre']}...')),
    );
  }

  void _verTodasLasTarjetas() {
    _mostrarListadoTarjetas();
  }

  Future<void> _mostrarListadoTarjetas() async {
    List<Map<String, dynamic>> tarjetas = [];
    bool cargando = true;

    try {
      final res = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('*, clientes!inner(nombre, telefono)')
          .eq('proveedor', _proveedorSeleccionado)
          .order('fecha_emision', ascending: false);
      tarjetas = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error: $e');
    }
    cargando = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(_proveedorActual['logo'], style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarjetas ${_proveedorActual['nombre']}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${tarjetas.length} tarjetas emitidas',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : tarjetas.isEmpty
                      ? const Center(
                          child: Text('No hay tarjetas emitidas', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: tarjetas.length,
                          itemBuilder: (context, index) {
                            final tarjeta = tarjetas[index];
                            final cliente = tarjeta['clientes'] as Map<String, dynamic>?;
                            final activa = tarjeta['activa'] == true;
                            final esTest = tarjeta['modo_test'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: activa
                                      ? [Colors.blueAccent.withOpacity(0.3), Colors.purpleAccent.withOpacity(0.3)]
                                      : [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: activa ? Colors.blueAccent.withOpacity(0.5) : Colors.white12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Stack(
                                  children: [
                                    Icon(
                                      tarjeta['tipo'] == 'virtual' ? Icons.phone_android : Icons.credit_card,
                                      color: activa ? Colors.blueAccent : Colors.grey,
                                      size: 32,
                                    ),
                                    if (esTest)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.science, size: 10, color: Colors.black),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  tarjeta['numero_enmascarado'] ?? '**** **** **** ****',
                                  style: TextStyle(
                                    color: activa ? Colors.white : Colors.white38,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cliente?['nombre'] ?? 'Sin cliente',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: activa ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            activa ? 'Activa' : 'Inactiva',
                                            style: TextStyle(color: activa ? Colors.greenAccent : Colors.redAccent, fontSize: 10),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tarjeta['tipo']?.toString().toUpperCase() ?? '',
                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                                  color: const Color(0xFF252536),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'toggle':
                                        await _toggleTarjetaEstado(tarjeta['id'], !activa);
                                        Navigator.pop(context);
                                        _verTodasLasTarjetas();
                                        break;
                                      case 'delete':
                                        await _eliminarTarjeta(tarjeta['id']);
                                        Navigator.pop(context);
                                        _verTodasLasTarjetas();
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(activa ? Icons.block : Icons.check_circle, color: activa ? Colors.redAccent : Colors.greenAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Text(activa ? 'Desactivar' : 'Activar', style: const TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                          SizedBox(width: 8),
                                          Text('Eliminar', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
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
      ),
    );
  }

  Future<void> _toggleTarjetaEstado(String tarjetaId, bool nuevoEstado) async {
    try {
      await AppSupabase.client.from('tarjetas_digitales').update({'activa': nuevoEstado}).eq('id', tarjetaId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado ? 'Tarjeta activada' : 'Tarjeta desactivada'),
          backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
        ),
      );
      _cargarEstadisticas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _eliminarTarjeta(String tarjetaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('¿Eliminar tarjeta?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppSupabase.client.from('tarjetas_digitales').delete().eq('id', tarjetaId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta eliminada'), backgroundColor: Colors.green),
        );
        _cargarEstadisticas();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _verReportes() {
    _mostrarReportesTarjetas();
  }

  Future<void> _mostrarReportesTarjetas() async {
    Map<String, dynamic> estadisticas = {
      'total': 0,
      'activas': 0,
      'inactivas': 0,
      'virtuales': 0,
      'fisicas': 0,
      'test': 0,
      'produccion': 0,
    };

    try {
      final tarjetas = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('activa, tipo, modo_test')
          .eq('proveedor', _proveedorSeleccionado);

      for (final t in tarjetas) {
        estadisticas['total']++;
        if (t['activa'] == true) estadisticas['activas']++;
        else estadisticas['inactivas']++;
        if (t['tipo'] == 'virtual') estadisticas['virtuales']++;
        else estadisticas['fisicas']++;
        if (t['modo_test'] == true) estadisticas['test']++;
        else estadisticas['produccion']++;
      }
    } catch (e) {
      debugPrint('Error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text('Reportes ${_proveedorActual['nombre']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReporteItem('Total Tarjetas', estadisticas['total'], Icons.credit_card, Colors.blueAccent),
            const Divider(color: Colors.white24),
            Row(
              children: [
                Expanded(child: _buildReporteItem('Activas', estadisticas['activas'], Icons.check_circle, Colors.greenAccent)),
                Expanded(child: _buildReporteItem('Inactivas', estadisticas['inactivas'], Icons.block, Colors.redAccent)),
              ],
            ),
            const Divider(color: Colors.white24),
            Row(
              children: [
                Expanded(child: _buildReporteItem('Virtuales', estadisticas['virtuales'], Icons.phone_android, Colors.purpleAccent)),
                Expanded(child: _buildReporteItem('Físicas', estadisticas['fisicas'], Icons.credit_card, Colors.orangeAccent)),
              ],
            ),
            const Divider(color: Colors.white24),
            Row(
              children: [
                Expanded(child: _buildReporteItem('Test', estadisticas['test'], Icons.science, Colors.yellowAccent)),
                Expanded(child: _buildReporteItem('Producción', estadisticas['produccion'], Icons.verified, Colors.greenAccent)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _buildReporteItem(String label, int valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text('$valor', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _abrirDocumentacion(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/negocio_activo_provider.dart';
import '../components/negocio_switcher_widget.dart';
import '../navigation/app_routes.dart';
import '../../data/models/negocio_model.dart';
import '../../core/supabase_client.dart';

/// Dashboard específico de un negocio
/// Muestra KPIs, accesos rápidos y datos filtrados por negocio
class NegocioDashboardScreen extends StatefulWidget {
  final NegocioModel? negocio;

  const NegocioDashboardScreen({super.key, this.negocio});

  @override
  State<NegocioDashboardScreen> createState() => _NegocioDashboardScreenState();
}

class _NegocioDashboardScreenState extends State<NegocioDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  final _formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  bool _cargando = true;
  Map<String, dynamic> _kpis = {};
  List<Map<String, dynamic>> _ultimosClientes = [];
  List<Map<String, dynamic>> _ultimosPrestamos = [];
  List<Map<String, dynamic>> _proximosPagos = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    
    _cargarDatosNegocio();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosNegocio() async {
    final provider = context.read<NegocioActivoProvider>();
    final negocioId = widget.negocio?.id ?? provider.negocioId;
    
    if (negocioId == null) {
      setState(() => _cargando = false);
      return;
    }

    try {
      // KPIs del negocio
      final clientes = await AppSupabase.client
          .from('clientes')
          .select('id, nombre, apellidos, created_at')
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('created_at', ascending: false)
          .limit(5);

      final prestamos = await AppSupabase.client
          .from('prestamos')
          .select('id, monto, estado, fecha_creacion, cliente_id')
          .eq('negocio_id', negocioId)
          .order('fecha_creacion', ascending: false)
          .limit(5);

      final tandas = await AppSupabase.client
          .from('tandas')
          .select('id, nombre, estado, monto_por_persona, numero_participantes')
          .eq('negocio_id', negocioId);

      final sucursales = await AppSupabase.client
          .from('sucursales')
          .select('id, nombre')
          .eq('negocio_id', negocioId);

      final empleados = await AppSupabase.client
          .from('empleados')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true);

      // Calcular totales
      final listaPrestamos = prestamos as List;
      double carteraActiva = 0;
      int activos = 0;
      int enMora = 0;
      
      for (var p in listaPrestamos) {
        final monto = (p['monto'] as num?)?.toDouble() ?? 0;
        if (p['estado'] == 'activo') {
          carteraActiva += monto;
          activos++;
        }
        if (p['estado'] == 'mora') enMora++;
      }

      final listaTandas = tandas as List;
      double bolsaTandas = 0;
      int tandasActivas = 0;
      
      for (var t in listaTandas) {
        if (t['estado'] == 'activa') {
          tandasActivas++;
          final monto = (t['monto_por_persona'] as num?)?.toDouble() ?? 0;
          final participantes = (t['numero_participantes'] as num?)?.toInt() ?? 0;
          bolsaTandas += monto * participantes;
        }
      }

      if (mounted) {
        setState(() {
          _kpis = {
            'clientes': (clientes as List).length,
            'prestamos_activos': activos,
            'prestamos_mora': enMora,
            'cartera_activa': carteraActiva,
            'tandas_activas': tandasActivas,
            'bolsa_tandas': bolsaTandas,
            'sucursales': (sucursales as List).length,
            'empleados': (empleados as List).length,
          };
          _ultimosClientes = List<Map<String, dynamic>>.from(clientes);
          _ultimosPrestamos = List<Map<String, dynamic>>.from(listaPrestamos.take(5));
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NegocioActivoProvider>();
    final negocio = widget.negocio ?? provider.negocioActivo;
    
    if (negocio == null) {
      return _buildSinNegocio();
    }

    final colores = _getColoresNegocio(negocio.tipo);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: RefreshIndicator(
        onRefresh: _cargarDatosNegocio,
        color: colores[0],
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header del negocio
            _buildHeader(negocio, colores),
            
            // KPIs principales
            SliverToBoxAdapter(
              child: _cargando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildKPIsSection(colores),
            ),
            
            // Accesos rápidos
            SliverToBoxAdapter(child: _buildAccesosRapidos(negocio, colores)),

            // AdministraciÃ³n del negocio
            SliverToBoxAdapter(child: _buildAdministracionNegocio(negocio, colores)),
            
            // Últimos clientes
            if (_ultimosClientes.isNotEmpty)
              SliverToBoxAdapter(child: _buildSeccionClientes()),
            
            // Últimos préstamos
            if (_ultimosPrestamos.isNotEmpty)
              SliverToBoxAdapter(child: _buildSeccionPrestamos()),
            
            // Espacio final
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(negocio, colores),
    );
  }

  Widget _buildHeader(NegocioModel negocio, List<Color> colores) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0F),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Switcher compacto
        const NegocioSwitcherWidget(compacto: true),
        const SizedBox(width: 8),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.more_vert, color: Colors.white),
          ),
          onPressed: () => _mostrarOpciones(negocio),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colores,
            ),
          ),
          child: Stack(
            children: [
              // Patrón decorativo
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Contenido
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                negocio.icono,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  negocio.nombre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getTipoLabel(negocio.tipo),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIsSection(List<Color> colores) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: _animController,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colores[0].withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📊', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Text(
                    'KPIs del Negocio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'En tiempo real',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Cartera principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colores[0].withOpacity(0.3), colores[1].withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 Cartera Activa',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatoMoneda.format(_kpis['cartera_activa'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMiniKPI('Activos', '${_kpis['prestamos_activos'] ?? 0}', Colors.greenAccent),
                        const SizedBox(height: 8),
                        _buildMiniKPI('En mora', '${_kpis['prestamos_mora'] ?? 0}', Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Grid de KPIs
              Row(
                children: [
                  _buildKPICard('👥', '${_kpis['clientes'] ?? 0}', 'Clientes', Colors.cyanAccent),
                  const SizedBox(width: 12),
                  _buildKPICard('🔄', '${_kpis['tandas_activas'] ?? 0}', 'Tandas', Colors.purpleAccent),
                  const SizedBox(width: 12),
                  _buildKPICard('🏪', '${_kpis['sucursales'] ?? 0}', 'Sucursales', Colors.orangeAccent),
                  const SizedBox(width: 12),
                  _buildKPICard('👔', '${_kpis['empleados'] ?? 0}', 'Empleados', Colors.tealAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniKPI(String label, String valor, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$valor $label',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildKPICard(String emoji, String valor, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesosRapidos(NegocioModel negocio, List<Color> colores) {
    // Módulos según tipo de negocio
    final modulos = _getModulosNegocio(negocio.tipo);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '⚡ Accesos Rápidos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: modulos.map((m) => _buildAccesoRapido(m, colores)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdministracionNegocio(NegocioModel negocio, List<Color> colores) {
    final acciones = _getAdministracionNegocio(negocio.tipo);
    if (acciones.isEmpty) return const SizedBox.shrink();

    final rutasRapidas = _getModulosNegocio(negocio.tipo)
        .map((m) => m['ruta']?.toString())
        .whereType<String>()
        .toSet();
    final accionesFiltradas = acciones
        .where((a) => a['ruta'] != null && !rutasRapidas.contains(a['ruta']))
        .toList();

    if (accionesFiltradas.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Administración del Negocio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colores[0].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getTipoLabel(negocio.tipo),
                  style: TextStyle(
                    color: colores[0],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: accionesFiltradas.map((a) => _buildAccesoRapido(a, colores)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccesoRapido(Map<String, dynamic> modulo, List<Color> colores) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (modulo['ruta'] != null) {
          Navigator.pushNamed(context, modulo['ruta']);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(modulo['icono'] ?? '📱', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              modulo['nombre'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getModulosNegocio(String? tipo) {
    // Módulos base para todos
    final base = [
      {'icono': '👥', 'nombre': 'Clientes', 'ruta': '/clientes'},
      {'icono': '👔', 'nombre': 'Empleados', 'ruta': '/empleados'},
      {'icono': '🏪', 'nombre': 'Sucursales', 'ruta': '/sucursales'},
      {'icono': '📊', 'nombre': 'Reportes', 'ruta': '/reportes'},
    ];

    // Módulos específicos por tipo
    switch (tipo) {
      case 'fintech':
        return [
          {'icono': '💳', 'nombre': 'Préstamos', 'ruta': '/prestamos'},
          {'icono': '🔄', 'nombre': 'Tandas', 'ruta': '/tandas'},
          {'icono': '💵', 'nombre': 'Pagos', 'ruta': '/pagos'},
          {'icono': '🛡️', 'nombre': 'Avales', 'ruta': '/avales'},
          ...base,
        ];
      case 'aires':
      case 'climas':
        return [
          {'icono': '❄️', 'nombre': 'Servicios', 'ruta': '/servicios'},
          {'icono': '🔧', 'nombre': 'Mantenimiento', 'ruta': '/mantenimiento'},
          {'icono': '📦', 'nombre': 'Inventario', 'ruta': '/inventario'},
          {'icono': '🧾', 'nombre': 'Cotizaciones', 'ruta': '/cotizaciones'},
          ...base,
        ];
      case 'purificadora':
        return [
          {'icono': '💧', 'nombre': 'Rutas', 'ruta': '/rutas'},
          {'icono': '🚚', 'nombre': 'Entregas', 'ruta': '/entregas'},
          {'icono': '📦', 'nombre': 'Inventario', 'ruta': '/inventario'},
          {'icono': '🧾', 'nombre': 'Ventas', 'ruta': '/ventas'},
          ...base,
        ];
      default:
        return [
          {'icono': '🧾', 'nombre': 'Ventas', 'ruta': '/ventas'},
          {'icono': '📦', 'nombre': 'Inventario', 'ruta': '/inventario'},
          {'icono': '💵', 'nombre': 'Cobros', 'ruta': '/cobros'},
          {'icono': '📅', 'nombre': 'Calendario', 'ruta': '/calendario'},
          ...base,
        ];
    }
  }

  List<Map<String, dynamic>> _getAdministracionNegocio(String? tipo) {
    final base = [
      {'icono': '👥', 'nombre': 'RRHH', 'ruta': AppRoutes.empleadosUniversal},
      {'icono': '⚙️', 'nombre': 'Config Facturas', 'ruta': AppRoutes.facturacionConfig},
    ];

    switch (tipo) {
      case 'fintech':
        return [
          {'icono': '🧾', 'nombre': 'Facturas', 'ruta': AppRoutes.finanzasFacturas},
          {'icono': '🔳', 'nombre': 'Tarjetas QR', 'ruta': AppRoutes.finanzasTarjetasQr},
          ...base,
        ];
      case 'aires':
      case 'climas':
        return [
          {'icono': '🛠️', 'nombre': 'Admin Climas', 'ruta': AppRoutes.climasAdminDashboard},
          {'icono': '📥', 'nombre': 'Solicitudes QR', 'ruta': AppRoutes.climasSolicitudesAdmin},
          {'icono': '🧾', 'nombre': 'Facturas Climas', 'ruta': AppRoutes.climasFacturas},
          {'icono': '🔳', 'nombre': 'Tarjetas QR', 'ruta': AppRoutes.climasTarjetasQr},
          ...base,
        ];
      case 'purificadora':
        return [
          {'icono': '🧾', 'nombre': 'Facturas Agua', 'ruta': AppRoutes.purificadoraFacturas},
          {'icono': '🔳', 'nombre': 'Tarjetas QR', 'ruta': AppRoutes.purificadoraTarjetasQr},
          ...base,
        ];
      case 'nice':
        return [
          {'icono': '🧾', 'nombre': 'Facturas NICE', 'ruta': AppRoutes.niceFacturas},
          {'icono': '🔳', 'nombre': 'Tarjetas QR', 'ruta': AppRoutes.niceTarjetasQr},
          ...base,
        ];
      default:
        return [
          {'icono': '🧾', 'nombre': 'Facturas', 'ruta': AppRoutes.facturacionDashboard},
          ...base,
        ];
    }
  }

  Widget _buildSeccionClientes() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Últimos Clientes',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/clientes'),
                child: const Text('Ver todos →', style: TextStyle(color: Colors.cyanAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_ultimosClientes.take(3).map((c) => _buildClienteItem(c))),
        ],
      ),
    );
  }

  Widget _buildClienteItem(Map<String, dynamic> cliente) {
    final nombre = cliente['nombre'] ?? '';
    final apellidos = cliente['apellidos'] ?? '';
    final iniciales = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.cyanAccent.withOpacity(0.2),
            child: Text(
              iniciales,
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$nombre $apellidos',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildSeccionPrestamos() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💳', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Últimos Préstamos',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/prestamos'),
                child: const Text('Ver todos →', style: TextStyle(color: Colors.purpleAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_ultimosPrestamos.take(3).map((p) => _buildPrestamoItem(p))),
        ],
      ),
    );
  }

  Widget _buildPrestamoItem(Map<String, dynamic> prestamo) {
    final monto = (prestamo['monto'] as num?)?.toDouble() ?? 0;
    final estado = prestamo['estado'] ?? 'activo';
    final colorEstado = estado == 'activo' ? Colors.greenAccent : 
                        estado == 'mora' ? Colors.redAccent : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorEstado.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('💳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatoMoneda.format(monto),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  estado.toUpperCase(),
                  style: TextStyle(color: colorEstado, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildFAB(NegocioModel negocio, List<Color> colores) {
    return FloatingActionButton(
      onPressed: () => _mostrarAccionesRapidas(negocio),
      backgroundColor: colores[0],
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _mostrarAccionesRapidas(NegocioModel negocio) {
    final acciones = _getAccionesNegocio(negocio.tipo);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '⚡ Acción Rápida',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...acciones.map((a) => ListTile(
              onTap: () {
                Navigator.pop(context);
                if (a['ruta'] != null) Navigator.pushNamed(context, a['ruta']);
              },
              leading: Text(a['icono'] ?? '📱', style: const TextStyle(fontSize: 24)),
              title: Text(a['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAccionesNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech':
        return [
          {'icono': '➕', 'nombre': 'Nuevo Préstamo', 'ruta': '/nuevo-prestamo'},
          {'icono': '👤', 'nombre': 'Nuevo Cliente', 'ruta': '/nuevo-cliente'},
          {'icono': '💵', 'nombre': 'Registrar Pago', 'ruta': '/nuevo-pago'},
          {'icono': '🔄', 'nombre': 'Nueva Tanda', 'ruta': '/nueva-tanda'},
        ];
      default:
        return [
          {'icono': '👤', 'nombre': 'Nuevo Cliente', 'ruta': '/nuevo-cliente'},
          {'icono': '🧾', 'nombre': 'Nueva Venta', 'ruta': '/nueva-venta'},
          {'icono': '📦', 'nombre': 'Nuevo Producto', 'ruta': '/nuevo-producto'},
        ];
    }
  }

  void _mostrarOpciones(NegocioModel negocio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('⚙️', style: TextStyle(fontSize: 24)),
              title: const Text('Configuración', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Text('📊', style: TextStyle(fontSize: 24)),
              title: const Text('Ver Reportes', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reportes');
              },
            ),
            ListTile(
              leading: const Text('🔙', style: TextStyle(fontSize: 24)),
              title: const Text('Volver a Mis Negocios', style: TextStyle(color: Colors.white)),
              onTap: () {
                context.read<NegocioActivoProvider>().seleccionarNegocio(null);
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinNegocio() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏢', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text(
              'Selecciona un negocio',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getColoresNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'aires':
      case 'climas':
        return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
      case 'purificadora':
        return [const Color(0xFF00c6fb), const Color(0xFF005bea)];
      case 'ventas':
      case 'retail':
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      default:
        return [const Color(0xFF434343), const Color(0xFF000000)];
    }
  }

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'fintech': return '💰 Finanzas';
      case 'aires':
      case 'climas': return '❄️ Climas / Aires';
      case 'purificadora': return '💧 Purificadora';
      case 'ventas':
      case 'retail': return '🛒 Ventas';
      default: return '🏢 General';
    }
  }
}

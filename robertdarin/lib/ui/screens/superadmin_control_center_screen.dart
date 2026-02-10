// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// ignore: unused_import
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';
import 'tarjetas_digitales_config_screen.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../navigation/app_routes.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unused_import
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centro de Control Total para Superadministrador
/// Control completo de: Temas, Fondos, Publicidad, Configuración Global
/// 
/// ARQUITECTURA DE NAVEGACIÓN:
/// ┌─────────────────────────────────────────────────────────┐
/// │                    DASHBOARD PRINCIPAL                   │
/// │  ┌───────────────────────────────────────────────────┐  │
/// │  │  Header + KPIs en Tiempo Real                     │  │
/// │  └───────────────────────────────────────────────────┘  │
/// │  ┌───────────┐ ┌───────────┐ ┌───────────┐            │
/// │  │ NEGOCIO   │ │ SISTEMA   │ │ MARKETING │            │
/// │  │ - Cartera │ │ - Config  │ │ - Promos  │            │
/// │  │ - Clientes│ │ - Temas   │ │ - Push    │            │
/// │  │ - Reportes│ │ - Fondos  │ │ - Banners │            │
/// │  └───────────┘ └───────────┘ └───────────┘            │
/// │  ┌───────────┐ ┌───────────┐ ┌───────────┐            │
/// │  │ FINANZAS  │ │ SEGURIDAD │ │ AVANZADO  │            │
/// │  │ - Tarjetas│ │ - Roles   │ │ - API     │            │
/// │  │ - Pagos   │ │ - Sesiones│ │ - Logs    │            │
/// │  │ - Stripe  │ │ - Backup  │ │ - Debug   │            │
/// │  └───────────┘ └───────────┘ └───────────┘            │
/// └─────────────────────────────────────────────────────────┘
class SuperadminControlCenterScreen extends StatefulWidget {
  const SuperadminControlCenterScreen({super.key});

  @override
  State<SuperadminControlCenterScreen> createState() =>
      _SuperadminControlCenterScreenState();
}

class _SuperadminControlCenterScreenState
    extends State<SuperadminControlCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = true;
  
  // Navegación por categorías
  String? _categoriaActiva;  // null = dashboard principal
  String? _seccionActiva;     // null = lista de categoría, o nombre de sección

  // Configuración global
  Map<String, dynamic> _configGlobal = {};
  List<Map<String, dynamic>> _temas = [];
  List<Map<String, dynamic>> _fondos = [];
  List<Map<String, dynamic>> _promociones = [];
  List<Map<String, dynamic>> _notificacionesMasivas = [];
  
  // KPIs en tiempo real
  int _totalPrestamos = 0;
  int _prestamosActivos = 0;
  int _prestamosEnMora = 0;
  double _carteraTotal = 0;
  double _carteraRecuperada = 0;
  int _totalClientes = 0;
  int _totalUsuarios = 0;
  int _tandasActivas = 0;
  
  // Búsqueda rápida
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _cargarDatos();
    _cargarKPIs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // DEFINICIÓN DE CATEGORÍAS Y MÓDULOS
  // ═══════════════════════════════════════════════════════════════════
  
  List<Map<String, dynamic>> get _categorias => [
    {
      'id': 'negocio',
      'nombre': 'Negocio',
      'descripcion': 'Cartera, clientes y métricas',
      'icono': Icons.business_center,
      'color': const Color(0xFF00D9FF),
      'modulos': [
        {'id': 'kpis', 'nombre': 'KPIs en Tiempo Real', 'icono': Icons.analytics, 'descripcion': 'Métricas de cartera y préstamos'},
        {'id': 'cartera', 'nombre': 'Análisis de Cartera', 'icono': Icons.account_balance_wallet, 'descripcion': 'Desglose de cartera total'},
        {'id': 'clientes_resumen', 'nombre': 'Resumen Clientes', 'icono': Icons.people, 'descripcion': 'Estado de clientes'},
        {'id': 'reportes_rapidos', 'nombre': 'Reportes Rápidos', 'icono': Icons.summarize, 'descripcion': 'Generar reportes'},
      ],
    },
    {
      'id': 'sistema',
      'nombre': 'Sistema',
      'descripcion': 'Configuración y apariencia',
      'icono': Icons.settings_applications,
      'color': const Color(0xFF8B5CF6),
      'modulos': [
        {'id': 'config_general', 'nombre': 'Configuración General', 'icono': Icons.tune, 'descripcion': 'Ajustes de la aplicación'},
        {'id': 'reglas_negocio', 'nombre': 'Reglas de Negocio', 'icono': Icons.rule, 'descripcion': 'Límites y parámetros'},
        {'id': 'temas', 'nombre': 'Temas y Colores', 'icono': Icons.palette, 'descripcion': 'Personalizar apariencia'},
        {'id': 'fondos', 'nombre': 'Fondos de Pantalla', 'icono': Icons.wallpaper, 'descripcion': 'Wallpapers de la app'},
        {'id': 'contacto', 'nombre': 'Contacto y Soporte', 'icono': Icons.support_agent, 'descripcion': 'Info de soporte'},
      ],
    },
    {
      'id': 'marketing',
      'nombre': 'Marketing',
      'descripcion': 'Promociones y comunicación',
      'icono': Icons.campaign,
      'color': const Color(0xFF10B981),
      'modulos': [
        {'id': 'promociones', 'nombre': 'Promociones', 'icono': Icons.local_offer, 'descripcion': 'Ofertas y banners'},
        {'id': 'notificaciones', 'nombre': 'Push Masivos', 'icono': Icons.notifications_active, 'descripcion': 'Enviar notificaciones'},
        {'id': 'historial_push', 'nombre': 'Historial de Push', 'icono': Icons.history, 'descripcion': 'Notificaciones enviadas'},
      ],
    },
    {
      'id': 'finanzas',
      'nombre': 'Finanzas',
      'descripcion': 'Pagos y tarjetas',
      'icono': Icons.account_balance,
      'color': const Color(0xFFF59E0B),
      'modulos': [
        {'id': 'tarjetas', 'nombre': 'Tarjetas Digitales', 'icono': Icons.credit_card, 'descripcion': 'Emisión de tarjetas'},
        {'id': 'stripe', 'nombre': 'Configuración Stripe', 'icono': Icons.payment, 'descripcion': 'Pasarela de pagos'},
        {'id': 'metodos_pago', 'nombre': 'Métodos de Pago', 'icono': Icons.account_balance_wallet, 'descripcion': 'Gestionar métodos'},
      ],
    },
    {
      'id': 'seguridad',
      'nombre': 'Seguridad',
      'descripcion': 'Accesos y respaldos',
      'icono': Icons.security,
      'color': const Color(0xFFEF4444),
      'modulos': [
        {'id': 'mantenimiento', 'nombre': 'Modo Mantenimiento', 'icono': Icons.engineering, 'descripcion': 'Activar/desactivar'},
        {'id': 'sesiones', 'nombre': 'Gestión de Sesiones', 'icono': Icons.devices, 'descripcion': 'Reiniciar sesiones'},
        {'id': 'backup', 'nombre': 'Respaldos', 'icono': Icons.backup, 'descripcion': 'Crear backup manual'},
        {'id': 'cache', 'nombre': 'Limpiar Caché', 'icono': Icons.cleaning_services, 'descripcion': 'Liberar memoria'},
      ],
    },
    {
      'id': 'tarjetas_presentacion',
      'nombre': 'Tarjetas QR',
      'descripcion': 'Tarjetas de presentación con QR',
      'icono': Icons.qr_code_2,
      'color': const Color(0xFFEC4899),
      'modulos': [
        {'id': 'mis_tarjetas_servicio', 'nombre': 'Mis Tarjetas', 'icono': Icons.style, 'descripcion': 'Crear y gestionar tarjetas'},
        {'id': 'estadisticas_qr', 'nombre': 'Estadísticas QR', 'icono': Icons.analytics, 'descripcion': 'Escaneos y métricas'},
        {'id': 'templates_tarjetas', 'nombre': 'Plantillas', 'icono': Icons.dashboard_customize, 'descripcion': 'Diseños disponibles'},
        {'id': 'landing_config', 'nombre': 'Landing Pages', 'icono': Icons.web, 'descripcion': 'Configurar páginas destino'},
      ],
    },
    {
      'id': 'avanzado',
      'nombre': 'Avanzado',
      'descripcion': 'Herramientas de desarrollo',
      'icono': Icons.code,
      'color': const Color(0xFF6366F1),
      'modulos': [
        {'id': 'test_notif', 'nombre': 'Test Notificación', 'icono': Icons.bug_report, 'descripcion': 'Enviar push de prueba'},
        {'id': 'estado_sistema', 'nombre': 'Estado del Sistema', 'icono': Icons.dns, 'descripcion': 'Estado de servicios'},
        {'id': 'auditoria', 'nombre': 'Logs de Auditoría', 'icono': Icons.history_edu, 'descripcion': 'Ver actividad'},
      ],
    },
  ];
  
  Future<void> _cargarKPIs() async {
    try {
      // Préstamos
      final prestamos = await AppSupabase.client.from('prestamos').select('id, monto, estado');
      final prestamosList = List<Map<String, dynamic>>.from(prestamos);
      
      int activos = 0;
      int enMora = 0;
      double cartera = 0;
      double recuperada = 0;
      
      for (var p in prestamosList) {
        final monto = (p['monto'] as num?)?.toDouble() ?? 0;
        cartera += monto;
        if (p['estado'] == 'activo') activos++;
        if (p['estado'] == 'mora' || p['estado'] == 'vencido') enMora++;
        if (p['estado'] == 'pagado' || p['estado'] == 'liquidado') recuperada += monto;
      }
      
      // Clientes
      final clientes = await AppSupabase.client.from('clientes').select('id');
      
      // Usuarios
      final usuarios = await AppSupabase.client.from('usuarios').select('id');
      
      // Tandas activas
      final tandas = await AppSupabase.client.from('tandas').select('id').eq('estado', 'activa');
      
      if (mounted) {
        setState(() {
          _totalPrestamos = prestamosList.length;
          _prestamosActivos = activos;
          _prestamosEnMora = enMora;
          _carteraTotal = cartera;
          _carteraRecuperada = recuperada;
          _totalClientes = (clientes as List).length;
          _totalUsuarios = (usuarios as List).length;
          _tandasActivas = (tandas as List).length;
        });
      }
    } catch (e) {
      debugPrint("Error cargando KPIs: $e");
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Cargar configuración global
      final config = await AppSupabase.client
          .from('configuracion_global')
          .select()
          .maybeSingle();

      // Cargar temas
      final temas =
          await AppSupabase.client.from('temas_app').select().order('nombre');

      // Cargar fondos de pantalla
      final fondos = await AppSupabase.client
          .from('fondos_pantalla')
          .select()
          .order('created_at', ascending: false);

      // Cargar promociones activas
      final promos = await AppSupabase.client
          .from('promociones')
          .select()
          .order('created_at', ascending: false);

      // Cargar notificaciones masivas
      final notifs = await AppSupabase.client
          .from('notificaciones_masivas')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _configGlobal = config ?? {};
        _temas = List<Map<String, dynamic>>.from(temas);
        _fondos = List<Map<String, dynamic>>.from(fondos);
        _promociones = List<Map<String, dynamic>>.from(promos);
        _notificacionesMasivas = List<Map<String, dynamic>>.from(notifs);
        _cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      setState(() => _cargando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVEGACIÓN - Lógica de breadcrumbs
  // ═══════════════════════════════════════════════════════════════════
  void _navegarAtras() {
    setState(() {
      if (_seccionActiva != null) {
        _seccionActiva = null;
      } else if (_categoriaActiva != null) {
        _categoriaActiva = null;
      } else {
        Navigator.pop(context);
      }
    });
  }
  
  String _getTitulo() {
    if (_seccionActiva != null) {
      // Buscar el nombre del módulo
      for (var cat in _categorias) {
        for (var mod in cat['modulos']) {
          if (mod['id'] == _seccionActiva) return mod['nombre'];
        }
      }
      return _seccionActiva!;
    }
    if (_categoriaActiva != null) {
      final cat = _categorias.firstWhere((c) => c['id'] == _categoriaActiva, orElse: () => {});
      return cat['nombre'] ?? 'Categoría';
    }
    return "Centro de Control";
  }
  
  String _getSubtitulo() {
    if (_seccionActiva != null) {
      final cat = _categorias.firstWhere((c) => c['id'] == _categoriaActiva, orElse: () => {});
      return cat['nombre'] ?? '';
    }
    if (_categoriaActiva != null) return "Selecciona un módulo";
    return "Panel Superadministrador";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _cargando
            ? _buildLoadingState()
            : _buildContenidoPrincipal(),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    final enMantenimiento = _configGlobal['modo_mantenimiento'] == true;
    
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          _categoriaActiva == null && _seccionActiva == null 
              ? Icons.arrow_back_ios_new 
              : Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: _navegarAtras,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _getTitulo(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_categoriaActiva != null || _seccionActiva != null)
                const Icon(Icons.chevron_right, size: 14, color: Colors.white38),
              Text(
                _getSubtitulo(),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Indicador de estado
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: enMantenimiento 
                ? Colors.redAccent.withOpacity(0.2) 
                : Colors.greenAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                enMantenimiento ? "Mant" : "Online",
                style: TextStyle(
                  color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 10, fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white54, size: 22),
          onPressed: () {
            _cargarDatos();
            _cargarKPIs();
          },
        ),
      ],
    );
  }
  
  Widget _buildContenidoPrincipal() {
    // Nivel 1: Dashboard principal con categorías
    if (_categoriaActiva == null && _seccionActiva == null) {
      return _buildDashboardPrincipal();
    }
    
    // Nivel 2: Lista de módulos de una categoría
    if (_categoriaActiva != null && _seccionActiva == null) {
      return _buildListaModulos();
    }
    
    // Nivel 3: Contenido de un módulo específico
    return _buildContenidoModulo();
  }

  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 1: DASHBOARD PRINCIPAL - Vista de Categorías
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDashboardPrincipal() {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER CON BIENVENIDA
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          
          // BARRA DE BÚSQUEDA RÁPIDA
          _buildSearchBar(),
          const SizedBox(height: 20),
          
          // KPIs EN TIEMPO REAL (Colapsable)
          _buildKPIsSection(currencyFormat),
          const SizedBox(height: 25),

          // TARJETA VISUAL: PROGRESO GLOBAL + INVERSION
          _buildProgresoInversionCard(currencyFormat),
          const SizedBox(height: 25),
          
          // CATEGORÍAS PRINCIPALES
          const Row(
            children: [
              Icon(Icons.apps, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Text("Módulos de Control", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Grid de categorías
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6, // Más compacto para ver todas las categorías
            ),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              return _buildCategoriaCard(cat);
            },
          ),
          
          const SizedBox(height: 25),
          
          // ACCESOS DIRECTOS FAVORITOS
          _buildAccesosDirectos(),
          
          const SizedBox(height: 20),
          
          // ESTADO DEL SISTEMA (compacto)
          _buildSystemStatusCompact(),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Buscar módulo, configuración o acción...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          if (value.isNotEmpty) _mostrarResultadosBusqueda(value);
        },
      ),
    );
  }
  
  void _mostrarResultadosBusqueda(String query) {
    final resultados = <Map<String, dynamic>>[];
    final q = query.toLowerCase();
    
    for (var cat in _categorias) {
      for (var mod in cat['modulos']) {
        if ((mod['nombre'] as String).toLowerCase().contains(q) ||
            (mod['descripcion'] as String).toLowerCase().contains(q)) {
          resultados.add({...mod, 'categoria': cat['id'], 'categoriaColor': cat['color']});
        }
      }
    }
    
    if (resultados.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: Colors.cyanAccent),
                const SizedBox(width: 10),
                Text("Resultados para \"$query\"", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            ...resultados.take(5).map((r) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (r['categoriaColor'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(r['icono'], color: r['categoriaColor'], size: 20),
              ),
              title: Text(r['nombre'], style: const TextStyle(color: Colors.white)),
              subtitle: Text(r['descripcion'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _categoriaActiva = r['categoria'];
                  _seccionActiva = r['id'];
                });
              },
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildKPIsSection(NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights, color: Colors.cyanAccent, size: 18),
            const SizedBox(width: 8),
            const Text("Métricas en Tiempo Real", 
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _categoriaActiva = 'negocio';
                  _seccionActiva = 'kpis';
                });
              },
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text("Ver más", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildKPIChip("Cartera", currencyFormat.format(_carteraTotal), Icons.account_balance_wallet, const Color(0xFF00D9FF)),
              const SizedBox(width: 10),
              _buildKPIChip("Activos", "$_prestamosActivos", Icons.trending_up, Colors.greenAccent),
              const SizedBox(width: 10),
              _buildKPIChip("Mora", "$_prestamosEnMora", Icons.warning_amber, _prestamosEnMora > 0 ? Colors.redAccent : Colors.grey),
              const SizedBox(width: 10),
              _buildKPIChip("Clientes", "$_totalClientes", Icons.people, Colors.purpleAccent),
              const SizedBox(width: 10),
              _buildKPIChip("Tandas", "$_tandasActivas", Icons.groups, Colors.orangeAccent),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildKPIChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoriaCard(Map<String, dynamic> cat) {
    final Color color = cat['color'];
    final int modulosCount = (cat['modulos'] as List).length;
    
    return InkWell(
      onTap: () => setState(() => _categoriaActiva = cat['id']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat['icono'], color: color, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("$modulosCount", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat['nombre'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(cat['descripcion'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccesosDirectos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
            SizedBox(width: 8),
            Text("Accesos Rápidos", 
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAccesoRapido("Mantenimiento", Icons.engineering, 
              _configGlobal['modo_mantenimiento'] == true ? Colors.redAccent : Colors.grey,
              _toggleModoMantenimiento),
            _buildAccesoRapido("Nuevo Push", Icons.send, Colors.blueAccent, 
              () => setState(() { _categoriaActiva = 'marketing'; _seccionActiva = 'notificaciones'; })),
            _buildAccesoRapido("Nueva Promo", Icons.local_offer, Colors.greenAccent,
              () => setState(() { _categoriaActiva = 'marketing'; _seccionActiva = 'promociones'; })),
            _buildAccesoRapido("Tarjetas", Icons.credit_card, Colors.pinkAccent,
              () => setState(() { _categoriaActiva = 'finanzas'; _seccionActiva = 'tarjetas'; })),
            _buildAccesoRapido("Temas", Icons.palette, Colors.purpleAccent,
              () => setState(() { _categoriaActiva = 'sistema'; _seccionActiva = 'temas'; })),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAccesoRapido(String texto, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 16),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemStatusCompact() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.dns, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sistema Operativo", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text("v${_configGlobal['version'] ?? '10.5'} • ${_temas.length} temas • ${_fondos.length} fondos", 
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                SizedBox(width: 4),
                Text("OK", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 2: LISTA DE MÓDULOS DE UNA CATEGORÍA
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListaModulos() {
    final cat = _categorias.firstWhere((c) => c['id'] == _categoriaActiva, orElse: () => _categorias[0]);
    final Color color = cat['color'];
    final List modulos = cat['modulos'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de categoría
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cat['icono'], color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat['nombre'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(cat['descripcion'], style: const TextStyle(color: Colors.white54)),
                      Text("${modulos.length} módulos disponibles", style: TextStyle(color: color, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Lista de módulos
          ...modulos.map((mod) => _buildModuloItem(mod, color)).toList(),
        ],
      ),
    );
  }
  
  Widget _buildModuloItem(Map<String, dynamic> mod, Color categoryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _seccionActiva = mod['id']),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(mod['icono'], color: categoryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mod['nombre'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(mod['descripcion'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: categoryColor.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 3: CONTENIDO DE MÓDULO ESPECÍFICO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildContenidoModulo() {
    switch (_seccionActiva) {
      // NEGOCIO
      case 'kpis':
        return _buildModuloKPIs();
      case 'cartera':
        return _buildModuloCartera();
      case 'clientes_resumen':
        return _buildModuloClientesResumen();
      case 'reportes_rapidos':
        return _buildModuloReportes();
      
      // SISTEMA
      case 'config_general':
        return _buildTabGeneral();
      case 'reglas_negocio':
        return _buildModuloReglasNegocio();
      case 'temas':
        return _buildTabTemas();
      case 'fondos':
        return _buildTabFondos();
      case 'contacto':
        return _buildModuloContacto();
      
      // MARKETING
      case 'promociones':
        return _buildTabPromociones();
      case 'notificaciones':
        return _buildTabNotificaciones();
      case 'historial_push':
        return _buildModuloHistorialPush();
      
      // FINANZAS
      case 'tarjetas':
        return _buildTabTarjetas();
      case 'stripe':
        return _buildModuloStripe();
      case 'metodos_pago':
        return _buildModuloMetodosPago();
      
      // SEGURIDAD
      case 'mantenimiento':
        return _buildModuloMantenimiento();
      case 'sesiones':
        return _buildModuloSesiones();
      case 'backup':
        return _buildModuloBackup();
      case 'cache':
        return _buildModuloCache();
      
      // TARJETAS DE PRESENTACIÓN QR
      case 'mis_tarjetas_servicio':
        return _buildModuloMisTarjetasServicio();
      case 'estadisticas_qr':
        return _buildModuloEstadisticasQR();
      case 'templates_tarjetas':
        return _buildModuloTemplatesTarjetas();
      case 'landing_config':
        return _buildModuloLandingConfig();
      
      // AVANZADO
      case 'test_notif':
        return _buildModuloTestNotif();
      case 'estado_sistema':
        return _buildModuloEstadoSistema();
      case 'auditoria':
        return _buildModuloAuditoria();
      
      default:
        return _buildTabGeneral();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - NEGOCIO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloKPIs() {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final porcentajeRecuperacion = _carteraTotal > 0 ? (_carteraRecuperada / _carteraTotal * 100) : 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cartera Total
          _buildKPICardGrande("Cartera Total", currencyFormat.format(_carteraTotal), Icons.account_balance_wallet, const Color(0xFF00D9FF), 
            "Capital total prestado en el sistema"),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildKPICard("Recuperado", currencyFormat.format(_carteraRecuperada), Icons.savings, Colors.greenAccent, "Préstamos pagados")),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard("Pendiente", currencyFormat.format(_carteraTotal - _carteraRecuperada), Icons.pending, Colors.orangeAccent, "Por cobrar")),
            ],
          ),
          const SizedBox(height: 12),
          
          // Barra de progreso de recuperación
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tasa de Recuperación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: porcentajeRecuperacion / 100,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(porcentajeRecuperacion > 70 ? Colors.greenAccent : Colors.orangeAccent),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Text("${porcentajeRecuperacion.toStringAsFixed(1)}% del capital recuperado", 
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildKPICard("Préstamos", "$_totalPrestamos", Icons.receipt_long, Colors.purpleAccent, "$_prestamosActivos activos")),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard("En Mora", "$_prestamosEnMora", Icons.warning_amber, _prestamosEnMora > 0 ? Colors.redAccent : Colors.grey, "Requieren atención")),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildKPICard("Clientes", "$_totalClientes", Icons.people, Colors.blueAccent, "$_totalUsuarios usuarios")),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard("Tandas", "$_tandasActivas", Icons.groups, Colors.tealAccent, "Activas")),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildKPICardGrande(String titulo, String valor, IconData icono, Color color, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 40),
          const SizedBox(height: 12),
          Text(valor, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildModuloCartera() {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final carteraPendiente = _carteraTotal - _carteraRecuperada;
    final porcentajeMora = _totalPrestamos > 0 ? (_prestamosEnMora / _totalPrestamos * 100) : 0.0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con total de cartera
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00D9FF).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet, color: Color(0xFF00D9FF), size: 40),
                const SizedBox(height: 10),
                Text(currencyFormat.format(_carteraTotal), 
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Cartera Total Colocada", style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Desglose de cartera
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Desglose de Cartera", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildCarteraItem("Capital Recuperado", currencyFormat.format(_carteraRecuperada), Colors.greenAccent, Icons.check_circle),
                _buildCarteraItem("Capital Pendiente", currencyFormat.format(carteraPendiente), Colors.orangeAccent, Icons.pending),
                _buildCarteraItem("En Mora ($_prestamosEnMora)", "${porcentajeMora.toStringAsFixed(1)}% de préstamos", Colors.redAccent, Icons.warning),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Acciones rápidas
          Row(
            children: [
              Expanded(
                child: _buildAccionCartera("Ver Préstamos", Icons.receipt_long, Colors.purpleAccent, 
                  () => Navigator.pushNamed(context, '/prestamos')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccionCartera("Ver Reportes", Icons.analytics, Colors.blueAccent, 
                  () => Navigator.pushNamed(context, '/reportes')),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCarteraItem(String titulo, String valor, Color color, IconData icono) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: const TextStyle(color: Colors.white70))),
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildAccionCartera(String texto, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(height: 8),
            Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModuloClientesResumen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KPI de clientes
          Row(
            children: [
              Expanded(child: _buildClienteKPI("Total", "$_totalClientes", Icons.people, Colors.cyanAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildClienteKPI("Usuarios", "$_totalUsuarios", Icons.account_circle, Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Estadísticas rápidas
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Estadísticas de Clientes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildEstadisticaCliente("Clientes con préstamo activo", "$_prestamosActivos", Colors.greenAccent),
                _buildEstadisticaCliente("Clientes en mora", "$_prestamosEnMora", Colors.redAccent),
                _buildEstadisticaCliente("Tandas activas", "$_tandasActivas", Colors.orangeAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Acceso rápido
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/clientes'),
              icon: const Icon(Icons.open_in_new),
              label: const Text("Ver Todos los Clientes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClienteKPI(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildEstadisticaCliente(String titulo, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloReportes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.summarize, color: Colors.blueAccent, size: 40),
                SizedBox(height: 10),
                Text("Reportes Rápidos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Genera reportes instantáneos", style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Opciones de reportes
          _buildReporteOption("Reporte de Cartera", "Estado actual de préstamos", Icons.account_balance_wallet, Colors.cyanAccent,
            () => Navigator.pushNamed(context, '/reportes')),
          _buildReporteOption("Reporte de Cobranza", "Pagos del día/semana/mes", Icons.payments, Colors.greenAccent,
            () => Navigator.pushNamed(context, '/reportes')),
          _buildReporteOption("Reporte de Clientes", "Lista de clientes activos", Icons.people, Colors.purpleAccent,
            () => Navigator.pushNamed(context, '/reportes')),
          _buildReporteOption("Reporte de Mora", "Préstamos vencidos", Icons.warning_amber, Colors.redAccent,
            () => Navigator.pushNamed(context, '/moras')),
          _buildReporteOption("Dashboard KPIs", "Métricas detalladas", Icons.analytics, Colors.orangeAccent,
            () => Navigator.pushNamed(context, '/dashboardKpi')),
        ],
      ),
    );
  }
  
  Widget _buildReporteOption(String titulo, String descripcion, IconData icono, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - SISTEMA
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloReglasNegocio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rule, color: Colors.orangeAccent),
                SizedBox(width: 10),
                Text("Reglas de Negocio", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24),
            _buildConfigItem("Máx. Avales por Préstamo", '${_configGlobal['max_avales_prestamo'] ?? 3}', Icons.people,
              () => _editarConfiguracion('max_avales_prestamo', 'Máximo de Avales por Préstamo', isNumber: true)),
            _buildConfigItem("Máx. Avales por Tanda", '${_configGlobal['max_avales_tanda'] ?? 2}', Icons.group,
              () => _editarConfiguracion('max_avales_tanda', 'Máximo de Avales por Tanda', isNumber: true)),
            _buildConfigItem("Monto Mín. Préstamo", '\$${_configGlobal['monto_min_prestamo'] ?? 1000}', Icons.attach_money,
              () => _editarConfiguracion('monto_min_prestamo', 'Monto Mínimo de Préstamo', isNumber: true)),
            _buildConfigItem("Monto Máx. Préstamo", '\$${_configGlobal['monto_max_prestamo'] ?? 500000}', Icons.money,
              () => _editarConfiguracion('monto_max_prestamo', 'Monto Máximo de Préstamo', isNumber: true)),
            _buildConfigItem("Interés Default (%)", '${_configGlobal['interes_default'] ?? 10}%', Icons.percent,
              () => _editarConfiguracion('interes_default', 'Interés por Defecto', isNumber: true)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModuloContacto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.support_agent, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text("Contacto y Soporte", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24),
            _buildConfigItem("Email de Soporte", _configGlobal['email_soporte'] ?? 'soporte@robertdarin.com', Icons.email,
              () => _editarConfiguracion('email_soporte', 'Email de Soporte')),
            _buildConfigItem("Teléfono Soporte", _configGlobal['telefono_soporte'] ?? '+52 555 123 4567', Icons.phone,
              () => _editarConfiguracion('telefono_soporte', 'Teléfono de Soporte')),
            _buildConfigItem("WhatsApp", _configGlobal['whatsapp'] ?? '+52 555 123 4567', Icons.chat,
              () => _editarConfiguracion('whatsapp', 'WhatsApp de Soporte')),
          ],
        ),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - MARKETING
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloHistorialPush() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.white54),
                SizedBox(width: 10),
                Text("Historial de Notificaciones", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24),
            _notificacionesMasivas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text("No hay notificaciones enviadas", style: TextStyle(color: Colors.white54))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notificacionesMasivas.length,
                    itemBuilder: (context, index) => _buildNotificacionHistorial(_notificacionesMasivas[index]),
                  ),
          ],
        ),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - FINANZAS (Ahora con Centro Unificado)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloStripe() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Banner principal del Centro de Pagos
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E3A8A).withOpacity(0.4), const Color(0xFF7C3AED).withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.attach_money, color: Colors.greenAccent, size: 30),
                    SizedBox(width: 10),
                    Icon(Icons.credit_card, color: Colors.cyanAccent, size: 30),
                  ],
                ),
                const SizedBox(height: 15),
                const Text("Centro de Pagos y Tarjetas", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Todo lo relacionado con cobros a clientes y emisión de tarjetas digitales en un solo lugar.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/centro-pagos-tarjetas'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Abrir Centro de Pagos"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Explicación rápida
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 10),
                    Text("¿Qué incluye?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildExplicacionItem("💰 Cobrar a Clientes", "Links de pago, OXXO, SPEI, tarjetas", Colors.greenAccent),
                _buildExplicacionItem("💳 Tarjetas Digitales", "Emite tarjetas virtuales para clientes", Colors.cyanAccent),
                _buildExplicacionItem("⚙️ Configuración", "Stripe, Pomelo, Rapyd y más proveedores", Colors.purpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExplicacionItem(String titulo, String descripcion, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloMetodosPago() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Métodos de Pago Habilitados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),
                _buildMetodoPagoItem("Efectivo", Icons.money, true),
                _buildMetodoPagoItem("Transferencia", Icons.swap_horiz, true),
                _buildMetodoPagoItem("Tarjeta (Stripe)", Icons.credit_card, _configGlobal['stripe_habilitado'] == true),
                _buildMetodoPagoItem("SPEI", Icons.account_balance, true),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/centro-pagos-tarjetas'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text("Configurar en Centro de Pagos"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
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
  
  Widget _buildMetodoPagoItem(String nombre, IconData icon, bool activo) {
    return ListTile(
      leading: Icon(icon, color: activo ? Colors.greenAccent : Colors.grey),
      title: Text(nombre, style: const TextStyle(color: Colors.white)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: activo ? Colors.greenAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          activo ? "Activo" : "Inactivo",
          style: TextStyle(
            color: activo ? Colors.greenAccent : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - SEGURIDAD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloMantenimiento() {
    final enMantenimiento = _configGlobal['modo_mantenimiento'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enMantenimiento 
                    ? [Colors.redAccent.withOpacity(0.3), Colors.redAccent.withOpacity(0.1)]
                    : [Colors.greenAccent.withOpacity(0.3), Colors.greenAccent.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(enMantenimiento ? Icons.engineering : Icons.check_circle, 
                  color: enMantenimiento ? Colors.redAccent : Colors.greenAccent, size: 60),
                const SizedBox(height: 15),
                Text(enMantenimiento ? "EN MANTENIMIENTO" : "SISTEMA OPERATIVO", 
                  style: TextStyle(color: enMantenimiento ? Colors.redAccent : Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(enMantenimiento 
                    ? "Los usuarios no pueden acceder a la app" 
                    : "Todo funciona con normalidad", 
                  style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  onPressed: _toggleModoMantenimiento,
                  icon: Icon(enMantenimiento ? Icons.play_arrow : Icons.pause),
                  label: Text(enMantenimiento ? "Desactivar Mantenimiento" : "Activar Mantenimiento"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enMantenimiento ? Colors.greenAccent : Colors.redAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloSesiones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumCard(
            child: Column(
              children: [
                const Icon(Icons.devices, color: Colors.orangeAccent, size: 50),
                const SizedBox(height: 15),
                const Text("Gestión de Sesiones", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Reiniciar todas las sesiones activas excepto la tuya.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _reiniciarSesiones,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reiniciar Sesiones"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloBackup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumCard(
            child: Column(
              children: [
                const Icon(Icons.backup, color: Colors.greenAccent, size: 50),
                const SizedBox(height: 15),
                const Text("Respaldos del Sistema", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Crear un punto de respaldo manual del sistema.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _backupManual,
                  icon: const Icon(Icons.save),
                  label: const Text("Crear Backup Ahora"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloCache() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumCard(
            child: Column(
              children: [
                const Icon(Icons.cleaning_services, color: Colors.blueAccent, size: 50),
                const SizedBox(height: 15),
                const Text("Limpiar Caché", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Liberar memoria limpiando el caché de imágenes.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _limpiarCache,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text("Limpiar Ahora"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS NUEVOS - AVANZADO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildModuloTestNotif() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumCard(
            child: Column(
              children: [
                const Icon(Icons.bug_report, color: Colors.purpleAccent, size: 50),
                const SizedBox(height: 15),
                const Text("Test de Notificaciones", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Enviar una notificación de prueba a tu cuenta.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _enviarNotificacionTest,
                  icon: const Icon(Icons.send),
                  label: const Text("Enviar Test"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModuloEstadoSistema() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSystemStatus(),
        ],
      ),
    );
  }
  
  Widget _buildModuloAuditoria() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_edu, color: Colors.amber, size: 40),
                SizedBox(height: 10),
                Text("Logs de Auditoría", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Historial de actividad del sistema", style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Accesos rápidos a auditoría
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.manage_search, color: Colors.white54, size: 20),
                    SizedBox(width: 10),
                    Text("Tipos de Auditoría", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildAuditoriaOption("Auditoría General", "Todas las acciones del sistema", Icons.list_alt, Colors.cyanAccent,
                  () => Navigator.pushNamed(context, '/auditoria')),
                _buildAuditoriaOption("Auditoría Legal", "Expedientes judiciales y cobranza", Icons.gavel, Colors.redAccent,
                  () => Navigator.pushNamed(context, '/auditoriaLegal')),
                _buildAuditoriaOption("Logs de Sesión", "Inicios de sesión de usuarios", Icons.login, Colors.greenAccent,
                  () => Navigator.pushNamed(context, '/auditoria')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Botón principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/auditoria'),
              icon: const Icon(Icons.open_in_new),
              label: const Text("Abrir Auditoría Completa"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAuditoriaOption(String titulo, String descripcion, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final enMantenimiento = _configGlobal['modo_mantenimiento'] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            enMantenimiento 
                ? Colors.redAccent.withOpacity(0.1) 
                : Colors.cyanAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enMantenimiento 
              ? Colors.redAccent.withOpacity(0.3) 
              : Colors.cyanAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.cyanAccent, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bienvenido, Superadmin",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("${DateFormat('EEEE dd MMM yyyy', 'es').format(DateTime.now())}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enMantenimiento
                  ? Colors.redAccent.withOpacity(0.2)
                  : Colors.greenAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enMantenimiento ? Icons.engineering : Icons.check_circle,
                  color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  enMantenimiento ? "Mant." : "Online",
                  style: TextStyle(
                    color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String titulo, String valor, IconData icono, Color color, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icono, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text(subtitulo, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildModuloCard(String titulo, String descripcion, IconData icono, Color color, String seccion) {
    return InkWell(
      onTap: () => setState(() => _seccionActiva = seccion),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String texto, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(width: 8),
            Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dns, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text("Estado del Sistema", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          _buildStatusRow("Base de Datos", "Conectada", Colors.greenAccent, Icons.check_circle),
          _buildStatusRow("API", "Operativa", Colors.greenAccent, Icons.check_circle),
          _buildStatusRow("Versión", _configGlobal['version'] ?? '1.0.0', Colors.cyanAccent, Icons.info_outline),
          _buildStatusRow("Temas Activos", "${_temas.length}", Colors.purpleAccent, Icons.palette),
          _buildStatusRow("Fondos Cargados", "${_fondos.length}", Colors.orangeAccent, Icons.wallpaper),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENIDO DE SECCIONES (usa los tabs existentes)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSeccionContenido() {
    switch (_seccionActiva) {
      case "General":
        return _buildTabGeneral();
      case "Temas":
        return _buildTabTemas();
      case "Fondos":
        return _buildTabFondos();
      case "Promos":
        return _buildTabPromociones();
      case "Push":
        return _buildTabNotificaciones();
      case "Tarjetas":
        return _buildTabTarjetas();
      default:
        return _buildTabGeneral();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER CON ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            Colors.cyanAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.cyanAccent, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bienvenido, Superadmin",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Control total del sistema • ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStatusIndicator(),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildMiniStat("Temas", "${_temas.length}", Icons.palette,
                  Colors.purpleAccent),
              _buildMiniStat("Fondos", "${_fondos.length}", Icons.wallpaper,
                  Colors.orangeAccent),
              _buildMiniStat("Promos", "${_promociones.length}",
                  Icons.local_offer, Colors.greenAccent),
              _buildMiniStat("Push", "${_notificacionesMasivas.length}",
                  Icons.notifications, Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final enMantenimiento = _configGlobal['modo_mantenimiento'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: enMantenimiento
            ? Colors.redAccent.withOpacity(0.2)
            : Colors.greenAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: enMantenimiento ? Colors.redAccent : Colors.greenAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enMantenimiento ? Icons.engineering : Icons.check_circle,
            color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            enMantenimiento ? "Mantenimiento" : "Operativo",
            style: TextStyle(
              color: enMantenimiento ? Colors.redAccent : Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.cyanAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Cargando configuraciones...",
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 6: TARJETAS DIGITALES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabTarjetas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Banner principal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.3),
                  Colors.blue.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.credit_card, color: Colors.white, size: 50),
                const SizedBox(height: 15),
                const Text(
                  "Tarjetas Digitales para Clientes",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Emite tarjetas virtuales y físicas para tus clientes. Configura proveedores como Stripe, Pomelo, Rapyd y más.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TarjetasDigitalesConfigScreen()),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text("Configurar Proveedores"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Opciones rápidas
          Row(
            children: [
              Expanded(
                  child: _buildTarjetaOption(
                "Emitir Tarjeta",
                "Nueva tarjeta virtual",
                Icons.add_card,
                Colors.greenAccent,
                () => _emitirTarjeta(),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildTarjetaOption(
                "Ver Tarjetas",
                "Listado de tarjetas",
                Icons.credit_score,
                Colors.blueAccent,
                () => _verTarjetas(),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildTarjetaOption(
                "Bloquear",
                "Bloquear tarjeta",
                Icons.block,
                Colors.orangeAccent,
                () => _bloquearTarjeta(),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildTarjetaOption(
                "Reportes",
                "Transacciones",
                Icons.receipt_long,
                Colors.cyanAccent,
                () => _reportesTarjetas(),
              )),
            ],
          ),

          const SizedBox(height: 20),

          // Info de proveedores
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.integration_instructions,
                        color: Colors.purpleAccent),
                    SizedBox(width: 10),
                    Text("Proveedores Soportados",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildProveedorItem(
                    "💳 Stripe Issuing", "Global - USD, EUR, MXN", true),
                _buildProveedorItem(
                    "🍋 Pomelo", "LATAM - MXN, ARS, COP", false),
                _buildProveedorItem("🌐 Rapyd", "Global - Multi-moneda", false),
                _buildProveedorItem("🇲🇽 STP + Carnet", "México - MXN", false),
                _buildProveedorItem("🏦 Openpay (BBVA)", "México - MXN", false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaOption(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildProveedorItem(String nombre, String info, bool activo) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(nombre, style: const TextStyle(color: Colors.white)),
      subtitle: Text(info,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: activo
          ? const Chip(
              label: Text("Activo", style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.greenAccent,
              labelStyle: TextStyle(color: Colors.black),
            )
          : const Chip(
              label: Text("Disponible", style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.white24,
            ),
    );
  }

  void _emitirTarjeta() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Abriendo formulario de emisión..."),
          backgroundColor: Colors.green),
    );
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const TarjetasDigitalesConfigScreen()));
  }

  void _verTarjetas() {
    Navigator.pushNamed(context, '/tarjetas');
  }

  void _bloquearTarjeta() {
    final TextEditingController busquedaController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Bloquear Tarjeta", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ingresa el número de tarjeta, ID del cliente o nombre para buscar y bloquear.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: busquedaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ej: **** 1234 o nombre del cliente",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final query = busquedaController.text.trim();
              if (query.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa un término de búsqueda"), backgroundColor: Colors.orange),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // Buscar tarjetas que coincidan
              try {
                final tarjetas = await AppSupabase.client
                    .from('tarjetas_digitales')
                    .select('*, clientes(nombre)')
                    .or('ultimos_cuatro.ilike.%$query%,clientes.nombre.ilike.%$query%')
                    .limit(10);
                
                if (!mounted) return;
                
                if ((tarjetas as List).isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No se encontraron tarjetas"), backgroundColor: Colors.orange),
                  );
                  return;
                }
                
                // Mostrar lista de tarjetas encontradas para seleccionar
                _mostrarListaTarjetasParaBloquear(List<Map<String, dynamic>>.from(tarjetas));
              } catch (e) {
                debugPrint('Error buscando tarjetas: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            child: const Text("Buscar"),
          ),
        ],
      ),
    );
  }
  
  void _mostrarListaTarjetasParaBloquear(List<Map<String, dynamic>> tarjetas) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.credit_card, color: Colors.orangeAccent),
                SizedBox(width: 10),
                Text("Selecciona tarjeta a bloquear", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            ...tarjetas.map((tarjeta) {
              final clienteNombre = tarjeta['clientes']?['nombre'] ?? 'Sin cliente';
              final ultimos4 = tarjeta['ultimos_cuatro'] ?? '****';
              final estado = tarjeta['estado'] ?? 'activa';
              final bloqueada = estado == 'bloqueada';
              
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bloqueada ? Colors.grey.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: bloqueada ? Colors.grey : Colors.blueAccent,
                  ),
                ),
                title: Text("**** **** **** $ultimos4", style: const TextStyle(color: Colors.white)),
                subtitle: Text(clienteNombre, style: const TextStyle(color: Colors.white54)),
                trailing: bloqueada
                    ? const Chip(label: Text("Bloqueada", style: TextStyle(fontSize: 10)), backgroundColor: Colors.grey)
                    : ElevatedButton(
                        onPressed: () => _confirmarBloqueoTarjeta(tarjeta['id'], ultimos4, clienteNombre),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text("Bloquear", style: TextStyle(fontSize: 12)),
                      ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  void _confirmarBloqueoTarjeta(String tarjetaId, String ultimos4, String clienteNombre) async {
    Navigator.pop(context); // Cerrar bottom sheet
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("⚠️ Confirmar Bloqueo", style: TextStyle(color: Colors.white)),
        content: Text(
          "¿Estás seguro de bloquear la tarjeta **** $ultimos4 de $clienteNombre?\n\nEsta acción se puede revertir desde la pantalla de tarjetas.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Sí, Bloquear"),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      await AppSupabase.client.from('tarjetas_digitales').update({
        'estado': 'bloqueada',
        'bloqueada_por': AppSupabase.client.auth.currentUser?.id,
        'fecha_bloqueo': DateTime.now().toIso8601String(),
      }).eq('id', tarjetaId);
      
      // Registrar en auditoría
      await AppSupabase.client.from('auditoria').insert({
        'usuario_id': AppSupabase.client.auth.currentUser?.id,
        'accion': 'BLOQUEO_TARJETA',
        'tabla_afectada': 'tarjetas_digitales',
        'registro_id': tarjetaId,
        'descripcion': 'Tarjeta **** $ultimos4 de $clienteNombre bloqueada por superadmin',
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🔒 Tarjeta **** $ultimos4 bloqueada exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _reportesTarjetas() {
    Navigator.pushNamed(context, '/tarjetas');
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: CONFIGURACIÓN GENERAL
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabGeneral() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configuración de la App
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.app_settings_alt, color: Colors.cyanAccent),
                    SizedBox(width: 10),
                    Text("Configuración de la Aplicación",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildConfigItem(
                  "Nombre de la App",
                  _configGlobal['nombre_app'] ?? 'Robert Darin Fintech',
                  Icons.business,
                  () => _editarConfiguracion('nombre_app', 'Nombre de la App'),
                ),
                _buildConfigItem(
                  "Versión",
                  _configGlobal['version'] ?? '6.1.0',
                  Icons.info_outline,
                  () => _editarConfiguracion('version', 'Versión'),
                ),
                _buildConfigItem(
                  "Modo Mantenimiento",
                  _configGlobal['modo_mantenimiento'] == true
                      ? 'Activo'
                      : 'Inactivo',
                  Icons.build,
                  () => _toggleModoMantenimiento(),
                  color: _configGlobal['modo_mantenimiento'] == true
                      ? Colors.redAccent
                      : Colors.greenAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Límites y Reglas
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rule, color: Colors.orangeAccent),
                    SizedBox(width: 10),
                    Text("Límites y Reglas de Negocio",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildConfigItem(
                  "Máx. Avales por Préstamo",
                  '${_configGlobal['max_avales_prestamo'] ?? 3}',
                  Icons.people,
                  () => _editarConfiguracion(
                      'max_avales_prestamo', 'Máximo de Avales por Préstamo',
                      isNumber: true),
                ),
                _buildConfigItem(
                  "Máx. Avales por Tanda",
                  '${_configGlobal['max_avales_tanda'] ?? 2}',
                  Icons.group,
                  () => _editarConfiguracion(
                      'max_avales_tanda', 'Máximo de Avales por Tanda',
                      isNumber: true),
                ),
                _buildConfigItem(
                  "Monto Mín. Préstamo",
                  '\$${_configGlobal['monto_min_prestamo'] ?? 1000}',
                  Icons.attach_money,
                  () => _editarConfiguracion(
                      'monto_min_prestamo', 'Monto Mínimo de Préstamo',
                      isNumber: true),
                ),
                _buildConfigItem(
                  "Monto Máx. Préstamo",
                  '\$${_configGlobal['monto_max_prestamo'] ?? 500000}',
                  Icons.money,
                  () => _editarConfiguracion(
                      'monto_max_prestamo', 'Monto Máximo de Préstamo',
                      isNumber: true),
                ),
                _buildConfigItem(
                  "Interés Default (%)",
                  '${_configGlobal['interes_default'] ?? 10}%',
                  Icons.percent,
                  () => _editarConfiguracion(
                      'interes_default', 'Interés por Defecto',
                      isNumber: true),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Contacto y Soporte
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.greenAccent),
                    SizedBox(width: 10),
                    Text("Contacto y Soporte",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildConfigItem(
                  "Email de Soporte",
                  _configGlobal['email_soporte'] ?? 'soporte@robertdarin.com',
                  Icons.email,
                  () =>
                      _editarConfiguracion('email_soporte', 'Email de Soporte'),
                ),
                _buildConfigItem(
                  "Teléfono Soporte",
                  _configGlobal['telefono_soporte'] ?? '+52 555 123 4567',
                  Icons.phone,
                  () => _editarConfiguracion(
                      'telefono_soporte', 'Teléfono de Soporte'),
                ),
                _buildConfigItem(
                  "WhatsApp",
                  _configGlobal['whatsapp'] ?? '+52 555 123 4567',
                  Icons.chat,
                  () => _editarConfiguracion('whatsapp', 'WhatsApp de Soporte'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Acciones Rápidas
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.amberAccent),
                    SizedBox(width: 10),
                    Text("Acciones Rápidas",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildQuickAction("Limpiar Caché", Icons.cleaning_services,
                        Colors.blueAccent, _limpiarCache),
                    _buildQuickAction("Backup Manual", Icons.backup,
                        Colors.greenAccent, _backupManual),
                    _buildQuickAction("Reiniciar Sesiones", Icons.refresh,
                        Colors.orangeAccent, _reiniciarSesiones),
                    _buildQuickAction("Enviar Test", Icons.send,
                        Colors.purpleAccent, _enviarNotificacionTest),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildConfigItem(
      String label, String value, IconData icon, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.white54),
      title: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
      subtitle: Text(value,
          style: TextStyle(
              color: color ?? Colors.white, fontWeight: FontWeight.bold)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 18),
        onPressed: onTap,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: TEMAS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabTemas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Tema activo
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.color_lens, color: Colors.purpleAccent),
                    const SizedBox(width: 10),
                    const Text("Tema Activo",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _crearTema(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Nuevo Tema"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Grid de temas
                _temas.isEmpty
                    ? const Center(
                        child: Text("No hay temas configurados",
                            style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _temas.length,
                        itemBuilder: (context, index) {
                          final tema = _temas[index];
                          final esActivo = tema['activo'] == true;
                          final temaId = tema['id']?.toString() ?? '';
                          return GestureDetector(
                            onTap: temaId.isNotEmpty 
                                ? () => _activarTema(temaId)
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(int.parse(tema['color_primario']
                                            ?.replaceFirst('#', '0xFF') ??
                                        '0xFF1E1E2C')),
                                    Color(int.parse(tema['color_secundario']
                                            ?.replaceFirst('#', '0xFF') ??
                                        '0xFF2D2D44')),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: esActivo
                                    ? Border.all(
                                        color: Colors.greenAccent, width: 3)
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    right: 10,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tema['nombre'] ?? 'Sin nombre',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        if (esActivo)
                                          const Text("✓ Activo",
                                              style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.white54, size: 18),
                                      color: const Color(0xFF2D2D44),
                                      onSelected: (v) {
                                        if (v == 'editar') _editarTema(tema);
                                        if (v == 'eliminar' && temaId.isNotEmpty)
                                          _eliminarTema(temaId);
                                      },
                                      itemBuilder: (c) => [
                                        const PopupMenuItem(
                                            value: 'editar',
                                            child: Text('Editar',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        const PopupMenuItem(
                                            value: 'eliminar',
                                            child: Text('Eliminar',
                                                style: TextStyle(
                                                    color: Colors.redAccent))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Colores personalizados
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_paint, color: Colors.cyanAccent),
                    SizedBox(width: 10),
                    Text("Colores Personalizados",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _buildColorPicker("Acento Principal",
                    _configGlobal['color_acento'] ?? '#00BCD4'),
                _buildColorPicker("Botones Primarios",
                    _configGlobal['color_botones'] ?? '#4CAF50'),
                _buildColorPicker(
                    "Alertas", _configGlobal['color_alertas'] ?? '#FF5722'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(String label, String colorHex) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(int.parse(colorHex.replaceFirst('#', '0xFF'))),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(colorHex,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 18),
        onPressed: () => _seleccionarColor(label, colorHex),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 3: FONDOS DE PANTALLA
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabFondos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Subir nuevo fondo
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_photo_alternate,
                        color: Colors.pinkAccent),
                    const SizedBox(width: 10),
                    const Text("Fondos de Pantalla",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _subirFondo(),
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text("Subir Fondo"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Grid de fondos
                _fondos.isEmpty
                    ? Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wallpaper,
                                size: 50, color: Colors.white24),
                            SizedBox(height: 10),
                            Text("No hay fondos subidos",
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _fondos.length,
                        itemBuilder: (context, index) {
                          final fondo = _fondos[index];
                          final esActivo = fondo['activo'] == true;
                          return GestureDetector(
                            onTap: () => _activarFondo(fondo['id']),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    fondo['url'] ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.white38),
                                    ),
                                  ),
                                ),
                                if (esActivo)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check,
                                          color: Colors.black, size: 14),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                          bottom: Radius.circular(8)),
                                    ),
                                    child: Text(
                                      fondo['nombre'] ?? 'Fondo ${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Configuración de fondos
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Colors.orangeAccent),
                    SizedBox(width: 10),
                    Text("Configuración de Fondos",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                SwitchListTile(
                  title: const Text("Fondos Inteligentes",
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Cambiar fondo según hora del día",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _configGlobal['fondos_inteligentes'] ?? false,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => _toggleFondosInteligentes(v),
                ),
                SwitchListTile(
                  title: const Text("Fondos por Rol",
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      "Diferente fondo para cada tipo de usuario",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _configGlobal['fondos_por_rol'] ?? false,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => _toggleFondosPorRol(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 4: PROMOCIONES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabPromociones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Crear nueva promoción
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, color: Colors.amberAccent),
                    const SizedBox(width: 10),
                    const Text("Promociones y Ofertas",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _crearPromocion(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Nueva Promoción"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Lista de promociones
                _promociones.isEmpty
                    ? Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: const Text("No hay promociones activas",
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _promociones.length,
                        itemBuilder: (context, index) {
                          final promo = _promociones[index];
                          return _buildPromocionCard(promo);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromocionCard(Map<String, dynamic> promo) {
    final activa = promo['activa'] == true;
    final fechaFin =
        promo['fecha_fin'] != null ? DateTime.parse(promo['fecha_fin']) : null;
    final expirada = fechaFin != null && fechaFin.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expirada
              ? Colors.redAccent.withOpacity(0.3)
              : activa
                  ? Colors.greenAccent.withOpacity(0.3)
                  : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activa
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  activa ? (expirada ? 'EXPIRADA' : 'ACTIVA') : 'INACTIVA',
                  style: TextStyle(
                    color: expirada
                        ? Colors.redAccent
                        : activa
                            ? Colors.greenAccent
                            : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon:
                    const Icon(Icons.edit, color: Colors.cyanAccent, size: 18),
                onPressed: () => _editarPromocion(promo),
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                onPressed: () => _eliminarPromocion(promo['id']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(promo['titulo'] ?? 'Sin título',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(promo['descripcion'] ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.link, color: Colors.blueAccent, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(promo['ruta_destino'] ?? '/dashboard',
                    style: const TextStyle(
                        color: Colors.blueAccent, fontSize: 11)),
              ),
              if (fechaFin != null)
                Text('Hasta: ${DateFormat('dd/MM/yy').format(fechaFin)}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 5: NOTIFICACIONES MASIVAS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabNotificaciones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Enviar nueva notificación
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Colors.redAccent),
                    const SizedBox(width: 10),
                    const Text("Enviar Notificación Masiva",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // Botones rápidos
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildNotifQuickButton(
                      "📢 Anuncio General",
                      Colors.blueAccent,
                      () => _enviarNotificacionPersonalizada(tipo: 'anuncio'),
                    ),
                    _buildNotifQuickButton(
                      "🔄 Invitar a Tanda",
                      Colors.orangeAccent,
                      () => _enviarNotificacionPersonalizada(
                          tipo: 'tanda', rutaDestino: '/tandas'),
                    ),
                    _buildNotifQuickButton(
                      "💰 Oferta de Préstamo",
                      Colors.greenAccent,
                      () => _enviarNotificacionPersonalizada(
                          tipo: 'prestamo', rutaDestino: '/prestamos'),
                    ),
                    _buildNotifQuickButton(
                      "🎉 Promoción Especial",
                      Colors.purpleAccent,
                      () => _enviarNotificacionPersonalizada(tipo: 'promocion'),
                    ),
                    _buildNotifQuickButton(
                      "⚠️ Aviso Importante",
                      Colors.amberAccent,
                      () => _enviarNotificacionPersonalizada(tipo: 'aviso'),
                    ),
                    _buildNotifQuickButton(
                      "✍️ Mensaje Personalizado",
                      Colors.cyanAccent,
                      () => _enviarNotificacionPersonalizada(
                          tipo: 'personalizado'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Historial de notificaciones
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: Colors.white54),
                    SizedBox(width: 10),
                    Text("Historial de Notificaciones",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white24),
                _notificacionesMasivas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                            child: Text("No hay notificaciones enviadas",
                                style: TextStyle(color: Colors.white54))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notificacionesMasivas.length > 10
                            ? 10
                            : _notificacionesMasivas.length,
                        itemBuilder: (context, index) {
                          final notif = _notificacionesMasivas[index];
                          return _buildNotificacionHistorial(notif);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifQuickButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildNotificacionHistorial(Map<String, dynamic> notif) {
    final fecha = notif['created_at'] != null
        ? DateFormat('dd/MM/yy HH:mm')
            .format(DateTime.parse(notif['created_at']))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            notif['tipo'] == 'tanda'
                ? Icons.loop
                : notif['tipo'] == 'prestamo'
                    ? Icons.attach_money
                    : notif['tipo'] == 'promocion'
                        ? Icons.local_offer
                        : Icons.notifications,
            color: Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif['titulo'] ?? 'Sin título',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(
                    '${notif['destinatarios_count'] ?? 0} destinatarios • $fecha',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Text('${notif['leidos_count'] ?? 0} leídos',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACCIONES Y DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _editarConfiguracion(String campo, String label,
      {bool isNumber = false}) async {
    final controller =
        TextEditingController(text: _configGlobal[campo]?.toString() ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _guardarConfiguracion(
          campo, isNumber ? int.tryParse(result) ?? result : result);
    }
  }

  Future<void> _guardarConfiguracion(String campo, dynamic valor) async {
    try {
      if (_configGlobal.isEmpty) {
        await AppSupabase.client
            .from('configuracion_global')
            .insert({campo: valor});
      } else {
        await AppSupabase.client
            .from('configuracion_global')
            .update({campo: valor}).eq('id', _configGlobal['id']);
      }
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✅ Configuración guardada"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _toggleModoMantenimiento() async {
    final nuevoValor = !(_configGlobal['modo_mantenimiento'] ?? false);
    await _guardarConfiguracion('modo_mantenimiento', nuevoValor);
  }

  void _limpiarCache() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Limpiar datos en memoria
      imageCache.clear();
      imageCache.clearLiveImages();
      
      // Forzar recolección de basura
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("🧹 Caché de imágenes limpiado correctamente"),
              ],
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _backupManual() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("💾 Punto de Respaldo", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Esto registrará un punto de referencia en el sistema para control de versiones.\n\n"
          "Nota: Los backups completos de datos se realizan automáticamente en Supabase cada 24h.\n\n"
          "¿Deseas registrar este punto de control?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Registrar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      // Registrar backup en la base de datos
      await AppSupabase.client.from('auditoria').insert({
        'accion': 'BACKUP_MANUAL',
        'tabla_afectada': 'sistema',
        'descripcion': 'Backup manual iniciado por superadmin',
        'usuario_id': AppSupabase.client.auth.currentUser?.id,
        'metadata': {
          'fecha': DateTime.now().toIso8601String(),
          'tipo': 'manual',
          'tablas': ['usuarios', 'clientes', 'prestamos', 'tandas', 'pagos'],
        },
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text("💾 Backup registrado - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}"),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _reiniciarSesiones() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("🔄 Marcar Sesiones para Revalidación", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Esto marcará todas las sesiones para revalidación en el próximo inicio de la app.\n\n"
          "Los usuarios verán un mensaje solicitando reiniciar la aplicación.\n\n"
          "Tu sesión actual no se verá afectada.\n\n¿Continuar?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text("Marcar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      // Registrar acción en auditoría
      await AppSupabase.client.from('auditoria').insert({
        'accion': 'REINICIAR_SESIONES',
        'tabla_afectada': 'usuarios',
        'descripcion': 'Sesiones de usuarios reiniciadas por superadmin',
        'usuario_id': AppSupabase.client.auth.currentUser?.id,
      });
      
      // Actualizar timestamp para forzar revalidación
      await AppSupabase.client.from('configuracion_global').update({
        'ultima_invalidacion_sesiones': DateTime.now().toIso8601String(),
      }).eq('id', _configGlobal['id'] ?? '');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("🔄 Sesiones reiniciadas correctamente"),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _enviarNotificacionTest() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay sesión activa');
      }
      
      // Crear notificación de prueba para el usuario actual
      await AppSupabase.client.from('notificaciones').insert({
        'usuario_id': userId,
        'titulo': '🧪 Notificación de Prueba',
        'mensaje': 'Esta es una notificación de prueba del Centro de Control. Si la ves, el sistema funciona correctamente.',
        'tipo': 'sistema',
        'ruta_destino': '/controlCenter',
        'leida': false,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("📨 Notificación enviada - Revisa la campanita")),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _crearTema() async {
    await _mostrarFormularioTema();
  }
  
  Future<void> _mostrarFormularioTema({Map<String, dynamic>? tema}) async {
    final nombreController = TextEditingController(text: tema?['nombre'] ?? '');
    Color colorPrimario = _hexToColor(tema?['color_primario'] ?? '#1E1E2C');
    Color colorSecundario = _hexToColor(tema?['color_secundario'] ?? '#2D2D44');
    Color colorAccent = _hexToColor(tema?['color_accent'] ?? '#00BCD4');
    bool activo = tema?['activo'] ?? false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Row(
            children: [
              const Icon(Icons.palette, color: Colors.purpleAccent),
              const SizedBox(width: 10),
              Text(
                tema == null ? "Crear Nuevo Tema" : "Editar Tema",
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Nombre del Tema",
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: "Ej: Tema Azul Oscuro",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Preview del tema
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorPrimario, colorSecundario],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorAccent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      "Vista Previa",
                      style: TextStyle(color: colorAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Selectores de color
                _buildColorSelector("Color Primario", colorPrimario, (color) {
                  setDialogState(() => colorPrimario = color);
                }),
                const SizedBox(height: 10),
                _buildColorSelector("Color Secundario", colorSecundario, (color) {
                  setDialogState(() => colorSecundario = color);
                }),
                const SizedBox(height: 10),
                _buildColorSelector("Color Accent", colorAccent, (color) {
                  setDialogState(() => colorAccent = color);
                }),
                
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text("Activar al guardar", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Será el tema por defecto", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: activo,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("El nombre es obligatorio"), backgroundColor: Colors.orange),
                  );
                  return;
                }
                
                try {
                  final data = {
                    'nombre': nombreController.text,
                    'color_primario': _colorToHex(colorPrimario),
                    'color_secundario': _colorToHex(colorSecundario),
                    'color_accent': _colorToHex(colorAccent),
                    'activo': activo,
                  };
                  
                  if (activo) {
                    // Desactivar otros temas
                    await AppSupabase.client.from('temas_app').update({'activo': false}).eq('activo', true);
                  }
                  
                  if (tema == null) {
                    await AppSupabase.client.from('temas_app').insert(data);
                  } else {
                    await AppSupabase.client.from('temas_app').update(data).eq('id', tema['id']);
                  }
                  
                  Navigator.pop(context);
                  _cargarDatos();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tema == null ? "✅ Tema creado" : "✅ Tema actualizado"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColorSelector(String label, Color currentColor, Function(Color) onColorSelected) {
    final colores = [
      Colors.blue.shade900, Colors.indigo.shade900, Colors.purple.shade900,
      Colors.cyan.shade900, Colors.teal.shade900, Colors.green.shade900,
      Colors.orange.shade900, Colors.red.shade900, Colors.pink.shade900,
      const Color(0xFF1E1E2C), const Color(0xFF0D0D14), const Color(0xFF2D2D44),
      Colors.blueAccent, Colors.cyanAccent, Colors.purpleAccent,
      Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent,
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: colores.map((color) {
            final isSelected = color.value == currentColor.value;
            return GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _activarTema(String id) async {
    if (id.isEmpty) {
      debugPrint('Error: ID de tema vacío');
      return;
    }
    try {
      // Desactivar todos primero
      await AppSupabase.client
          .from('temas_app')
          .update({'activo': false})
          .eq('activo', true);
      // Activar el seleccionado
      await AppSupabase.client
          .from('temas_app')
          .update({'activo': true}).eq('id', id);
      
      // Buscar el nombre del tema y aplicarlo globalmente
      final tema = _temas.firstWhere((t) => t['id'] == id, orElse: () => {});
      if (tema.isNotEmpty && tema['nombre'] != null) {
        final themeVm = Provider.of<ThemeViewModel>(context, listen: false);
        final themeName = (tema['nombre'] as String).toLowerCase();
        if (themeName.contains('azul')) {
          themeVm.setTheme('azul');
        } else if (themeName.contains('verde')) {
          themeVm.setTheme('verde');
        } else if (themeName.contains('purpura') || themeName.contains('morado')) {
          themeVm.setTheme('purpura');
        } else {
          themeVm.setTheme('oscuro');
        }
      }
      
      HapticFeedback.mediumImpact();
      _cargarDatos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Tema aplicado globalmente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _editarTema(Map<String, dynamic> tema) {
    _mostrarFormularioTema(tema: tema);
  }

  void _eliminarTema(String id) async {
    if (id.isEmpty) {
      debugPrint('Error: ID de tema vacío para eliminar');
      return;
    }
    try {
      await AppSupabase.client.from('temas_app').delete().eq('id', id);
      _cargarDatos();
    } catch (e) {
      debugPrint("Error eliminando tema: $e");
    }
  }

  void _seleccionarColor(String label, String colorActual) async {
    Color selectedColor = _hexToColor(colorActual);
    
    final colores = [
      Colors.blue, Colors.indigo, Colors.purple, Colors.deepPurple,
      Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
      Colors.orange, Colors.deepOrange, Colors.red, Colors.pink,
      Colors.amber, Colors.yellow, Colors.lime, Colors.brown,
      Colors.blueGrey, Colors.grey, const Color(0xFF1E1E2C), const Color(0xFF0D0D14),
    ];
    
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text("🎨 $label", style: const TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colores.map((color) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
    
    if (result != null) {
      final hexColor = _colorToHex(result);
      await _guardarConfiguracion(label.toLowerCase().replaceAll(' ', '_'), hexColor);
    }
  }

  void _subirFondo() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Mostrar opciones
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("📷 Subir Fondo de Pantalla", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.cyanAccent),
                title: const Text("Galería", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.pinkAccent),
                title: const Text("Cámara", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      // Mostrar loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.cyanAccent),
                SizedBox(height: 15),
                Text("Subiendo imagen...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }
      
      // Subir a Supabase Storage
      final bytes = await image.readAsBytes();
      final fileName = 'fondo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await AppSupabase.client.storage
          .from('fondos')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/jpeg'));
      
      // Obtener URL pública
      final publicUrl = AppSupabase.client.storage.from('fondos').getPublicUrl(fileName);
      
      // Guardar en la tabla fondos_pantalla
      await AppSupabase.client.from('fondos_pantalla').insert({
        'nombre': 'Fondo ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        'url': publicUrl,
        'activo': false,
        'tipo': 'imagen',
      });
      
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Fondo subido correctamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading si está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al subir: ${e.toString().contains('Bucket') ? 'Bucket no existe - créalo en Supabase' : e}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _activarFondo(String id) async {
    if (id.isEmpty) {
      debugPrint('Error: ID de fondo vacío');
      return;
    }
    try {
      await AppSupabase.client
          .from('fondos_pantalla')
          .update({'activo': false})
          .eq('activo', true);
      await AppSupabase.client
          .from('fondos_pantalla')
          .update({'activo': true}).eq('id', id);
      _cargarDatos();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _toggleFondosInteligentes(bool valor) async {
    await _guardarConfiguracion('fondos_inteligentes', valor);
  }

  void _toggleFondosPorRol(bool valor) async {
    await _guardarConfiguracion('fondos_por_rol', valor);
  }

  void _crearPromocion() async {
    await _mostrarFormularioPromocion();
  }

  void _editarPromocion(Map<String, dynamic> promo) async {
    await _mostrarFormularioPromocion(promo: promo);
  }

  void _eliminarPromocion(String id) async {
    try {
      await AppSupabase.client.from('promociones').delete().eq('id', id);
      _cargarDatos();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _mostrarFormularioPromocion(
      {Map<String, dynamic>? promo}) async {
    final tituloController =
        TextEditingController(text: promo?['titulo'] ?? '');
    final descripcionController =
        TextEditingController(text: promo?['descripcion'] ?? '');
    final rutaController =
        TextEditingController(text: promo?['ruta_destino'] ?? '/tandas');
    bool activa = promo?['activa'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Text(promo == null ? "Nueva Promoción" : "Editar Promoción",
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Título",
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descripcionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: "Descripción",
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rutaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Ruta destino (al hacer click)",
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: "/tandas, /prestamos, /chat",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text("Activa",
                      style: TextStyle(color: Colors.white)),
                  value: activa,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setDialogState(() => activa = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = {
                    'titulo': tituloController.text,
                    'descripcion': descripcionController.text,
                    'ruta_destino': rutaController.text,
                    'activa': activa,
                  };
                  if (promo == null) {
                    await AppSupabase.client.from('promociones').insert(data);
                  } else {
                    await AppSupabase.client
                        .from('promociones')
                        .update(data)
                        .eq('id', promo['id']);
                  }
                  Navigator.pop(context);
                  _cargarDatos();
                } catch (e) {
                  debugPrint("Error: $e");
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarNotificacionPersonalizada(
      {required String tipo, String? rutaDestino}) async {
    final tituloController = TextEditingController();
    final mensajeController = TextEditingController();
    final rutaController = TextEditingController(text: rutaDestino ?? '');
    String audiencia = 'todos';

    // Títulos sugeridos por tipo
    final sugerencias = {
      'tanda': {
        'titulo': '¡Únete a nuestra Tanda!',
        'mensaje':
            'Tenemos nuevas tandas disponibles con excelentes beneficios. ¡No te lo pierdas!'
      },
      'prestamo': {
        'titulo': '💰 Préstamo Pre-aprobado',
        'mensaje':
            'Tienes un préstamo pre-aprobado esperándote. Consulta las condiciones especiales.'
      },
      'promocion': {
        'titulo': '🎉 ¡Promoción Especial!',
        'mensaje': 'Por tiempo limitado, aprovecha nuestras ofertas exclusivas.'
      },
      'aviso': {
        'titulo': '⚠️ Aviso Importante',
        'mensaje': 'Tenemos información importante que compartir contigo.'
      },
      'anuncio': {
        'titulo': '📢 Nuevo Anuncio',
        'mensaje': 'Queremos informarte sobre las novedades en Robert Darin.'
      },
    };

    if (sugerencias.containsKey(tipo)) {
      tituloController.text = sugerencias[tipo]!['titulo']!;
      mensajeController.text = sugerencias[tipo]!['mensaje']!;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("📨 Enviar Notificación Masiva",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: tituloController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Título",
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mensajeController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: "Mensaje",
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rutaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Al hacer click, ir a:",
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: "/tandas, /prestamos, /chat",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 15),
                const Text("Audiencia:",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("Todos"),
                      selected: audiencia == 'todos',
                      selectedColor: Colors.cyanAccent,
                      onSelected: (s) =>
                          setDialogState(() => audiencia = 'todos'),
                    ),
                    ChoiceChip(
                      label: const Text("Clientes"),
                      selected: audiencia == 'cliente',
                      selectedColor: Colors.cyanAccent,
                      onSelected: (s) =>
                          setDialogState(() => audiencia = 'cliente'),
                    ),
                    ChoiceChip(
                      label: const Text("Empleados"),
                      selected: audiencia == 'empleado',
                      selectedColor: Colors.cyanAccent,
                      onSelected: (s) =>
                          setDialogState(() => audiencia = 'empleado'),
                    ),
                    ChoiceChip(
                      label: const Text("Avales"),
                      selected: audiencia == 'aval',
                      selectedColor: Colors.cyanAccent,
                      onSelected: (s) =>
                          setDialogState(() => audiencia = 'aval'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar")),
            ElevatedButton.icon(
              onPressed: () async {
                if (tituloController.text.isEmpty ||
                    mensajeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Completa título y mensaje"),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  // Contar destinatarios
                  var query = AppSupabase.client.from('usuarios').select('id');
                  if (audiencia != 'todos') {
                    query = query.eq('rol', audiencia);
                  }
                  final usuarios = await query;
                  final destinatariosCount = (usuarios as List).length;

                  // Guardar notificación masiva
                  final notifMasiva = await AppSupabase.client
                      .from('notificaciones_masivas')
                      .insert({
                        'titulo': tituloController.text,
                        'mensaje': mensajeController.text,
                        'tipo': tipo,
                        'ruta_destino': rutaController.text,
                        'audiencia': audiencia,
                        'destinatarios_count': destinatariosCount,
                        'enviado_por': AppSupabase.client.auth.currentUser?.id,
                      })
                      .select()
                      .single();

                  // Crear notificación individual para cada usuario
                  for (var user in usuarios) {
                    await AppSupabase.client.from('notificaciones').insert({
                      'usuario_id': user['id'],
                      'titulo': tituloController.text,
                      'mensaje': mensajeController.text,
                      'tipo': tipo,
                      'ruta_destino': rutaController.text,
                      'notificacion_masiva_id': notifMasiva['id'],
                    });
                  }

                  Navigator.pop(context);
                  _cargarDatos();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "✅ Notificación enviada a $destinatariosCount usuarios"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text("Enviar"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÓDULOS - TARJETAS DE PRESENTACIÓN QR V10.52
  // ═══════════════════════════════════════════════════════════════════

  void _abrirTarjetasServicio({
    bool abrirCrear = false,
    String? modulo,
    String? template,
    String? negocioId,
  }) {
    final args = <String, dynamic>{};
    if (abrirCrear) args['abrirCrear'] = true;
    if (modulo != null) args['modulo'] = modulo;
    if (template != null) args['template'] = template;
    if (negocioId != null) args['negocioId'] = negocioId;
    Navigator.pushNamed(
      context,
      AppRoutes.tarjetasServicio,
      arguments: args.isEmpty ? null : args,
    );
  }

  Widget _buildProgresoInversionCard(NumberFormat currencyFormat) {
    final total = _carteraTotal;
    final recuperada = _carteraRecuperada;
    final progreso = total > 0 ? (recuperada / total).clamp(0.0, 1.0) : 0.0;
    final progresoPct = (progreso * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blueAccent.withOpacity(0.2),
                Colors.indigo.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.trending_up, color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Progreso global',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Text(
                    '$progresoPct%',
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progreso,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMiniStatCompact(
                    'Cartera',
                    currencyFormat.format(total),
                    Icons.account_balance_wallet,
                    Colors.cyanAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniStatCompact(
                    'Recuperado',
                    currencyFormat.format(recuperada),
                    Icons.check_circle,
                    Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniStatCompact(
                    'Mora',
                    '$_prestamosEnMora',
                    Icons.warning_amber,
                    _prestamosEnMora > 0 ? Colors.redAccent : Colors.white54,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.pushNamed(context, AppRoutes.superadminInversionGlobal),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purpleAccent.withOpacity(0.2),
                  Colors.deepPurple.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.show_chart, color: Colors.purpleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inversion global',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ver detalle de capital e inversion',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCompact(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirConfiguradorQR({String? modulo, String? negocioId, String? tarjetaId}) {
    final args = <String, dynamic>{};
    if (modulo != null) args['modulo'] = modulo;
    if (negocioId != null) args['negocioId'] = negocioId;
    if (tarjetaId != null) args['tarjetaId'] = tarjetaId;
    Navigator.pushNamed(
      context,
      AppRoutes.configuradorFormulariosQR,
      arguments: args.isEmpty ? null : args,
    );
  }

  Widget _buildModuloMisTarjetasServicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con gradiente
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tarjetas de Presentación QR",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Crea tarjetas profesionales con código QR",
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Acciones principales
          const Text("🎨 Acciones Rápidas",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAccionTarjetaQR(
                  "➕ Crear Tarjeta",
                  "Nueva tarjeta de servicio",
                  Icons.add_card,
                  const Color(0xFF00D9FF),
                  () => _abrirTarjetasServicio(abrirCrear: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccionTarjetaQR(
                  "📋 Mis Tarjetas",
                  "Ver todas mis tarjetas",
                  Icons.style,
                  const Color(0xFF8B5CF6),
                  () => _abrirTarjetasServicio(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccionTarjetaQR(
                  "📱 Vista Previa",
                  "Cómo se ve el QR",
                  Icons.preview,
                  const Color(0xFF10B981),
                  () => _abrirTarjetasServicio(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccionTarjetaQR(
                  "⚙️ Configurar",
                  "Formularios QR",
                  Icons.tune,
                  const Color(0xFFF59E0B),
                  () => _abrirConfiguradorQR(modulo: 'general'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Módulos disponibles
          const Text("📦 Módulos con Tarjetas QR",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildModuloTarjetaItem(
            "❄️ Climas/Aires",
            "Servicios de A/C",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'climas'),
          ),
          _buildModuloTarjetaItem(
            "💰 Préstamos",
            "Solicitud de préstamos",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'prestamos'),
          ),
          _buildModuloTarjetaItem(
            "🤝 Tandas",
            "Ahorro grupal",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'tandas'),
          ),
          _buildModuloTarjetaItem(
            "💵 Cobranza",
            "Cobro de deudas",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'cobranza'),
          ),
          _buildModuloTarjetaItem(
            "🔧 Servicios",
            "Servicios generales",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'servicios'),
          ),
          _buildModuloTarjetaItem(
            "📋 General",
            "Uso general",
            true,
            onTap: () => _abrirTarjetasServicio(abrirCrear: true, modulo: 'general'),
          ),

          const SizedBox(height: 24),

          // Botón principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _abrirTarjetasServicio(),
              icon: const Icon(Icons.open_in_new),
              label: const Text("Abrir Módulo Completo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionTarjetaQR(String titulo, String subtitulo, IconData icono, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildModuloTarjetaItem(
    String nombre,
    String descripcion,
    bool disponible, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: disponible ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                disponible ? Colors.greenAccent.withOpacity(0.3) : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Text(nombre,
                style:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(descripcion,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            Icon(
              disponible ? Icons.check_circle : Icons.cancel,
              color: disponible ? Colors.greenAccent : Colors.redAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuloEstadisticasQR() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cargarEstadisticasQR(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? {'total': 0, 'escaneos': 0, 'activas': 0};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📊 Estadísticas de Tarjetas QR",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildKPICard("Total Tarjetas", stats['total'].toString(), Icons.style, const Color(0xFF00D9FF), "Tarjetas creadas")),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKPICard("Activas", stats['activas'].toString(), Icons.check_circle, Colors.greenAccent, "En funcionamiento")),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildKPICard("Escaneos Total", stats['escaneos'].toString(), Icons.qr_code_scanner, const Color(0xFF8B5CF6), "Veces escaneado")),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKPICard("Este Mes", stats['escaneosmes']?.toString() ?? '0', Icons.calendar_today, Colors.orangeAccent, "Escaneos recientes")),
                ],
              ),

              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _abrirTarjetasServicio(),
                  icon: const Icon(Icons.analytics),
                  label: const Text("Ver Estadísticas Detalladas"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _cargarEstadisticasQR() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return {'total': 0, 'activas': 0, 'escaneos': 0};

      final tarjetas = await AppSupabase.client
          .from('tarjetas_servicio')
          .select('id, activa, escaneos_total')
          .eq('created_by', user.id);

      final lista = List<Map<String, dynamic>>.from(tarjetas);
      final total = lista.length;
      final activas = lista.where((t) => t['activa'] == true).length;
      final escaneos = lista.fold<int>(0, (sum, t) => sum + ((t['escaneos_total'] ?? 0) as int));

      return {'total': total, 'activas': activas, 'escaneos': escaneos, 'escaneosmes': escaneos};
    } catch (e) {
      debugPrint('Error cargando stats QR: $e');
      return {'total': 0, 'activas': 0, 'escaneos': 0};
    }
  }

  Widget _buildModuloTemplatesTarjetas() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cargarTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final templates = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🎨 Plantillas de Diseño",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Selecciona un estilo para tus tarjetas de presentación",
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 16),

              if (templates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text("No hay plantillas disponibles", style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                ...templates.map((t) => _buildTemplateItem(
                      t,
                      onTap: () => _abrirTarjetasServicio(
                        abrirCrear: true,
                        template: t['nombre']?.toString(),
                      ),
                    )),

              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _abrirTarjetasServicio(abrirCrear: true),
                  icon: const Icon(Icons.add_card),
                  label: const Text("Crear Tarjeta con Template"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _cargarTemplates() async {
    try {
      final result = await AppSupabase.client
          .from('tarjetas_templates')
          .select('*')
          .eq('activo', true)
          .order('orden');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error cargando templates: $e');
      return [];
    }
  }

  Widget _buildTemplateItem(Map<String, dynamic> template, {VoidCallback? onTap}) {
    final nombre = template['nombre'] ?? 'Sin nombre';
    final descripcion = template['descripcion'] ?? '';
    final esPremium = template['es_premium'] ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E293B),
              _getTemplateColor(nombre).withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getTemplateColor(nombre).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTemplateColor(nombre).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTemplateIcon(nombre), color: _getTemplateColor(nombre), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nombre.toString().toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (esPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("PRO", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Color _getTemplateColor(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'profesional': return const Color(0xFF3B82F6);
      case 'moderno': return const Color(0xFF10B981);
      case 'minimalista': return Colors.white54;
      case 'clasico': return const Color(0xFFD4AF37);
      case 'premium': return const Color(0xFF8B5CF6);
      case 'corporativo': return const Color(0xFF1E3A8A);
      default: return const Color(0xFF00D9FF);
    }
  }

  IconData _getTemplateIcon(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'profesional': return Icons.business_center;
      case 'moderno': return Icons.auto_awesome;
      case 'minimalista': return Icons.crop_square;
      case 'clasico': return Icons.style;
      case 'premium': return Icons.diamond;
      case 'corporativo': return Icons.account_balance;
      default: return Icons.dashboard_customize;
    }
  }

  Widget _buildModuloLandingConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🌐 Configuración de Landing Pages",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Personaliza las páginas de destino cuando escaneen tu QR",
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),

          _buildLandingOptionCard(
            "❄️ Climas/Aires",
            "Formulario de solicitud de servicio de A/C",
            "/climas/formulario-publico",
            const Color(0xFF00D9FF),
            onTap: () => _abrirConfiguradorQR(modulo: 'climas'),
          ),
          _buildLandingOptionCard(
            "💰 Préstamos",
            "Solicitud de cotización de préstamo",
            "/prestamos/solicitar",
            const Color(0xFF10B981),
            onTap: () => _abrirConfiguradorQR(modulo: 'prestamos'),
          ),
          _buildLandingOptionCard(
            "🤝 Tandas",
            "Inscripción a grupo de ahorro",
            "/tandas/inscribirse",
            const Color(0xFFFBBF24),
            onTap: () => _abrirConfiguradorQR(modulo: 'tandas'),
          ),
          _buildLandingOptionCard(
            "📋 General",
            "Formulario de contacto general",
            "/contacto",
            const Color(0xFF8B5CF6),
            onTap: () => _abrirConfiguradorQR(modulo: 'general'),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text("¿Cómo funciona?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "1. Crea una tarjeta de servicio con QR\n"
                  "2. Elige el módulo (Climas, Préstamos, etc.)\n"
                  "3. Al escanear el QR, el cliente ve tu landing page\n"
                  "4. El cliente llena el formulario y te contacta",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _abrirConfiguradorQR(modulo: 'general'),
              icon: const Icon(Icons.tune),
              label: const Text("Configurar Formularios QR"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingOptionCard(
    String titulo,
    String descripcion,
    String ruta,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.web, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(ruta, style: TextStyle(color: color, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.edit, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

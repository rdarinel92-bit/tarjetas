// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/prestamos_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/dashboard_aval_screen.dart';
import '../screens/dashboard_cliente_screen.dart';
import '../screens/finanzas_dashboard_screen.dart';
import '../screens/climas_dashboard_screen.dart';
import '../screens/purificadora_dashboard_screen.dart';
import '../screens/nice_dashboard_screen.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/negocio_activo_provider.dart';
import 'app_routes.dart';
import '../components/premium_background.dart';
import '../../core/supabase_client.dart';
import '../../core/permisos_rol.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// APP SHELL - NAVEGACIÓN PRINCIPAL CON PERMISOS POR ROL
/// ══════════════════════════════════════════════════════════════════════════════
/// - Drawer dinámico según rol
/// - Bottom nav según permisos
/// - Validación de acceso
/// ══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String? _userRole;
  String _userName = "Usuario";
  String _userEmail = "";
  bool _esAval = false;
  bool _isLoading = true;

  // Control de la barra de navegación con auto-hide en scroll
  bool _navBarVisible = true;
  late AnimationController _navBarController;
  // ignore: unused_field
  late Animation<Offset> _navBarSlideAnimation;
  
  // Control de scroll para auto-hide
  double _lastScrollPosition = 0;
  static const double _scrollThreshold = 10.0; // Sensibilidad del scroll

  @override
  void initState() {
    super.initState();

    // Inicializar animación de deslizamiento vertical (hacia abajo para ocultar)
    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _navBarSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1), // Se desliza hacia abajo (oculta)
    ).animate(CurvedAnimation(
      parent: _navBarController,
      curve: Curves.easeInOut,
    ));

    _loadUserInfo();
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  /// Maneja las notificaciones de scroll para auto-hide
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      final delta = currentPosition - _lastScrollPosition;
      
      // Solo actuar si el delta supera el umbral
      if (delta.abs() > _scrollThreshold) {
        if (delta > 0 && _navBarVisible) {
          // Scrolling hacia abajo - ocultar
          _hideNavBar();
        } else if (delta < 0 && !_navBarVisible) {
          // Scrolling hacia arriba - mostrar
          _showNavBar();
        }
        _lastScrollPosition = currentPosition;
      }
    } else if (notification is ScrollEndNotification) {
      // Al terminar el scroll, guardar posición
      _lastScrollPosition = notification.metrics.pixels;
      if (!_navBarVisible) {
        _showNavBar();
      }
    }
    return false; // Permitir que la notificación continúe propagándose
  }

  void _hideNavBar() {
    if (_navBarVisible) {
      setState(() => _navBarVisible = false);
      _navBarController.forward();
    }
  }

  void _showNavBar() {
    if (!_navBarVisible) {
      setState(() => _navBarVisible = true);
      _navBarController.reverse();
    }
  }

  /// Toggle para uso futuro en gestos
  // ignore: unused_element
  void _toggleNavBar() {
    if (_navBarVisible) {
      _hideNavBar();
    } else {
      _showNavBar();
    }
  }

  Future<void> _loadUserInfo() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final role = await authVm.obtenerRol();
    final normalizedRole = role.trim().toLowerCase();
    final user = authVm.usuarioActual;
    
    // DEBUG V10.56 - Verificar rol detectado
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔍 AppShell._loadUserInfo');
    debugPrint('📧 Email: ${user?.email}');
    debugPrint('🎭 Rol detectado: "$role"');
    debugPrint('🎭 Rol normalizado: "$normalizedRole"');
    debugPrint('═══════════════════════════════════════════════');

    // Verificar si es un aval
    bool esAval = false;
    if (user != null) {
      try {
        final avalCheck = await AppSupabase.client
            .from('avales')
            .select('id')
            .eq('usuario_id', user.id)
            .maybeSingle();
        esAval = avalCheck != null;
      } catch (e) {
        debugPrint("Error verificando aval: $e");
      }
    }

    if (mounted) {
      setState(() {
        _userRole = normalizedRole;
        _userEmail = user?.email ?? "";
        _userName = user?.userMetadata?['full_name'] ??
            user?.email?.split('@').first ??
            "Usuario";
        _esAval = esAval;
        _isLoading = false;
      });
    }

    if (normalizedRole == 'superadmin' || normalizedRole == 'admin') {
      try {
        Provider.of<NegocioActivoProvider>(context, listen: false)
            .cargarNegocios();
      } catch (_) {}
    }
  }

  void _onBottomTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN DE PANTALLAS Y BOTTOM NAV SEGÚN ROL
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> get _screens {
    // Si es un AVAL (por rol 'aval' o por estar en tabla avales)
    if (_userRole == 'aval' || (_esAval && _userRole == 'cliente')) {
      return const [
        DashboardAvalScreen(),
        ChatScreen(),
      ];
    }

    // Superadmin / Admin
    if (PermisosRol.esAdminOSuperior(_userRole)) {
      return const [
        DashboardScreen(),
        FinanzasDashboardScreen(),
        ClimasDashboardScreen(),
        PurificadoraDashboardScreen(),
        NiceDashboardScreen(),
      ];
    }
    // Operador
    else if (PermisosRol.esOperadorOSuperior(_userRole)) {
      return const [
        DashboardScreen(),
        FinanzasDashboardScreen(),
      ];
    }
    // Cliente normal (NO aval)
    else if (_userRole == 'cliente') {
      return const [
        DashboardClienteScreen(),
        ChatScreen(),
      ];
    }
    // Fallback
    else {
      return const [
        DashboardScreen(),
        PrestamosScreen(),
        ChatScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> get _bottomItems {
    // Si es un AVAL (por rol 'aval' o por estar en tabla avales)
    if (_userRole == 'aval' || (_esAval && _userRole == 'cliente')) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.shield), label: "Mi Panel"),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: "Soporte"),
      ];
    }

    // Superadmin / Admin
    if (PermisosRol.esAdminOSuperior(_userRole)) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: "Finanzas"),
        BottomNavigationBarItem(icon: Icon(Icons.ac_unit), label: "Climas"),
        BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: "Agua"),
        BottomNavigationBarItem(icon: Icon(Icons.diamond), label: "Nice"),
      ];
    }
    // Operador
    else if (PermisosRol.esOperadorOSuperior(_userRole)) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: "Finanzas"),
      ];
    }
    // Cliente normal (NO aval)
    else if (_userRole == 'cliente') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Mi Panel"),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: "Soporte"),
      ];
    }
    // Fallback
    else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), label: "Mis Préstamos"),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: "Soporte"),
      ];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRAWER DINÁMICO CON PERMISOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDrawer() {
    final items = MenusApp.obtenerItemsParaRol(_userRole);

    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Header del usuario
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A),
                  _getRolColor().withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: _getRolColor(),
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : "U",
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            accountName: Text(
              _userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_userEmail,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRolColor().withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRolLabel(),
                    style: TextStyle(
                      color: _getRolColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items del menú
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length + 1, // +1 para cerrar sesión
              itemBuilder: (context, index) {
                if (index == items.length) {
                  // Cerrar sesión al final
                  return Column(
                    children: [
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading:
                            const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text("Cerrar Sesión",
                            style: TextStyle(color: Colors.redAccent)),
                        onTap: () =>
                            Provider.of<AuthViewModel>(context, listen: false)
                                .cerrarSesion(context),
                      ),
                    ],
                  );
                }

                final item = items[index];

                if (item.esDivider) {
                  return const Divider(color: Colors.white24, height: 1);
                }

                return _buildDrawerItem(item);
              },
            ),
          ),

          // Versión de la app
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Uniko v10.51',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(MenuItemConPermiso item) {
    final color = _getItemColor(item.color);
    final icon = _getIconFromString(item.icono);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.titulo, style: TextStyle(color: color)),
      trailing: item.color != null
          ? Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 18)
          : null,
      onTap: () {
        Navigator.pop(context); // Cerrar drawer

        if (item.tabIndex != null) {
          // Cambiar tab
          setState(() => _currentIndex = item.tabIndex!);
        } else if (item.ruta != null) {
          // Navegar a ruta
          Navigator.pushNamed(context, item.ruta!);
        }
      },
    );
  }

  IconData _getIconFromString(dynamic iconName) {
    if (iconName is IconData) return iconName;

    final icons = <String, IconData>{
      'dashboard': Icons.dashboard,
      'people': Icons.people,
      'home': Icons.home,
      'attach_money': Icons.attach_money,
      'group_work': Icons.group_work,
      'shield': Icons.shield,
      'payments': Icons.payments,
      'badge': Icons.badge,
      'account_balance': Icons.account_balance,
      'calculate': Icons.calculate,
      'receipt_long': Icons.receipt_long,
      'receipt': Icons.receipt,
      'savings': Icons.savings,
      'calendar_month': Icons.calendar_month,
      'event_note': Icons.event_note,
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'notifications': Icons.notifications,
      'analytics': Icons.analytics,
      'trending_up': Icons.trending_up,
      'security': Icons.security,
      'gavel': Icons.gavel,
      'fact_check': Icons.fact_check,
      'manage_accounts': Icons.manage_accounts,
      'admin_panel_settings': Icons.admin_panel_settings,
      'store': Icons.store,
      'storefront': Icons.storefront,
      'settings': Icons.settings,
      'tune': Icons.tune,
      'api': Icons.api,
      'landscape': Icons.landscape,
      'warning_amber': Icons.warning_amber,
      'assignment': Icons.assignment,
      'business_center': Icons.business_center,
      // Nuevos modulos V10.13
      'ac_unit': Icons.ac_unit,
      'water_drop': Icons.water_drop,
      'inventory_2': Icons.inventory_2,
      'history': Icons.history,
      'group_add': Icons.group_add,
      'groups': Icons.groups,
      'forum': Icons.forum,
      'credit_card': Icons.credit_card,
      'qr_code_2': Icons.qr_code_2,
      'inbox': Icons.inbox,
      'directions_walk': Icons.directions_walk,
      'view_module': Icons.view_module,
      'build': Icons.build,
      'hvac': Icons.hvac,
      'diamond': Icons.diamond,
    };;

    return icons[iconName] ?? Icons.circle;
  }

  Color _getItemColor(String? colorName) {
    if (colorName == null) return Colors.white;

    final colors = <String, Color>{
      'lightBlue': Colors.lightBlueAccent,
      'green': Colors.greenAccent,
      'purple': Colors.purpleAccent,
      'red': Colors.redAccent,
      'orange': Colors.orangeAccent,
      'deepOrange': Colors.deepOrangeAccent,
      'teal': Colors.tealAccent,
      'cyan': Colors.cyanAccent,
      'amber': Colors.amberAccent,
      'deepPurple': Colors.deepPurpleAccent,
      'indigo': Colors.indigoAccent,
    };

    return colors[colorName] ?? Colors.white;
  }

  Color _getRolColor() {
    switch (_userRole) {
      case 'superadmin':
        return Colors.deepOrangeAccent;
      case 'admin':
        return Colors.orangeAccent;
      case 'operador':
        return Colors.blueAccent;
      case 'cliente':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }

  String _getRolLabel() {
    if (_esAval) return '🛡️ AVAL';
    switch (_userRole) {
      case 'superadmin':
        return '👑 SUPERADMIN';
      case 'admin':
        return '⚡ ADMIN';
      case 'operador':
        return '📋 OPERADOR';
      case 'cliente':
        return '👤 CLIENTE';
      default:
        return _userRole?.toUpperCase() ?? 'USUARIO';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    final negocioProvider = context.watch<NegocioActivoProvider>();
    final requiereNegocio = PermisosRol.esAdminOSuperior(_userRole);
    if (requiereNegocio &&
        !negocioProvider.cargando &&
        negocioProvider.misNegocios.isEmpty) {
      return _buildNegocioGate();
    }

    return Scaffold(
      drawer: _buildDrawer(),
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: PremiumBackground(
          child: SafeArea(
            child: IndexedStack(
              index: _currentIndex.clamp(0, _screens.length - 1),
              children: _screens,
            ),
          ),
        ),
      ),
      // Botón flotante de chat - visible para todos los roles
      floatingActionButton: _buildChatFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildAutoHideNavBar(),
    );
  }

  Widget _buildNegocioGate() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, color: Colors.orangeAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay negocios registrados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu primer negocio para continuar',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.superadminNegocios,
                      ),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Crear Negocio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.centroMultiEmpresa,
                      ),
                      icon: const Icon(Icons.tune),
                      label: const Text('Abrir Centro de Control'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botón flotante de chat minimalista y no invasivo
  Widget _buildChatFAB() {
    // No mostrar si ya está en la pantalla de chat (para clientes/avales)
    final esCliente = _userRole == 'cliente';
    final estaEnChat = esCliente && _currentIndex == (_esAval ? 1 : 2);
    
    if (estaEnChat) return const SizedBox.shrink();

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: _navBarVisible ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _navBarVisible ? 1.0 : 0.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: FloatingActionButton.small(
            heroTag: "chat_fab",
            backgroundColor: Colors.blueAccent.withOpacity(0.9),
            elevation: 4,
            tooltip: "Mensajes",
            onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  /// Barra de navegación con auto-hide en scroll
  Widget _buildAutoHideNavBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: _navBarVisible ? kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _navBarVisible ? 1.0 : 0.0,
        child: Wrap(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: _getRolColor(),
                  unselectedItemColor: Colors.white54,
                  selectedFontSize: 12,
                  unselectedFontSize: 10,
                  currentIndex: _currentIndex.clamp(0, _bottomItems.length - 1),
                  onTap: _onBottomTap,
                  items: _bottomItems,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

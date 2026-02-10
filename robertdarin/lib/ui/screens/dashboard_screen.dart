// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _esSuperadmin = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _verificarRol();
  }

  Future<void> _verificarRol() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final rol = await authVm.obtenerRol();
    if (mounted) {
      setState(() => _esSuperadmin = rol == 'superadmin');
      // Iniciar la animación de fade-in
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Negocios",
      body: RefreshIndicator(
        onRefresh: _verificarRol,
        color: Colors.cyanAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle("Modulos Principales", Icons.apps),
                const SizedBox(height: 15),
                _buildMainModules(),
                const SizedBox(height: 25),
                _buildSectionTitle("Herramientas", Icons.build_outlined),
                const SizedBox(height: 15),
                _buildToolsSection(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.cyanAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMainModules() {
    final modules = [
      _ModuleCardData(
        "Finanzas",
        Icons.account_balance,
        Colors.greenAccent,
        AppRoutes.finanzasDashboard,
        "Clientes, prestamos y tandas",
      ),
      _ModuleCardData(
        "Climas",
        Icons.ac_unit,
        Colors.cyanAccent,
        AppRoutes.climasDashboard,
        "Servicios y ordenes",
      ),
      _ModuleCardData(
        "Agua",
        Icons.water_drop,
        Colors.lightBlueAccent,
        AppRoutes.purificadoraDashboard,
        "Purificadora y entregas",
      ),
      _ModuleCardData(
        "Nice",
        Icons.diamond,
        Colors.purpleAccent,
        AppRoutes.niceDashboard,
        "Catalogo y pedidos",
      ),
      _ModuleCardData(
        "Ventas",
        Icons.storefront,
        Colors.orangeAccent,
        AppRoutes.ventasDashboard,
        "Productos y pedidos",
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.15,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final item = modules[index];
        return _buildModuleCard(
          item.title,
          item.icon,
          item.color,
          item.route,
          item.subtitle,
        );
      },
    );
  }

  Widget _buildModuleCard(
      String title, IconData icon, Color color, String route, String subtitle) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    return Column(
      children: [
        if (_esSuperadmin) ...[
          _buildToolButton(
            "Accesos Superadmin",
            Icons.admin_panel_settings,
            Colors.tealAccent,
            AppRoutes.superadminHub,
            "Panel organizado de módulos",
          ),
          const SizedBox(height: 12),
          _buildToolButton(
            "Centro de Control",
            Icons.tune,
            Colors.deepOrangeAccent,
            AppRoutes.controlCenter,
            "Supervision del sistema",
          ),
          const SizedBox(height: 12),
        ],
        _buildToolButton(
          "Auditoria y Reportes",
          Icons.analytics_outlined,
          Colors.purpleAccent,
          AppRoutes.reportes,
          "Genera informes detallados",
        ),
        const SizedBox(height: 12),
        _buildToolButton(
          "Cobros Pendientes",
          Icons.payment,
          Colors.orangeAccent,
          AppRoutes.cobrosPendientes,
          "Gestiona cobranza del dia",
        ),
        const SizedBox(height: 12),
        _buildToolButton(
          "Notificaciones",
          Icons.notifications_outlined,
          Colors.cyanAccent,
          AppRoutes.notificaciones,
          "Mensajes y alertas",
        ),
      ],
    );
  }

  Widget _buildToolButton(
      String title, IconData icon, Color color, String route, String subtitle) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

class _ModuleCardData {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String subtitle;

  const _ModuleCardData(
    this.title,
    this.icon,
    this.color,
    this.route,
    this.subtitle,
  );
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // Estado del sistema (cargado dinámicamente)
  Map<String, int> _contadores = {};
  List<dynamic> _actividadReciente = [];
  bool _cargando = true;
  bool _dbConectada = false;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    _cargarEstadoSistema();
  }

  Future<void> _cargarEstadoSistema() async {
    setState(() => _cargando = true);
    
    try {
      // Test de conexión a BD
      final testConexion = await AppSupabase.client.from('usuarios').select('id').limit(1);
      _dbConectada = testConexion.isNotEmpty;

      // Cargar contadores en paralelo
      final futures = await Future.wait([
        AppSupabase.client.from('usuarios').select('id'),
        AppSupabase.client.from('empleados').select('id'),
        AppSupabase.client.from('prestamos').select('id'),
        AppSupabase.client.from('tandas').select('id'),
        AppSupabase.client.from('clientes').select('id'),
        AppSupabase.client.from('sucursales').select('id'),
        AppSupabase.client.from('avales').select('id'),
        // Préstamos activos
        AppSupabase.client.from('prestamos').select('id').eq('estado', 'activo'),
        // Tandas activas
        AppSupabase.client.from('tandas').select('id').eq('estado', 'activa'),
      ]);

      // Cargar actividad reciente (auditoría)
      final auditoriaRes = await AppSupabase.client
          .from('auditoria')
          .select('*, usuarios(nombre_completo)')
          .order('fecha', ascending: false)
          .limit(5);

      setState(() {
        _contadores = {
          'usuarios': (futures[0] as List).length,
          'empleados': (futures[1] as List).length,
          'prestamos': (futures[2] as List).length,
          'tandas': (futures[3] as List).length,
          'clientes': (futures[4] as List).length,
          'sucursales': (futures[5] as List).length,
          'avales': (futures[6] as List).length,
          'prestamosActivos': (futures[7] as List).length,
          'tandasActivas': (futures[8] as List).length,
        };
        _actividadReciente = auditoriaRes;
        _ultimaActualizacion = DateTime.now();
      });
    } catch (e) {
      debugPrint("Error cargando estado: $e");
      _dbConectada = false;
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Centro de Control",
      body: RefreshIndicator(
        onRefresh: _cargarEstadoSistema,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ESTADO DEL SISTEMA EN TIEMPO REAL
              _buildEstadoSistemaCard(),
              const SizedBox(height: 20),

              // KPIs PRINCIPALES
              const Text("Resumen Operativo", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildKPIsGrid(),
              const SizedBox(height: 20),

              // ACCESOS RÁPIDOS
              const Text("Gestión del Sistema", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildAccesosRapidos(),
              const SizedBox(height: 20),

              // HERRAMIENTAS DE SEGURIDAD
              const Text("Seguridad y Monitoreo", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildHerramientasSeguridad(),
              const SizedBox(height: 20),

              // ACTIVIDAD RECIENTE
              const Text("Actividad Reciente", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildActividadReciente(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoSistemaCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Estado del Sistema", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (_cargando)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white38, size: 20),
                  onPressed: _cargarEstadoSistema,
                ),
            ],
          ),
          const Divider(color: Colors.white12),
          
          // Indicadores de estado
          _buildEstadoItem(
            "Base de Datos",
            _dbConectada ? "Conectada (Supabase)" : "Sin conexión",
            _dbConectada ? Colors.greenAccent : Colors.redAccent,
            _dbConectada ? Icons.cloud_done : Icons.cloud_off,
          ),
          _buildEstadoItem(
            "Seguridad RLS",
            "Activa",
            Colors.greenAccent,
            Icons.security,
          ),
          _buildEstadoItem(
            "Modo",
            "Producción",
            Colors.blueAccent,
            Icons.rocket_launch,
          ),
          
          if (_ultimaActualizacion != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "Actualizado: ${DateFormat('HH:mm:ss').format(_ultimaActualizacion!)}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEstadoItem(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildKPIsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _buildKPICard("Clientes", _contadores['clientes']?.toString() ?? '-', Icons.people, Colors.blueAccent),
        _buildKPICard("Préstamos", _contadores['prestamosActivos']?.toString() ?? '-', Icons.account_balance_wallet, Colors.greenAccent, subtitle: "activos"),
        _buildKPICard("Tandas", _contadores['tandasActivas']?.toString() ?? '-', Icons.loop, Colors.orangeAccent, subtitle: "activas"),
        _buildKPICard("Empleados", _contadores['empleados']?.toString() ?? '-', Icons.badge, Colors.purpleAccent),
        _buildKPICard("Sucursales", _contadores['sucursales']?.toString() ?? '-', Icons.store, Colors.tealAccent),
        _buildKPICard("Avales", _contadores['avales']?.toString() ?? '-', Icons.handshake, Colors.amberAccent),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildAccesosRapidos() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildIconButton("Usuarios", Icons.people, AppRoutes.usuarios, Colors.blueAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildIconButton("Empleados", Icons.badge, AppRoutes.empleados, Colors.indigoAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildIconButton("Avales", Icons.handshake, AppRoutes.avales, Colors.amberAccent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildIconButton("Sucursales", Icons.store, AppRoutes.sucursales, Colors.tealAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildIconButton("Roles", Icons.admin_panel_settings, AppRoutes.roles, Colors.orangeAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildIconButton("Clientes", Icons.person, AppRoutes.clientes, Colors.cyanAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildHerramientasSeguridad() {
    return Column(
      children: [
        PremiumButton(
          text: "Auditoría de Sistema",
          icon: Icons.history_edu,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.auditoria),
        ),
        const SizedBox(height: 10),
        PremiumButton(
          text: "Reportes Inteligentes",
          icon: Icons.analytics,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.reportes),
        ),
        const SizedBox(height: 10),
        PremiumButton(
          text: "Dashboard KPIs",
          icon: Icons.dashboard,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboardKpi),
        ),
        const SizedBox(height: 10),
        // AUDITORÍA LEGAL - NUEVO V10.1
        PremiumButton(
          text: "⚖️ Auditoría Legal",
          icon: Icons.gavel,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.auditoriaLegal),
          color: Colors.redAccent,
        ),
        const SizedBox(height: 10),
        // COBROS Y COBRANZA
        PremiumButton(
          text: "💰 Cobros Pendientes",
          icon: Icons.payment,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.cobrosPendientes),
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 10),
        // CENTRO DE CONTROL TOTAL
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purpleAccent.withOpacity(0.3), Colors.cyanAccent.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_suggest, color: Colors.cyanAccent),
            ),
            title: const Text("🎛️ Centro de Control Total",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("Temas, Fondos, Promociones, Notificaciones",
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.cyanAccent, size: 16),
            onTap: () => Navigator.pushNamed(context, AppRoutes.controlCenter),
          ),
        ),
      ],
    );
  }

  Widget _buildActividadReciente() {
    if (_actividadReciente.isEmpty) {
      return PremiumCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text("No hay actividad reciente", style: TextStyle(color: Colors.white38)),
          ),
        ),
      );
    }

    return PremiumCard(
      child: Column(
        children: _actividadReciente.map((a) {
          final usuario = a['usuarios']?['nombre_completo'] ?? 'Sistema';
          final accion = a['accion'] ?? 'ACCIÓN';
          final tabla = a['tabla'] ?? '';
          final fecha = a['created_at'] != null 
              ? DateFormat('dd/MM HH:mm').format(DateTime.parse(a['created_at']))
              : '';
          
          IconData iconAccion;
          Color colorAccion;
          
          switch (accion) {
            case 'INSERT':
              iconAccion = Icons.add_circle;
              colorAccion = Colors.greenAccent;
              break;
            case 'UPDATE':
              iconAccion = Icons.edit;
              colorAccion = Colors.orangeAccent;
              break;
            case 'DELETE':
              iconAccion = Icons.delete;
              colorAccion = Colors.redAccent;
              break;
            default:
              iconAccion = Icons.info;
              colorAccion = Colors.blueAccent;
          }

          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(iconAccion, color: colorAccion, size: 20),
            title: Text("$accion en $tabla", style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text("Por: $usuario", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: Text(fecha, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIconButton(String label, IconData icon, String route, Color color) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

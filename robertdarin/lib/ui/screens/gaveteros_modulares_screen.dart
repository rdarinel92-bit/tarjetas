// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'tarjetas_digitales_config_screen.dart';
import 'configuracion_apis_screen.dart';
import 'centro_control_multi_empresa_screen.dart';

/// Panel de Gaveteros Modulares
/// Cada "gavetero" es un módulo independiente del negocio
/// que puede activarse/desactivarse y configurarse por separado
class GaveterosModularesScreen extends StatefulWidget {
  const GaveterosModularesScreen({super.key});

  @override
  State<GaveterosModularesScreen> createState() => _GaveterosModularesScreenState();
}

class _GaveterosModularesScreenState extends State<GaveterosModularesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _modulos = [];

  // Definición de gaveteros disponibles
  final List<Gavetero> _gaveterosDisponibles = [
    // === GAVETERO FINTECH ===
    Gavetero(
      id: 'fintech',
      nombre: '💰 Fintech',
      descripcion: 'Sistema completo de préstamos y cobranza',
      color: Colors.greenAccent,
      icono: Icons.account_balance,
      submodulos: [
        Submodulo('prestamos', 'Préstamos', Icons.monetization_on, true),
        Submodulo('cobranza', 'Cobranza', Icons.payments, true),
        Submodulo('amortizaciones', 'Amortizaciones', Icons.calendar_today, true),
        Submodulo('clientes', 'CRM Clientes', Icons.people, true),
        Submodulo('avales', 'Sistema de Avales', Icons.shield, true),
        Submodulo('tarjetas', 'Tarjetas Digitales', Icons.credit_card, false),
        Submodulo('reportes_fin', 'Reportes Financieros', Icons.analytics, true),
      ],
    ),
    
    // === GAVETERO AIRES ACONDICIONADOS ===
    Gavetero(
      id: 'aires',
      nombre: '❄️ Aires Acondicionados',
      descripcion: 'Gestión de servicios de climatización',
      color: Colors.cyanAccent,
      icono: Icons.ac_unit,
      submodulos: [
        Submodulo('inventario_aires', 'Inventario Equipos', Icons.inventory, false),
        Submodulo('servicios_aires', 'Órdenes de Servicio', Icons.build, false),
        Submodulo('tecnicos', 'Técnicos', Icons.engineering, false),
        Submodulo('clientes_aires', 'Clientes', Icons.business, false),
        Submodulo('cotizaciones', 'Cotizaciones', Icons.request_quote, false),
        Submodulo('instalaciones', 'Instalaciones', Icons.home_repair_service, false),
        Submodulo('garantias', 'Garantías', Icons.verified_user, false),
      ],
    ),
    
    // === GAVETERO RRHH ===
    Gavetero(
      id: 'rrhh',
      nombre: '👥 Recursos Humanos',
      descripcion: 'Gestión de empleados y nómina',
      color: Colors.purpleAccent,
      icono: Icons.groups,
      submodulos: [
        Submodulo('empleados', 'Empleados', Icons.badge, true),
        Submodulo('asistencia', 'Asistencia', Icons.access_time, false),
        Submodulo('nomina', 'Nómina', Icons.account_balance_wallet, false),
        Submodulo('vacaciones', 'Vacaciones', Icons.beach_access, false),
        Submodulo('evaluaciones', 'Evaluaciones', Icons.rate_review, false),
      ],
    ),
    
    // === GAVETERO CONTABILIDAD ===
    Gavetero(
      id: 'contabilidad',
      nombre: '📊 Contabilidad',
      descripcion: 'Control financiero y fiscal',
      color: Colors.amberAccent,
      icono: Icons.calculate,
      submodulos: [
        Submodulo('cuentas', 'Catálogo de Cuentas', Icons.account_tree, false),
        Submodulo('polizas', 'Pólizas Contables', Icons.receipt_long, false),
        Submodulo('facturacion', 'Facturación CFDI', Icons.description, false),
        Submodulo('impuestos', 'Impuestos', Icons.gavel, false),
        Submodulo('balances', 'Estados Financieros', Icons.assessment, false),
      ],
    ),
    
    // === GAVETERO INVENTARIO ===
    Gavetero(
      id: 'inventario',
      nombre: '📦 Inventario',
      descripcion: 'Control de productos y almacén',
      color: Colors.orangeAccent,
      icono: Icons.inventory_2,
      submodulos: [
        Submodulo('productos', 'Productos', Icons.category, false),
        Submodulo('almacenes', 'Almacenes', Icons.warehouse, false),
        Submodulo('movimientos', 'Movimientos', Icons.swap_horiz, false),
        Submodulo('proveedores', 'Proveedores', Icons.local_shipping, false),
        Submodulo('compras', 'Órdenes de Compra', Icons.shopping_cart, false),
      ],
    ),
    
    // === GAVETERO VENTAS ===
    Gavetero(
      id: 'ventas',
      nombre: '🛒 Ventas',
      descripcion: 'Punto de venta y comercio',
      color: Colors.redAccent,
      icono: Icons.point_of_sale,
      submodulos: [
        Submodulo('pos', 'Punto de Venta', Icons.point_of_sale, false),
        Submodulo('pedidos', 'Pedidos', Icons.shopping_bag, false),
        Submodulo('cotizaciones_venta', 'Cotizaciones', Icons.request_quote, false),
        Submodulo('comisiones', 'Comisiones', Icons.percent, false),
        Submodulo('ecommerce', 'E-Commerce', Icons.store, false),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cargarModulos();
  }

  Future<void> _cargarModulos() async {
    try {
      final res = await AppSupabase.client
          .from('modulos_activos')
          .select();
      
      _modulos = List<Map<String, dynamic>>.from(res);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando módulos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isModuloActivo(String moduloId) {
    return _modulos.any((m) => m['modulo_id'] == moduloId && m['activo'] == true);
  }

  bool _isSubmoduloActivo(String submoduloId) {
    return _modulos.any((m) => m['modulo_id'] == submoduloId && m['activo'] == true);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Gaveteros Modulares",
      subtitle: "Configura los módulos de tu negocio",
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConfiguracionApisScreen()),
          ),
          tooltip: 'Configurar APIs',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarModulos,
              child: ListView(
                children: [
                  // Resumen rápido
                  _buildResumen(),
                  const SizedBox(height: 20),

                  // Accesos rápidos
                  _buildAccesosRapidos(),
                  const SizedBox(height: 25),

                  // Lista de gaveteros
                  const Text('Módulos Disponibles',
                      style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  ..._gaveterosDisponibles.map((g) => _buildGaveteroCard(g)),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildResumen() {
    int activos = _gaveterosDisponibles.where((g) => _isModuloActivo(g.id)).length;
    int total = _gaveterosDisponibles.length;
    
    return PremiumCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.widgets, color: Colors.orangeAccent, size: 35),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gaveteros Activos',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('$activos de $total módulos',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: activos / total,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccesosRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Accesos Rápidos',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildAccesoRapido(
              Icons.business,
              'Multi-Empresa',
              Colors.blueAccent,
              () => Navigator.push(context, 
                  MaterialPageRoute(builder: (_) => const CentroControlMultiEmpresaScreen())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildAccesoRapido(
              Icons.credit_card,
              'Tarjetas',
              Colors.purpleAccent,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TarjetasDigitalesConfigScreen())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildAccesoRapido(
              Icons.api,
              'APIs',
              Colors.tealAccent,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConfiguracionApisScreen())),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildAccesoRapido(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: PremiumCard(
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildGaveteroCard(Gavetero gavetero) {
    final activo = _isModuloActivo(gavetero.id);
    final submodulosActivos = gavetero.submodulos
        .where((s) => _isSubmoduloActivo(s.id))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: PremiumCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: gavetero.color.withOpacity(activo ? 0.3 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              gavetero.icono,
              color: activo ? gavetero.color : Colors.white38,
              size: 28,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(gavetero.nombre,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activo 
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  activo ? 'ACTIVO' : 'INACTIVO',
                  style: TextStyle(
                    color: activo ? Colors.greenAccent : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gavetero.descripcion,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 5),
              Text('$submodulosActivos/${gavetero.submodulos.length} submódulos activos',
                  style: TextStyle(
                    color: gavetero.color.withOpacity(0.7),
                    fontSize: 10,
                  )),
            ],
          ),
          trailing: Switch(
            value: activo,
            onChanged: (v) => _toggleGavetero(gavetero.id, v),
            activeColor: gavetero.color,
          ),
          children: [
            // Lista de submódulos
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: gavetero.submodulos.map((submodulo) {
                  final subActivo = _isSubmoduloActivo(submodulo.id);
                  return ListTile(
                    dense: true,
                    leading: Icon(submodulo.icono, 
                        color: subActivo ? gavetero.color : Colors.white38, size: 20),
                    title: Text(submodulo.nombre,
                        style: TextStyle(
                          color: subActivo ? Colors.white : Colors.white54,
                          fontSize: 13,
                        )),
                    trailing: Switch(
                      value: subActivo,
                      onChanged: activo 
                          ? (v) => _toggleSubmodulo(submodulo.id, v)
                          : null,
                      activeColor: gavetero.color,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Botón de configuración avanzada
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _configurarGavetero(gavetero),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Configurar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gavetero.color,
                      side: BorderSide(color: gavetero.color.withOpacity(0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _verDocumentacion(gavetero),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Documentación'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleGavetero(String gaveteroId, bool activo) async {
    try {
      await AppSupabase.client.from('modulos_activos').upsert({
        'modulo_id': gaveteroId,
        'tipo': 'gavetero',
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'modulo_id');

      await _cargarModulos();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activo ? 'Gavetero activado' : 'Gavetero desactivado'),
          backgroundColor: activo ? Colors.greenAccent : Colors.grey,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleSubmodulo(String submoduloId, bool activo) async {
    try {
      await AppSupabase.client.from('modulos_activos').upsert({
        'modulo_id': submoduloId,
        'tipo': 'submodulo',
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'modulo_id');

      await _cargarModulos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _configurarGavetero(Gavetero gavetero) {
    // TODO: Navegar a configuración específica del gavetero
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configurar ${gavetero.nombre}')),
    );
  }

  void _verDocumentacion(Gavetero gavetero) {
    // TODO: Mostrar documentación del gavetero
  }
}

// === CLASES DE DATOS ===

class Gavetero {
  final String id;
  final String nombre;
  final String descripcion;
  final Color color;
  final IconData icono;
  final List<Submodulo> submodulos;

  Gavetero({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.color,
    required this.icono,
    required this.submodulos,
  });
}

class Submodulo {
  final String id;
  final String nombre;
  final IconData icono;
  final bool activoPorDefecto;

  Submodulo(this.id, this.nombre, this.icono, this.activoPorDefecto);
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';

/// Pantalla de Control de Capital e Inversiones
/// Permite al superadmin ver su capital total, registrar envíos
/// de dinero y llevar control de inversiones
class MiCapitalScreen extends StatefulWidget {
  const MiCapitalScreen({super.key});

  @override
  State<MiCapitalScreen> createState() => _MiCapitalScreenState();
}

class _MiCapitalScreenState extends State<MiCapitalScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;

  // Formatters
  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');

  // Data
  Map<String, dynamic> _resumenCapital = {};
  List<Map<String, dynamic>> _envios = [];
  List<Map<String, dynamic>> _activos = [];
  List<Map<String, dynamic>> _empleados = [];
  String? _negocioId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      // Obtener negocio del usuario
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final usuarioRes = await AppSupabase.client
          .from('usuarios')
          .select('negocio_id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      _negocioId = usuarioRes?['negocio_id'];

      if (_negocioId != null) {
        // Cargar datos en paralelo
        await Future.wait([
          _cargarResumenCapital(),
          _cargarEnvios(),
          _cargarActivos(),
          _cargarEmpleados(),
        ]);
      }
    } catch (e) {
      debugPrint('Error cargando datos de capital: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarResumenCapital() async {
    try {
      // Capital en préstamos activos
      final prestamosRes = await AppSupabase.client
          .from('prestamos')
          .select('monto')
          .eq('negocio_id', _negocioId!)
          .inFilter('estado', ['activo', 'vigente']);

      double capitalPrestamos = 0;
      for (var p in prestamosRes) {
        capitalPrestamos += (p['monto'] ?? 0).toDouble();
      }

      // Capital en préstamos diarios
      final prestamosDiariosRes = await AppSupabase.client
          .from('prestamos')
          .select('monto')
          .eq('negocio_id', _negocioId!)
          .eq('estado', 'activo')
          .eq('tipo_prestamo', 'diario');

      double capitalDiarios = 0;
      for (var p in prestamosDiariosRes) {
        capitalDiarios += (p['monto'] ?? 0).toDouble();
      }

      // Capital en activos
      final activosRes = await AppSupabase.client
          .from('activos_capital')
          .select('valor_actual')
          .eq('negocio_id', _negocioId!)
          .eq('estado', 'activo');

      double capitalActivos = 0;
      for (var a in activosRes) {
        capitalActivos += (a['valor_actual'] ?? 0).toDouble();
      }

      // Total enviado
      final enviosRes = await AppSupabase.client
          .from('envios_capital')
          .select('monto_mxn')
          .eq('negocio_id', _negocioId!);

      double totalEnviado = 0;
      for (var e in enviosRes) {
        totalEnviado += (e['monto_mxn'] ?? 0).toDouble();
      }

      _resumenCapital = {
        'capital_prestamos': capitalPrestamos,
        'capital_diarios': capitalDiarios,
        'capital_activos': capitalActivos,
        'total_enviado': totalEnviado,
        'capital_total': capitalPrestamos + capitalDiarios + capitalActivos,
      };
    } catch (e) {
      debugPrint('Error cargando resumen: $e');
      _resumenCapital = {
        'capital_prestamos': 0.0,
        'capital_diarios': 0.0,
        'capital_activos': 0.0,
        'total_enviado': 0.0,
        'capital_total': 0.0,
      };
    }
  }

  Future<void> _cargarEnvios() async {
    try {
      final res = await AppSupabase.client
          .from('envios_capital')
          .select('''
            *,
            empleado:empleados(nombre),
            confirmador:usuarios!envios_capital_confirmado_por_fkey(nombre)
          ''')
          .eq('negocio_id', _negocioId!)
          .order('fecha_envio', ascending: false)
          .limit(50);

      _envios = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error cargando envíos: $e');
      _envios = [];
    }
  }

  Future<void> _cargarActivos() async {
    try {
      final res = await AppSupabase.client
          .from('activos_capital')
          .select('''
            *,
            empleado:empleados(nombre)
          ''')
          .eq('negocio_id', _negocioId!)
          .order('created_at', ascending: false);

      _activos = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error cargando activos: $e');
      _activos = [];
    }
  }

  Future<void> _cargarEmpleados() async {
    try {
      final res = await AppSupabase.client
          .from('empleados')
          .select('id, nombre')
          .eq('negocio_id', _negocioId!)
          .eq('activo', true)
          .order('nombre');

      _empleados = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error cargando empleados: $e');
      _empleados = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildResumenCapital()),
                SliverToBoxAdapter(child: _buildTabBar()),
                SliverFillRemaining(child: _buildTabContent()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevoEnvio,
        backgroundColor: Colors.cyanAccent,
        icon: const Icon(Icons.send, color: Colors.black),
        label: const Text('Registrar Envío', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D14),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Mi Capital',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Control de inversiones y envíos',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
        IconButton(
          icon: const Icon(Icons.add_chart),
          onPressed: _mostrarDialogoNuevoActivo,
          tooltip: 'Agregar Activo',
        ),
      ],
    );
  }

  Widget _buildResumenCapital() {
    final capitalTotal = _resumenCapital['capital_total'] ?? 0.0;
    final capitalPrestamos = _resumenCapital['capital_prestamos'] ?? 0.0;
    final capitalDiarios = _resumenCapital['capital_diarios'] ?? 0.0;
    final capitalActivos = _resumenCapital['capital_activos'] ?? 0.0;
    final totalEnviado = _resumenCapital['total_enviado'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'CAPITAL TOTAL INVERTIDO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency.format(capitalTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '📋 Préstamos',
                  _formatCurrency.format(capitalPrestamos),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  '📆 Diarios',
                  _formatCurrency.format(capitalDiarios),
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '🔧 Equipos/Activos',
                  _formatCurrency.format(capitalActivos),
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  '💸 Total Enviado',
                  _formatCurrency.format(totalEnviado),
                  Colors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.cyanAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.cyanAccent,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(icon: Icon(Icons.send), text: 'Envíos'),
          Tab(icon: Icon(Icons.inventory), text: 'Activos'),
          Tab(icon: Icon(Icons.analytics), text: 'Resumen'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListaEnvios(),
        _buildListaActivos(),
        _buildResumenDetallado(),
      ],
    );
  }

  Widget _buildListaEnvios() {
    if (_envios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No hay envíos registrados',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _mostrarDialogoNuevoEnvio,
              icon: const Icon(Icons.add),
              label: const Text('Registrar primer envío'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _envios.length,
      itemBuilder: (context, index) => _buildEnvioCard(_envios[index]),
    );
  }

  Widget _buildEnvioCard(Map<String, dynamic> envio) {
    final fecha = envio['fecha_envio'] != null
        ? DateTime.parse(envio['fecha_envio'])
        : DateTime.now();
    final monto = (envio['monto_mxn'] ?? envio['monto'] ?? 0).toDouble();
    final empleado = envio['empleado']?['nombre'] ?? envio['nombre_receptor'] ?? 'Sin especificar';
    final categoria = envio['categoria'] ?? 'inversion';
    final estado = envio['estado'] ?? 'enviado';
    final proposito = envio['proposito'] ?? '';
    final metodo = envio['metodo_envio'] ?? 'transferencia';

    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'recibido':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case 'aplicado':
        estadoColor = Colors.blue;
        estadoIcon = Icons.verified;
        break;
      default:
        estadoColor = Colors.orange;
        estadoIcon = Icons.schedule;
    }

    IconData categoriaIcon;
    switch (categoria) {
      case 'inversion':
        categoriaIcon = Icons.trending_up;
        break;
      case 'compra_equipo':
        categoriaIcon = Icons.build;
        break;
      case 'nomina':
        categoriaIcon = Icons.people;
        break;
      case 'operacion':
        categoriaIcon = Icons.settings;
        break;
      default:
        categoriaIcon = Icons.attach_money;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleEnvio(envio),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(categoriaIcon, color: Colors.greenAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency.format(monto),
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatDate.format(fecha)} • $metodo',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, color: estadoColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          estado.toUpperCase(),
                          style: TextStyle(
                            color: estadoColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Para: $empleado',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (proposito.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.note_outlined, color: Colors.white38, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        proposito,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaActivos() {
    if (_activos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No hay activos registrados',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _mostrarDialogoNuevoActivo,
              icon: const Icon(Icons.add),
              label: const Text('Agregar activo'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activos.length,
      itemBuilder: (context, index) => _buildActivoCard(_activos[index]),
    );
  }

  Widget _buildActivoCard(Map<String, dynamic> activo) {
    final nombre = activo['nombre'] ?? 'Sin nombre';
    final tipo = activo['tipo'] ?? 'otro';
    final valorActual = (activo['valor_actual'] ?? 0).toDouble();
    final estado = activo['estado'] ?? 'activo';
    final empleado = activo['empleado']?['nombre'];

    IconData tipoIcon;
    Color tipoColor;
    switch (tipo) {
      case 'equipo_clima':
        tipoIcon = Icons.ac_unit;
        tipoColor = Colors.cyan;
        break;
      case 'vehiculo':
        tipoIcon = Icons.directions_car;
        tipoColor = Colors.blue;
        break;
      case 'herramienta':
        tipoIcon = Icons.build;
        tipoColor = Colors.orange;
        break;
      case 'propiedad':
        tipoIcon = Icons.home;
        tipoColor = Colors.green;
        break;
      default:
        tipoIcon = Icons.inventory;
        tipoColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tipoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tipoIcon, color: tipoColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tipo.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: tipoColor, fontSize: 11),
                ),
                if (empleado != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Asignado a: $empleado',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency.format(valorActual),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estado == 'activo' 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estado.toUpperCase(),
                  style: TextStyle(
                    color: estado == 'activo' ? Colors.green : Colors.red,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDetallado() {
    // Calcular totales por categoría de envío
    double totalInversion = 0;
    double totalOperacion = 0;
    double totalEquipos = 0;
    double totalNomina = 0;

    for (var envio in _envios) {
      final monto = (envio['monto_mxn'] ?? envio['monto'] ?? 0).toDouble();
      switch (envio['categoria']) {
        case 'inversion':
          totalInversion += monto;
          break;
        case 'operacion':
          totalOperacion += monto;
          break;
        case 'compra_equipo':
          totalEquipos += monto;
          break;
        case 'nomina':
          totalNomina += monto;
          break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de Envíos',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildCategoriaRow('📈 Inversión', totalInversion, Colors.green),
          _buildCategoriaRow('⚙️ Operación', totalOperacion, Colors.blue),
          _buildCategoriaRow('🔧 Compra Equipos', totalEquipos, Colors.orange),
          _buildCategoriaRow('👥 Nómina', totalNomina, Colors.purple),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Estadísticas',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatRow('Total de envíos', '${_envios.length}'),
                _buildStatRow('Total de activos', '${_activos.where((a) => a['estado'] == 'activo').length}'),
                _buildStatRow('Promedio por envío', _envios.isNotEmpty 
                    ? _formatCurrency.format((_resumenCapital['total_enviado'] ?? 0) / _envios.length)
                    : '\$0.00'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaRow(String label, double monto, Color color) {
    final total = _resumenCapital['total_enviado'] ?? 1.0;
    final porcentaje = total > 0 ? (monto / total * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(
                _formatCurrency.format(monto),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: porcentaje / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${porcentaje.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevoEnvio() {
    final montoController = TextEditingController();
    final tipoCambioController = TextEditingController(text: '17.50');
    final referenciaController = TextEditingController();
    final propositoController = TextEditingController();
    String moneda = 'USD';
    String metodo = 'transferencia';
    String categoria = 'inversion';
    String? empleadoSeleccionado;
    DateTime fechaEnvio = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send, color: Colors.cyanAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Registrar Envío de Dinero',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Monto y moneda
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: montoController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 24),
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          prefixText: moneda == 'USD' ? '\$ ' : '\$ ',
                          prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 24),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: moneda,
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Moneda',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD 🇺🇸')),
                          DropdownMenuItem(value: 'MXN', child: Text('MXN 🇲🇽')),
                        ],
                        onChanged: (v) => setSheetState(() => moneda = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tipo de cambio (solo si es USD)
                if (moneda == 'USD')
                  TextField(
                    controller: tipoCambioController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tipo de cambio',
                      hintText: 'Ej: 17.50',
                      hintStyle: const TextStyle(color: Colors.white24),
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 12),

                // Empleado destino
                DropdownButtonFormField<String>(
                  value: empleadoSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enviar a (empleado)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _empleados.map((e) => DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(e['nombre'] ?? 'Sin nombre'),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => empleadoSeleccionado = v),
                ),
                const SizedBox(height: 12),

                // Categoría y método
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: categoria,
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'inversion', child: Text('📈 Inversión')),
                          DropdownMenuItem(value: 'operacion', child: Text('⚙️ Operación')),
                          DropdownMenuItem(value: 'compra_equipo', child: Text('🔧 Equipo')),
                          DropdownMenuItem(value: 'nomina', child: Text('👥 Nómina')),
                          DropdownMenuItem(value: 'otro', child: Text('📦 Otro')),
                        ],
                        onChanged: (v) => setSheetState(() => categoria = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: metodo,
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Método',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'transferencia', child: Text('🏦 Transfer')),
                          DropdownMenuItem(value: 'remesa', child: Text('💸 Remesa')),
                          DropdownMenuItem(value: 'efectivo', child: Text('💵 Efectivo')),
                          DropdownMenuItem(value: 'otro', child: Text('📦 Otro')),
                        ],
                        onChanged: (v) => setSheetState(() => metodo = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Referencia
                TextField(
                  controller: referenciaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Referencia / Confirmación',
                    hintText: 'Número de referencia del envío',
                    hintStyle: const TextStyle(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Propósito
                TextField(
                  controller: propositoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Propósito / Notas',
                    hintText: 'Ej: Para capital de préstamos semanales',
                    hintStyle: const TextStyle(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final monto = double.tryParse(montoController.text) ?? 0;
                      if (monto <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa un monto válido'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      final tipoCambio = double.tryParse(tipoCambioController.text) ?? 17.5;
                      final montoMxn = moneda == 'USD' ? monto * tipoCambio : monto;

                      try {
                        final user = AppSupabase.client.auth.currentUser;
                        await AppSupabase.client.from('envios_capital').insert({
                          'negocio_id': _negocioId,
                          'fecha_envio': fechaEnvio.toIso8601String().split('T')[0],
                          'monto': monto,
                          'moneda': moneda,
                          'tipo_cambio': moneda == 'USD' ? tipoCambio : null,
                          'monto_mxn': montoMxn,
                          'metodo_envio': metodo,
                          'referencia': referenciaController.text.isNotEmpty ? referenciaController.text : null,
                          'empleado_id': empleadoSeleccionado,
                          'categoria': categoria,
                          'proposito': propositoController.text.isNotEmpty ? propositoController.text : null,
                          'estado': 'enviado',
                          'created_by': user?.id,
                        });

                        Navigator.pop(context);
                        await _cargarDatos();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Envío de ${_formatCurrency.format(montoMxn)} registrado'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('REGISTRAR ENVÍO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoNuevoActivo() {
    final nombreController = TextEditingController();
    final valorController = TextEditingController();
    final descripcionController = TextEditingController();
    String tipo = 'equipo_clima';
    String? empleadoSeleccionado;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_chart, color: Colors.purple),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Agregar Activo/Equipo',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nombre
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del activo',
                    hintText: 'Ej: Minisplit Mirage 1 Ton',
                    hintStyle: const TextStyle(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Tipo y valor
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: tipo,
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'equipo_clima', child: Text('❄️ Equipo Clima')),
                          DropdownMenuItem(value: 'vehiculo', child: Text('🚗 Vehículo')),
                          DropdownMenuItem(value: 'herramienta', child: Text('🔧 Herramienta')),
                          DropdownMenuItem(value: 'propiedad', child: Text('🏠 Propiedad')),
                          DropdownMenuItem(value: 'otro', child: Text('📦 Otro')),
                        ],
                        onChanged: (v) => setSheetState(() => tipo = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: valorController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Valor',
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: Colors.greenAccent),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Asignado a
                DropdownButtonFormField<String>(
                  value: empleadoSeleccionado,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Asignado a (opcional)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ..._empleados.map((e) => DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text(e['nombre'] ?? 'Sin nombre'),
                    )),
                  ],
                  onChanged: (v) => setSheetState(() => empleadoSeleccionado = v),
                ),
                const SizedBox(height: 12),

                // Descripción
                TextField(
                  controller: descripcionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintStyle: const TextStyle(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nombreController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa el nombre del activo'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      final valor = double.tryParse(valorController.text) ?? 0;

                      try {
                        final user = AppSupabase.client.auth.currentUser;
                        await AppSupabase.client.from('activos_capital').insert({
                          'negocio_id': _negocioId,
                          'nombre': nombreController.text,
                          'descripcion': descripcionController.text.isNotEmpty ? descripcionController.text : null,
                          'tipo': tipo,
                          'costo_adquisicion': valor,
                          'valor_actual': valor,
                          'fecha_adquisicion': DateTime.now().toIso8601String().split('T')[0],
                          'asignado_a': empleadoSeleccionado,
                          'estado': 'activo',
                          'created_by': user?.id,
                        });

                        Navigator.pop(context);
                        await _cargarDatos();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Activo registrado'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('GUARDAR ACTIVO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleEnvio(Map<String, dynamic> envio) {
    final fecha = envio['fecha_envio'] != null
        ? DateTime.parse(envio['fecha_envio'])
        : DateTime.now();
    final monto = (envio['monto'] ?? 0).toDouble();
    final montoMxn = (envio['monto_mxn'] ?? monto).toDouble();
    final moneda = envio['moneda'] ?? 'MXN';
    final tipoCambio = envio['tipo_cambio'];
    final empleado = envio['empleado']?['nombre'] ?? envio['nombre_receptor'] ?? 'Sin especificar';
    final metodo = envio['metodo_envio'] ?? 'transferencia';
    final referencia = envio['referencia'];
    final proposito = envio['proposito'];
    final estado = envio['estado'] ?? 'enviado';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.greenAccent),
            ),
            const SizedBox(width: 12),
            const Text('Detalle del Envío', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _formatCurrency.format(montoMxn),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (moneda == 'USD' && tipoCambio != null) ...[
                Center(
                  child: Text(
                    '\$${monto.toStringAsFixed(2)} USD × $tipoCambio',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildDetalleRow('📅 Fecha', _formatDate.format(fecha)),
              _buildDetalleRow('👤 Destinatario', empleado),
              _buildDetalleRow('💳 Método', metodo),
              if (referencia != null && referencia.isNotEmpty)
                _buildDetalleRow('🔢 Referencia', referencia),
              if (proposito != null && proposito.isNotEmpty)
                _buildDetalleRow('📝 Propósito', proposito),
              _buildDetalleRow('📊 Estado', estado.toUpperCase()),
            ],
          ),
        ),
        actions: [
          if (estado == 'enviado')
            TextButton.icon(
              onPressed: () async {
                await AppSupabase.client
                    .from('envios_capital')
                    .update({'estado': 'recibido', 'fecha_recibido': DateTime.now().toIso8601String()})
                    .eq('id', envio['id']);
                Navigator.pop(context);
                _cargarDatos();
              },
              icon: const Icon(Icons.check, color: Colors.green),
              label: const Text('Marcar Recibido', style: TextStyle(color: Colors.green)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

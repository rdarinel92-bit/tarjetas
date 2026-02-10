// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS CONTRATOS MANTENIMIENTO - V10.55
// Gestión de contratos mensuales/anuales con renovación automática
// Para Superadmin y Empleados
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class ClimasContratosScreen extends StatefulWidget {
  final String? negocioId;
  
  const ClimasContratosScreen({super.key, this.negocioId});

  @override
  State<ClimasContratosScreen> createState() => _ClimasContratosScreenState();
}

class _ClimasContratosScreenState extends State<ClimasContratosScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  String _filtroEstado = 'todos';
  
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _proximosVencimientos = [];
  List<Map<String, dynamic>> _historialRenovaciones = [];
  
  // KPIs
  int _contratosActivos = 0;
  double _ingresosMensualesRecurrentes = 0;
  int _contratosPorVencer = 0;
  double _tasaRenovacion = 0;

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
      // Cargar contratos
      var query = AppSupabase.client
          .from('climas_contratos')
          .select('*, climas_clientes(nombre, telefono, email), climas_equipos(marca, modelo)');
      
      if (widget.negocioId != null) {
        query = query.eq('negocio_id', widget.negocioId!);
      }
      
      final resultado = await query.order('fecha_vencimiento');
      _contratos = List<Map<String, dynamic>>.from(resultado);
      
      // Calcular KPIs
      _contratosActivos = _contratos.where((c) => c['estado'] == 'activo').length;
      _ingresosMensualesRecurrentes = _contratos
          .where((c) => c['estado'] == 'activo')
          .fold(0.0, (sum, c) {
            final monto = double.tryParse(c['monto']?.toString() ?? '0') ?? 0;
            final periodicidad = c['periodicidad'] ?? 'mensual';
            return sum + (periodicidad == 'anual' ? monto / 12 : monto);
          });
      
      // Contratos por vencer (próximos 30 días)
      final ahora = DateTime.now();
      final en30Dias = ahora.add(const Duration(days: 30));
      _proximosVencimientos = _contratos.where((c) {
        final vencimiento = DateTime.tryParse(c['fecha_vencimiento'] ?? '');
        return vencimiento != null && 
               vencimiento.isAfter(ahora) && 
               vencimiento.isBefore(en30Dias) &&
               c['estado'] == 'activo';
      }).toList();
      _contratosPorVencer = _proximosVencimientos.length;
      
      // Historial de renovaciones (últimos 90 días)
      await _cargarHistorialRenovaciones();
      
      // Tasa de renovación
      final ventadosMes = _contratos.where((c) {
        final vencimiento = DateTime.tryParse(c['fecha_vencimiento'] ?? '');
        final hace90Dias = ahora.subtract(const Duration(days: 90));
        return vencimiento != null && 
               vencimiento.isBefore(ahora) && 
               vencimiento.isAfter(hace90Dias);
      }).toList();
      
      if (ventadosMes.isNotEmpty) {
        final renovados = ventadosMes.where((c) => c['renovado'] == true).length;
        _tasaRenovacion = (renovados / ventadosMes.length) * 100;
      }
      
    } catch (e) {
      debugPrint('Error cargando contratos: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarHistorialRenovaciones() async {
    try {
      var query = AppSupabase.client
          .from('climas_contratos_historial')
          .select('*, climas_contratos(*, climas_clientes(nombre))');
      
      if (widget.negocioId != null) {
        query = query.eq('negocio_id', widget.negocioId!);
      }
      
      final resultado = await query.order('created_at', ascending: false).limit(50);
      _historialRenovaciones = List<Map<String, dynamic>>.from(resultado);
    } catch (e) {
      debugPrint('Error cargando historial: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Contratos Mantenimiento',
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _mostrarFormularioContrato,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
              children: [
                // KPIs
                _buildKPIsRow(),
                
                // Tabs
                Container(
                  color: const Color(0xFF0D0D14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.cyan,
                    labelColor: Colors.cyan,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Contratos'),
                      Tab(icon: Icon(Icons.warning_amber, size: 20), text: 'Por Vencer'),
                      Tab(icon: Icon(Icons.history, size: 20), text: 'Historial'),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContratosTab(),
                      _buildPorVencerTab(),
                      _buildHistorialTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKPIsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildMiniKPI(
            Icons.description,
            '$_contratosActivos',
            'Activos',
            Colors.green,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            Icons.attach_money,
            _currencyFormat.format(_ingresosMensualesRecurrentes),
            'MRR',
            Colors.amber,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            Icons.warning,
            '$_contratosPorVencer',
            'Por vencer',
            Colors.orange,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniKPI(
            Icons.autorenew,
            '${_tasaRenovacion.toStringAsFixed(0)}%',
            'Renovación',
            Colors.cyan,
          )),
        ],
      ),
    );
  }

  Widget _buildMiniKPI(IconData icono, String valor, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildContratosTab() {
    // Filtrar contratos
    List<Map<String, dynamic>> contratosFiltrados = _filtroEstado == 'todos'
        ? _contratos
        : _contratos.where((c) => c['estado'] == _filtroEstado).toList();
    
    return Column(
      children: [
        // Filtros
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFiltroChip('todos', 'Todos'),
                const SizedBox(width: 8),
                _buildFiltroChip('activo', 'Activos'),
                const SizedBox(width: 8),
                _buildFiltroChip('vencido', 'Vencidos'),
                const SizedBox(width: 8),
                _buildFiltroChip('cancelado', 'Cancelados'),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: contratosFiltrados.isEmpty
              ? _buildEmptyState('No hay contratos')
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contratosFiltrados.length,
                    itemBuilder: (context, index) => _buildContratoCard(contratosFiltrados[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String valor, String label) {
    final isSelected = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildContratoCard(Map<String, dynamic> contrato) {
    final cliente = contrato['climas_clientes'];
    final equipo = contrato['climas_equipos'];
    final estado = contrato['estado'] ?? 'activo';
    final vencimiento = DateTime.tryParse(contrato['fecha_vencimiento'] ?? '');
    final diasParaVencer = vencimiento?.difference(DateTime.now()).inDays ?? 0;
    final monto = double.tryParse(contrato['monto']?.toString() ?? '0') ?? 0;
    
    Color estadoColor = estado == 'activo' ? Colors.green 
                      : estado == 'vencido' ? Colors.orange 
                      : Colors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: diasParaVencer <= 30 && diasParaVencer > 0 && estado == 'activo'
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [estadoColor.withOpacity(0.2), Colors.transparent],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description, color: Colors.cyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente?['nombre'] ?? 'Sin cliente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (equipo != null)
                        Text(
                          '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('Tipo', contrato['tipo_contrato'] ?? 'Mantenimiento')),
                    Expanded(child: _buildInfoItem('Periodicidad', contrato['periodicidad'] ?? 'Mensual')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('Monto', _currencyFormat.format(monto))),
                    Expanded(child: _buildInfoItem(
                      'Vence',
                      vencimiento != null ? _dateFormat.format(vencimiento) : '-',
                      color: diasParaVencer <= 30 && estado == 'activo' ? Colors.orange : null,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Servicios incluidos
                if (contrato['servicios_incluidos'] != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Servicios incluidos:',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contrato['servicios_incluidos'],
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Acciones
                Row(
                  children: [
                    if (estado == 'activo') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _renovarContrato(contrato),
                          icon: const Icon(Icons.autorenew, size: 18),
                          label: const Text('Renovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editarContrato(contrato),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String valor, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          valor, 
          style: TextStyle(
            color: color ?? Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPorVencerTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: _proximosVencimientos.isEmpty
          ? _buildEmptyState('No hay contratos por vencer')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _proximosVencimientos.length,
              itemBuilder: (context, index) {
                final contrato = _proximosVencimientos[index];
                final vencimiento = DateTime.tryParse(contrato['fecha_vencimiento'] ?? '');
                final diasRestantes = vencimiento?.difference(DateTime.now()).inDays ?? 0;
                final cliente = contrato['climas_clientes'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: diasRestantes <= 7 ? Colors.red : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Días restantes
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: (diasRestantes <= 7 ? Colors.red : Colors.orange).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$diasRestantes',
                                style: TextStyle(
                                  color: diasRestantes <= 7 ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'días',
                                style: TextStyle(
                                  color: (diasRestantes <= 7 ? Colors.red : Colors.orange).withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente?['nombre'] ?? 'Sin cliente',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (cliente?['telefono'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone, size: 12, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      cliente['telefono'],
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildMiniTag(contrato['tipo_contrato'] ?? 'Mantenimiento'),
                                const SizedBox(width: 8),
                                Text(
                                  _currencyFormat.format(double.tryParse(contrato['monto']?.toString() ?? '0') ?? 0),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Acción rápida
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.autorenew, color: Colors.cyan),
                            onPressed: () => _renovarContrato(contrato),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.green),
                            onPressed: () => _contactarCliente(contrato),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMiniTag(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHistorialTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: _historialRenovaciones.isEmpty
          ? _buildEmptyState('No hay historial de renovaciones')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _historialRenovaciones.length,
              itemBuilder: (context, index) {
                final item = _historialRenovaciones[index];
                final contrato = item['climas_contratos'];
                final cliente = contrato?['climas_clientes'];
                final fecha = DateTime.tryParse(item['created_at'] ?? '');
                final accion = item['accion'] ?? 'renovacion';
                
                Color accionColor = accion == 'renovacion' ? Colors.green 
                                  : accion == 'cancelacion' ? Colors.red 
                                  : Colors.blue;
                IconData accionIcon = accion == 'renovacion' ? Icons.autorenew 
                                    : accion == 'cancelacion' ? Icons.cancel 
                                    : Icons.edit;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accionColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(accionIcon, color: accionColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente?['nombre'] ?? 'Sin cliente',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _formatearAccion(accion),
                              style: TextStyle(color: accionColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (fecha != null)
                        Text(
                          _dateFormat.format(fecha),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatearAccion(String accion) {
    switch (accion) {
      case 'renovacion': return 'Contrato renovado';
      case 'cancelacion': return 'Contrato cancelado';
      case 'modificacion': return 'Contrato modificado';
      case 'creacion': return 'Contrato creado';
      default: return accion;
    }
  }

  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(mensaje, style: TextStyle(color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  void _mostrarFormularioContrato() {
    // Navegar a formulario de nuevo contrato
    Navigator.pushNamed(context, '/climas/contratos/nuevo');
  }

  void _renovarContrato(Map<String, dynamic> contrato) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Renovar Contrato', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Desea renovar el contrato de ${contrato['climas_clientes']?['nombre']}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildRenovacionOption('1 mes', 1),
            _buildRenovacionOption('3 meses', 3),
            _buildRenovacionOption('6 meses', 6),
            _buildRenovacionOption('1 año', 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRenovacionOption(String label, int meses) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today, color: Colors.cyan),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        Navigator.pop(context);
        // Aquí iría la lógica para renovar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contrato renovado por $label'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarDatos();
      },
    );
  }

  void _editarContrato(Map<String, dynamic> contrato) {
    Navigator.pushNamed(
      context, 
      '/climas/contratos/editar',
      arguments: contrato,
    );
  }

  void _contactarCliente(Map<String, dynamic> contrato) {
    final cliente = contrato['climas_clientes'];
    if (cliente == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contactar a ${cliente['nombre']}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (cliente['telefono'] != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(cliente['telefono'], style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Llamar', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  // Lógica para llamar
                },
              ),
            if (cliente['telefono'] != null)
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Enviar mensaje', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  // Lógica para WhatsApp
                },
              ),
            if (cliente['email'] != null)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: Text(cliente['email'], style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Enviar correo', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  // Lógica para email
                },
              ),
          ],
        ),
      ),
    );
  }
}

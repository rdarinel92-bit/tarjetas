// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// PANEL DE RECURSOS HUMANOS
/// Robert Darin Platform V10.11
/// ══════════════════════════════════════════════════════════════════════════════
/// Panel especializado para gestión de personal, nómina y expedientes
/// ══════════════════════════════════════════════════════════════════════════════

class RecursosHumanosScreen extends StatefulWidget {
  const RecursosHumanosScreen({super.key});

  @override
  State<RecursosHumanosScreen> createState() => _RecursosHumanosScreenState();
}

class _RecursosHumanosScreenState extends State<RecursosHumanosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  bool _isLoading = true;
  
  // Datos de RRHH
  List<Map<String, dynamic>> _empleados = [];
  Map<String, dynamic> _estadisticas = {};
  List<Map<String, dynamic>> _contratacionesRecientes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatosRRHH();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosRRHH() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Cargar todos los empleados con sus datos
      final empleadosRes = await AppSupabase.client
          .from('empleados')
          .select('''
            id, puesto, salario, estado, fecha_contratacion,
            comision_porcentaje, comision_tipo,
            usuarios(id, nombre_completo, email, telefono),
            sucursales(nombre)
          ''')
          .order('fecha_contratacion', ascending: false);
      
      _empleados = List<Map<String, dynamic>>.from(empleadosRes);
      
      // Calcular estadísticas
      int activos = 0;
      int inactivos = 0;
      double totalNomina = 0;
      double promedioSalario = 0;
      int conComision = 0;
      
      for (var emp in _empleados) {
        if (emp['estado'] == 'activo') {
          activos++;
          totalNomina += (emp['salario'] ?? 0).toDouble();
        } else {
          inactivos++;
        }
        if ((emp['comision_porcentaje'] ?? 0) > 0) conComision++;
      }
      
      if (activos > 0) promedioSalario = totalNomina / activos;
      
      // Contrataciones recientes (últimos 90 días)
      final hace90Dias = DateTime.now().subtract(const Duration(days: 90));
      _contratacionesRecientes = _empleados.where((e) {
        final fecha = DateTime.tryParse(e['fecha_contratacion'] ?? '');
        return fecha != null && fecha.isAfter(hace90Dias);
      }).toList();
      
      setState(() {
        _estadisticas = {
          'total_empleados': _empleados.length,
          'activos': activos,
          'inactivos': inactivos,
          'total_nomina': totalNomina,
          'promedio_salario': promedioSalario,
          'con_comision': conComision,
          'contrataciones_recientes': _contratacionesRecientes.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando datos RRHH: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '👥 Recursos Humanos',
      subtitle: 'Gestión de Personal',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tabs
                Container(
                  color: const Color(0xFF1A1A2E),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.purpleAccent,
                    labelColor: Colors.purpleAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Resumen'),
                      Tab(icon: Icon(Icons.people, size: 20), text: 'Plantilla'),
                      Tab(icon: Icon(Icons.payments, size: 20), text: 'Nómina'),
                      Tab(icon: Icon(Icons.folder_shared, size: 20), text: 'Expedientes'),
                    ],
                  ),
                ),
                
                // Contenido
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildPlantillaTab(),
                      _buildNominaTab(),
                      _buildExpedientesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosRRHH,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs principales
            Row(
              children: [
                Expanded(child: _buildKpiCard(
                  'Total Empleados',
                  '${_estadisticas['total_empleados'] ?? 0}',
                  Icons.groups,
                  Colors.blueAccent,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(
                  'Activos',
                  '${_estadisticas['activos'] ?? 0}',
                  Icons.check_circle,
                  Colors.greenAccent,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildKpiCard(
                  'Nómina Mensual',
                  _currencyFormat.format(_estadisticas['total_nomina'] ?? 0),
                  Icons.account_balance_wallet,
                  Colors.orangeAccent,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(
                  'Con Comisión',
                  '${_estadisticas['con_comision'] ?? 0}',
                  Icons.percent,
                  Colors.purpleAccent,
                )),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Contrataciones recientes
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_add, color: Colors.greenAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Contrataciones Recientes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Últimos 90 días: ${_contratacionesRecientes.length}',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  if (_contratacionesRecientes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No hay contrataciones recientes', style: TextStyle(color: Colors.white54))),
                    )
                  else
                    ...List.generate(
                      _contratacionesRecientes.length > 5 ? 5 : _contratacionesRecientes.length,
                      (index) {
                        final emp = _contratacionesRecientes[index];
                        final nombre = emp['usuarios']?['nombre_completo'] ?? 'Sin nombre';
                        final puesto = emp['puesto'] ?? 'Sin puesto';
                        final fecha = DateTime.tryParse(emp['fecha_contratacion'] ?? '');
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Text(nombre[0].toUpperCase(), style: const TextStyle(color: Colors.blueAccent)),
                          ),
                          title: Text(nombre, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(puesto, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: fecha != null
                              ? Text(DateFormat('dd/MM/yy').format(fecha), style: const TextStyle(color: Colors.white38, fontSize: 11))
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Distribución por estado
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Distribución del Personal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildDistribucionBar('Activos', _estadisticas['activos'] ?? 0, _estadisticas['total_empleados'] ?? 1, Colors.greenAccent),
                  const SizedBox(height: 10),
                  _buildDistribucionBar('Inactivos', _estadisticas['inactivos'] ?? 0, _estadisticas['total_empleados'] ?? 1, Colors.grey),
                  const SizedBox(height: 10),
                  _buildDistribucionBar('Con Comisión', _estadisticas['con_comision'] ?? 0, _estadisticas['total_empleados'] ?? 1, Colors.purpleAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantillaTab() {
    final empleadosActivos = _empleados.where((e) => e['estado'] == 'activo').toList();
    
    return RefreshIndicator(
      onRefresh: _cargarDatosRRHH,
      child: empleadosActivos.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, color: Colors.white24, size: 60),
                  SizedBox(height: 16),
                  Text('No hay empleados activos', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: empleadosActivos.length,
              itemBuilder: (context, index) {
                final emp = empleadosActivos[index];
                return _buildEmpleadoCard(emp);
              },
            ),
    );
  }

  Widget _buildNominaTab() {
    final empleadosActivos = _empleados.where((e) => e['estado'] == 'activo').toList();
    
    return RefreshIndicator(
      onRefresh: _cargarDatosRRHH,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de nómina
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('💰 Nómina Total Mensual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        _currencyFormat.format(_estadisticas['total_nomina'] ?? 0),
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Promedio por empleado:', style: const TextStyle(color: Colors.white54)),
                      Text(
                        _currencyFormat.format(_estadisticas['promedio_salario'] ?? 0),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            const Text('📋 Desglose por Empleado', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Lista de salarios
            ...empleadosActivos.map((emp) {
              final nombre = emp['usuarios']?['nombre_completo'] ?? 'Sin nombre';
              final puesto = emp['puesto'] ?? 'Sin puesto';
              final salario = (emp['salario'] ?? 0).toDouble();
              final comision = (emp['comision_porcentaje'] ?? 0).toDouble();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PremiumCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(puesto, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currencyFormat.format(salario), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          if (comision > 0)
                            Text('+ ${comision.toStringAsFixed(0)}% comisión', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 20),
            
            // Botón de exportar
            ElevatedButton.icon(
              onPressed: _exportarNomina,
              icon: const Icon(Icons.download),
              label: const Text('Exportar Nómina'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpedientesTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatosRRHH,
      child: _empleados.isEmpty
          ? const Center(
              child: Text('No hay expedientes', style: TextStyle(color: Colors.white54)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _empleados.length,
              itemBuilder: (context, index) {
                final emp = _empleados[index];
                return _buildExpedienteCard(emp);
              },
            ),
    );
  }

  Widget _buildEmpleadoCard(Map<String, dynamic> emp) {
    final nombre = emp['usuarios']?['nombre_completo'] ?? 'Sin nombre';
    final email = emp['usuarios']?['email'] ?? '';
    final telefono = emp['usuarios']?['telefono'] ?? '';
    final puesto = emp['puesto'] ?? 'Sin puesto';
    final sucursal = emp['sucursales']?['nombre'] ?? 'Sin asignar';
    final estado = emp['estado'] ?? 'activo';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: estado == 'activo' 
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: estado == 'activo' ? Colors.greenAccent : Colors.grey,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(puesto, style: const TextStyle(color: Colors.purpleAccent, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estado == 'activo' ? Colors.greenAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      color: estado == 'activo' ? Colors.greenAccent : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            Row(
              children: [
                Expanded(child: _buildInfoChip(Icons.store, sucursal)),
                if (email.isNotEmpty)
                  Expanded(child: _buildInfoChip(Icons.email, email)),
              ],
            ),
            if (telefono.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildInfoChip(Icons.phone, telefono),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpedienteCard(Map<String, dynamic> emp) {
    final nombre = emp['usuarios']?['nombre_completo'] ?? 'Sin nombre';
    final puesto = emp['puesto'] ?? 'Sin puesto';
    final fechaContratacion = DateTime.tryParse(emp['fecha_contratacion'] ?? '');
    final salario = (emp['salario'] ?? 0).toDouble();
    final comision = (emp['comision_porcentaje'] ?? 0).toDouble();
    final tipoComision = emp['comision_tipo'] ?? 'ninguna';
    final estado = emp['estado'] ?? 'activo';
    
    // Calcular antigüedad
    String antiguedad = 'N/A';
    if (fechaContratacion != null) {
      final dias = DateTime.now().difference(fechaContratacion).inDays;
      if (dias < 30) {
        antiguedad = '$dias días';
      } else if (dias < 365) {
        antiguedad = '${(dias / 30).floor()} meses';
      } else {
        final anos = (dias / 365).floor();
        final meses = ((dias % 365) / 30).floor();
        antiguedad = '$anos año${anos > 1 ? 's' : ''}${meses > 0 ? ', $meses mes${meses > 1 ? 'es' : ''}' : ''}';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            child: const Icon(Icons.folder_shared, color: Colors.blueAccent, size: 20),
          ),
          title: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(puesto, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white38,
          children: [
            const Divider(color: Colors.white12),
            _buildExpedienteRow('📅 Fecha Contratación', fechaContratacion != null ? DateFormat('dd/MM/yyyy').format(fechaContratacion) : 'N/A'),
            _buildExpedienteRow('⏱️ Antigüedad', antiguedad),
            _buildExpedienteRow('💰 Salario', _currencyFormat.format(salario)),
            _buildExpedienteRow('📊 Comisión', comision > 0 ? '${comision.toStringAsFixed(0)}% ($tipoComision)' : 'Sin comisión'),
            _buildExpedienteRow('📌 Estado', estado.toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _buildExpedienteRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icon, Color color) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDistribucionBar(String label, int valor, int total, Color color) {
    final porcentaje = total > 0 ? (valor / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text('$valor (${(porcentaje * 100).toStringAsFixed(0)}%)', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: porcentaje,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _exportarNomina() {
    final empleadosActivos = _empleados.where((e) => e['estado'] == 'activo').toList();
    
    final StringBuffer reporte = StringBuffer();
    reporte.writeln('════════════════════════════════════════');
    reporte.writeln('REPORTE DE NÓMINA - ROBERT DARIN FINTECH');
    reporte.writeln('════════════════════════════════════════');
    reporte.writeln('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    reporte.writeln('');
    reporte.writeln('EMPLEADO,PUESTO,SALARIO,COMISION');
    
    for (var emp in empleadosActivos) {
      final nombre = emp['usuarios']?['nombre_completo'] ?? 'Sin nombre';
      final puesto = emp['puesto'] ?? 'Sin puesto';
      final salario = (emp['salario'] ?? 0).toDouble();
      final comision = (emp['comision_porcentaje'] ?? 0).toDouble();
      reporte.writeln('"$nombre","$puesto",${salario.toStringAsFixed(2)},${comision.toStringAsFixed(0)}%');
    }
    
    reporte.writeln('');
    reporte.writeln('TOTAL NÓMINA: ${_currencyFormat.format(_estadisticas['total_nomina'] ?? 0)}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('📋 Nómina Exportada', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reporte.toString(),
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 Nómina copiada - Pega en Excel'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar CSV'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
          ),
        ],
      ),
    );
  }
}

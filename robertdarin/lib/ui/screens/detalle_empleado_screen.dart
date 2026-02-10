// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import 'permisos_chat_qr_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DETALLE EMPLEADO - Robert Darin Platform v10.18
/// Información completa, comisiones, desempeño y actividad
/// ═══════════════════════════════════════════════════════════════════════════════
class DetalleEmpleadoScreen extends StatefulWidget {
  final String empleadoId;
  const DetalleEmpleadoScreen({super.key, required this.empleadoId});

  @override
  State<DetalleEmpleadoScreen> createState() => _DetalleEmpleadoScreenState();
}

class _DetalleEmpleadoScreenState extends State<DetalleEmpleadoScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late TabController _tabController;
  
  bool _isLoading = true;
  Map<String, dynamic> _empleado = {};
  Map<String, dynamic>? _usuario;
  Map<String, dynamic>? _sucursal;
  List<Map<String, dynamic>> _comisiones = [];
  List<Map<String, dynamic>> _prestamosAsignados = [];
  List<Map<String, dynamic>> _cobrosRealizados = [];
  
  // Estadísticas
  double _totalComisionesGanadas = 0;
  double _comisionesPendientes = 0;
  // ignore: unused_field
  int _prestamosGestionados = 0;
  int _cobrosDelMes = 0;
  double _montoRecaudado = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar empleado
      final empRes = await AppSupabase.client
          .from('empleados')
          .select('*, usuarios(*), sucursales(*)')
          .eq('id', widget.empleadoId)
          .single();

      _empleado = empRes;
      _usuario = empRes['usuarios'];
      _sucursal = empRes['sucursales'];

      // Cargar comisiones
      try {
        final comRes = await AppSupabase.client
            .from('comisiones_empleados')
            .select('*, prestamos(clientes(nombre))')
            .eq('empleado_id', widget.empleadoId)
            .order('created_at', ascending: false)
            .limit(50);
        _comisiones = List<Map<String, dynamic>>.from(comRes);
        
        for (var c in _comisiones) {
          if (c['estado'] == 'pagada') {
            _totalComisionesGanadas += (c['monto'] ?? 0).toDouble();
          } else {
            _comisionesPendientes += (c['monto'] ?? 0).toDouble();
          }
        }
      } catch (e) {
        debugPrint('No hay tabla comisiones: $e');
      }

      // Cargar préstamos asignados (si tiene usuario)
      if (_usuario != null) {
        try {
          final prestRes = await AppSupabase.client
              .from('prestamos')
              .select('*, clientes(nombre)')
              .eq('creado_por', _usuario!['id'])
              .order('created_at', ascending: false)
              .limit(20);
          _prestamosAsignados = List<Map<String, dynamic>>.from(prestRes);
          _prestamosGestionados = _prestamosAsignados.length;
        } catch (e) {
          debugPrint('Error cargando préstamos: $e');
        }
      }

      // Cargar cobros realizados del mes
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      try {
        final cobrosRes = await AppSupabase.client
            .from('pagos')
            .select('*, prestamos(clientes(nombre))')
            .eq('registrado_por', _usuario?['id'] ?? '')
            .gte('fecha_pago', inicioMes.toIso8601String())
            .order('fecha_pago', ascending: false);
        _cobrosRealizados = List<Map<String, dynamic>>.from(cobrosRes);
        _cobrosDelMes = _cobrosRealizados.length;
        
        for (var c in _cobrosRealizados) {
          _montoRecaudado += (c['monto'] ?? 0).toDouble();
        }
      } catch (e) {
        debugPrint('Error cargando cobros: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando empleado: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario?['nombre_completo'] ?? _empleado['puesto'] ?? 'Empleado';
    
    return PremiumScaffold(
      title: nombre,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () => _mostrarEditarEmpleado(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'pagar_comisiones':
                _pagarComisionesPendientes();
                break;
              case 'cambiar_sucursal':
                _mostrarCambiarSucursal();
                break;
              case 'desactivar':
                _toggleEstado();
                break;
              case 'permisos_chat_qr':
                _abrirPermisosChatQR();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'pagar_comisiones', child: Text('💰 Pagar Comisiones')),
            const PopupMenuItem(value: 'cambiar_sucursal', child: Text('🏢 Cambiar Sucursal')),
            const PopupMenuItem(value: 'permisos_chat_qr', child: Text('🔔 Permisos Chat QR')),
            PopupMenuItem(
              value: 'desactivar',
              child: Text(_empleado['activo'] == true ? '🔴 Desactivar' : '🟢 Activar'),
            ),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildStats(),
                _buildTabs(),
                Expanded(child: _buildTabContent()),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final nombre = _usuario?['nombre_completo'] ?? 'Sin nombre';
    final email = _usuario?['email'] ?? '';
    final telefono = _usuario?['telefono'] ?? '';
    final puesto = _empleado['puesto'] ?? 'Sin puesto';
    final activo = _empleado['activo'] == true;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activo 
              ? [const Color(0xFF1E3A5F), const Color(0xFF0D47A1)]
              : [const Color(0xFF424242), const Color(0xFF616161)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: activo ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activo ? 'ACTIVO' : 'INACTIVO',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(puesto, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.white.withOpacity(0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(email, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ],
                if (telefono.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.white.withOpacity(0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(telefono, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ],
                if (_sucursal != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.store, color: Colors.white.withOpacity(0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(_sucursal!['nombre'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Comisiones', _currencyFormat.format(_totalComisionesGanadas), Icons.attach_money, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildStatCard('Pendiente', _currencyFormat.format(_comisionesPendientes), Icons.pending, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildStatCard('Cobros Mes', '$_cobrosDelMes', Icons.receipt, const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _buildStatCard('Recaudado', _currencyFormat.format(_montoRecaudado), Icons.savings, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11),
        tabs: const [
          Tab(text: 'Info'),
          Tab(text: 'Comisiones'),
          Tab(text: 'Préstamos'),
          Tab(text: 'Cobros'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildInfoTab(),
        _buildComisionesTab(),
        _buildPrestamosTab(),
        _buildCobrosTab(),
      ],
    );
  }

  Widget _buildInfoTab() {
    final salario = (_empleado['salario'] ?? 0).toDouble();
    final comisionPorcentaje = (_empleado['comision_porcentaje'] ?? 0).toDouble();
    final comisionTipo = _empleado['comision_tipo'] ?? 'ninguna';
    final fechaContratacion = _empleado['fecha_contratacion'];
    
    String tipoComisionLabel = 'Sin comisión';
    switch (comisionTipo) {
      case 'al_liquidar': tipoComisionLabel = 'Al liquidar préstamo'; break;
      case 'proporcional': tipoComisionLabel = 'Proporcional por cuota'; break;
      case 'primer_pago': tipoComisionLabel = 'Al primer pago'; break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('Información Laboral', [
            _buildInfoRow('Puesto', _empleado['puesto'] ?? 'Sin asignar'),
            _buildInfoRow('Sucursal', _sucursal?['nombre'] ?? 'Sin asignar'),
            _buildInfoRow('Fecha Contratación', fechaContratacion != null 
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaContratacion)) 
                : 'No especificada'),
            _buildInfoRow('Estado', _empleado['activo'] == true ? 'Activo' : 'Inactivo'),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection('Compensación', [
            _buildInfoRow('Salario', _currencyFormat.format(salario)),
            _buildInfoRow('Comisión', comisionPorcentaje > 0 ? '${comisionPorcentaje.toStringAsFixed(1)}%' : 'Sin comisión'),
            _buildInfoRow('Tipo Comisión', tipoComisionLabel),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection('Contacto', [
            _buildInfoRow('Email', _usuario?['email'] ?? 'No especificado'),
            _buildInfoRow('Teléfono', _usuario?['telefono'] ?? 'No especificado'),
          ]),
          const SizedBox(height: 16),
          _buildConfigComision(),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String titulo, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildConfigComision() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text('Configurar Comisiones', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _mostrarConfigComision(),
            icon: const Icon(Icons.percent),
            label: const Text('Cambiar Esquema de Comisión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComisionesTab() {
    if (_comisiones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Sin comisiones registradas', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comisiones.length,
      itemBuilder: (context, index) {
        final com = _comisiones[index];
        final monto = (com['monto'] ?? 0).toDouble();
        final estado = com['estado'] ?? 'pendiente';
        final fecha = com['created_at'] != null ? DateTime.parse(com['created_at']) : DateTime.now();
        final cliente = com['prestamos']?['clientes']?['nombre'] ?? 'Préstamo';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estado == 'pagada' ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  estado == 'pagada' ? Icons.check_circle : Icons.pending,
                  color: estado == 'pagada' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(DateFormat('dd/MM/yyyy').format(fecha), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currencyFormat.format(monto), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(estado.toUpperCase(), style: TextStyle(color: estado == 'pagada' ? Colors.green : Colors.orange, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrestamosTab() {
    if (_prestamosAsignados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Sin préstamos gestionados', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prestamosAsignados.length,
      itemBuilder: (context, index) {
        final p = _prestamosAsignados[index];
        final monto = (p['monto_principal'] ?? 0).toDouble();
        final estado = p['estado'] ?? 'activo';
        final cliente = p['clientes']?['nombre'] ?? 'Cliente';
        
        Color estadoColor = Colors.blue;
        if (estado == 'pagado') estadoColor = Colors.green;
        if (estado == 'vencido') estadoColor = Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.credit_card, color: estadoColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(estado.toUpperCase(), style: TextStyle(color: estadoColor, fontSize: 11)),
                  ],
                ),
              ),
              Text(_currencyFormat.format(monto), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCobrosTab() {
    if (_cobrosRealizados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Sin cobros este mes', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cobrosRealizados.length,
      itemBuilder: (context, index) {
        final c = _cobrosRealizados[index];
        final monto = (c['monto'] ?? 0).toDouble();
        final fecha = c['fecha_pago'] != null ? DateTime.parse(c['fecha_pago']) : DateTime.now();
        final cliente = c['prestamos']?['clientes']?['nombre'] ?? 'Cliente';
        final metodo = c['metodo_pago'] ?? 'efectivo';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  metodo == 'efectivo' ? Icons.money : Icons.credit_card,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
              Text(_currencyFormat.format(monto), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════════

  void _mostrarEditarEmpleado() {
    final puestoCtrl = TextEditingController(text: _empleado['puesto'] ?? '');
    final salarioCtrl = TextEditingController(text: (_empleado['salario'] ?? 0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Editar Empleado', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: puestoCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Puesto',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: salarioCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Salario',
                prefixText: '\$ ',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await AppSupabase.client.from('empleados').update({
                  'puesto': puestoCtrl.text,
                  'salario': double.tryParse(salarioCtrl.text) ?? 0,
                }).eq('id', widget.empleadoId);
                if (mounted) {
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Empleado actualizado'), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar Cambios'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarConfigComision() {
    double porcentaje = (_empleado['comision_porcentaje'] ?? 0).toDouble();
    String tipo = _empleado['comision_tipo'] ?? 'ninguna';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configurar Comisiones', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Porcentaje: ${porcentaje.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
              Slider(
                value: porcentaje,
                min: 0,
                max: 50,
                divisions: 100,
                activeColor: const Color(0xFF10B981),
                onChanged: (v) => setModalState(() => porcentaje = v),
              ),
              const SizedBox(height: 16),
              const Text('Tipo de Comisión', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              ...['ninguna', 'al_liquidar', 'proporcional', 'primer_pago'].map((t) {
                String label = t;
                switch (t) {
                  case 'ninguna': label = 'Sin comisión'; break;
                  case 'al_liquidar': label = 'Al liquidar préstamo'; break;
                  case 'proporcional': label = 'Proporcional por cuota'; break;
                  case 'primer_pago': label = 'Al primer pago'; break;
                }
                return RadioListTile<String>(
                  title: Text(label, style: const TextStyle(color: Colors.white)),
                  value: t,
                  groupValue: tipo,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (v) => setModalState(() => tipo = v!),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await AppSupabase.client.from('empleados').update({
                    'comision_porcentaje': porcentaje,
                    'comision_tipo': tipo,
                  }).eq('id', widget.empleadoId);
                  if (mounted) {
                    Navigator.pop(context);
                    _cargarDatos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Comisiones actualizadas'), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Guardar Configuración'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarCambiarSucursal() async {
    final sucursales = await AppSupabase.client.from('sucursales').select().eq('activa', true);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cambiar Sucursal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...(sucursales as List).map((s) => ListTile(
              title: Text(s['nombre'], style: const TextStyle(color: Colors.white)),
              subtitle: Text(s['direccion'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              trailing: _empleado['sucursal_id'] == s['id'] ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () async {
                await AppSupabase.client.from('empleados').update({
                  'sucursal_id': s['id'],
                }).eq('id', widget.empleadoId);
                if (mounted) {
                  Navigator.pop(context);
                  _cargarDatos();
                }
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pagarComisionesPendientes() async {
    final pendientes = _comisiones.where((c) => c['estado'] == 'pendiente').toList();
    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comisiones pendientes'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Pagar Comisiones', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Marcar ${pendientes.length} comisiones como pagadas?\nTotal: ${_currencyFormat.format(_comisionesPendientes)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var c in pendientes) {
        await AppSupabase.client.from('comisiones_empleados').update({
          'estado': 'pagada',
          'fecha_pago': DateTime.now().toIso8601String(),
        }).eq('id', c['id']);
      }
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Comisiones pagadas'), backgroundColor: Colors.green),
        );
      }
    }
  }

  /// Abre la pantalla de permisos de chat QR para este empleado
  void _abrirPermisosChatQR() async {
    // Obtener el negocio_id del empleado
    final negocioId = _empleado['negocio_id']?.toString();
    String? negocioNombre;
    
    if (negocioId != null) {
      try {
        final negocio = await AppSupabase.client
            .from('negocios')
            .select('nombre')
            .eq('id', negocioId)
            .maybeSingle();
        negocioNombre = negocio?['nombre'];
      } catch (e) {
        debugPrint('Error obteniendo negocio: $e');
      }
    }
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PermisosChatQRScreen(
            negocioId: negocioId,
            negocioNombre: negocioNombre,
          ),
        ),
      );
    }
  }

  void _toggleEstado() async {
    final nuevoEstado = !(_empleado['activo'] == true);
    await AppSupabase.client.from('empleados').update({
      'activo': nuevoEstado,
    }).eq('id', widget.empleadoId);
    _cargarDatos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado ? '✅ Empleado activado' : '🔴 Empleado desactivado'),
          backgroundColor: nuevoEstado ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

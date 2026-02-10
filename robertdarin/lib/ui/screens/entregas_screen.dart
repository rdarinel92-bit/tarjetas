// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'detalle_entrega_screen.dart';

class EntregasScreen extends StatefulWidget {
  const EntregasScreen({super.key});

  @override
  State<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends State<EntregasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _entregas = [];
  List<Map<String, dynamic>> _entregasPendientes = [];
  List<Map<String, dynamic>> _entregasCompletadas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('entregas')
          .select('*, clientes(nombre_completo, telefono, direccion)')
          .order('fecha_programada', ascending: true);
      
      if (mounted) {
        setState(() {
          _entregas = List<Map<String, dynamic>>.from(res);
          _entregasPendientes = _entregas.where((e) => e['estado'] == 'pendiente' || e['estado'] == 'en_camino').toList();
          _entregasCompletadas = _entregas.where((e) => e['estado'] == 'entregado').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando entregas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Entregas",
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
        IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _mostrarDialogoNuevaEntrega),
      ],
      body: Column(
        children: [
          _buildStats(),
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.tealAccent,
              tabs: [
                Tab(text: "Todas (${_entregas.length})"),
                Tab(text: "Pendientes (${_entregasPendientes.length})"),
                Tab(text: "Completadas (${_entregasCompletadas.length})"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaEntregas(_entregas),
                      _buildListaEntregas(_entregasPendientes),
                      _buildListaEntregas(_entregasCompletadas),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final hoy = DateTime.now();
    final entregasHoy = _entregas.where((e) {
      final fecha = DateTime.tryParse(e['fecha_programada'] ?? '');
      return fecha != null && fecha.day == hoy.day && fecha.month == hoy.month && fecha.year == hoy.year;
    }).length;
    
    return PremiumCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total", _entregas.length.toString(), Icons.local_shipping),
          _buildStatItem("Hoy", entregasHoy.toString(), Icons.today, Colors.orange),
          _buildStatItem("Pendientes", _entregasPendientes.length.toString(), Icons.pending_actions, Colors.amber),
          _buildStatItem("Completadas", _entregasCompletadas.length.toString(), Icons.check_circle, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.tealAccent, size: 26),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildListaEntregas(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, size: 60, color: Colors.white24),
            const SizedBox(height: 15),
            const Text("No hay entregas", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _mostrarDialogoNuevaEntrega, icon: const Icon(Icons.add), label: const Text("Nueva Entrega")),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final entrega = lista[index];
        final estado = entrega['estado'] ?? 'pendiente';
        final fechaProg = DateTime.tryParse(entrega['fecha_programada'] ?? '') ?? DateTime.now();
        final cliente = entrega['clientes'];
        
        return Card(
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleEntregaScreen(entregaId: entrega['id']))),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorEstado(estado).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getIconoEstado(estado), color: _getColorEstado(estado)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cliente?['nombre_completo'] ?? 'Sin cliente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(cliente?['direccion'] ?? 'Sin dirección', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _getColorEstado(estado).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(_getTextoEstado(estado), style: TextStyle(color: _getColorEstado(estado), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
                      const SizedBox(width: 5),
                      Text(DateFormat('EEE d MMM, HH:mm', 'es').format(fechaProg), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const Spacer(),
                      if (cliente?['telefono'] != null) ...[
                        const Icon(Icons.phone, size: 14, color: Colors.white38),
                        const SizedBox(width: 5),
                        Text(cliente['telefono'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ],
                  ),
                  if (entrega['notas'] != null && entrega['notas'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.note, size: 14, color: Colors.white38),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entrega['notas'], style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente': return Colors.amber;
      case 'en_camino': return Colors.blue;
      case 'entregado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getIconoEstado(String estado) {
    switch (estado) {
      case 'pendiente': return Icons.schedule;
      case 'en_camino': return Icons.local_shipping;
      case 'entregado': return Icons.check_circle;
      case 'cancelado': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getTextoEstado(String estado) {
    switch (estado) {
      case 'pendiente': return 'PENDIENTE';
      case 'en_camino': return 'EN CAMINO';
      case 'entregado': return 'ENTREGADO';
      case 'cancelado': return 'CANCELADO';
      default: return estado.toUpperCase();
    }
  }

  void _mostrarDialogoNuevaEntrega() {
    final destinoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    DateTime fechaProgramada = DateTime.now().add(const Duration(hours: 1));
    String? clienteId;
    List<Map<String, dynamic>> clientes = [];

    // Cargar clientes
    AppSupabase.client.from('clientes').select('id, nombre_completo, direccion, telefono').then((res) {
      clientes = List<Map<String, dynamic>>.from(res);
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("Nueva Entrega", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: clienteId,
                  decoration: const InputDecoration(labelText: "Cliente"),
                  items: clientes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre_completo'] ?? ''))).toList(),
                  onChanged: (v) {
                    setDialogState(() => clienteId = v);
                    final cliente = clientes.firstWhere((c) => c['id'] == v, orElse: () => {});
                    if (cliente['direccion'] != null) destinoCtrl.text = cliente['direccion'];
                  },
                ),
                const SizedBox(height: 15),
                TextField(controller: destinoCtrl, decoration: const InputDecoration(labelText: "Dirección de entrega")),
                const SizedBox(height: 15),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Fecha programada", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  subtitle: Text(DateFormat('EEE d MMM yyyy, HH:mm', 'es').format(fechaProgramada), style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.tealAccent),
                  onTap: () async {
                    final fecha = await showDatePicker(context: context, initialDate: fechaProgramada, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (fecha != null) {
                      final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(fechaProgramada));
                      if (hora != null) {
                        setDialogState(() => fechaProgramada = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
                      }
                    }
                  },
                ),
                const SizedBox(height: 15),
                TextField(controller: notasCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Notas (opcional)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () async {
                if (destinoCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa la dirección'), backgroundColor: Colors.orange));
                  return;
                }
                try {
                  await AppSupabase.client.from('entregas').insert({
                    'cliente_id': clienteId,
                    'destino': destinoCtrl.text,
                    'fecha_programada': fechaProgramada.toIso8601String(),
                    'notas': notasCtrl.text.isEmpty ? null : notasCtrl.text,
                    'estado': 'pendiente',
                  });
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrega programada'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text("Programar", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

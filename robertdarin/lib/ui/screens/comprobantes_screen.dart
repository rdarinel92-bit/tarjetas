// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import '../viewmodels/negocio_activo_provider.dart';

class ComprobantesScreen extends StatefulWidget {
  const ComprobantesScreen({super.key});

  @override
  State<ComprobantesScreen> createState() => _ComprobantesScreenState();
}

class _ComprobantesScreenState extends State<ComprobantesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _comprobantes = [];
  List<Map<String, dynamic>> _comprobantesPendientes = [];
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // V10.55: Obtener negocio activo para filtrar
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      var query = AppSupabase.client
          .from('comprobantes')
          .select('*, clientes(nombre_completo)');
      
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      
      final res = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _comprobantes = List<Map<String, dynamic>>.from(res);
          _comprobantesPendientes = _comprobantes.where((c) => c['verificado'] != true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando comprobantes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Comprobantes",
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
      ],
      body: Column(
        children: [
          _buildStats(),
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.orangeAccent,
              tabs: [
                Tab(text: "Todos (${_comprobantes.length})"),
                Tab(text: "Pendientes (${_comprobantesPendientes.length})"),
                const Tab(text: "Subir"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaComprobantes(_comprobantes),
                      _buildListaComprobantes(_comprobantesPendientes),
                      _buildSubirComprobante(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final total = _comprobantes.fold<double>(0, (sum, c) => sum + ((c['monto'] ?? 0) as num).toDouble());
    final verificados = _comprobantes.where((c) => c['verificado'] == true).length;
    
    return PremiumCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total", _comprobantes.length.toString(), Icons.receipt_long),
          _buildStatItem("Verificados", verificados.toString(), Icons.verified, Colors.green),
          _buildStatItem("Monto", _currencyFormat.format(total), Icons.attach_money),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.orangeAccent, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildListaComprobantes(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.white24),
            SizedBox(height: 15),
            Text("No hay comprobantes", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final comp = lista[index];
        final monto = ((comp['monto'] ?? 0) as num).toDouble();
        final verificado = comp['verificado'] == true;
        final fecha = DateTime.tryParse(comp['created_at'] ?? '') ?? DateTime.now();
        
        return Card(
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: verificado ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              child: Icon(_getIconoTipo(comp['tipo']), color: verificado ? Colors.green : Colors.orange),
            ),
            title: Text(comp['descripcion'] ?? 'Sin descripción', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comp['clientes']?['nombre_completo'] ?? 'Sin cliente', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currencyFormat.format(monto), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                Icon(verificado ? Icons.verified : Icons.pending, color: verificado ? Colors.green : Colors.orange, size: 16),
              ],
            ),
            onTap: () => _mostrarDetalle(comp),
          ),
        );
      },
    );
  }

  IconData _getIconoTipo(String? tipo) {
    switch (tipo) {
      case 'pago': return Icons.payment;
      case 'gasto': return Icons.money_off;
      case 'ingreso': return Icons.attach_money;
      case 'transferencia': return Icons.swap_horiz;
      default: return Icons.receipt;
    }
  }

  Widget _buildSubirComprobante() {
    final tipoCtrl = TextEditingController(text: 'pago');
    final montoCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    String? archivoUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Nuevo Comprobante", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: 'pago',
            decoration: const InputDecoration(labelText: "Tipo de comprobante"),
            items: const [
              DropdownMenuItem(value: 'pago', child: Text('Pago')),
              DropdownMenuItem(value: 'gasto', child: Text('Gasto')),
              DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
              DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
            ],
            onChanged: (v) => tipoCtrl.text = v ?? 'pago',
          ),
          const SizedBox(height: 15),
          TextField(controller: montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Monto", prefixText: "\$ ")),
          const SizedBox(height: 15),
          TextField(controller: descripcionCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Descripción", hintText: "Ej: Pago de préstamo #123")),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  final fileName = 'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  await AppSupabase.client.storage.from('comprobantes').uploadBinary(fileName, bytes);
                  archivoUrl = AppSupabase.client.storage.from('comprobantes').getPublicUrl(fileName);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida correctamente'), backgroundColor: Colors.green));
                }
              },
              icon: const Icon(Icons.upload),
              label: const Text("Seleccionar Imagen"),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (montoCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el monto'), backgroundColor: Colors.orange));
                  return;
                }
                try {
                  await AppSupabase.client.from('comprobantes').insert({
                    'tipo': tipoCtrl.text,
                    'monto': double.tryParse(montoCtrl.text) ?? 0,
                    'descripcion': descripcionCtrl.text,
                    'archivo_url': archivoUrl,
                  });
                  _cargarDatos();
                  _tabController.animateTo(0);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprobante guardado'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.save, color: Colors.black),
              label: const Text("Guardar Comprobante", style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalle(Map<String, dynamic> comp) {
    final verificado = comp['verificado'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(verificado ? Icons.verified : Icons.pending, color: verificado ? Colors.green : Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(comp['descripcion'] ?? 'Sin descripción', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(height: 30),
            _buildDetalleRow("Tipo", comp['tipo'] ?? '-'),
            _buildDetalleRow("Monto", _currencyFormat.format((comp['monto'] ?? 0).toDouble())),
            _buildDetalleRow("Cliente", comp['clientes']?['nombre_completo'] ?? 'Sin cliente'),
            _buildDetalleRow("Estado", verificado ? 'Verificado ✓' : 'Pendiente'),
            const SizedBox(height: 20),
            if (!verificado)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await AppSupabase.client.from('comprobantes').update({'verificado': true, 'verificado_at': DateTime.now().toIso8601String()}).eq('id', comp['id']);
                    Navigator.pop(context);
                    _cargarDatos();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check),
                  label: const Text("Marcar como Verificado"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white54)), Text(value, style: const TextStyle(color: Colors.white))]),
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

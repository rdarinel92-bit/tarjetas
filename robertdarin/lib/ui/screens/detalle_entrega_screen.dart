// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

class DetalleEntregaScreen extends StatefulWidget {
  final String entregaId;
  const DetalleEntregaScreen({super.key, required this.entregaId});

  @override
  State<DetalleEntregaScreen> createState() => _DetalleEntregaScreenState();
}

class _DetalleEntregaScreenState extends State<DetalleEntregaScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _entrega;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('entregas')
          .select('*, clientes(nombre_completo, telefono, direccion, email)')
          .eq('id', widget.entregaId)
          .single();
      
      if (mounted) {
        setState(() {
          _entrega = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando entrega: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Detalle de Entrega",
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entrega == null
              ? const Center(child: Text("Entrega no encontrada", style: TextStyle(color: Colors.white54)))
              : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final cliente = _entrega!['clientes'];
    final estado = _entrega!['estado'] ?? 'pendiente';
    final fechaProg = DateTime.tryParse(_entrega!['fecha_programada'] ?? '') ?? DateTime.now();
    final fechaEntrega = _entrega!['fecha_entrega'] != null ? DateTime.tryParse(_entrega!['fecha_entrega']) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_getColorEstado(estado).withOpacity(0.3), _getColorEstado(estado).withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _getColorEstado(estado).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Icon(_getIconoEstado(estado), size: 50, color: _getColorEstado(estado)),
                const SizedBox(height: 10),
                Text(_getTextoEstado(estado), style: TextStyle(color: _getColorEstado(estado), fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(DateFormat('EEEE d MMMM, HH:mm', 'es').format(fechaProg), style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Datos del cliente
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.tealAccent),
                    const SizedBox(width: 10),
                    const Text("Cliente", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(cliente?['nombre_completo'] ?? 'Sin asignar', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (cliente?['telefono'] != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _llamar(cliente['telefono']),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Text(cliente['telefono'], style: const TextStyle(color: Colors.greenAccent)),
                      ],
                    ),
                  ),
                ],
                if (cliente?['email'] != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.white38),
                      const SizedBox(width: 8),
                      Text(cliente['email'], style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Dirección
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    const Text("Destino", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_entrega!['destino'] ?? cliente?['direccion'] ?? 'Sin dirección', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirMapa(_entrega!['destino'] ?? cliente?['direccion'] ?? ''),
                    icon: const Icon(Icons.map),
                    label: const Text("Ver en Mapa"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Notas
          if (_entrega!['notas'] != null && _entrega!['notas'].toString().isNotEmpty)
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.note, color: Colors.amberAccent),
                      SizedBox(width: 10),
                      Text("Notas", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_entrega!['notas'], style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          const SizedBox(height: 15),

          // Timestamps
          PremiumCard(
            child: Column(
              children: [
                _buildInfoRow("Creada", DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(_entrega!['created_at'] ?? '') ?? DateTime.now())),
                _buildInfoRow("Programada", DateFormat('dd/MM/yyyy HH:mm').format(fechaProg)),
                if (fechaEntrega != null) _buildInfoRow("Entregada", DateFormat('dd/MM/yyyy HH:mm').format(fechaEntrega)),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Botones de acción
          if (estado == 'pendiente') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _cambiarEstado('en_camino'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15)),
                icon: const Icon(Icons.local_shipping),
                label: const Text("Iniciar Entrega", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (estado == 'en_camino') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _cambiarEstado('entregado'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                icon: const Icon(Icons.check_circle),
                label: const Text("Marcar como Entregada", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (estado != 'entregado' && estado != 'cancelado') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cambiarEstado('cancelado'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)),
                icon: const Icon(Icons.cancel),
                label: const Text("Cancelar Entrega", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Acciones rápidas
          Row(
            children: [
              Expanded(
                child: _buildAccionRapida(Icons.phone, "Llamar", Colors.green, () {
                  if (cliente?['telefono'] != null) _llamar(cliente['telefono']);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAccionRapida(Icons.chat, "WhatsApp", Colors.teal, () {
                  if (cliente?['telefono'] != null) _enviarWhatsApp(cliente['telefono']);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAccionRapida(Icons.navigation, "Navegar", Colors.blue, () {
                  _abrirMapa(_entrega!['destino'] ?? cliente?['direccion'] ?? '');
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAccionRapida(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
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

  Future<void> _cambiarEstado(String nuevoEstado) async {
    try {
      final Map<String, dynamic> datos = {'estado': nuevoEstado};
      if (nuevoEstado == 'entregado') {
        datos['fecha_entrega'] = DateTime.now().toIso8601String();
      }
      await AppSupabase.client.from('entregas').update(datos).eq('id', widget.entregaId);
      _cargarDatos();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado actualizado a: ${_getTextoEstado(nuevoEstado)}'), backgroundColor: _getColorEstado(nuevoEstado)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _llamar(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _enviarWhatsApp(String telefono) async {
    final tel = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final mensaje = 'Hola, le informo sobre su entrega programada para ${DateFormat('EEEE d MMMM', 'es').format(DateTime.tryParse(_entrega!['fecha_programada'] ?? '') ?? DateTime.now())}.';
    final uri = Uri.parse('https://wa.me/52$tel?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirMapa(String direccion) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

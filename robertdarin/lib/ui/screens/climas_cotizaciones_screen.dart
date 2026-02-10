// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class ClimasCotizacionesScreen extends StatefulWidget {
  final bool abrirNueva;

  const ClimasCotizacionesScreen({super.key, this.abrirNueva = false});

  @override
  State<ClimasCotizacionesScreen> createState() => _ClimasCotizacionesScreenState();
}

class _ClimasCotizacionesScreenState extends State<ClimasCotizacionesScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  bool _accionInicialEjecutada = false;

  String? _negocioId;
  List<Map<String, dynamic>> _cotizaciones = [];
  List<Map<String, dynamic>> _clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        final empleado = await AppSupabase.client
            .from('empleados')
            .select('negocio_id')
            .eq('usuario_id', user.id)
            .maybeSingle();
        _negocioId = empleado?['negocio_id'];
      }

      if (_negocioId == null) {
        final negocio = await AppSupabase.client
            .from('negocios')
            .select('id')
            .limit(1)
            .maybeSingle();
        _negocioId = negocio?['id'];
      }

      final cotizacionesRes = await AppSupabase.client
          .from('climas_cotizaciones')
          .select('*, climas_clientes(nombre, telefono)')
          .order('created_at', ascending: false);
      _cotizaciones = List<Map<String, dynamic>>.from(cotizacionesRes);

      final clientesRes = await AppSupabase.client
          .from('climas_clientes')
          .select()
          .eq('activo', true)
          .order('nombre');
      _clientes = List<Map<String, dynamic>>.from(clientesRes);
    } catch (e) {
      debugPrint('Error cargando cotizaciones: $e');
    }

    if (mounted) setState(() => _isLoading = false);

    if (widget.abrirNueva && !_accionInicialEjecutada) {
      _accionInicialEjecutada = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarNuevaCotizacion());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Cotizaciones Climas',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cotizaciones.isEmpty
              ? Center(
                  child: Text(
                    'Sin cotizaciones registradas',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cotizaciones.length,
                  itemBuilder: (context, index) => _buildCotizacionCard(_cotizaciones[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarNuevaCotizacion,
        backgroundColor: const Color(0xFF22C55E),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nueva Cotizacion', style: TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildCotizacionCard(Map<String, dynamic> cotizacion) {
    final cliente = cotizacion['climas_clientes'] ?? {};
    final estado = cotizacion['estado'] ?? 'pendiente';
    final total = (cotizacion['total'] ?? 0).toDouble();
    final fecha = cotizacion['fecha'];
    final numero = cotizacion['numero'] ?? cotizacion['folio'] ?? '';

    Color estadoColor;
    switch (estado) {
      case 'aprobada':
        estadoColor = const Color(0xFF10B981);
        break;
      case 'rechazada':
        estadoColor = const Color(0xFFEF4444);
        break;
      default:
        estadoColor = const Color(0xFFF59E0B);
    }

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          numero.toString().isEmpty ? 'Cotizacion' : 'Cotizacion $numero',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${cliente['nombre'] ?? 'Cliente'} • ${estado.toString()}',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_currencyFormat.format(total), style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold)),
            if (fecha != null)
              Text(
                DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha)),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarNuevaCotizacion() {
    if (_clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra clientes de climas')),
      );
      return;
    }

    String? clienteId;
    final totalCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    final vigenciaCtrl = TextEditingController(text: '30');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nueva Cotizacion', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: clienteId,
                  dropdownColor: const Color(0xFF0D0D14),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  items: _clientes
                      .map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? '')))
                      .toList(),
                  onChanged: (v) => setModalState(() => clienteId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vigenciaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Vigencia (dias)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: clienteId == null
                      ? null
                      : () async {
                          final total = double.tryParse(totalCtrl.text) ?? 0;
                          final vigencia = int.tryParse(vigenciaCtrl.text) ?? 30;
                          final numero = 'COT-${DateTime.now().millisecondsSinceEpoch}';
                          await AppSupabase.client.from('climas_cotizaciones').insert({
                            'negocio_id': _negocioId,
                            'cliente_id': clienteId,
                            'numero': numero,
                            'fecha': DateTime.now().toIso8601String().split('T')[0],
                            'vigencia_dias': vigencia,
                            'subtotal': total,
                            'iva': 0,
                            'total': total,
                            'estado': 'pendiente',
                            'notas': notasCtrl.text,
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            _cargarDatos();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cotizacion creada'), backgroundColor: Colors.green),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Crear', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import '../viewmodels/negocio_activo_provider.dart';

class AportacionesScreen extends StatefulWidget {
  const AportacionesScreen({super.key});

  @override
  State<AportacionesScreen> createState() => _AportacionesScreenState();
}

class _AportacionesScreenState extends State<AportacionesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _aportaciones = [];
  List<Map<String, dynamic>> _colaboradores = [];
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');

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
      // V10.55: Obtener negocio activo para filtrar
      final negocioId = context.read<NegocioActivoProvider>().negocioId;
      
      // Cargar aportaciones
      var queryAportaciones = AppSupabase.client
          .from('aportaciones')
          .select('*, colaboradores(nombre_completo, tipo)');
      
      if (negocioId != null) {
        queryAportaciones = queryAportaciones.eq('negocio_id', negocioId);
      }
      
      final resAportaciones = await queryAportaciones.order('fecha_aportacion', ascending: false);
      
      // Cargar colaboradores tipo inversionista/socio
      var queryColaboradores = AppSupabase.client
          .from('colaboradores')
          .select()
          .or('tipo.eq.inversionista,tipo.eq.socio')
          .eq('activo', true);
      
      if (negocioId != null) {
        queryColaboradores = queryColaboradores.eq('negocio_id', negocioId);
      }
      
      final resColaboradores = await queryColaboradores.order('nombre_completo');
      
      if (mounted) {
        setState(() {
          _aportaciones = List<Map<String, dynamic>>.from(resAportaciones);
          _colaboradores = List<Map<String, dynamic>>.from(resColaboradores);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando aportaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Aportaciones de Capital",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _mostrarDialogoNuevaAportacion,
        ),
      ],
      body: Column(
        children: [
          _buildStats(),
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              tabs: [
                Tab(text: "Historial (${_aportaciones.length})"),
                Tab(text: "Inversionistas (${_colaboradores.length})"),
                const Tab(text: "Resumen"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaAportaciones(),
                      _buildListaInversionistas(),
                      _buildResumenCapital(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final totalAportado = _aportaciones.fold<double>(
      0,
      (sum, a) => sum + ((a['monto'] ?? 0) as num).toDouble(),
    );
    final mesActual = _aportaciones
        .where((a) {
          final fecha = DateTime.tryParse(a['fecha_aportacion'] ?? '');
          if (fecha == null) return false;
          final now = DateTime.now();
          return fecha.month == now.month && fecha.year == now.year;
        })
        .fold<double>(0, (sum, a) => sum + ((a['monto'] ?? 0) as num).toDouble());

    return PremiumCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            "Capital Total",
            _currencyFormat.format(totalAportado),
            Icons.account_balance,
            Colors.amber,
          ),
          _buildStatItem(
            "Este Mes",
            _currencyFormat.format(mesActual),
            Icons.calendar_today,
            Colors.green,
          ),
          _buildStatItem(
            "Inversionistas",
            _colaboradores.length.toString(),
            Icons.people,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildListaAportaciones() {
    if (_aportaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              "No hay aportaciones registradas",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _mostrarDialogoNuevaAportacion,
              icon: const Icon(Icons.add),
              label: const Text("Registrar Primera Aportación"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _aportaciones.length,
      itemBuilder: (context, index) {
        final aportacion = _aportaciones[index];
        final colaborador = aportacion['colaboradores'];
        final fecha = DateFormat('dd/MM/yyyy').format(
          DateTime.tryParse(aportacion['fecha_aportacion'] ?? '') ?? DateTime.now(),
        );

        return PremiumCard(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withOpacity(0.2),
              child: const Icon(Icons.attach_money, color: Colors.amber),
            ),
            title: Text(
              colaborador?['nombre_completo'] ?? 'Desconocido',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "$fecha • ${aportacion['concepto'] ?? 'Aportación de capital'}",
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: Text(
              _currencyFormat.format(aportacion['monto'] ?? 0),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaInversionistas() {
    if (_colaboradores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              "No hay inversionistas registrados",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            const Text(
              "Registra colaboradores tipo 'Inversionista' o 'Socio'\nen el módulo de Colaboradores",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _colaboradores.length,
      itemBuilder: (context, index) {
        final colaborador = _colaboradores[index];
        final totalAportado = _aportaciones
            .where((a) => a['colaborador_id'] == colaborador['id'])
            .fold<double>(0, (sum, a) => sum + ((a['monto'] ?? 0) as num).toDouble());

        return PremiumCard(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorTipo(colaborador['tipo']).withOpacity(0.2),
              child: Text(
                (colaborador['nombre_completo'] ?? 'X')[0].toUpperCase(),
                style: TextStyle(color: _getColorTipo(colaborador['tipo'])),
              ),
            ),
            title: Text(
              colaborador['nombre_completo'] ?? 'Sin nombre',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${_capitalize(colaborador['tipo'] ?? '')} • ${colaborador['telefono'] ?? 'Sin teléfono'}",
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(totalAportado),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "aportado",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            onTap: () => _mostrarDetalleInversionista(colaborador),
          ),
        );
      },
    );
  }

  Widget _buildResumenCapital() {
    // Agrupar por mes
    final porMes = <String, double>{};
    for (final a in _aportaciones) {
      final fecha = DateTime.tryParse(a['fecha_aportacion'] ?? '');
      if (fecha != null) {
        final mes = DateFormat('MMM yyyy').format(fecha);
        porMes[mes] = (porMes[mes] ?? 0) + ((a['monto'] ?? 0) as num).toDouble();
      }
    }

    // Agrupar por tipo colaborador
    final porTipo = <String, double>{};
    for (final a in _aportaciones) {
      final tipo = a['colaboradores']?['tipo'] ?? 'otro';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + ((a['monto'] ?? 0) as num).toDouble();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Aportaciones por Mes",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (porMes.isEmpty)
            const Text("Sin datos", style: TextStyle(color: Colors.white54))
          else
            ...porMes.entries.map((e) => _buildBarraProgreso(e.key, e.value, porMes.values.reduce((a, b) => a > b ? a : b))),
          
          const SizedBox(height: 24),
          const Text(
            "Distribución por Tipo",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (porTipo.isEmpty)
            const Text("Sin datos", style: TextStyle(color: Colors.white54))
          else
            ...porTipo.entries.map((e) => _buildDistribucionTipo(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildBarraProgreso(String label, double valor, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(_currencyFormat.format(valor), style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max > 0 ? valor / max : 0,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribucionTipo(String tipo, double valor) {
    final total = _aportaciones.fold<double>(
      0,
      (sum, a) => sum + ((a['monto'] ?? 0) as num).toDouble(),
    );
    final porcentaje = total > 0 ? (valor / total * 100).toStringAsFixed(1) : '0';

    return PremiumCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorTipo(tipo).withOpacity(0.2),
          child: Icon(_getIconoTipo(tipo), color: _getColorTipo(tipo)),
        ),
        title: Text(
          _capitalize(tipo),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          "$porcentaje% del total",
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Text(
          _currencyFormat.format(valor),
          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _getColorTipo(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'inversionista':
        return Colors.amber;
      case 'socio':
        return Colors.purple;
      case 'familiar':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconoTipo(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'inversionista':
        return Icons.trending_up;
      case 'socio':
        return Icons.handshake;
      case 'familiar':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _mostrarDialogoNuevaAportacion() {
    String? colaboradorSeleccionado;
    final montoController = TextEditingController();
    final conceptoController = TextEditingController(text: 'Aportación de capital');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Nueva Aportación", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Inversionista/Socio",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                items: _colaboradores.map((c) {
                  return DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['nombre_completo'] ?? 'Sin nombre'),
                  );
                }).toList(),
                onChanged: (value) => colaboradorSeleccionado = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Monto",
                  prefixText: "\$ ",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: conceptoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Concepto",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (colaboradorSeleccionado == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Selecciona un inversionista")),
                );
                return;
              }
              final monto = double.tryParse(montoController.text.replaceAll(',', ''));
              if (monto == null || monto <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa un monto válido")),
                );
                return;
              }

              try {
                await AppSupabase.client.from('aportaciones').insert({
                  'colaborador_id': colaboradorSeleccionado,
                  'monto': monto,
                  'concepto': conceptoController.text.trim(),
                  'fecha_aportacion': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Aportación registrada"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text("Registrar"),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleInversionista(Map<String, dynamic> colaborador) {
    final aportacionesColaborador = _aportaciones
        .where((a) => a['colaborador_id'] == colaborador['id'])
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text(
                      (colaborador['nombre_completo'] ?? 'X')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          colaborador['nombre_completo'] ?? 'Sin nombre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _capitalize(colaborador['tipo'] ?? ''),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: aportacionesColaborador.isEmpty
                  ? const Center(
                      child: Text(
                        "Sin aportaciones registradas",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: aportacionesColaborador.length,
                      itemBuilder: (context, index) {
                        final a = aportacionesColaborador[index];
                        final fecha = DateFormat('dd/MM/yyyy').format(
                          DateTime.tryParse(a['fecha_aportacion'] ?? '') ?? DateTime.now(),
                        );
                        return ListTile(
                          leading: const Icon(Icons.attach_money, color: Colors.amber),
                          title: Text(
                            _currencyFormat.format(a['monto'] ?? 0),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${a['concepto'] ?? ''} • $fecha",
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

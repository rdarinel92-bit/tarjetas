// ignore_for_file: deprecated_member_use
/// ═══════════════════════════════════════════════════════════════════════════════
/// EXPEDIENTE DE CRÉDITO PROFESIONAL - Robert Darin Fintech V10.5
/// ═══════════════════════════════════════════════════════════════════════════════
/// - Vista completa del préstamo con progreso
/// - Tabla de amortización con estado de cada cuota
/// - Información del cliente y aval
/// - Acciones rápidas funcionales
/// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../../data/models/prestamo_model.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

class DetallePrestamoScreen extends StatefulWidget {
  final PrestamoModel prestamo;

  const DetallePrestamoScreen({super.key, required this.prestamo});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cliente;
  Map<String, dynamic>? _aval;
  List<Map<String, dynamic>> _amortizaciones = [];
  
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar cliente
      if (widget.prestamo.clienteId.isNotEmpty) {
        final clienteRes = await AppSupabase.client
            .from('clientes')
            .select()
            .eq('id', widget.prestamo.clienteId)
            .maybeSingle();
        _cliente = clienteRes;
      }

      // Cargar aval del préstamo
      final avalRes = await AppSupabase.client
          .from('avales')
          .select()
          .eq('prestamo_id', widget.prestamo.id)
          .maybeSingle();
      _aval = avalRes;

      // Cargar amortizaciones
      final amortRes = await AppSupabase.client
          .from('amortizaciones')
          .select()
          .eq('prestamo_id', widget.prestamo.id)
          .order('numero_cuota');
      _amortizaciones = List<Map<String, dynamic>>.from(amortRes);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Expediente de Crédito",
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.greenAccent),
          onPressed: () async {
            final result = await Navigator.pushNamed(
              context,
              AppRoutes.editarPrestamo,
              arguments: widget.prestamo.id,
            );
            if (result == true) {
              _cargarDatos();
            }
          },
          tooltip: 'Editar Préstamo',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TARJETA PRINCIPAL
                    _buildHeaderCard(),
                    const SizedBox(height: 20),

                    // PROGRESO DE PAGO
                    _buildProgresoCard(),
                    const SizedBox(height: 20),

                    // INFORMACIÓN DEL CLIENTE
                    _buildSectionTitle("Cliente", Icons.person),
                    const SizedBox(height: 10),
                    _buildClienteCard(),
                    const SizedBox(height: 20),

                    // INFORMACIÓN DEL AVAL
                    _buildSectionTitle("Aval / Garante", Icons.security),
                    const SizedBox(height: 10),
                    _buildAvalCard(),
                    const SizedBox(height: 20),

                    // TABLA DE AMORTIZACIÓN
                    _buildSectionTitle("Tabla de Amortización", Icons.table_chart),
                    const SizedBox(height: 10),
                    _buildAmortizacionList(),
                    const SizedBox(height: 25),

                    // ACCIONES RÁPIDAS
                    _buildSectionTitle("Acciones", Icons.flash_on),
                    const SizedBox(height: 10),
                    _buildAcciones(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D9FF), size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeaderCard() {
    // Calcular próximo pago
    Map<String, dynamic>? proximaCuota;
    for (var a in _amortizaciones) {
      if (a['estado'] == 'pendiente') {
        proximaCuota = a;
        break;
      }
    }

    // Determinar estado visual
    Color estadoColor;
    String estadoTexto;
    IconData estadoIcon;

    if (widget.prestamo.estado == 'pagado' || widget.prestamo.estado == 'liquidado') {
      estadoColor = const Color(0xFF10B981);
      estadoTexto = 'LIQUIDADO';
      estadoIcon = Icons.check_circle;
    } else if (widget.prestamo.estado == 'cancelado') {
      estadoColor = Colors.grey;
      estadoTexto = 'CANCELADO';
      estadoIcon = Icons.cancel;
    } else {
      estadoColor = const Color(0xFF00D9FF);
      estadoTexto = 'ACTIVO';
      estadoIcon = Icons.play_circle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), estadoColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("MONTO PRESTADO", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(_currencyFormat.format(widget.prestamo.monto),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estadoColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estadoIcon, color: estadoColor, size: 14),
                    const SizedBox(width: 4),
                    Text(estadoTexto, style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniInfo("Interés", "${widget.prestamo.interes}%", Icons.percent),
              _buildMiniInfo("Plazo", "${widget.prestamo.plazoMeses} meses", Icons.calendar_today),
              _buildMiniInfo("Tipo", widget.prestamo.tipoPrestamo.toUpperCase(), Icons.category),
              _buildMiniInfo("Inicio", DateFormat('dd/MM/yy').format(widget.prestamo.fechaCreacion), Icons.event),
            ],
          ),
          if (proximaCuota != null && widget.prestamo.estado == 'activo') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Próximo Pago", style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        Text(
                          "${_currencyFormat.format(proximaCuota['monto_cuota'])} - Cuota ${proximaCuota['numero_cuota']}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (proximaCuota['fecha_pago'] != null)
                    Text(
                      DateFormat('dd/MM/yy').format(DateTime.parse(proximaCuota['fecha_pago'])),
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildProgresoCard() {
    // Calcular progreso
    int cuotasPagadas = 0;
    double montoPagado = 0;
    
    for (var a in _amortizaciones) {
      if (a['estado'] == 'pagado' || a['estado'] == 'pagada') {
        cuotasPagadas++;
        montoPagado += (a['monto_cuota'] as num?)?.toDouble() ?? 0;
      }
    }
    
    final totalCuotas = _amortizaciones.length;
    final progreso = totalCuotas > 0 ? cuotasPagadas / totalCuotas : 0.0;
    final montoTotal = widget.prestamo.monto * (1 + widget.prestamo.interes / 100);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Progreso de Pago", style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text("${(progreso * 100).toInt()}%", 
                style: const TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00D9FF)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pagado", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(_currencyFormat.format(montoPagado),
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  const Text("Cuotas", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text("$cuotasPagadas / $totalCuotas",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Pendiente", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(_currencyFormat.format(montoTotal - montoPagado),
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard() {
    if (_cliente == null) {
      return PremiumCard(
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            child: Icon(Icons.person, color: Colors.white30),
          ),
          title: Text("Cliente no encontrado", style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final nombre = _cliente!['nombre'] ?? 'Sin nombre';
    final telefono = _cliente!['telefono'] ?? '';
    final email = _cliente!['email'] ?? '';
    final direccion = _cliente!['direccion'] ?? '';

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          radius: 24,
          child: Text(nombre[0].toUpperCase(),
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        title: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (telefono.isNotEmpty) Text("📱 $telefono", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (email.isNotEmpty) Text("✉️ $email", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            if (direccion.isNotEmpty) Text("📍 $direccion", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Color(0xFF00D9FF)),
          onPressed: () {
            // Llamar al cliente
          },
        ),
      ),
    );
  }

  Widget _buildAvalCard() {
    if (_aval == null) {
      return PremiumCard(
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            child: Icon(Icons.security, color: Colors.white30),
          ),
          title: Text("Sin aval registrado", style: TextStyle(color: Colors.white38)),
          subtitle: Text("Este préstamo no tiene aval asignado", style: TextStyle(color: Colors.white24, fontSize: 11)),
        ),
      );
    }

    final nombre = _aval!['nombre'] ?? 'Sin nombre';
    final telefono = _aval!['telefono'] ?? '';
    final relacion = _aval!['relacion'] ?? '';
    final verificado = _aval!['verificado'] ?? false;

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orangeAccent.withOpacity(0.2),
              radius: 24,
              child: const Icon(Icons.security, color: Colors.orangeAccent),
            ),
            if (verificado)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D0D14), width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            if (verificado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("VERIFICADO", style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (relacion.isNotEmpty) Text("👥 $relacion", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (telefono.isNotEmpty) Text("📱 $telefono", style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.orangeAccent),
          onPressed: () {
            // Llamar al aval
          },
        ),
      ),
    );
  }

  Widget _buildAmortizacionList() {
    if (_amortizaciones.isEmpty) {
      return PremiumCard(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text("No hay tabla de amortización", style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Column(
      children: _amortizaciones.take(6).map((a) {
        final numeroCuota = a['numero_cuota'] ?? 0;
        final montoCuota = (a['monto_cuota'] as num?)?.toDouble() ?? 0;
        final fechaPago = a['fecha_pago'] != null ? DateTime.tryParse(a['fecha_pago']) : null;
        final estado = a['estado'] ?? 'pendiente';
        
        Color estadoColor;
        IconData estadoIcon;
        
        if (estado == 'pagado' || estado == 'pagada') {
          estadoColor = const Color(0xFF10B981);
          estadoIcon = Icons.check_circle;
        } else if (fechaPago != null && fechaPago.isBefore(DateTime.now())) {
          estadoColor = const Color(0xFFEF4444);
          estadoIcon = Icons.warning;
        } else {
          estadoColor = Colors.white38;
          estadoIcon = Icons.schedule;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: estadoColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text("$numeroCuota", style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currencyFormat.format(montoCuota),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (fechaPago != null)
                      Text(DateFormat('dd/MM/yyyy').format(fechaPago),
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Icon(estadoIcon, color: estadoColor, size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAcciones() {
    return Column(
      children: [
        PremiumButton(
          text: "Registrar Pago",
          icon: Icons.payments_outlined,
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.pagos);
          },
        ),
        const SizedBox(height: 10),
        PremiumButton(
          text: "Ver Historial Completo",
          icon: Icons.history,
          color: Colors.white24,
          onPressed: () {
            _mostrarAmortizacionCompleta();
          },
        ),
      ],
    );
  }

  void _mostrarAmortizacionCompleta() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D14),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tabla de Amortización Completa",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _amortizaciones.length,
                itemBuilder: (context, index) {
                  final a = _amortizaciones[index];
                  final numeroCuota = a['numero_cuota'] ?? 0;
                  final montoCuota = (a['monto_cuota'] as num?)?.toDouble() ?? 0;
                  final fechaPago = a['fecha_pago'] != null ? DateTime.tryParse(a['fecha_pago']) : null;
                  final estado = a['estado'] ?? 'pendiente';
                  
                  Color estadoColor;
                  if (estado == 'pagado' || estado == 'pagada') {
                    estadoColor = const Color(0xFF10B981);
                  } else if (fechaPago != null && fechaPago.isBefore(DateTime.now())) {
                    estadoColor = const Color(0xFFEF4444);
                  } else {
                    estadoColor = Colors.white38;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: estadoColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: estadoColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text("$numeroCuota", style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_currencyFormat.format(montoCuota),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              if (fechaPago != null)
                                Text("Vence: ${DateFormat('dd/MM/yyyy').format(fechaPago)}",
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: estadoColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(estado.toUpperCase(),
                            style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
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

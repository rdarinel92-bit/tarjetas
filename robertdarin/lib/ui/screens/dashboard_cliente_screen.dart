// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../modules/finanzas/tandas/controllers/tandas_controller.dart';
import '../../modules/finanzas/avales/controllers/avales_controller.dart';
import '../../data/models/tanda_model.dart';
import '../../data/models/aval_model.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';
import 'package:intl/intl.dart';

class DashboardClienteScreen extends StatefulWidget {
  const DashboardClienteScreen({super.key});

  @override
  State<DashboardClienteScreen> createState() => _DashboardClienteScreenState();
}

class _DashboardClienteScreenState extends State<DashboardClienteScreen> {
  bool _isLoading = true;
  List<TandaModel> _misTandas = [];
  List<AvalModel> _misGarantias = [];
  bool _tieneTarjetas = false; // V10.22

  @override
  void initState() {
    super.initState();
    _cargarDatosReales();
  }

  Future<void> _cargarDatosReales() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final tandasCtrl = Provider.of<TandasController>(context, listen: false);
    final avalesCtrl = Provider.of<AvalesController>(context, listen: false);
    
    final userId = authVm.usuarioActual?.id;
    if (userId == null) return;

    try {
      // 1. Cargar Avales (Garantías) reales vinculadas al usuario_id
      final todosLosAvales = await avalesCtrl.obtenerAvales();
      _misGarantias = todosLosAvales.where((a) => a.usuarioId == userId).toList();

      // 2. Cargar Tandas (Simulado hasta tener el endpoint de participantes por cliente)
      _misTandas = await tandasCtrl.obtenerTandas(); 
      // Nota: Aquí filtraremos por la tabla tanda_participantes en el siguiente paso

      // 3. V10.22: Verificar si tiene tarjetas asignadas
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        final clienteData = await AppSupabase.client
            .from('clientes')
            .select('id')
            .eq('auth_uid', user.id)
            .maybeSingle();
        
        if (clienteData != null) {
          final tarjetas = await AppSupabase.client
              .from('tarjetas_digitales')
              .select('id')
              .eq('cliente_id', clienteData['id'])
              .eq('activa', true)
              .limit(1);
          _tieneTarjetas = (tarjetas as List).isNotEmpty;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error cargando datos reales: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = Provider.of<AuthViewModel>(context);
    final user = authVm.usuarioActual;
    final currencyFormat = NumberFormat.simpleCurrency();

    return PremiumScaffold(
      title: "Mi Panel",
      body: RefreshIndicator(
        onRefresh: _cargarDatosReales,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("¡Hola, ${user?.userMetadata?['full_name'] ?? 'Usuario'}!",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("Resumen de tus productos financieros activos.",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 25),

                  // SECCIÓN DE TANDAS REALES
                  const Text("Mis Tandas",
                      style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_misTandas.isEmpty)
                    const Text("No participas en ninguna tanda actualmente.", style: TextStyle(color: Colors.white38))
                  else
                    ..._misTandas.map((tanda) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tanda.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                _buildStatusBadge(tanda.estado),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniInfo("Monto", currencyFormat.format(tanda.montoPorPersona)),
                                _buildMiniInfo("Participantes", tanda.numeroParticipantes.toString()),
                                _buildMiniInfo("Inicio", DateFormat('dd/MMM').format(tanda.fechaInicio)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),

                  const SizedBox(height: 25),

                  // SECCIÓN DE AVALES REALES
                  const Text("Garantías (Como Aval)",
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_misGarantias.isEmpty)
                    const Text("No eres aval de ningún préstamo activo.", style: TextStyle(color: Colors.white38))
                  else
                    ..._misGarantias.map((aval) => PremiumCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.security, color: Colors.orangeAccent),
                        title: Text("Aval de: ${aval.nombre}", style: const TextStyle(color: Colors.white)),
                        subtitle: Text("Relación: ${aval.relacion}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      ),
                    )),

                  const SizedBox(height: 30),
                  
                  // V10.25: BOTÓN PROMINENTE PARA PAGAR CUOTAS
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.misPagosPendientes),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.payments, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "💰 Pagar Mis Cuotas",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Ver préstamos y generar links de pago",
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ACCIONES RÁPIDAS
                  const Text("Acciones Rápidas",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
                    children: [
                      _buildActionButton(Icons.chat, "Soporte", Colors.blueAccent, () => Navigator.pushNamed(context, '/chat')),
                      _buildActionButton(Icons.history, "Historial", Colors.purpleAccent, () => Navigator.pushNamed(context, '/historial')),
                      _buildActionButton(Icons.notifications, "Alertas", Colors.orangeAccent, () => Navigator.pushNamed(context, '/notificaciones')),
                      _buildActionButton(Icons.receipt_long, "Facturas", Colors.tealAccent, () => _solicitarFactura()),
                      _buildActionButton(Icons.calendar_today, "Calendario", Colors.pinkAccent, () => Navigator.pushNamed(context, '/calendario')),
                      _buildActionButton(Icons.help_outline, "Ayuda", Colors.grey, () => _mostrarAyuda()),
                    ],
                  ),
                  
                  // V10.22: Botón de Mis Tarjetas (solo si tiene tarjetas)
                  if (_tieneTarjetas) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(
                        Icons.credit_card, 
                        "💳 Mis Tarjetas", 
                        const Color(0xFF00D9FF),
                        () => Navigator.pushNamed(context, AppRoutes.misTarjetas),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildStatusBadge(String estado) {
    final bool activa = estado.toLowerCase() == 'activa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (activa ? Colors.green : Colors.orange).withOpacity(0.2),
        borderRadius: BorderRadius.circular(10)
      ),
      child: Text(estado.toUpperCase(), 
        style: TextStyle(color: activa ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _solicitarFactura() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, color: Colors.tealAccent, size: 48),
            const SizedBox(height: 16),
            const Text('Solicitar Factura', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Para solicitar factura de tus pagos, contacta a soporte por chat o llama a la oficina.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              },
              icon: const Icon(Icons.chat),
              label: const Text('Ir a Soporte'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarAyuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: Icon(Icons.help_outline, color: Colors.grey, size: 48)),
            const SizedBox(height: 16),
            const Center(child: Text('Centro de Ayuda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            _buildAyudaItem('¿Cómo funciona una tanda?', 'Una tanda es un ahorro colectivo donde cada participante aporta un monto fijo periódicamente y recibe el total acumulado en su turno.'),
            _buildAyudaItem('¿Qué es ser aval?', 'Como aval, garantizas el pago de un préstamo. Si el titular no paga, podrías ser responsable del saldo.'),
            _buildAyudaItem('¿Cómo registro mis pagos?', 'Tus pagos se registran automáticamente cuando el cobrador confirma tu pago. Puedes ver el historial en "Mis Pagos".'),
            _buildAyudaItem('¿Cómo contacto soporte?', 'Usa el chat de soporte disponible en tu panel para comunicarte con nosotros.'),
          ],
        ),
      ),
    );
  }

  Widget _buildAyudaItem(String titulo, String descripcion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(descripcion, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../components/premium_scaffold.dart';
import '../../services/mora_cliente_service.dart';
import '../../core/supabase_client.dart';
import '../viewmodels/negocio_activo_provider.dart';

/// Pantalla de gestión de moras
/// Permite ver clientes en mora, configurar penalizaciones y gestionar cobranza
class MorasScreen extends StatefulWidget {
  const MorasScreen({super.key});

  @override
  State<MorasScreen> createState() => _MorasScreenState();
}

class _MorasScreenState extends State<MorasScreen> with SingleTickerProviderStateMixin {
  final MoraClienteService _moraService = MoraClienteService();
  late TabController _tabController;

  bool _isLoading = true;
  List<ClienteEnMora> _clientesEnMora = [];
  List<MoraPrestamo> _morasPendientes = [];
  ConfiguracionMora _config = ConfiguracionMora();
  Map<String, dynamic> _resumen = {};

  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

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
      
      _config = await _moraService.obtenerConfiguracion();
      _clientesEnMora = await _moraService.obtenerClientesEnMora(negocioId: negocioId);
      _morasPendientes = await _moraService.obtenerMorasPendientes(negocioId: negocioId);
      _resumen = await _moraService.obtenerResumenMoras(negocioId: negocioId);
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Gestión de Moras',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: _mostrarConfiguracion,
          tooltip: 'Configuración',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Resumen superior
                _buildResumenCards(),
                
                // Tabs
                Container(
                  color: const Color(0xFF1A1A2E),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00D9FF),
                    labelColor: const Color(0xFF00D9FF),
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.people, size: 20),
                        child: Text(
                          'Clientes (${_clientesEnMora.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Tab(
                        icon: const Icon(Icons.receipt_long, size: 20),
                        child: Text(
                          'Moras (${_morasPendientes.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const Tab(
                        icon: Icon(Icons.notifications_active, size: 20),
                        child: Text(
                          'Notificaciones',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Contenido de tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabClientesEnMora(),
                      _buildTabMorasPendientes(),
                      _buildTabNotificaciones(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenCards() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildResumenCard(
              'Clientes en Mora',
              '${_resumen['total_clientes_mora'] ?? 0}',
              Icons.people_outline,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildResumenCard(
              'Total Adeudado',
              _currencyFormat.format(_resumen['total_adeudado'] ?? 0),
              Icons.account_balance_wallet,
              Colors.redAccent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildResumenCard(
              'Total Moras',
              _currencyFormat.format(_resumen['total_moras'] ?? 0),
              Icons.warning_amber,
              Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(String titulo, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            titulo,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabClientesEnMora() {
    if (_clientesEnMora.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              '¡Sin clientes en mora!',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const Text(
              'Todos los pagos están al corriente',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _clientesEnMora.length,
      itemBuilder: (context, index) {
        final cliente = _clientesEnMora[index];
        return _buildClienteMoraCard(cliente);
      },
    );
  }

  Widget _buildClienteMoraCard(ClienteEnMora cliente) {
    final colorNivel = _getColorNivel(cliente.nivelMora);
    
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorNivel.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleCliente(cliente),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Avatar con nivel de mora
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorNivel.withOpacity(0.2),
                        child: Text(
                          cliente.clienteNombre[0].toUpperCase(),
                          style: TextStyle(color: colorNivel, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (cliente.bloqueado)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.block, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.clienteNombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (cliente.clienteTelefono != null)
                          Text(
                            cliente.clienteTelefono!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  
                  // Badge nivel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorNivel.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorNivel),
                    ),
                    child: Text(
                      cliente.nivelMora.toUpperCase(),
                      style: TextStyle(
                        color: colorNivel,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Divider(color: Colors.white12, height: 20),
              
              // Detalles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    '${cliente.diasMoraMaximo} días',
                    'Mora',
                    Icons.schedule,
                  ),
                  _buildDetailItem(
                    '${cliente.totalPrestamosEnMora}',
                    'Préstamos',
                    Icons.account_balance,
                  ),
                  _buildDetailItem(
                    _currencyFormat.format(cliente.montoTotalAdeudado),
                    'Adeudado',
                    Icons.money_off,
                  ),
                  _buildDetailItem(
                    _currencyFormat.format(cliente.montoTotalMora),
                    'En mora',
                    Icons.warning,
                  ),
                ],
              ),
              
              // Acciones rápidas
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _enviarNotificacion(cliente),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Notificar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _llamarCliente(cliente),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Llamar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String valor, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTabMorasPendientes() {
    if (_morasPendientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Sin moras registradas',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _morasPendientes.length,
      itemBuilder: (context, index) {
        final mora = _morasPendientes[index];
        return _buildMoraCard(mora);
      },
    );
  }

  Widget _buildMoraCard(MoraPrestamo mora) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Text(
            '${mora.diasMora}d',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          mora.clienteNombre ?? 'Préstamo',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Cuota ${mora.numeroCuota ?? '?'} • ${_currencyFormat.format(mora.montoCuotaOriginal)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${_currencyFormat.format(mora.montoMora)}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${mora.porcentajeMoraAplicado.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        onTap: () => _mostrarDetalleMora(mora),
      ),
    );
  }

  Widget _buildTabNotificaciones() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.blue.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'Notificaciones Automáticas',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _config.notificarRecordatorioDiario
                ? 'Las notificaciones están ACTIVAS'
                : 'Las notificaciones están DESACTIVADAS',
            style: TextStyle(
              color: _config.notificarRecordatorioDiario ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _enviarNotificacionesMasivas,
            icon: const Icon(Icons.send),
            label: const Text('Enviar Notificaciones Ahora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorNivel(String nivel) {
    switch (nivel) {
      case 'al_corriente':
        return Colors.green;
      case 'recordatorio':
        return Colors.blue;
      case 'leve':
        return Colors.yellow;
      case 'seria':
        return Colors.orange;
      case 'grave':
        return Colors.deepOrange;
      case 'critica':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _mostrarDetalleCliente(ClienteEnMora cliente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Nombre
            Text(
              cliente.clienteNombre,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cliente.clienteTelefono != null)
              Text(
                cliente.clienteTelefono!,
                style: const TextStyle(color: Colors.white54),
              ),
            
            const SizedBox(height: 24),
            
            // Estadísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Días en Mora',
                    '${cliente.diasMoraMaximo}',
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Nivel',
                    cliente.nivelMora.toUpperCase(),
                    _getColorNivel(cliente.nivelMora),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Adeudado',
                    _currencyFormat.format(cliente.montoTotalAdeudado),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Mora',
                    _currencyFormat.format(cliente.montoTotalMora),
                    Colors.amber,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Préstamos en mora
            const Text(
              'Préstamos en Mora:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...cliente.prestamosIds.map((id) => ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.redAccent),
              title: Text(
                'Préstamo',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                id.substring(0, 8),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                // Navegar al detalle del préstamo
              },
            )),
            
            const SizedBox(height: 24),
            
            // Acciones
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _enviarNotificacion(cliente);
              },
              icon: const Icon(Icons.send),
              label: const Text('Enviar Notificación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 8),
            if (!cliente.bloqueado)
              OutlinedButton.icon(
                onPressed: () => _bloquearCliente(cliente),
                icon: const Icon(Icons.block),
                label: const Text('Bloquear Cliente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(50),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _desbloquearCliente(cliente),
                icon: const Icon(Icons.lock_open),
                label: const Text('Desbloquear Cliente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleMora(MoraPrestamo mora) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Detalle de Mora', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleRow('Cliente', mora.clienteNombre ?? '-'),
            _buildDetalleRow('Cuota #', '${mora.numeroCuota ?? '-'}'),
            _buildDetalleRow('Días de mora', '${mora.diasMora}'),
            _buildDetalleRow('Monto cuota', _currencyFormat.format(mora.montoCuotaOriginal)),
            _buildDetalleRow('% Mora aplicado', '${mora.porcentajeMoraAplicado}%'),
            _buildDetalleRow('Monto mora', _currencyFormat.format(mora.montoMora)),
            const Divider(color: Colors.white24),
            _buildDetalleRow(
              'TOTAL A PAGAR',
              _currencyFormat.format(mora.montoTotalConMora),
              highlight: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _condonarMora(mora);
            },
            child: const Text('Condonar', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white54,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF00D9FF) : Colors.white,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarConfiguracion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => ConfiguracionMorasSheet(
        config: _config,
        onSave: (newConfig) async {
          final success = await _moraService.guardarConfiguracion(newConfig);
          if (success && mounted) {
            _cargarDatos();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Configuración guardada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _enviarNotificacion(ClienteEnMora cliente) async {
    // Calcular mora actual
    final calculo = _moraService.calcularMora(
      montoCuota: cliente.montoTotalAdeudado,
      fechaVencimiento: DateTime.now().subtract(Duration(days: cliente.diasMoraMaximo)),
    );
    
    final mensaje = MoraClienteService.obtenerMensajeMora(
      nivelMora: cliente.nivelMora,
      clienteNombre: cliente.clienteNombre,
      diasMora: cliente.diasMoraMaximo,
      montoPendiente: cliente.montoTotalAdeudado,
      montoMora: calculo.montoMora,
    );
    
    // Mostrar preview
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Enviar Notificación', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se enviará el siguiente mensaje:',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              for (var prestamoId in cliente.prestamosIds) {
                await _moraService.enviarNotificacionMora(
                  clienteId: cliente.clienteId,
                  tipoDeuda: 'prestamo',
                  prestamoId: prestamoId,
                  nivelMora: cliente.nivelMora,
                  titulo: 'Recordatorio de Pago',
                  mensaje: mensaje,
                  diasMora: cliente.diasMoraMaximo,
                  montoPendiente: cliente.montoTotalAdeudado,
                  montoMora: calculo.montoMora,
                );
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificación enviada'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _llamarCliente(ClienteEnMora cliente) {
    if (cliente.clienteTelefono == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cliente no tiene teléfono registrado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:${cliente.clienteTelefono}');
    canLaunchUrl(uri).then((can) async {
      if (can) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _bloquearCliente(ClienteEnMora cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('¿Bloquear Cliente?', style: TextStyle(color: Colors.white)),
        content: Text(
          'El cliente ${cliente.clienteNombre} no podrá solicitar nuevos préstamos mientras esté bloqueado.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = AppSupabase.client.auth.currentUser?.id ?? '';
              await _moraService.bloquearCliente(
                clienteId: cliente.clienteId,
                motivo: 'Mora excesiva de ${cliente.diasMoraMaximo} días',
                diasMora: cliente.diasMoraMaximo,
                montoAdeudado: cliente.montoTotalAdeudado + cliente.montoTotalMora,
                prestamosEnMora: cliente.prestamosIds,
                bloqueadoPor: userId,
              );
              _cargarDatos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  void _desbloquearCliente(ClienteEnMora cliente) {
    final motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Desbloquear Cliente', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: motivoController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Motivo de desbloqueo',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = AppSupabase.client.auth.currentUser?.id ?? '';
              await _moraService.desbloquearCliente(
                clienteId: cliente.clienteId,
                desbloqueadoPor: userId,
                motivo: motivoController.text.trim().isEmpty ? 'Desbloqueo manual' : motivoController.text.trim(),
              );
              _cargarDatos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }

  void _condonarMora(MoraPrestamo mora) {
    final motivoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Condonar Mora', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Perdonar mora de ${_currencyFormat.format(mora.montoMora)}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Motivo de condonación',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa el motivo'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              
              final userId = AppSupabase.client.auth.currentUser?.id ?? '';
              await _moraService.condonarMora(
                moraId: mora.id,
                condonadoPor: userId,
                motivo: motivoController.text,
              );
              
              _cargarDatos();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mora condonada'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Condonar'),
          ),
        ],
      ),
    );
  }

  void _enviarNotificacionesMasivas() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Enviando notificaciones...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
    
    // Ejecutar verificación de moras que envía notificaciones
    _moraService.iniciarVerificacionAutomatica();
    
    // Esperar un momento
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notificaciones enviadas a ${_clientesEnMora.length} clientes'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// Sheet para configuración de moras
class ConfiguracionMorasSheet extends StatefulWidget {
  final ConfiguracionMora config;
  final Function(ConfiguracionMora) onSave;

  const ConfiguracionMorasSheet({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<ConfiguracionMorasSheet> createState() => _ConfiguracionMorasSheetState();
}

class _ConfiguracionMorasSheetState extends State<ConfiguracionMorasSheet> {
  late TextEditingController _moraDiariaController;
  late TextEditingController _moraMaximaController;
  late TextEditingController _diasGraciaController;
  late bool _aplicarAutomatico;
  late bool _notificarDiario;
  late bool _notificarAval;

  @override
  void initState() {
    super.initState();
    _moraDiariaController = TextEditingController(
      text: widget.config.prestamosMoraDiaria.toString(),
    );
    _moraMaximaController = TextEditingController(
      text: widget.config.prestamosMoraMaxima.toString(),
    );
    _diasGraciaController = TextEditingController(
      text: widget.config.prestamosDiasGracia.toString(),
    );
    _aplicarAutomatico = widget.config.prestamosAplicarAutomatico;
    _notificarDiario = widget.config.notificarRecordatorioDiario;
    _notificarAval = widget.config.notificarAlAval;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const Text(
            'Configuración de Moras',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Define cómo se calculan y aplican las moras',
            style: TextStyle(color: Colors.white54),
          ),
          
          const SizedBox(height: 24),
          
          // Mora diaria
          _buildTextField(
            controller: _moraDiariaController,
            label: 'Mora diaria (%)',
            hint: 'Ej: 1.0 = 1% por día',
            icon: Icons.percent,
          ),
          
          const SizedBox(height: 16),
          
          // Mora máxima
          _buildTextField(
            controller: _moraMaximaController,
            label: 'Mora máxima (%)',
            hint: 'Ej: 30.0 = máximo 30%',
            icon: Icons.trending_up,
          ),
          
          const SizedBox(height: 16),
          
          // Días de gracia
          _buildTextField(
            controller: _diasGraciaController,
            label: 'Días de gracia',
            hint: 'Días sin mora después de vencimiento',
            icon: Icons.calendar_today,
          ),
          
          const SizedBox(height: 24),
          
          // Switches
          SwitchListTile(
            title: const Text('Aplicar mora automáticamente', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Calcula y registra mora cada día', style: TextStyle(color: Colors.white54)),
            value: _aplicarAutomatico,
            onChanged: (v) => setState(() => _aplicarAutomatico = v),
            activeColor: const Color(0xFF00D9FF),
          ),
          
          SwitchListTile(
            title: const Text('Notificar diariamente', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Enviar recordatorio cada día', style: TextStyle(color: Colors.white54)),
            value: _notificarDiario,
            onChanged: (v) => setState(() => _notificarDiario = v),
            activeColor: const Color(0xFF00D9FF),
          ),
          
          SwitchListTile(
            title: const Text('Notificar al aval', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Incluir aval en notificaciones', style: TextStyle(color: Colors.white54)),
            value: _notificarAval,
            onChanged: (v) => setState(() => _notificarAval = v),
            activeColor: const Color(0xFF00D9FF),
          ),
          
          const SizedBox(height: 24),
          
          // Ejemplo de cálculo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Ejemplo de Cálculo:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuota: \$1,000\n'
                  'Días de retraso: 10\n'
                  'Días de gracia: ${_diasGraciaController.text}\n'
                  'Mora diaria: ${_moraDiariaController.text}%\n'
                  '---\n'
                  'Días con mora: ${10 - (int.tryParse(_diasGraciaController.text) ?? 0)}\n'
                  'Mora: \$${((10 - (int.tryParse(_diasGraciaController.text) ?? 0)) * (double.tryParse(_moraDiariaController.text) ?? 1.0) * 10).toStringAsFixed(2)}\n'
                  'Total: \$${(1000 + (10 - (int.tryParse(_diasGraciaController.text) ?? 0)) * (double.tryParse(_moraDiariaController.text) ?? 1.0) * 10).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Botón guardar
          ElevatedButton(
            onPressed: _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Guardar Configuración'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  void _guardar() {
    final newConfig = ConfiguracionMora(
      id: widget.config.id,
      negocioId: widget.config.negocioId,
      prestamosMoraDiaria: double.tryParse(_moraDiariaController.text) ?? 1.0,
      prestamosMoraMaxima: double.tryParse(_moraMaximaController.text) ?? 30.0,
      prestamosDiasGracia: int.tryParse(_diasGraciaController.text) ?? 0,
      prestamosAplicarAutomatico: _aplicarAutomatico,
      notificarRecordatorioDiario: _notificarDiario,
      notificarAlAval: _notificarAval,
    );
    
    widget.onSave(newConfig);
    Navigator.pop(context);
  }
}

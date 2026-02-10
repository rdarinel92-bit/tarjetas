// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_qr_models.dart';
import 'climas_chat_solicitud_screen.dart';
import 'climas_formulario_publico_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PANEL DE ADMINISTRACIÓN DE SOLICITUDES QR - CLIMAS
/// Ver, aprobar, rechazar y gestionar solicitudes desde el QR
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasSolicitudesAdminScreen extends StatefulWidget {
  final String? solicitudId;

  const ClimasSolicitudesAdminScreen({super.key, this.solicitudId});

  @override
  State<ClimasSolicitudesAdminScreen> createState() => _ClimasSolicitudesAdminScreenState();
}

class _ClimasSolicitudesAdminScreenState extends State<ClimasSolicitudesAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ClimasSolicitudQrModel> _solicitudes = [];
  String _filtroEstado = 'todas';
  bool _accionInicialEjecutada = false;
  
  // Estadísticas
  int _nuevas = 0;
  int _enProceso = 0;
  int _aprobadas = 0;
  int _rechazadas = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _cargarSolicitudes();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final estados = ['todas', 'nueva', 'contactado', 'aprobado'];
    setState(() => _filtroEstado = estados[_tabController.index]);
  }

  Future<void> _cargarSolicitudes() async {
    setState(() => _isLoading = true);
    try {
      // Solo cargar de climas_solicitudes_qr - sin mezclar con otras tablas
      final res = await AppSupabase.client
          .from('climas_solicitudes_qr')
          .select()
          .order('created_at', ascending: false);
      
      final lista = (res as List).map((e) => ClimasSolicitudQrModel.fromMap(e)).toList();
      
      if (mounted) {
        setState(() {
          _solicitudes = lista;
          _nuevas = lista.where((s) => s.estado == 'nueva').length;
          _enProceso = lista.where((s) => ['revisando', 'contactado', 'agendado'].contains(s.estado)).length;
          _aprobadas = lista.where((s) => s.estado == 'aprobado' || s.estado == 'convertido').length;
          _rechazadas = lista.where((s) => s.estado == 'rechazado').length;
          _isLoading = false;
        });
        _ejecutarAccionInicial();
      }
    } catch (e) {
      debugPrint('Error cargando solicitudes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ejecutarAccionInicial() {
    if (_accionInicialEjecutada) return;
    _accionInicialEjecutada = true;
    if (widget.solicitudId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final solicitud = _solicitudes.firstWhere(
        (s) => s.id == widget.solicitudId,
        orElse: () => ClimasSolicitudQrModel(
          id: '',
          telefono: '',
          nombreCompleto: '',
          direccion: '',
          tipoServicio: 'cotizacion',
          estado: 'nueva',
          createdAt: DateTime.now(),
        ),
      );
      if (solicitud.id.isNotEmpty) {
        _mostrarDetalleSolicitud(solicitud);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la solicitud')),
        );
      }
    });
  }

  List<ClimasSolicitudQrModel> get _solicitudesFiltradas {
    if (_filtroEstado == 'todas') return _solicitudes;
    if (_filtroEstado == 'nueva') return _solicitudes.where((s) => s.estado == 'nueva').toList();
    if (_filtroEstado == 'contactado') {
      return _solicitudes.where((s) => ['revisando', 'contactado', 'agendado'].contains(s.estado)).toList();
    }
    if (_filtroEstado == 'aprobado') {
      return _solicitudes.where((s) => s.estado == 'aprobado' || s.estado == 'convertido').toList();
    }
    return _solicitudes;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Solicitudes QR',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarSolicitudes,
          tooltip: 'Actualizar',
        ),
        IconButton(
          icon: const Icon(Icons.qr_code),
          onPressed: _mostrarQRConfig,
          tooltip: 'Configurar QR',
        ),
      ],
      body: Column(
        children: [
          _buildEstadisticas(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _solicitudesFiltradas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarSolicitudes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _solicitudesFiltradas.length,
                          itemBuilder: (ctx, i) => _buildSolicitudCard(_solicitudesFiltradas[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Nuevas', _nuevas, const Color(0xFF00D9FF), Icons.fiber_new),
          const SizedBox(width: 12),
          _buildStatCard('En Proceso', _enProceso, const Color(0xFFFBBF24), Icons.pending_actions),
          const SizedBox(width: 12),
          _buildStatCard('Aprobadas', _aprobadas, const Color(0xFF10B981), Icons.check_circle),
          const SizedBox(width: 12),
          _buildStatCard('Rechazadas', _rechazadas, const Color(0xFFEF4444), Icons.cancel),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(text: 'Todas (${_solicitudes.length})'),
          Tab(text: 'Nuevas ($_nuevas)'),
          Tab(text: 'Proceso ($_enProceso)'),
          Tab(text: 'Cerradas (${_aprobadas + _rechazadas})'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No hay solicitudes',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Las solicitudes desde el QR aparecerán aquí',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(ClimasSolicitudQrModel solicitud) {
    final colorEstado = _getColorEstado(solicitud.estado);
    final tiempoTranscurrido = _getTiempoTranscurrido(solicitud.createdAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E).withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: solicitud.esUrgente
              ? const Color(0xFFEF4444).withOpacity(0.5)
              : colorEstado.withOpacity(0.3),
          width: solicitud.esUrgente ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalleSolicitud(solicitud),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconServicio(solicitud.tipoServicio),
                        color: colorEstado,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                solicitud.nombreCompleto,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (solicitud.esUrgente) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '🚨 URGENTE',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            solicitud.tipoServicioDisplay,
                            style: TextStyle(color: colorEstado, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            solicitud.estadoDisplay,
                            style: TextStyle(
                              color: colorEstado,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tiempoTranscurrido,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info
                Row(
                  children: [
                    _buildInfoChip(Icons.phone, solicitud.telefono),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(Icons.location_on_outlined, solicitud.direccion, flex: true),
                    ),
                  ],
                ),
                if (solicitud.problemaReportado != null && solicitud.problemaReportado!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            solicitud.problemaReportado!,
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Acciones rápidas
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirChat(solicitud),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D9FF),
                          side: const BorderSide(color: Color(0xFF00D9FF)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _llamarCliente(solicitud.telefono),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Llamar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (solicitud.estaPendiente)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _aprobarSolicitud(solicitud),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool flex = false}) {
    final child = Row(
      mainAxisSize: flex ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.5), size: 14),
        const SizedBox(width: 4),
        flex
            ? Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                text,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
      ],
    );
    return child;
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'nueva': return const Color(0xFF00D9FF);
      case 'revisando': return const Color(0xFFFBBF24);
      case 'contactado': return const Color(0xFF8B5CF6);
      case 'agendado': return const Color(0xFF06B6D4);
      case 'aprobado': return const Color(0xFF10B981);
      case 'convertido': return const Color(0xFF10B981);
      case 'rechazado': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  IconData _getIconServicio(String tipo) {
    switch (tipo) {
      case 'cotizacion': return Icons.request_quote;
      case 'instalacion': return Icons.build;
      case 'mantenimiento': return Icons.handyman;
      case 'reparacion': return Icons.construction;
      case 'emergencia': return Icons.emergency;
      default: return Icons.ac_unit;
    }
  }

  String _getTiempoTranscurrido(DateTime? fecha) {
    if (fecha == null) return '';
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  void _mostrarDetalleSolicitud(ClimasSolicitudQrModel solicitud) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DetallesSolicitudSheet(
        solicitud: solicitud,
        onAprobar: () {
          Navigator.pop(ctx);
          _aprobarSolicitud(solicitud);
        },
        onRechazar: () {
          Navigator.pop(ctx);
          _rechazarSolicitud(solicitud);
        },
        onCambiarEstado: (nuevoEstado) {
          Navigator.pop(ctx);
          _cambiarEstado(solicitud, nuevoEstado);
        },
      ),
    );
  }

  void _abrirChat(ClimasSolicitudQrModel solicitud) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClimasChatSolicitudScreen(solicitud: solicitud),
      ),
    );
  }

  void _llamarCliente(String telefono) {
    // Implementar lógica de llamada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Llamando a $telefono...')),
    );
  }

  Future<void> _aprobarSolicitud(ClimasSolicitudQrModel solicitud) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Aprobar Solicitud', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Aprobar solicitud de ${solicitud.nombreCompleto}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Se creará automáticamente como cliente de Climas',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Aprobar y crear cliente'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      await AppSupabase.client.rpc('climas_aprobar_solicitud_qr', params: {
        'p_solicitud_id': solicitud.id,
        'p_crear_cliente': true,
        'p_notas': 'Aprobado desde panel admin',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Solicitud aprobada y cliente creado'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      
      _cargarSolicitudes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rechazarSolicitud(ClimasSolicitudQrModel solicitud) async {
    final motivoController = TextEditingController();
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Rechazar Solicitud', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Rechazar solicitud de ${solicitud.nombreCompleto}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motivo del rechazo (opcional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      await AppSupabase.client.from('climas_solicitudes_qr').update({
        'estado': 'rechazado',
        'motivo_rechazo': motivoController.text.isEmpty ? null : motivoController.text,
      }).eq('id', solicitud.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada'), backgroundColor: Color(0xFFEF4444)),
      );
      
      _cargarSolicitudes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cambiarEstado(ClimasSolicitudQrModel solicitud, String nuevoEstado) async {
    try {
      await AppSupabase.client.from('climas_solicitudes_qr').update({
        'estado': nuevoEstado,
      }).eq('id', solicitud.id);
      
      // Registrar en historial
      await AppSupabase.client.from('climas_solicitud_historial').insert({
        'solicitud_id': solicitud.id,
        'estado_anterior': solicitud.estado,
        'estado_nuevo': nuevoEstado,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a: $nuevoEstado')),
      );
      
      _cargarSolicitudes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarQRConfig() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Código QR', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2, size: 150, color: Colors.black),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escanea este código para probar el formulario público',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClimasFormularioPublicoScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Ver formulario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET DE DETALLES
// ═══════════════════════════════════════════════════════════════════════════════
class _DetallesSolicitudSheet extends StatelessWidget {
  final ClimasSolicitudQrModel solicitud;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Function(String) onCambiarEstado;

  const _DetallesSolicitudSheet({
    required this.solicitud,
    required this.onAprobar,
    required this.onRechazar,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solicitud.nombreCompleto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            solicitud.tipoServicioDisplay,
                            style: const TextStyle(color: Color(0xFF00D9FF)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 32),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSeccion('📱 Contacto', [
                      _buildItem('Teléfono', solicitud.telefono),
                      if (solicitud.email != null) _buildItem('Email', solicitud.email!),
                      _buildItem('Medio preferido', solicitud.medioContactoPreferido),
                      if (solicitud.horarioContactoPreferido != null)
                        _buildItem('Horario', solicitud.horarioContactoPreferido!),
                    ]),
                    const SizedBox(height: 20),
                    _buildSeccion('📍 Ubicación', [
                      _buildItem('Dirección', solicitud.direccion),
                      if (solicitud.colonia != null) _buildItem('Colonia', solicitud.colonia!),
                      if (solicitud.ciudad != null) _buildItem('Ciudad', solicitud.ciudad!),
                      if (solicitud.referenciaUbicacion != null)
                        _buildItem('Referencia', solicitud.referenciaUbicacion!),
                    ]),
                    if (solicitud.tieneEquipoActual) ...[
                      const SizedBox(height: 20),
                      _buildSeccion('❄️ Equipo Actual', [
                        if (solicitud.marcaEquipoActual != null)
                          _buildItem('Marca', solicitud.marcaEquipoActual!),
                        if (solicitud.antiguedadEquipo != null)
                          _buildItem('Antigüedad', solicitud.antiguedadEquipo!),
                        if (solicitud.problemaReportado != null)
                          _buildItem('Problema', solicitud.problemaReportado!),
                      ]),
                    ],
                    if (solicitud.tipoEspacio != null) ...[
                      const SizedBox(height: 20),
                      _buildSeccion('🏠 Espacio', [
                        _buildItem('Tipo', solicitud.tipoEspacioDisplay),
                        if (solicitud.metrosCuadrados != null)
                          _buildItem('m²', '${solicitud.metrosCuadrados}'),
                        _buildItem('Equipos', '${solicitud.cantidadEquiposDeseados}'),
                        if (solicitud.presupuestoEstimado != null)
                          _buildItem('Presupuesto', solicitud.presupuestoEstimado!),
                      ]),
                    ],
                    if (solicitud.notasCliente != null) ...[
                      const SizedBox(height: 20),
                      _buildSeccion('📝 Notas del Cliente', [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            solicitud.notasCliente!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    // Cambiar estado
                    _buildSeccion('🔄 Cambiar Estado', []),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['revisando', 'contactado', 'agendado'].map((e) {
                        final isSelected = solicitud.estado == e;
                        return ChoiceChip(
                          label: Text(e.toUpperCase()),
                          selected: isSelected,
                          onSelected: isSelected ? null : (_) => onCambiarEstado(e),
                          backgroundColor: const Color(0xFF1A1A2E),
                          selectedColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Acciones
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (!solicitud.estaRechazado)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRechazar,
                          icon: const Icon(Icons.close),
                          label: const Text('Rechazar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (!solicitud.estaRechazado && !solicitud.estaAprobado)
                      const SizedBox(width: 12),
                    if (!solicitud.estaAprobado)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAprobar,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

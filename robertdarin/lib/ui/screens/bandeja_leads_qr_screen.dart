// ═══════════════════════════════════════════════════════════════════════════════
// BANDEJA DE LEADS QR - CRM Mini V10.54
// Gestión de solicitudes recibidas via formularios QR
// Estados: nuevo, visto, contactado, en_proceso, completado, cancelado, spam
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';

class BandejaLeadsQrScreen extends StatefulWidget {
  final String? negocioId;
  final String? tarjetaId;
  final String? filtroModulo;
  
  const BandejaLeadsQrScreen({
    super.key,
    this.negocioId,
    this.tarjetaId,
    this.filtroModulo,
  });

  @override
  State<BandejaLeadsQrScreen> createState() => _BandejaLeadsQrScreenState();
}

class _BandejaLeadsQrScreenState extends State<BandejaLeadsQrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leads = [];
  String _filtroEstado = 'todos';
  String _ordenamiento = 'recientes';
  
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  // Estados disponibles con colores e iconos
  final Map<String, Map<String, dynamic>> _estadosConfig = {
    'nuevo': {'color': Colors.blue, 'icono': Icons.fiber_new, 'label': 'Nuevo'},
    'visto': {'color': Colors.grey, 'icono': Icons.visibility, 'label': 'Visto'},
    'contactado': {'color': Colors.orange, 'icono': Icons.phone_callback, 'label': 'Contactado'},
    'en_proceso': {'color': Colors.purple, 'icono': Icons.hourglass_top, 'label': 'En Proceso'},
    'completado': {'color': Colors.green, 'icono': Icons.check_circle, 'label': 'Completado'},
    'cancelado': {'color': Colors.red, 'icono': Icons.cancel, 'label': 'Cancelado'},
    'spam': {'color': Colors.brown, 'icono': Icons.block, 'label': 'Spam'},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: _filtroEstado = 'todos'; break;
            case 1: _filtroEstado = 'nuevo'; break;
            case 2: _filtroEstado = 'en_proceso'; break;
            case 3: _filtroEstado = 'completado'; break;
          }
        });
      }
    });
    _cargarLeads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarLeads() async {
    setState(() => _isLoading = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      var query = AppSupabase.client
          .from('formularios_qr_envios')
          .select('*, tarjetas_servicio!inner(id, titulo, modulo, created_by, negocio_id)');

      // Filtrar por usuario creador de la tarjeta
      query = query.eq('tarjetas_servicio.created_by', user.id);

      if (widget.tarjetaId != null) {
        query = query.eq('tarjeta_id', widget.tarjetaId!);
      }

      if (widget.filtroModulo != null) {
        query = query.eq('tarjetas_servicio.modulo', widget.filtroModulo!);
      }

      final response = await query.order('created_at', ascending: false);
      _leads = List<Map<String, dynamic>>.from(response);

    } catch (e) {
      debugPrint('Error cargando leads: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _leadsFiltrados {
    var lista = _leads;
    
    if (_filtroEstado != 'todos') {
      lista = lista.where((l) => l['estado'] == _filtroEstado).toList();
    }
    
    switch (_ordenamiento) {
      case 'recientes':
        lista.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case 'antiguos':
        lista.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
        break;
      case 'nombre':
        lista.sort((a, b) {
          final nombreA = _extraerNombre(a['datos_formulario']);
          final nombreB = _extraerNombre(b['datos_formulario']);
          return nombreA.compareTo(nombreB);
        });
        break;
    }
    
    return lista;
  }

  String _extraerNombre(dynamic datos) {
    if (datos == null) return '';
    if (datos is Map) {
      return datos['nombre']?.toString() ?? 
             datos['nombre_completo']?.toString() ?? 
             datos['cliente_nombre']?.toString() ?? '';
    }
    return '';
  }

  String _extraerTelefono(dynamic datos) {
    if (datos == null) return '';
    if (datos is Map) {
      return datos['telefono']?.toString() ?? 
             datos['celular']?.toString() ?? 
             datos['whatsapp']?.toString() ?? '';
    }
    return '';
  }

  String _extraerEmail(dynamic datos) {
    if (datos == null) return '';
    if (datos is Map) {
      return datos['email']?.toString() ?? 
             datos['correo']?.toString() ?? '';
    }
    return '';
  }

  Future<void> _cambiarEstado(String leadId, String nuevoEstado) async {
    try {
      await AppSupabase.client
          .from('formularios_qr_envios')
          .update({
            'estado': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', leadId);

      // Actualizar localmente
      final index = _leads.indexWhere((l) => l['id'] == leadId);
      if (index != -1) {
        setState(() {
          _leads[index]['estado'] = nuevoEstado;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado a: ${_estadosConfig[nuevoEstado]?['label'] ?? nuevoEstado}'),
            backgroundColor: _estadosConfig[nuevoEstado]?['color'] ?? Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cambiando estado: $e');
    }
  }

  Future<void> _agregarNota(String leadId) async {
    final controller = TextEditingController();
    final lead = _leads.firstWhere((l) => l['id'] == leadId, orElse: () => {});
    final notasActuales = lead['notas']?.toString() ?? '';
    controller.text = notasActuales;

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.note_add, color: Colors.amber),
            SizedBox(width: 10),
            Text('Notas', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Escribe notas sobre este lead...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      try {
        await AppSupabase.client
            .from('formularios_qr_envios')
            .update({
              'notas': resultado,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', leadId);

        final index = _leads.indexWhere((l) => l['id'] == leadId);
        if (index != -1) {
          setState(() {
            _leads[index]['notas'] = resultado;
          });
        }
      } catch (e) {
        debugPrint('Error guardando nota: $e');
      }
    }
  }

  Future<void> _llamar(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarWhatsApp(String telefono, {String? mensaje}) async {
    final numero = telefono.replaceAll(RegExp(r'[^\d]'), '');
    final msg = mensaje ?? 'Hola, recibí tu solicitud y me gustaría contactarte.';
    final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _enviarEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Respuesta a tu solicitud');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nuevos = _leads.where((l) => l['estado'] == 'nuevo').length;
    final enProceso = _leads.where((l) => l['estado'] == 'en_proceso').length;
    final completados = _leads.where((l) => l['estado'] == 'completado').length;

    return PremiumScaffold(
      title: 'Bandeja de Leads',
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics, color: Colors.cyan),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.qrAnalytics),
          tooltip: 'Ver Analytics',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, color: Colors.white),
          onSelected: (value) => setState(() => _ordenamiento = value),
          itemBuilder: (context) => [
            _buildOrdenItem('recientes', 'Más recientes'),
            _buildOrdenItem('antiguos', 'Más antiguos'),
            _buildOrdenItem('nombre', 'Por nombre'),
          ],
        ),
      ],
      body: Column(
        children: [
          // Tabs de filtro rápido
          Container(
            color: const Color(0xFF0D0D14),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyan,
              labelColor: Colors.cyan,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Todos (${_leads.length})'),
                Tab(text: 'Nuevos ($nuevos)'),
                Tab(text: 'En Proceso ($enProceso)'),
                Tab(text: 'Completados ($completados)'),
              ],
            ),
          ),
          
          // Lista de leads
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                : _leadsFiltrados.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarLeads,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leadsFiltrados.length,
                          itemBuilder: (context, index) => _buildLeadCard(_leadsFiltrados[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildOrdenItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_ordenamiento == value)
            const Icon(Icons.check, color: Colors.cyan, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filtroEstado == 'nuevo' ? Icons.inbox : Icons.hourglass_empty,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroEstado == 'todos'
                ? 'No hay solicitudes aún'
                : 'No hay leads con estado "${_estadosConfig[_filtroEstado]?['label']}"',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Las solicitudes de tus tarjetas QR aparecerán aquí',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final estado = lead['estado'] ?? 'nuevo';
    final estadoConfig = _estadosConfig[estado] ?? _estadosConfig['nuevo']!;
    final datos = lead['datos_formulario'];
    final tarjeta = lead['tarjetas_servicio'];
    
    final nombre = _extraerNombre(datos);
    final telefono = _extraerTelefono(datos);
    final email = _extraerEmail(datos);
    final fecha = lead['created_at'] != null 
        ? _formatoFecha.format(DateTime.parse(lead['created_at']))
        : '';
    final modulo = tarjeta?['modulo']?.toString().toUpperCase() ?? 'GENERAL';
    final tituloTarjeta = tarjeta?['titulo'] ?? 'Sin título';
    final tieneNotas = (lead['notas']?.toString() ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estado == 'nuevo' 
              ? Colors.blue.withOpacity(0.5) 
              : Colors.white10,
          width: estado == 'nuevo' ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (estadoConfig['color'] as Color).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(estadoConfig['icono'] as IconData, color: estadoConfig['color'] as Color, size: 18),
                const SizedBox(width: 8),
                Text(
                  estadoConfig['label'] as String,
                  style: TextStyle(color: estadoConfig['color'] as Color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(modulo, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                if (nombre.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nombre,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 8),
                
                // Contacto
                Row(
                  children: [
                    if (telefono.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _llamar(telefono),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              Text(telefono, style: const TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (email.isNotEmpty)
                      GestureDetector(
                        onTap: () => _enviarEmail(email),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                email.length > 20 ? '${email.substring(0, 20)}...' : email,
                                style: const TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),
                
                // Tarjeta origen
                Text(
                  'Via: $tituloTarjeta',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),

                // Notas si existen
                if (tieneNotas) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lead['notas'],
                            style: const TextStyle(color: Colors.amber, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Acciones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(Icons.visibility, 'Ver', () => _verDetalle(lead)),
                if (telefono.isNotEmpty)
                  _buildActionBtn(Icons.chat, 'WhatsApp', () => _enviarWhatsApp(telefono), color: Colors.teal),
                _buildActionBtn(Icons.note_add, 'Nota', () => _agregarNota(lead['id'])),
                _buildActionBtn(Icons.swap_horiz, 'Estado', () => _mostrarCambioEstado(lead['id'], estado)),
                _buildActionBtn(Icons.person_add, 'Convertir', () => _convertirACliente(lead), color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white54, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color ?? Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _verDetalle(Map<String, dynamic> lead) {
    final datos = lead['datos_formulario'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '📋 Datos del Formulario',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (datos is Map)
                ...datos.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          _formatearCampo(e.key.toString()),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value?.toString() ?? '-',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )).toList()
              else
                Text(
                  datos?.toString() ?? 'Sin datos',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearCampo(String campo) {
    return campo
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  void _mostrarCambioEstado(String leadId, String estadoActual) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cambiar Estado',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._estadosConfig.entries.map((e) {
              final esActual = e.key == estadoActual;
              return ListTile(
                leading: Icon(e.value['icono'] as IconData, color: e.value['color'] as Color),
                title: Text(
                  e.value['label'] as String,
                  style: TextStyle(
                    color: esActual ? e.value['color'] as Color : Colors.white,
                    fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: esActual ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (!esActual) _cambiarEstado(leadId, e.key);
                },
              );
            }).toList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _convertirACliente(Map<String, dynamic> lead) {
    final datos = lead['datos_formulario'];
    final nombre = _extraerNombre(datos);
    final telefono = _extraerTelefono(datos);
    final email = _extraerEmail(datos);
    final tarjeta = lead['tarjetas_servicio'];
    final modulo = tarjeta?['modulo']?.toString() ?? 'general';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.green),
            SizedBox(width: 10),
            Text('Convertir a Cliente', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Crear cliente con estos datos?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 16),
            if (nombre.isNotEmpty) _buildInfoRow('Nombre', nombre),
            if (telefono.isNotEmpty) _buildInfoRow('Teléfono', telefono),
            if (email.isNotEmpty) _buildInfoRow('Email', email),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se abrirá el formulario de cliente con los datos prellenados',
                      style: TextStyle(color: Colors.blue.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
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
            onPressed: () {
              Navigator.pop(context);
              // Navegar al formulario de cliente con datos prellenados
              Navigator.pushNamed(
                context,
                AppRoutes.formularioCliente,
                arguments: {
                  'nombre': nombre,
                  'telefono': telefono,
                  'email': email,
                  'origen': 'qr_lead',
                  'lead_id': lead['id'],
                  'modulo_origen': modulo,
                },
              );
              // Marcar como completado
              _cambiarEstado(lead['id'], 'completado');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Crear Cliente'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// DETALLE COMPLETO DE CLIENTE CLIMAS
/// Incluye: Equipos, GPS, Documentos, Notas, Contactos, Cotizaciones
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasClienteDetalleScreen extends StatefulWidget {
  final String clienteId;
  const ClimasClienteDetalleScreen({super.key, required this.clienteId});

  @override
  State<ClimasClienteDetalleScreen> createState() => _ClimasClienteDetalleScreenState();
}

class _ClimasClienteDetalleScreenState extends State<ClimasClienteDetalleScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  
  late TabController _tabController;
  bool _isLoading = true;
  
  ClimasClienteModel? _cliente;
  List<Map<String, dynamic>> _equipos = [];
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _documentos = [];
  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _contactos = [];
  List<Map<String, dynamic>> _cotizaciones = [];
  
  // Stats
  int _totalServicios = 0;
  double _totalGastado = 0;
  int _equiposActivos = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar cliente
      final clienteRes = await AppSupabase.client
          .from('climas_clientes')
          .select()
          .eq('id', widget.clienteId)
          .single();
      
      _cliente = ClimasClienteModel.fromMap(clienteRes);

      // Cargar equipos del cliente
      try {
        final equiposRes = await AppSupabase.client
            .from('climas_equipos_cliente')
            .select('*, climas_productos(nombre, marca, modelo)')
            .eq('cliente_id', widget.clienteId)
            .order('fecha_instalacion', ascending: false);
        _equipos = List<Map<String, dynamic>>.from(equiposRes);
        _equiposActivos = _equipos.where((e) => e['activo'] == true).length;
      } catch (_) {
        _equipos = [];
      }

      // Cargar historial de servicios
      try {
        final serviciosRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_tecnicos(nombre)')
            .eq('cliente_id', widget.clienteId)
            .order('fecha_programada', ascending: false);
        _servicios = List<Map<String, dynamic>>.from(serviciosRes);
        _totalServicios = _servicios.length;
        _totalGastado = _servicios.fold(0.0, (sum, s) => sum + (s['total'] ?? 0).toDouble());
      } catch (_) {
        _servicios = [];
      }

      // Cargar documentos
      try {
        final docsRes = await AppSupabase.client
            .from('climas_cliente_documentos')
            .select()
            .eq('cliente_id', widget.clienteId)
            .order('created_at', ascending: false);
        _documentos = List<Map<String, dynamic>>.from(docsRes);
      } catch (_) {
        _documentos = [];
      }

      // Cargar notas
      try {
        final notasRes = await AppSupabase.client
            .from('climas_cliente_notas')
            .select()
            .eq('cliente_id', widget.clienteId)
            .order('created_at', ascending: false);
        _notas = List<Map<String, dynamic>>.from(notasRes);
      } catch (_) {
        _notas = [];
      }

      // Cargar contactos adicionales
      try {
        final contactosRes = await AppSupabase.client
            .from('climas_cliente_contactos')
            .select()
            .eq('cliente_id', widget.clienteId)
            .order('es_principal', ascending: false);
        _contactos = List<Map<String, dynamic>>.from(contactosRes);
      } catch (_) {
        _contactos = [];
      }

      // Cargar cotizaciones
      try {
        final cotizacionesRes = await AppSupabase.client
            .from('climas_cotizaciones')
            .select()
            .eq('cliente_id', widget.clienteId)
            .order('fecha', ascending: false);
        _cotizaciones = List<Map<String, dynamic>>.from(cotizacionesRes);
      } catch (_) {
        _cotizaciones = [];
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: _cliente?.nombre ?? 'Cliente',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: _editarCliente,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1A1A2E),
          onSelected: (value) {
            if (value == 'llamar') _llamar();
            if (value == 'whatsapp') _abrirWhatsApp();
            if (value == 'email') _enviarEmail();
            if (value == 'mapa') _abrirMapa();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'llamar', child: Row(children: [Icon(Icons.phone, color: Colors.green, size: 20), SizedBox(width: 8), Text('Llamar', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'whatsapp', child: Row(children: [Icon(Icons.chat, color: Colors.green, size: 20), SizedBox(width: 8), Text('WhatsApp', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'email', child: Row(children: [Icon(Icons.email, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Email', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'mapa', child: Row(children: [Icon(Icons.map, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Ver en Mapa', style: TextStyle(color: Colors.white))])),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cliente == null
              ? const Center(child: Text('Cliente no encontrado', style: TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    _buildHeader(),
                    _buildStats(),
                    _buildTabs(),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _cliente!.nombre.isNotEmpty ? _cliente!.nombre[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cliente!.nombre,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _cliente!.activo ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _cliente!.activo ? 'ACTIVO' : 'INACTIVO',
                        style: TextStyle(color: _cliente!.activo ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cliente!.tipoCliente == 'empresa' ? '🏢 Empresa' : '👤 Particular',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                if (_cliente!.telefono != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(_cliente!.telefono!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                if (_cliente!.email != null)
                  Row(
                    children: [
                      const Icon(Icons.email, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(_cliente!.email!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Equipos', '$_equiposActivos', Icons.ac_unit, const Color(0xFF00B4D8)),
          const SizedBox(width: 8),
          _buildStatCard('Servicios', '$_totalServicios', Icons.build, const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          _buildStatCard('Invertido', _currencyFormat.format(_totalGastado), Icons.attach_money, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF00B4D8),
        labelColor: const Color(0xFF00B4D8),
        unselectedLabelColor: Colors.white54,
        tabs: [
          Tab(text: 'Equipos (${_equipos.length})'),
          Tab(text: 'Servicios (${_servicios.length})'),
          Tab(text: 'Contactos (${_contactos.length})'),
          Tab(text: 'Documentos (${_documentos.length})'),
          Tab(text: 'Notas (${_notas.length})'),
          Tab(text: 'Cotizaciones (${_cotizaciones.length})'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEquiposTab(),
        _buildServiciosTab(),
        _buildContactosTab(),
        _buildDocumentosTab(),
        _buildNotasTab(),
        _buildCotizacionesTab(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: EQUIPOS INSTALADOS
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildEquiposTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _agregarEquipo,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar Equipo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _equipos.isEmpty
              ? _buildEmptyState('Sin equipos registrados', Icons.ac_unit)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _equipos.length,
                  itemBuilder: (context, index) => _buildEquipoCard(_equipos[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final producto = equipo['climas_productos'] as Map<String, dynamic>?;
    final fechaInstalacion = equipo['fecha_instalacion'] != null
        ? _dateFormat.format(DateTime.parse(equipo['fecha_instalacion']))
        : 'Sin fecha';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: equipo['activo'] == true ? const Color(0xFF00B4D8).withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.ac_unit, color: Color(0xFF00B4D8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto?['nombre'] ?? equipo['descripcion'] ?? 'Equipo',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (producto != null)
                      Text(
                        '${producto['marca'] ?? ''} ${producto['modelo'] ?? ''}'.trim(),
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: equipo['activo'] == true ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  equipo['activo'] == true ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: equipo['activo'] == true ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today, 'Instalado: $fechaInstalacion'),
              const SizedBox(width: 8),
              if (equipo['numero_serie'] != null)
                _buildInfoChip(Icons.qr_code, 'S/N: ${equipo['numero_serie']}'),
            ],
          ),
          if (equipo['ubicacion'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(equipo['ubicacion'], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ],
          if (equipo['garantia_hasta'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  size: 14,
                  color: DateTime.parse(equipo['garantia_hasta']).isAfter(DateTime.now())
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  'Garantía hasta: ${_dateFormat.format(DateTime.parse(equipo['garantia_hasta']))}',
                  style: TextStyle(
                    color: DateTime.parse(equipo['garantia_hasta']).isAfter(DateTime.now())
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: HISTORIAL DE SERVICIOS
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildServiciosTab() {
    return _servicios.isEmpty
        ? _buildEmptyState('Sin servicios registrados', Icons.build)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _servicios.length,
            itemBuilder: (context, index) => _buildServicioCard(_servicios[index]),
          );
  }

  Widget _buildServicioCard(Map<String, dynamic> servicio) {
    final tecnico = servicio['climas_tecnicos'] as Map<String, dynamic>?;
    final fecha = servicio['fecha_programada'] != null
        ? _dateFormat.format(DateTime.parse(servicio['fecha_programada']))
        : 'Sin fecha';
    
    Color estadoColor;
    switch (servicio['estado']) {
      case 'completado':
        estadoColor = Colors.green;
        break;
      case 'en_proceso':
        estadoColor = Colors.orange;
        break;
      case 'cancelado':
        estadoColor = Colors.red;
        break;
      default:
        estadoColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIconoTipoServicio(servicio['tipo_servicio']), color: estadoColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servicio['tipo_servicio']?.toUpperCase() ?? 'SERVICIO',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(servicio['total'] ?? 0),
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (servicio['estado'] ?? 'pendiente').toUpperCase(),
                      style: TextStyle(color: estadoColor, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (servicio['descripcion'] != null) ...[
            const SizedBox(height: 8),
            Text(
              servicio['descripcion'],
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (tecnico != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.engineering, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text('Técnico: ${tecnico['nombre']}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconoTipoServicio(String? tipo) {
    switch (tipo) {
      case 'instalacion':
        return Icons.build;
      case 'mantenimiento':
        return Icons.engineering;
      case 'reparacion':
        return Icons.handyman;
      case 'revision':
        return Icons.search;
      default:
        return Icons.miscellaneous_services;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: CONTACTOS ADICIONALES
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildContactosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _agregarContacto,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Agregar Contacto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _contactos.isEmpty
              ? _buildEmptyState('Sin contactos adicionales', Icons.contacts)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contactos.length,
                  itemBuilder: (context, index) => _buildContactoCard(_contactos[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildContactoCard(Map<String, dynamic> contacto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: contacto['es_principal'] == true
            ? Border.all(color: const Color(0xFF00B4D8).withOpacity(0.5))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF00B4D8).withOpacity(0.2),
            child: Text(
              (contacto['nombre'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF00B4D8)),
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
                      contacto['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (contacto['es_principal'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B4D8).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PRINCIPAL', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                if (contacto['cargo'] != null)
                  Text(contacto['cargo'], style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                const SizedBox(height: 4),
                if (contacto['telefono'] != null)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(contacto['telefono'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    ],
                  ),
                if (contacto['email'] != null)
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(contacto['email'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                onPressed: () => _llamarContacto(contacto['telefono']),
              ),
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                onPressed: () => _whatsappContacto(contacto['telefono']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: DOCUMENTOS
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildDocumentosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _agregarDocumento,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Subir Documento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _documentos.isEmpty
              ? _buildEmptyState('Sin documentos', Icons.folder_open)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documentos.length,
                  itemBuilder: (context, index) => _buildDocumentoCard(_documentos[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildDocumentoCard(Map<String, dynamic> doc) {
    final fecha = doc['created_at'] != null
        ? _dateFormat.format(DateTime.parse(doc['created_at']))
        : '';
    
    IconData icono;
    Color color;
    switch (doc['tipo']) {
      case 'contrato':
        icono = Icons.description;
        color = Colors.blue;
        break;
      case 'factura':
        icono = Icons.receipt;
        color = Colors.green;
        break;
      case 'garantia':
        icono = Icons.verified_user;
        color = Colors.purple;
        break;
      case 'foto':
        icono = Icons.image;
        color = Colors.orange;
        break;
      default:
        icono = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: color),
        ),
        title: Text(doc['nombre'] ?? 'Documento', style: const TextStyle(color: Colors.white)),
        subtitle: Text('$fecha • ${doc['tipo'] ?? 'Otro'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.download, color: Color(0xFF00B4D8)),
          onPressed: () => _descargarDocumento(doc),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: NOTAS
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildNotasTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _agregarNota,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Nota'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _notas.isEmpty
              ? _buildEmptyState('Sin notas', Icons.note)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notas.length,
                  itemBuilder: (context, index) => _buildNotaCard(_notas[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildNotaCard(Map<String, dynamic> nota) {
    final fecha = nota['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(nota['created_at']))
        : '';
    
    Color prioridadColor;
    switch (nota['prioridad']) {
      case 'alta':
        prioridadColor = Colors.red;
        break;
      case 'media':
        prioridadColor = Colors.orange;
        break;
      default:
        prioridadColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: prioridadColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nota['titulo'] ?? 'Sin título',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nota['contenido'] ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          if (nota['autor'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 12, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(nota['autor'], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: COTIZACIONES
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildCotizacionesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _crearCotizacion,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Cotización'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cotizaciones.isEmpty
              ? _buildEmptyState('Sin cotizaciones', Icons.request_quote)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cotizaciones.length,
                  itemBuilder: (context, index) => _buildCotizacionCard(_cotizaciones[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildCotizacionCard(Map<String, dynamic> cotizacion) {
    final fecha = cotizacion['fecha'] != null
        ? _dateFormat.format(DateTime.parse(cotizacion['fecha']))
        : '';
    final vigenciaHasta = cotizacion['vigencia_hasta'] != null
        ? DateTime.parse(cotizacion['vigencia_hasta'])
        : null;
    final vigente = vigenciaHasta != null && vigenciaHasta.isAfter(DateTime.now());
    
    Color estadoColor;
    String estadoTexto;
    switch (cotizacion['estado']) {
      case 'aceptada':
        estadoColor = Colors.green;
        estadoTexto = 'ACEPTADA';
        break;
      case 'rechazada':
        estadoColor = Colors.red;
        estadoTexto = 'RECHAZADA';
        break;
      case 'vencida':
        estadoColor = Colors.grey;
        estadoTexto = 'VENCIDA';
        break;
      default:
        estadoColor = vigente ? Colors.blue : Colors.grey;
        estadoTexto = vigente ? 'VIGENTE' : 'VENCIDA';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.request_quote, color: estadoColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COT-${cotizacion['folio'] ?? cotizacion['id'].toString().substring(0, 8)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(fecha, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(cotizacion['total'] ?? 0),
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(estadoTexto, style: TextStyle(color: estadoColor, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
          if (cotizacion['descripcion'] != null) ...[
            const SizedBox(height: 12),
            Text(
              cotizacion['descripcion'],
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Ver'),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF00B4D8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String mensaje, IconData icono) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(mensaje, style: TextStyle(color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════════
  
  Future<void> _llamar() async {
    if (_cliente?.telefono != null) {
      final uri = Uri.parse('tel:${_cliente!.telefono}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _abrirWhatsApp() async {
    if (_cliente?.telefono != null) {
      final phone = _cliente!.telefono!.replaceAll(RegExp(r'[^\d]'), '');
      final uri = Uri.parse('https://wa.me/52$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _enviarEmail() async {
    if (_cliente?.email != null) {
      final uri = Uri.parse('mailto:${_cliente!.email}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _abrirMapa() async {
    if (_cliente?.latitud != null && _cliente?.longitud != null) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_cliente!.latitud},${_cliente!.longitud}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (_cliente?.direccion != null) {
      final direccionEncoded = Uri.encodeComponent(_cliente!.direccion!);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$direccionEncoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ubicación registrada')),
        );
      }
    }
  }

  Future<void> _llamarContacto(String? telefono) async {
    if (telefono != null) {
      final uri = Uri.parse('tel:$telefono');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _whatsappContacto(String? telefono) async {
    if (telefono != null) {
      final phone = telefono.replaceAll(RegExp(r'[^\d]'), '');
      final uri = Uri.parse('https://wa.me/52$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _editarCliente() {
    // Navegar a edición
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de edición')),
    );
  }

  void _agregarEquipo() async {
    final result = await _mostrarFormularioEquipo();
    if (result == true) _cargarDatos();
  }

  Future<bool?> _mostrarFormularioEquipo() async {
    final descripcionController = TextEditingController();
    final serieController = TextEditingController();
    final ubicacionController = TextEditingController();
    DateTime? fechaInstalacion = DateTime.now();
    DateTime? garantiaHasta;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Nuevo Equipo', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(descripcionController, 'Descripción/Modelo *', Icons.ac_unit),
                const SizedBox(height: 12),
                _buildDialogTextField(serieController, 'Número de Serie', Icons.qr_code),
                const SizedBox(height: 12),
                _buildDialogTextField(ubicacionController, 'Ubicación (ej: Sala principal)', Icons.location_on),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF00B4D8)),
                  title: const Text('Fecha instalación', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  subtitle: Text(
                    fechaInstalacion != null ? _dateFormat.format(fechaInstalacion!) : 'Seleccionar',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaInstalacion ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaInstalacion = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user, color: Color(0xFF00B4D8)),
                  title: const Text('Garantía hasta', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  subtitle: Text(
                    garantiaHasta != null ? _dateFormat.format(garantiaHasta!) : 'Sin garantía',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: garantiaHasta ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => garantiaHasta = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (descripcionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La descripción es obligatoria')),
                  );
                  return;
                }
                try {
                  await AppSupabase.client.from('climas_equipos_cliente').insert({
                    'cliente_id': widget.clienteId,
                    'descripcion': descripcionController.text,
                    'numero_serie': serieController.text.isEmpty ? null : serieController.text,
                    'ubicacion': ubicacionController.text.isEmpty ? null : ubicacionController.text,
                    'fecha_instalacion': fechaInstalacion?.toIso8601String(),
                    'garantia_hasta': garantiaHasta?.toIso8601String(),
                    'activo': true,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarContacto() async {
    final result = await _mostrarFormularioContacto();
    if (result == true) _cargarDatos();
  }

  Future<bool?> _mostrarFormularioContacto() async {
    final nombreController = TextEditingController();
    final cargoController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();
    bool esPrincipal = false;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Nuevo Contacto', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nombreController, 'Nombre *', Icons.person),
                const SizedBox(height: 12),
                _buildDialogTextField(cargoController, 'Cargo/Puesto', Icons.work),
                const SizedBox(height: 12),
                _buildDialogTextField(telefonoController, 'Teléfono', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogTextField(emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contacto Principal', style: TextStyle(color: Colors.white)),
                  value: esPrincipal,
                  onChanged: (v) => setDialogState(() => esPrincipal = v),
                  activeColor: const Color(0xFF00B4D8),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                try {
                  await AppSupabase.client.from('climas_cliente_contactos').insert({
                    'cliente_id': widget.clienteId,
                    'nombre': nombreController.text,
                    'cargo': cargoController.text.isEmpty ? null : cargoController.text,
                    'telefono': telefonoController.text.isEmpty ? null : telefonoController.text,
                    'email': emailController.text.isEmpty ? null : emailController.text,
                    'es_principal': esPrincipal,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarDocumento() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de subir documento - Requiere file_picker')),
    );
  }

  void _descargarDocumento(Map<String, dynamic> doc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando: ${doc['nombre']}')),
    );
  }

  void _agregarNota() async {
    final result = await _mostrarFormularioNota();
    if (result == true) _cargarDatos();
  }

  Future<bool?> _mostrarFormularioNota() async {
    final tituloController = TextEditingController();
    final contenidoController = TextEditingController();
    String prioridad = 'normal';

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Nueva Nota', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(tituloController, 'Título', Icons.title),
                const SizedBox(height: 12),
                TextField(
                  controller: contenidoController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Contenido *',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: const Color(0xFF0D0D14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Prioridad:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Normal'),
                      selected: prioridad == 'normal',
                      onSelected: (_) => setDialogState(() => prioridad = 'normal'),
                      selectedColor: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Media'),
                      selected: prioridad == 'media',
                      onSelected: (_) => setDialogState(() => prioridad = 'media'),
                      selectedColor: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Alta'),
                      selected: prioridad == 'alta',
                      onSelected: (_) => setDialogState(() => prioridad = 'alta'),
                      selectedColor: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contenidoController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El contenido es obligatorio')),
                  );
                  return;
                }
                try {
                  await AppSupabase.client.from('climas_cliente_notas').insert({
                    'cliente_id': widget.clienteId,
                    'titulo': tituloController.text.isEmpty ? null : tituloController.text,
                    'contenido': contenidoController.text,
                    'prioridad': prioridad,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _crearCotizacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crear cotización - Navegar a pantalla de cotizaciones')),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF00B4D8)),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

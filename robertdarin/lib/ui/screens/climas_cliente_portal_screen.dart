// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PORTAL DEL CLIENTE CLIMAS - V1.0
/// ═══════════════════════════════════════════════════════════════════════════════
/// Portal de autoservicio para clientes donde pueden:
/// - Ver sus equipos instalados
/// - Solicitar servicios
/// - Ver historial de servicios
/// - Ver garantías activas
/// - Chatear con soporte
/// - Ver cotizaciones
/// - Descargar facturas
/// ═══════════════════════════════════════════════════════════════════════════════

class ClimasClientePortalScreen extends StatefulWidget {
  final String? clienteId; // Opcional: si no se pasa, usa el usuario actual
  const ClimasClientePortalScreen({super.key, this.clienteId});

  @override
  State<ClimasClientePortalScreen> createState() => _ClimasClientePortalScreenState();
}

class _ClimasClientePortalScreenState extends State<ClimasClientePortalScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _isLoading = true;
  late String _clienteId;
  String? _negocioId;
  
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _equipos = [];
  List<Map<String, dynamic>> _serviciosRecientes = [];
  List<Map<String, dynamic>> _solicitudesPendientes = [];
  List<Map<String, dynamic>> _solicitudesQr = [];
  List<Map<String, dynamic>> _garantiasActivas = [];
  List<Map<String, dynamic>> _recordatorios = [];
  List<Map<String, dynamic>> _catalogoEquipos = [];
  int _mensajesNoLeidos = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // Obtener clienteId del parámetro o buscar por usuario actual
    if (widget.clienteId != null) {
      _clienteId = widget.clienteId!;
    } else {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final cliente = await AppSupabase.client
              .from('climas_clientes')
              .select('id')
              .eq('auth_uid', userId)
              .maybeSingle();
          if (cliente != null) {
            _clienteId = cliente['id'];
          } else {
            _clienteId = userId; // Fallback
          }
        } catch (_) {
          _clienteId = userId;
        }
      } else {
        _clienteId = '';
      }
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (_clienteId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Cargar datos del cliente
      final clienteRes = await AppSupabase.client
          .from('climas_clientes')
          .select()
          .eq('id', _clienteId)
          .single();
      _cliente = clienteRes;
      _negocioId = _cliente?['negocio_id']?.toString();
      final telefonoCliente = (_cliente?['telefono'] ?? '').toString();
      final emailCliente = (_cliente?['email'] ?? '').toString();

      // Equipos del cliente
      try {
        final equiposRes = await AppSupabase.client
            .from('climas_equipos')
            .select()
            .eq('cliente_id', _clienteId)
            .order('fecha_instalacion', ascending: false);
        _equipos = List<Map<String, dynamic>>.from(equiposRes);
      } catch (_) {}

      // Servicios recientes
      try {
        final serviciosRes = await AppSupabase.client
            .from('climas_ordenes_servicio')
            .select('*, climas_tecnicos(nombre)')
            .eq('cliente_id', _clienteId)
            .order('fecha_programada', ascending: false)
            .limit(5);
        _serviciosRecientes = List<Map<String, dynamic>>.from(serviciosRes);
      } catch (_) {}

      // Solicitudes pendientes
      try {
        final solicitudesRes = await AppSupabase.client
            .from('climas_solicitudes_cliente')
            .select()
            .eq('cliente_id', _clienteId)
            .inFilter('estado', ['nueva', 'vista'])
            .order('created_at', ascending: false);
        _solicitudesPendientes = List<Map<String, dynamic>>.from(solicitudesRes);
      } catch (_) {}

      // Solicitudes QR del cliente (por telefono o email)
      try {
        if (telefonoCliente.isNotEmpty || emailCliente.isNotEmpty) {
          var qrQuery = AppSupabase.client
              .from('climas_solicitudes_qr')
              .select();
          final negocioId = _negocioId;
          if (negocioId != null) {
            qrQuery = qrQuery.eq('negocio_id', negocioId);
          }
          if (telefonoCliente.isNotEmpty && emailCliente.isNotEmpty) {
            qrQuery = qrQuery.or('telefono.eq.$telefonoCliente,email.eq.$emailCliente');
          } else if (telefonoCliente.isNotEmpty) {
            qrQuery = qrQuery.eq('telefono', telefonoCliente);
          } else if (emailCliente.isNotEmpty) {
            qrQuery = qrQuery.eq('email', emailCliente);
          }
          final qrRes = await qrQuery
              .order('created_at', ascending: false)
              .limit(10);
          _solicitudesQr = List<Map<String, dynamic>>.from(qrRes);
        }
      } catch (_) {}

      // Garantías activas
      try {
        final garantiasRes = await AppSupabase.client
            .from('climas_garantias')
            .select('*, climas_equipos(marca, modelo)')
            .eq('cliente_id', _clienteId)
            .eq('activa', true)
            .order('fecha_fin');
        _garantiasActivas = List<Map<String, dynamic>>.from(garantiasRes);
      } catch (_) {}

      // Catalogo de equipos disponibles (inventario)
      try {
        final negocioId = _negocioId;
        if (negocioId != null) {
          final catalogoRes = await AppSupabase.client
              .from('climas_productos')
              .select()
              .eq('negocio_id', negocioId)
              .eq('activo', true)
              .gt('stock', 0)
              .order('nombre')
              .limit(12);
          _catalogoEquipos = List<Map<String, dynamic>>.from(catalogoRes);
        }
      } catch (_) {}

      // Recordatorios de mantenimiento próximos
      try {
        final recordatoriosRes = await AppSupabase.client
            .from('climas_recordatorios_mantenimiento')
            .select('*, climas_equipos(marca, modelo, ubicacion)')
            .eq('cliente_id', _clienteId)
            .gte('fecha_programada', DateTime.now().toIso8601String().split('T')[0])
            .order('fecha_programada')
            .limit(3);
        _recordatorios = List<Map<String, dynamic>>.from(recordatoriosRes);
      } catch (_) {}

      // Mensajes no leídos
      try {
        final mensajesRes = await AppSupabase.client
            .from('climas_mensajes')
            .select('id')
            .eq('cliente_id', _clienteId)
            .eq('leido', false)
            .neq('remitente', 'cliente');
        _mensajesNoLeidos = (mensajesRes as List).length;
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando portal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🏠 Mi Portal',
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: () => _abrirChat(),
            ),
            if (_mensajesNoLeidos > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_mensajesNoLeidos',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBienvenida(),
                    const SizedBox(height: 20),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    if (_recordatorios.isNotEmpty) ...[
                      _buildRecordatorios(),
                      const SizedBox(height: 24),
                    ],
                    _buildMisEquipos(),
                    const SizedBox(height: 24),
                    if (_catalogoEquipos.isNotEmpty) ...[
                      _buildCatalogoEquipos(),
                      const SizedBox(height: 24),
                    ],
                    if (_solicitudesQr.isNotEmpty) ...[
                      _buildSolicitudesQr(),
                      const SizedBox(height: 24),
                    ],
                    if (_solicitudesPendientes.isNotEmpty) ...[
                      _buildSolicitudesPendientes(),
                      const SizedBox(height: 24),
                    ],
                    _buildServiciosRecientes(),
                    const SizedBox(height: 24),
                    if (_garantiasActivas.isNotEmpty) _buildGarantias(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevaSolicitud(),
        backgroundColor: const Color(0xFF00D9FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Solicitar Servicio', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBienvenida() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 35),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, ${_cliente?['nombre']?.split(' ')[0] ?? 'Cliente'}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_equipos.length} equipo${_equipos.length != 1 ? 's' : ''} registrado${_equipos.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildAccionCard(
              icon: Icons.build,
              label: 'Solicitar\nServicio',
              color: const Color(0xFF10B981),
              onTap: () => _nuevaSolicitud(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.receipt_long,
              label: 'Mis\nFacturas',
              color: const Color(0xFF3B82F6),
              onTap: () => _verFacturas(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.verified_user,
              label: 'Mis\nGarantías',
              color: const Color(0xFFF59E0B),
              onTap: () => _verGarantias(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.history,
              label: 'Historial\nServicios',
              color: const Color(0xFF8B5CF6),
              onTap: () => _verHistorial(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildAccionCard(
              icon: Icons.request_quote,
              label: 'Cotizador',
              color: const Color(0xFF22C55E),
              onTap: () => _mostrarCotizadorRapido(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.qr_code_2,
              label: 'Solicitudes\nQR',
              color: const Color(0xFFF97316),
              onTap: () => _mostrarSolicitudesQr(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.ac_unit,
              label: 'Catalogo\nEquipos',
              color: const Color(0xFF00D9FF),
              onTap: () => _mostrarCatalogoEquipos(),
            ),
            const SizedBox(width: 12),
            _buildAccionCard(
              icon: Icons.chat_bubble_outline,
              label: 'Chat\nSoporte',
              color: const Color(0xFF60A5FA),
              onTap: () => _abrirChat(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordatorios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Próximos Mantenimientos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recordatorios.map((r) => _buildRecordatorioCard(r)),
      ],
    );
  }

  Widget _buildRecordatorioCard(Map<String, dynamic> recordatorio) {
    final fecha = DateTime.tryParse(recordatorio['fecha_programada'] ?? '');
    final equipo = recordatorio['climas_equipos'] ?? {};
    final diasRestantes = fecha?.difference(DateTime.now()).inDays ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: diasRestantes <= 7 ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${fecha?.day ?? '--'}',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  _getMesCorto(fecha?.month ?? 1),
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mantenimiento Preventivo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''} - ${equipo['ubicacion'] ?? ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                Text(
                  diasRestantes == 0 ? '¡Hoy!' : 'En $diasRestantes días',
                  style: TextStyle(
                    color: diasRestantes <= 3 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _agendarMantenimiento(recordatorio),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Agendar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMisEquipos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mis Equipos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {/* Ver todos */},
              child: const Text('Ver todos', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_equipos.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.ac_unit, size: 50, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 10),
                  Text(
                    'Sin equipos registrados',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _equipos.length,
              itemBuilder: (context, index) => _buildEquipoCard(_equipos[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final estado = equipo['estado'] ?? 'activo';
    final estadoColor = estado == 'activo' 
        ? const Color(0xFF10B981) 
        : estado == 'requiere_servicio'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ac_unit, color: estadoColor, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estado == 'activo' ? '✓' : estado == 'requiere_servicio' ? '!' : '✕',
                  style: TextStyle(color: estadoColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${equipo['marca'] ?? 'Sin marca'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            equipo['modelo'] ?? 'Sin modelo',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            maxLines: 1,
          ),
          Text(
            equipo['ubicacion'] ?? 'Sin ubicación',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogoEquipos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Catalogo equipos disponibles',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _mostrarCatalogoEquipos(),
              child: const Text('Ver todo', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _catalogoEquipos.length,
            itemBuilder: (context, index) => _buildCatalogoCard(_catalogoEquipos[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogoCard(Map<String, dynamic> equipo) {
    final imagenUrl = (equipo['imagen_url'] ?? '').toString();
    final precio = (equipo['precio_venta'] ?? equipo['precio'] ?? 0).toDouble();
    final stock = equipo['stock'] ?? 0;

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imagenUrl.isNotEmpty
                ? Image.network(
                    imagenUrl,
                    height: 70,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 70,
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const Icon(Icons.ac_unit, color: Colors.white54),
                    ),
                  )
                : Container(
                    height: 70,
                    color: Colors.white10,
                    alignment: Alignment.center,
                    child: const Icon(Icons.ac_unit, color: Colors.white54),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            equipo['nombre'] ?? 'Equipo',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            maxLines: 1,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currencyFormat.format(precio),
                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                'Stock $stock',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudesQr() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Solicitudes QR',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _mostrarSolicitudesQr(),
              child: const Text('Ver todo', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._solicitudesQr.take(3).map((s) => _buildSolicitudQrCard(s)),
      ],
    );
  }

  Widget _buildSolicitudQrCard(Map<String, dynamic> solicitud) {
    final estado = (solicitud['estado'] ?? 'nueva').toString();
    final tipo = (solicitud['tipo_servicio'] ?? 'cotizacion').toString();
    final fecha = DateTime.tryParse(solicitud['created_at'] ?? '');
    final estadoColor = _getEstadoQrColor(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.qr_code_2, color: estadoColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicio ${tipo.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'Fecha no disponible',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getEstadoQrLabel(estado),
              style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudesPendientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis Solicitudes Pendientes',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._solicitudesPendientes.map((s) => _buildSolicitudCard(s)),
      ],
    );
  }

  Widget _buildSolicitudCard(Map<String, dynamic> solicitud) {
    final estado = solicitud['estado'] ?? 'nueva';
    final estadoColor = estado == 'nueva' ? const Color(0xFF3B82F6) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              estado == 'nueva' ? Icons.schedule : Icons.visibility,
              color: estadoColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitud['tipo_solicitud']?.toString().toUpperCase() ?? 'SERVICIO',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  solicitud['descripcion'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              estado == 'nueva' ? 'Enviada' : 'En Revisión',
              style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiciosRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Servicios Recientes',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _verHistorial(),
              child: const Text('Ver historial', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_serviciosRecientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.build_circle_outlined, size: 50, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 10),
                  Text(
                    'Sin servicios registrados',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          )
        else
          ..._serviciosRecientes.map((s) => _buildServicioCard(s)),
      ],
    );
  }

  Widget _buildServicioCard(Map<String, dynamic> servicio) {
    final estado = servicio['estado'] ?? 'pendiente';
    final estadoColor = _getEstadoColor(estado);
    final tecnico = servicio['climas_tecnicos'] ?? {};
    final fecha = DateTime.tryParse(servicio['fecha_programada'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      servicio['tipo_servicio']?.toString().toUpperCase() ?? '',
                      style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    servicio['folio'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getEstadoLabel(estado),
                  style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : '--',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
          if (tecnico['nombre'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  'Técnico: ${tecnico['nombre']}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ],
          if (servicio['total'] != null && (servicio['total'] as num) > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  'Total: ${_currencyFormat.format(servicio['total'])}',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          // Calificación si ya está completado
          if (estado == 'completada') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (servicio['calificacion'] != null)
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < (servicio['calificacion'] ?? 0) ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    )),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _calificarServicio(servicio),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Calificar servicio'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGarantias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Garantías Activas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _verGarantias(),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFF00D9FF))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._garantiasActivas.take(2).map((g) => _buildGarantiaCard(g)),
      ],
    );
  }

  Widget _buildGarantiaCard(Map<String, dynamic> garantia) {
    final fechaFin = DateTime.tryParse(garantia['fecha_fin'] ?? '');
    final diasRestantes = fechaFin?.difference(DateTime.now()).inDays ?? 0;
    final equipo = garantia['climas_equipos'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: diasRestantes <= 30 
              ? const Color(0xFFF59E0B).withOpacity(0.5) 
              : const Color(0xFF10B981).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  garantia['tipo_garantia']?.toString().toUpperCase() ?? 'GARANTÍA',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                Text(
                  diasRestantes > 0 
                      ? 'Vence en $diasRestantes días'
                      : '¡Vencida!',
                  style: TextStyle(
                    color: diasRestantes <= 30 ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFF59E0B);
      case 'asignada': return const Color(0xFF3B82F6);
      case 'en_proceso': return const Color(0xFF8B5CF6);
      case 'completada': return const Color(0xFF10B981);
      case 'cancelada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  Color _getEstadoQrColor(String estado) {
    switch (estado) {
      case 'nueva': return const Color(0xFF3B82F6);
      case 'revisando': return const Color(0xFFF59E0B);
      case 'contactado': return const Color(0xFF8B5CF6);
      case 'agendado': return const Color(0xFF00D9FF);
      case 'aprobado': return const Color(0xFF10B981);
      case 'rechazado': return const Color(0xFFEF4444);
      case 'convertido': return const Color(0xFF22C55E);
      default: return Colors.grey;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'asignada': return 'Asignada';
      case 'en_proceso': return 'En Proceso';
      case 'completada': return 'Completada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  String _getEstadoQrLabel(String estado) {
    switch (estado) {
      case 'nueva': return 'Nueva';
      case 'revisando': return 'Revisando';
      case 'contactado': return 'Contactado';
      case 'agendado': return 'Agendado';
      case 'aprobado': return 'Aprobado';
      case 'rechazado': return 'Rechazado';
      case 'convertido': return 'Convertido';
      default: return estado;
    }
  }

  String _getMesCorto(int mes) {
    const meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return meses[mes];
  }

  void _nuevaSolicitud() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NuevaSolicitudSheet(
        clienteId: _clienteId,
        equipos: _equipos,
        onCreada: _cargarDatos,
      ),
    );
  }

  void _abrirChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat próximamente...'), backgroundColor: Color(0xFF3B82F6)),
    );
  }

  void _verFacturas() {
    Navigator.pushNamed(context, AppRoutes.climasClienteFacturas, arguments: _clienteId);
  }

  void _verGarantias() {
    Navigator.pushNamed(context, AppRoutes.climasClienteGarantias, arguments: _clienteId);
  }

  void _verHistorial() {
    Navigator.pushNamed(context, AppRoutes.climasClienteHistorial, arguments: _clienteId);
  }

  Future<void> _mostrarCotizadorRapido() async {
    final negocioId = _negocioId;
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero configura un negocio activo')),
      );
      return;
    }

    List<Map<String, dynamic>> precios = [];
    try {
      final res = await AppSupabase.client
          .from('climas_precios_servicio')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('precio_base');
      precios = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando precios: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (precios.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay precios configurados para cotizar.')),
        );
      }
      return;
    }

    if (!mounted) return;

    String? seleccionadoId = precios.first['id']?.toString();
    final cantidadCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final seleccionado = precios.firstWhere(
            (p) => p['id']?.toString() == seleccionadoId,
            orElse: () => precios.first,
          );
          final precioBase = (seleccionado['precio_base'] ?? 0).toDouble();

          double calcularTotal() {
            final qty = int.tryParse(cantidadCtrl.text) ?? 1;
            return precioBase * qty;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cotizador rapido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: seleccionadoId,
                  decoration: _inputDecoration('Servicio'),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: precios.map<DropdownMenuItem<String>>((p) {
                    final id = p['id']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('${p['nombre']} - \$${(p['precio_base'] ?? 0)}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setModalState(() {
                      seleccionadoId = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Cantidad'),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total estimado', style: TextStyle(color: Colors.white70)),
                      Text(
                        '\$${calcularTotal().toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.climasCotizaciones),
                    icon: const Icon(Icons.request_quote),
                    label: const Text('Ir a cotizaciones'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void _mostrarSolicitudesQr() {
    if (_solicitudesQr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay solicitudes QR registradas.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _solicitudesQr.length,
          itemBuilder: (context, index) => _buildSolicitudQrCard(_solicitudesQr[index]),
        ),
      ),
    );
  }

  void _mostrarCatalogoEquipos() {
    if (_catalogoEquipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay equipos disponibles en el catalogo.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _catalogoEquipos.length,
          itemBuilder: (context, index) => _buildCatalogoListItem(_catalogoEquipos[index]),
        ),
      ),
    );
  }

  Widget _buildCatalogoListItem(Map<String, dynamic> equipo) {
    final imagenUrl = (equipo['imagen_url'] ?? '').toString();
    final precio = (equipo['precio_venta'] ?? equipo['precio'] ?? 0).toDouble();
    final stock = equipo['stock'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imagenUrl.isNotEmpty
                ? Image.network(
                    imagenUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const Icon(Icons.ac_unit, color: Colors.white54),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.white10,
                    alignment: Alignment.center,
                    child: const Icon(Icons.ac_unit, color: Colors.white54),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipo['nombre'] ?? 'Equipo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${equipo['marca'] ?? ''} ${equipo['modelo'] ?? ''}'.trim(),
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  maxLines: 1,
                ),
                Text(
                  'Stock $stock',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(precio),
            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      filled: true,
      fillColor: const Color(0xFF16213E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D9FF)),
      ),
    );
  }

  void _agendarMantenimiento(Map<String, dynamic> recordatorio) {
    // Crear solicitud automática
    _nuevaSolicitud();
  }

  void _calificarServicio(Map<String, dynamic> servicio) async {
    int? calificacion = await showDialog<int>(
      context: context,
      builder: (context) => _CalificacionDialog(),
    );
    
    if (calificacion != null) {
      try {
        await AppSupabase.client
            .from('climas_ordenes_servicio')
            .update({
              'calificacion': calificacion,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', servicio['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Gracias por calificar!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _cargarDatos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// FORMULARIO NUEVA SOLICITUD
/// ═══════════════════════════════════════════════════════════════════════════════
class _NuevaSolicitudSheet extends StatefulWidget {
  final String clienteId;
  final List<Map<String, dynamic>> equipos;
  final VoidCallback onCreada;

  const _NuevaSolicitudSheet({
    required this.clienteId,
    required this.equipos,
    required this.onCreada,
  });

  @override
  State<_NuevaSolicitudSheet> createState() => _NuevaSolicitudSheetState();
}

class _NuevaSolicitudSheetState extends State<_NuevaSolicitudSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  
  String _tipoSolicitud = 'mantenimiento';
  String _urgencia = 'normal';
  String? _equipoSeleccionado;
  DateTime? _fechaDisponible;
  String _horario = 'todo_el_dia';
  bool _guardando = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.add_circle, color: Color(0xFF00D9FF)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nueva Solicitud de Servicio',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de solicitud
                    const Text('Tipo de Servicio', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChipTipo('Mantenimiento', 'mantenimiento', Icons.build),
                        _buildChipTipo('Reparación', 'reparacion', Icons.handyman),
                        _buildChipTipo('Emergencia', 'emergencia', Icons.warning),
                        _buildChipTipo('Cotización', 'cotizacion', Icons.request_quote),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Urgencia
                    const Text('Urgencia', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChipUrgencia('Normal', 'normal', Colors.green),
                        const SizedBox(width: 8),
                        _buildChipUrgencia('Urgente', 'urgente', Colors.orange),
                        const SizedBox(width: 8),
                        _buildChipUrgencia('Emergencia', 'emergencia', Colors.red),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Equipo (opcional)
                    if (widget.equipos.isNotEmpty) ...[
                      const Text('Equipo (opcional)', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: _equipoSeleccionado,
                        decoration: _inputDecoration('Seleccionar equipo'),
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Ninguno'),
                          ),
                          ...widget.equipos.map<DropdownMenuItem<String?>>(
                            (e) => DropdownMenuItem<String?>(
                              value: e['id']?.toString(),
                              child: Text('${e['marca']} ${e['modelo']} - ${e['ubicacion']}'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _equipoSeleccionado = v),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Descripción
                    const Text('Describe el problema o servicio *', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descripcionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: _inputDecoration('Ej: El aire no enfría bien, hace ruido...'),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Fecha disponible
                    const Text('¿Cuándo puedes recibir el servicio?', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _seleccionarFecha,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF00D9FF)),
                            const SizedBox(width: 12),
                            Text(
                              _fechaDisponible != null
                                  ? DateFormat('EEEE dd/MM/yyyy', 'es').format(_fechaDisponible!)
                                  : 'Seleccionar fecha',
                              style: TextStyle(
                                color: _fechaDisponible != null ? Colors.white : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Horario preferido
                    const Text('Horario preferido', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChipHorario('Mañana', 'manana', '8-12 hrs'),
                        const SizedBox(width: 8),
                        _buildChipHorario('Tarde', 'tarde', '12-18 hrs'),
                        const SizedBox(width: 8),
                        _buildChipHorario('Todo el día', 'todo_el_dia', ''),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Botón enviar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _enviarSolicitud,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Enviar Solicitud',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipTipo(String label, String value, IconData icon) {
    final selected = _tipoSolicitud == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.black : Colors.white70),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (v) => setState(() => _tipoSolicitud = value),
      selectedColor: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70),
    );
  }

  Widget _buildChipUrgencia(String label, String value, Color color) {
    final selected = _urgencia == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencia = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.3) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipHorario(String label, String value, String sub) {
    final selected = _horario == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _horario = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF00D9FF).withOpacity(0.2) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF00D9FF) : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF00D9FF) : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (sub.isNotEmpty)
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D9FF)),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF00D9FF)),
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) setState(() => _fechaDisponible = fecha);
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await AppSupabase.client.from('climas_solicitudes_cliente').insert({
        'cliente_id': widget.clienteId,
        'equipo_id': _equipoSeleccionado,
        'tipo_solicitud': _tipoSolicitud,
        'urgencia': _urgencia,
        'descripcion': _descripcionController.text.trim(),
        'disponibilidad_fecha': _fechaDisponible?.toIso8601String().split('T')[0],
        'disponibilidad_horario': _horario,
        'estado': 'nueva',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onCreada();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud enviada. Te contactaremos pronto.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// DIALOG CALIFICACIÓN
/// ═══════════════════════════════════════════════════════════════════════════════
class _CalificacionDialog extends StatefulWidget {
  @override
  State<_CalificacionDialog> createState() => _CalificacionDialogState();
}

class _CalificacionDialogState extends State<_CalificacionDialog> {
  int _estrellas = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('Califica el servicio', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¿Qué tan satisfecho quedaste con el servicio?',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _estrellas = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _estrellas ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF59E0B),
                  size: 40,
                ),
              ),
            )),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _estrellas > 0 ? () => Navigator.pop(context, _estrellas) : null,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

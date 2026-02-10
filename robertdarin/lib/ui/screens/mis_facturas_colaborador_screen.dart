// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/facturacion_service.dart';
import '../../data/models/facturacion_models.dart';
import '../navigation/app_routes.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA MIS FACTURAS (PARA CONTADOR/FACTURADOR)
// Lista de facturas emitidas por este colaborador
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class MisFacturasColaboradorScreen extends StatefulWidget {
  const MisFacturasColaboradorScreen({super.key});
  
  @override
  State<MisFacturasColaboradorScreen> createState() => _MisFacturasColaboradorScreenState();
}

class _MisFacturasColaboradorScreenState extends State<MisFacturasColaboradorScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _facturas = [];
  late TabController _tabController;
  final FacturacionService _factService = FacturacionService();
  final Map<String, FacturacionEmisorModel> _emisorCache = {};
  
  // Filtros
  String _filtroEstado = 'todos';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  
  // Stats
  int _totalFacturas = 0;
  double _totalFacturado = 0;
  int _facturasEsteMes = 0;

  final _moneyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
    _cargarFacturas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      switch (index) {
        case 0: _filtroEstado = 'todos'; break;
        case 1: _filtroEstado = 'timbrada'; break;
        case 2: _filtroEstado = 'borrador'; break;
        case 3: _filtroEstado = 'cancelada'; break;
      }
    });
  }

  Future<void> _cargarFacturas() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Buscar el colaborador actual
      final colabRes = await AppSupabase.client
          .from('colaboradores')
          .select('id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (colabRes == null) {
        // No es colaborador, cargar todas las facturas del usuario
        await _cargarFacturasUsuario(user.id);
      } else {
        // Es colaborador, cargar sus facturas
        await _cargarFacturasColaborador(colabRes['id']);
      }
    } catch (e) {
      debugPrint('Error al cargar facturas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarFacturasColaborador(String colaboradorId) async {
    try {
      var query = AppSupabase.client
          .from('facturas')
          .select('*, clientes(nombre)')
          .eq('creado_por_colaborador_id', colaboradorId);

      final res = await query.order('created_at', ascending: false);
      
      _procesarFacturas(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarFacturasUsuario(String userId) async {
    try {
      final res = await AppSupabase.client
          .from('facturas')
          .select('*, clientes(nombre)')
          .order('created_at', ascending: false);
      
      _procesarFacturas(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procesarFacturas(List<Map<String, dynamic>> facturas) {
    _facturas = facturas;
    
    _totalFacturas = facturas.length;
    _totalFacturado = 0;
    _facturasEsteMes = 0;
    
    final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
    
    for (var f in facturas) {
      if (f['estado'] == 'timbrada') {
        _totalFacturado += (f['total'] as num?)?.toDouble() ?? 0;
      }
      final fecha = DateTime.tryParse(f['created_at'] ?? '');
      if (fecha != null && fecha.isAfter(inicioMes)) {
        _facturasEsteMes++;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _facturasFiltradas {
    return _facturas.where((f) {
      // Filtro por estado
      if (_filtroEstado != 'todos' && f['estado'] != _filtroEstado) {
        return false;
      }
      
      // Filtro por fecha
      if (_fechaInicio != null || _fechaFin != null) {
        final fecha = DateTime.tryParse(f['created_at'] ?? '');
        if (fecha == null) return false;
        if (_fechaInicio != null && fecha.isBefore(_fechaInicio!)) return false;
        if (_fechaFin != null && fecha.isAfter(_fechaFin!.add(const Duration(days: 1)))) return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🧾 Mis Facturas',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _mostrarFiltros,
          tooltip: 'Filtrar',
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.facturacionNueva).then((_) => _cargarFacturas()),
          tooltip: 'Nueva factura',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarFacturas,
              child: Column(
                children: [
                  _buildStats(),
                  _buildTabs(),
                  Expanded(child: _buildListaFacturas()),
                ],
              ),
            ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Facturas', '$_totalFacturas', Icons.receipt),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem('Total Facturado', _moneyFormat.format(_totalFacturado), Icons.attach_money),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem('Este Mes', '$_facturasEsteMes', Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF8B5CF6),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: 'Todas (${_facturas.length})'),
          Tab(text: 'Timbradas (${_facturas.where((f) => f['estado'] == 'timbrada').length})'),
          Tab(text: 'Borrador (${_facturas.where((f) => f['estado'] == 'borrador').length})'),
          Tab(text: 'Canceladas (${_facturas.where((f) => f['estado'] == 'cancelada').length})'),
        ],
      ),
    );
  }

  Widget _buildListaFacturas() {
    final facturas = _facturasFiltradas;
    
    if (facturas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              _filtroEstado == 'todos' 
                  ? 'No hay facturas registradas'
                  : 'No hay facturas con estado "$_filtroEstado"',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.facturacionNueva).then((_) => _cargarFacturas()),
              icon: const Icon(Icons.add),
              label: const Text('Crear Primera Factura'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: facturas.length,
      itemBuilder: (context, index) {
        final factura = facturas[index];
        return _buildFacturaCard(factura);
      },
    );
  }

  Widget _buildFacturaCard(Map<String, dynamic> factura) {
    final estado = factura['estado'] ?? 'borrador';
    final total = (factura['total'] as num?)?.toDouble() ?? 0;
    final fecha = DateTime.tryParse(factura['created_at'] ?? '');
    final clienteNombre = factura['clientes']?['nombre'] ?? 'Sin cliente';
    final folio = factura['folio'] ?? '-';
    final serie = factura['serie'] ?? '';
    
    Color estadoColor;
    IconData estadoIcon;
    
    switch (estado) {
      case 'timbrada':
        estadoColor = const Color(0xFF10B981);
        estadoIcon = Icons.verified;
        break;
      case 'borrador':
        estadoColor = const Color(0xFFF59E0B);
        estadoIcon = Icons.edit_note;
        break;
      case 'cancelada':
        estadoColor = const Color(0xFFEF4444);
        estadoIcon = Icons.cancel;
        break;
      case 'pendiente':
        estadoColor = const Color(0xFF3B82F6);
        estadoIcon = Icons.schedule;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.receipt;
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleFactura(factura),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: estado == 'timbrada' 
              ? Border.all(color: estadoColor.withOpacity(0.3))
              : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(estadoIcon, color: estadoColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              serie.isNotEmpty ? '$serie-$folio' : 'Folio: $folio',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: estadoColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estado.toUpperCase(),
                                style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clienteNombre,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (fecha != null)
                              Text(
                                _dateFormat.format(fecha),
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                            const Spacer(),
                            Text(
                              _moneyFormat.format(total),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Acciones rápidas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAccionRapida('Ver', Icons.visibility, () => _mostrarDetalleFactura(factura)),
                  if (estado == 'timbrada')
                    _buildAccionRapida('PDF', Icons.picture_as_pdf, () => _descargarPDF(factura)),
                  if (estado == 'timbrada')
                    _buildAccionRapida('XML', Icons.code, () => _descargarXML(factura)),
                  if (estado == 'borrador')
                    _buildAccionRapida('Editar', Icons.edit, () => _editarFactura(factura)),
                  if (estado == 'borrador')
                    _buildAccionRapida('Timbrar', Icons.verified, () => _timbrarFactura(factura)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionRapida(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar por Fecha',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _fechaInicio ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (fecha != null) {
                          setSheetState(() => _fechaInicio = fecha);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Desde', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              _fechaInicio != null ? _dateFormat.format(_fechaInicio!) : 'Seleccionar',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _fechaFin ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (fecha != null) {
                          setSheetState(() => _fechaFin = fecha);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hasta', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              _fechaFin != null ? _dateFormat.format(_fechaFin!) : 'Seleccionar',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _fechaInicio = null;
                          _fechaFin = null;
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Aplicar'),
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

  void _mostrarDetalleFactura(Map<String, dynamic> factura) {
    final estado = factura['estado'] ?? 'borrador';
    final total = (factura['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (factura['subtotal'] as num?)?.toDouble() ?? 0;
    final iva = (factura['iva'] as num?)?.toDouble() ?? 0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
              
              Text(
                'Factura ${factura['serie'] ?? ''}-${factura['folio'] ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getColorEstado(estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estado.toUpperCase(),
                  style: TextStyle(color: _getColorEstado(estado), fontWeight: FontWeight.w600),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildDetalleRow('Cliente', factura['clientes']?['nombre'] ?? '-'),
              _buildDetalleRow('RFC Receptor', factura['rfc_receptor'] ?? '-'),
              _buildDetalleRow('Uso CFDI', factura['uso_cfdi'] ?? '-'),
              _buildDetalleRow('Forma de Pago', factura['forma_pago'] ?? '-'),
              _buildDetalleRow('Método de Pago', factura['metodo_pago'] ?? '-'),
              
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              
              _buildDetalleRow('Subtotal', _moneyFormat.format(subtotal)),
              _buildDetalleRow('IVA (16%)', _moneyFormat.format(iva)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(_moneyFormat.format(total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
              
              if (estado == 'timbrada') ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _descargarPDF(factura),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Descargar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _descargarXML(factura),
                        icon: const Icon(Icons.code),
                        label: const Text('Descargar XML'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'timbrada': return const Color(0xFF10B981);
      case 'borrador': return const Color(0xFFF59E0B);
      case 'cancelada': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  Future<FacturacionEmisorModel?> _obtenerEmisor(String negocioId) async {
    if (_emisorCache.containsKey(negocioId)) return _emisorCache[negocioId];
    final emisor = await _factService.obtenerEmisor(negocioId);
    if (emisor != null) _emisorCache[negocioId] = emisor;
    return emisor;
  }

  Future<File> _guardarArchivoTemporal(String nombre, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _descargarPDF(Map<String, dynamic> factura) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando PDF...'), backgroundColor: Color(0xFF3B82F6)),
    );
    final facturaId = factura['id']?.toString();
    final negocioId = factura['negocio_id']?.toString();
    if (facturaId == null || negocioId == null) return;

    final emisor = await _obtenerEmisor(negocioId);
    if (emisor?.apiKey == null || emisor!.apiKey!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura el API Key de facturación'), backgroundColor: Colors.red),
      );
      return;
    }

    final base64Pdf = await _factService.descargarPdf(
      facturaId,
      emisor.apiKey!,
      emisor.modoPruebas,
    );
    if (!mounted) return;

    if (base64Pdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el PDF'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final bytes = base64Decode(base64Pdf);
      final nombre = 'factura_${factura['serie'] ?? 'A'}-${(factura['folio'] ?? '000000').toString()}.pdf';
      final file = await _guardarArchivoTemporal(nombre, bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Factura ${nombre.replaceAll('.pdf', '')}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _descargarXML(Map<String, dynamic> factura) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando XML...'), backgroundColor: Color(0xFF3B82F6)),
    );
    final facturaId = factura['id']?.toString();
    if (facturaId == null) return;

    final xml = await _factService.descargarXml(facturaId);
    if (!mounted) return;

    if (xml == null || xml.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró XML'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final nombre = 'factura_${factura['serie'] ?? 'A'}-${(factura['folio'] ?? '000000').toString()}.xml';
      final file = await _guardarArchivoTemporal(nombre, xml.codeUnits);
      await Share.shareXFiles([XFile(file.path)], text: 'XML ${nombre.replaceAll('.xml', '')}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar XML: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _editarFactura(Map<String, dynamic> factura) {
    Navigator.pushNamed(context, AppRoutes.facturacionNueva, arguments: factura).then((_) => _cargarFacturas());
  }

  void _timbrarFactura(Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Timbrar Factura', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas timbrar esta factura? Una vez timbrada no se puede modificar.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enviando a timbrar...'), backgroundColor: Color(0xFF8B5CF6)),
              );
              final facturaId = factura['id']?.toString();
              final negocioId = factura['negocio_id']?.toString();
              if (facturaId == null || negocioId == null) return;

              final emisor = await _obtenerEmisor(negocioId);
              if (emisor?.apiKey == null || emisor!.apiKey!.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configura el API Key de facturación'), backgroundColor: Colors.red),
                );
                return;
              }

              final resultado = await _factService.timbrarConFacturApi(
                facturaId: facturaId,
                apiKey: emisor.apiKey!,
                modoPruebas: emisor.modoPruebas,
              );

              if (!mounted) return;
              if (resultado['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Factura timbrada'), backgroundColor: Colors.green),
                );
                await _cargarFacturas();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(resultado['error'] ?? 'Error al timbrar'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Timbrar'),
          ),
        ],
      ),
    );
  }
}

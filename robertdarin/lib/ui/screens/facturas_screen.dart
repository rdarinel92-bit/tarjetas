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

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE FACTURAS
// Robert Darin Platform v10.13
// ═══════════════════════════════════════════════════════════════════════════════

class FacturasScreen extends StatefulWidget {
  final String? moduloOrigen;

  const FacturasScreen({super.key, this.moduloOrigen});

  @override
  State<FacturasScreen> createState() => _FacturasScreenState();
}

class _FacturasScreenState extends State<FacturasScreen> with SingleTickerProviderStateMixin {
  final _service = FacturacionService();
  
  late TabController _tabController;
  bool _isLoading = true;
  String? _negocioId;
  FacturacionEmisorModel? _emisor;
  
  List<FacturaModel> _facturas = [];
  List<FacturaModel> _facturasFiltradas = [];
  Map<String, dynamic> _estadisticas = {};
  
  final _searchController = TextEditingController();
  // ignore: unused_field
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _aplicarFiltros();
      }
    });
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Obtener negocio_id desde empleados (el id de usuarios ES el auth.uid)
      final empleado = await AppSupabase.client
          .from('empleados')
          .select('negocio_id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (empleado != null) {
        _negocioId = empleado['negocio_id'];
      } else {
        // Fallback: obtener primer negocio (superadmin)
        final negocio = await AppSupabase.client
            .from('negocios')
            .select('id')
            .limit(1)
            .maybeSingle();
        _negocioId = negocio?['id'];
      }

      if (_negocioId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Cargar emisor
      _emisor = await _service.obtenerEmisor(_negocioId!);

      // Cargar facturas
      _facturas = await _service.obtenerFacturas(
        negocioId: _negocioId!,
        moduloOrigen: widget.moduloOrigen,
      );

      // Cargar estad?sticas
      if (widget.moduloOrigen == null) {
        _estadisticas = await _service.obtenerEstadisticas(_negocioId!);
      } else {
        _estadisticas = _calcularEstadisticasFiltradas(_facturas);
      }

      _aplicarFiltros();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    final search = _searchController.text.toLowerCase();
    
    // Filtrar por tab
    String? estadoFiltro;
    switch (_tabController.index) {
      case 1: estadoFiltro = 'borrador'; break;
      case 2: estadoFiltro = 'timbrada'; break;
      case 3: estadoFiltro = 'enviada'; break;
      case 4: estadoFiltro = 'cancelada'; break;
    }

    _facturasFiltradas = _facturas.where((f) {
      // Filtro por estado
      if (estadoFiltro != null && f.estado != estadoFiltro) return false;
      
      // Filtro por búsqueda
      if (search.isNotEmpty) {
        final matchRfc = f.clienteRfc?.toLowerCase().contains(search) ?? false;
        final matchRazon = f.clienteRazonSocial?.toLowerCase().contains(search) ?? false;
        final matchFolio = f.numeroFactura.toLowerCase().contains(search);
        final matchUuid = f.uuidFiscal?.toLowerCase().contains(search) ?? false;
        
        if (!matchRfc && !matchRazon && !matchFolio && !matchUuid) return false;
      }
      
      return true;
    }).toList();

    setState(() {});
  }

  Map<String, dynamic> _calcularEstadisticasFiltradas(List<FacturaModel> facturas) {
    final now = DateTime.now();
    final total = facturas.length;
    final timbradas = facturas.where((f) => f.estado == 'timbrada').length;
    final canceladas = facturas.where((f) => f.estado == 'cancelada').length;
    final montoTotal = facturas.fold<double>(0, (sum, f) => sum + f.total);

    return {
      'mes': now.month,
      'anio': now.year,
      'total_facturas': total,
      'timbradas': timbradas,
      'canceladas': canceladas,
      'monto_total': montoTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Facturación',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, '/facturacion/config')
              .then((_) => _cargarDatos()),
          tooltip: 'Configuración',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emisor == null
              ? _buildNoConfigured()
              : _buildContent(),
      floatingActionButton: _emisor != null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/facturacion/nueva')
                  .then((_) => _cargarDatos()),
              backgroundColor: const Color(0xFF1E40AF),
              icon: const Icon(Icons.add),
              label: const Text('Nueva Factura'),
            )
          : null,
    );
  }

  Widget _buildNoConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 80,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Facturación no configurada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Configura tus datos fiscales y el proveedor de facturación para comenzar a emitir CFDI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/facturacion/config')
                  .then((_) => _cargarDatos()),
              icon: const Icon(Icons.settings),
              label: const Text('Configurar Facturación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Estadísticas
        _buildEstadisticas(),
        
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _aplicarFiltros(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por RFC, razón social, folio o UUID...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _aplicarFiltros();
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.cyan,
            labelColor: Colors.cyan,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Todas (${_facturas.length})'),
              Tab(text: 'Borradores (${_facturas.where((f) => f.estado == 'borrador').length})'),
              Tab(text: 'Timbradas (${_facturas.where((f) => f.estado == 'timbrada').length})'),
              Tab(text: 'Enviadas (${_facturas.where((f) => f.estado == 'enviada').length})'),
              Tab(text: 'Canceladas (${_facturas.where((f) => f.estado == 'cancelada').length})'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Lista de facturas
        Expanded(
          child: _facturasFiltradas.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _facturasFiltradas.length,
                  itemBuilder: (context, index) {
                    return _buildFacturaCard(_facturasFiltradas[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEstadisticas() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Resumen ${_getMonthName(_estadisticas['mes'] ?? DateTime.now().month)} ${_estadisticas['anio'] ?? DateTime.now().year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                '${_estadisticas['total_facturas'] ?? 0}',
                Icons.receipt,
              ),
              _buildStatItem(
                'Timbradas',
                '${_estadisticas['timbradas'] ?? 0}',
                Icons.check_circle,
                color: Colors.green,
              ),
              _buildStatItem(
                'Canceladas',
                '${_estadisticas['canceladas'] ?? 0}',
                Icons.cancel,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.attach_money, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Total facturado: \$${NumberFormat('#,##0.00', 'es_MX').format(_estadisticas['monto_total'] ?? 0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay facturas',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea tu primera factura',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFacturaCard(FacturaModel factura) {
    final formatter = NumberFormat('#,##0.00', 'es_MX');
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: factura.estadoColor.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalleFactura(factura),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icono y estado
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: factura.estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        factura.estaTimbrada ? Icons.verified : Icons.description,
                        color: factura.estadoColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Info principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                factura.numeroFactura,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: factura.estadoColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  factura.estadoDisplay,
                                  style: TextStyle(
                                    color: factura.estadoColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            factura.clienteRazonSocial ?? 'Sin cliente',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (factura.clienteRfc != null)
                            Text(
                              factura.clienteRfc!,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    
                    // Total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${formatter.format(factura.total)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          factura.moneda,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Fecha y UUID
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey.withOpacity(0.7), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      dateFormatter.format(factura.fechaEmision),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (factura.uuidFiscal != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.fingerprint, color: Colors.grey.withOpacity(0.7), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          factura.uuidFiscal!,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Módulo de origen
                if (factura.moduloOrigen != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📦 ${_getModuloName(factura.moduloOrigen!)}',
                      style: const TextStyle(color: Colors.cyan, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleFactura(FacturaModel factura) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _buildDetalleFactura(factura, scrollController),
      ),
    );
  }

  Widget _buildDetalleFactura(FacturaModel factura, ScrollController scrollController) {
    final formatter = NumberFormat('#,##0.00', 'es_MX');
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: factura.estadoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                factura.estaTimbrada ? Icons.verified : Icons.description,
                color: factura.estadoColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factura ${factura.numeroFactura}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: factura.estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      factura.estadoDisplay,
                      style: TextStyle(
                        color: factura.estadoColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Cliente
        _buildDetalleSection('Cliente', [
          _buildDetalleRow('Razón Social', factura.clienteRazonSocial ?? '-'),
          _buildDetalleRow('RFC', factura.clienteRfc ?? '-'),
          _buildDetalleRow('Email', factura.clienteEmail ?? '-'),
        ]),

        // Montos
        _buildDetalleSection('Montos', [
          _buildDetalleRow('Subtotal', '\$${formatter.format(factura.subtotal)}'),
          if (factura.descuento > 0)
            _buildDetalleRow('Descuento', '-\$${formatter.format(factura.descuento)}'),
          _buildDetalleRow('IVA', '\$${formatter.format(factura.iva)}'),
          _buildDetalleRow('Total', '\$${formatter.format(factura.total)}', highlight: true),
        ]),

        // Datos fiscales
        _buildDetalleSection('Datos Fiscales', [
          _buildDetalleRow('Tipo', factura.tipoComprobanteDisplay),
          _buildDetalleRow('Uso CFDI', factura.usoCfdi),
          _buildDetalleRow('Método de Pago', factura.metodoPago),
          _buildDetalleRow('Forma de Pago', factura.formaPago),
          _buildDetalleRow('Moneda', factura.moneda),
        ]),

        // UUID y fechas
        if (factura.uuidFiscal != null)
          _buildDetalleSection('Timbrado', [
            _buildDetalleRow('UUID Fiscal', factura.uuidFiscal!),
            _buildDetalleRow('Fecha Timbrado', 
              factura.fechaTimbrado != null 
                ? dateFormatter.format(factura.fechaTimbrado!)
                : '-'),
          ]),

        const SizedBox(height: 24),

        // Acciones
        if (factura.estaTimbrada && !factura.estaCancelada) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _descargarPdf(factura),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _descargarXml(factura),
                  icon: const Icon(Icons.code),
                  label: const Text('XML'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _enviarEmail(factura),
                  icon: const Icon(Icons.email),
                  label: const Text('Enviar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _cancelarFactura(factura),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    foregroundColor: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ] else if (factura.puedeModificarse) ...[
          ElevatedButton.icon(
            onPressed: () => _timbrarFactura(factura),
            icon: const Icon(Icons.verified),
            label: const Text('Timbrar Factura'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetalleSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
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
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? Colors.green : Colors.white,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 16 : 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<File> _guardarArchivoTemporal(String nombre, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<({String motivo, String? uuid})?> _solicitarMotivoCancelacion() async {
    const motivos = <String, String>{
      '01': 'Comprobante emitido con errores con relación',
      '02': 'Comprobante emitido con errores sin relación',
      '03': 'No se llevó a cabo la operación',
      '04': 'Operación nominativa relacionada en factura global',
    };
    String motivo = '01';
    final uuidController = TextEditingController();
    String? errorText;

    final result = await showDialog<({String motivo, String? uuid})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Cancelar factura', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: motivo,
                dropdownColor: const Color(0xFF1A1A2E),
                items: motivos.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            '${e.key} - ${e.value}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    motivo = value;
                    errorText = null;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uuidController,
                enabled: motivo == '01',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'UUID sustitución (si aplica)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  errorText: errorText,
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
                if (motivo == '01' && uuidController.text.trim().isEmpty) {
                  setState(() => errorText = 'Requerido para motivo 01');
                  return;
                }
                Navigator.pop(context, (motivo: motivo, uuid: uuidController.text.trim().isEmpty ? null : uuidController.text.trim()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  // Acciones
  Future<void> _timbrarFactura(FacturaModel factura) async {
    Navigator.pop(context);
    if (_emisor?.apiKey == null || _emisor!.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key de facturación')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Timbrar factura', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas timbrar esta factura? Una vez timbrada no se puede modificar.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Timbrar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timbrando factura...'), backgroundColor: Color(0xFF1E40AF)),
    );

    final resultado = await _service.timbrarConFacturApi(
      facturaId: factura.id,
      apiKey: _emisor!.apiKey!,
      modoPruebas: _emisor!.modoPruebas,
    );

    if (!mounted) return;
    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura timbrada'), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado['error'] ?? 'Error al timbrar'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _descargarPdf(FacturaModel factura) async {
    if (_emisor?.apiKey == null || _emisor!.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key de facturación')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando PDF...')),
    );

    final base64Pdf = await _service.descargarPdf(
      factura.id,
      _emisor!.apiKey!,
      _emisor!.modoPruebas,
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
      final file = await _guardarArchivoTemporal('factura_${factura.numeroFactura}.pdf', bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Factura ${factura.numeroFactura}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _descargarXml(FacturaModel factura) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando XML...')),
    );

    final xml = await _service.descargarXml(factura.id);
    if (!mounted) return;

    if (xml == null || xml.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró XML para esta factura'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final file = await _guardarArchivoTemporal('factura_${factura.numeroFactura}.xml', xml.codeUnits);
      await Share.shareXFiles([XFile(file.path)], text: 'XML Factura ${factura.numeroFactura}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar XML: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _enviarEmail(FacturaModel factura) async {
    if (_emisor?.apiKey == null || _emisor!.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key de facturación')),
      );
      return;
    }

    final controller = TextEditingController(text: factura.clienteEmail ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Enviar factura', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enviando factura...')),
    );

    final ok = await _service.enviarPorEmail(
      factura.id,
      email,
      _emisor!.apiKey!,
      _emisor!.modoPruebas,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura enviada a $email'), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la factura'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelarFactura(FacturaModel factura) async {
    Navigator.pop(context);
    if (_emisor?.apiKey == null || _emisor!.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key de facturación')),
      );
      return;
    }

    final datos = await _solicitarMotivoCancelacion();
    if (datos == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancelando factura...')),
    );

    final result = await _service.cancelarFactura(
      facturaId: factura.id,
      apiKey: _emisor!.apiKey!,
      motivo: datos.motivo,
      uuidSustitucion: datos.uuid,
      modoPruebas: _emisor!.modoPruebas,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura cancelada'), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Error al cancelar'), backgroundColor: Colors.red),
      );
    }
  }

  String _getMonthName(int month) {
    const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month];
  }

  String _getModuloName(String modulo) {
    switch (modulo) {
      case 'fintech': return 'Fintech';
      case 'climas': return 'Climas';
      case 'ventas': return 'Ventas';
      case 'purificadora': return 'Purificadora';
      case 'nice': return 'NICE';
      default: return modulo;
    }
  }
}

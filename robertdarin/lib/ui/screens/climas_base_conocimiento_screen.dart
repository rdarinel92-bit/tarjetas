// ═══════════════════════════════════════════════════════════════════════════════
// CLIMAS BASE DE CONOCIMIENTOS - V10.55
// Sistema de manuales, videos, soluciones por modelo de equipo
// Para Técnicos, Empleados y Clientes (con permisos diferenciados)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class ClimasBaseConocimientoScreen extends StatefulWidget {
  final String? negocioId;
  final String? rolUsuario; // 'tecnico', 'cliente', 'admin'
  
  const ClimasBaseConocimientoScreen({super.key, this.negocioId, this.rolUsuario});

  @override
  State<ClimasBaseConocimientoScreen> createState() => _ClimasBaseConocimientoScreenState();
}

class _ClimasBaseConocimientoScreenState extends State<ClimasBaseConocimientoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String _busqueda = '';
  String? _categoriaSeleccionada;
  String? _marcaSeleccionada;
  
  List<Map<String, dynamic>> _articulos = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _manuales = [];
  List<Map<String, dynamic>> _soluciones = [];
  List<String> _categorias = [];
  List<String> _marcas = [];
  
  // Artículos populares/recientes
  List<Map<String, dynamic>> _populares = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar artículos
      var articulosQuery = AppSupabase.client
          .from('climas_base_conocimiento')
          .select()
          .eq('tipo', 'articulo')
          .eq('activo', true);
      
      if (widget.negocioId != null) {
        articulosQuery = articulosQuery.or('negocio_id.eq.${widget.negocioId},negocio_id.is.null');
      }
      
      // Filtrar por rol
      if (widget.rolUsuario == 'cliente') {
        articulosQuery = articulosQuery.eq('visible_cliente', true);
      }
      
      final articulosRes = await articulosQuery.order('vistas', ascending: false);
      _articulos = List<Map<String, dynamic>>.from(articulosRes);
      
      // Cargar videos
      var videosQuery = AppSupabase.client
          .from('climas_base_conocimiento')
          .select()
          .eq('tipo', 'video')
          .eq('activo', true);
      
      if (widget.negocioId != null) {
        videosQuery = videosQuery.or('negocio_id.eq.${widget.negocioId},negocio_id.is.null');
      }
      
      if (widget.rolUsuario == 'cliente') {
        videosQuery = videosQuery.eq('visible_cliente', true);
      }
      
      final videosRes = await videosQuery.order('vistas', ascending: false);
      _videos = List<Map<String, dynamic>>.from(videosRes);
      
      // Cargar manuales
      var manualesQuery = AppSupabase.client
          .from('climas_base_conocimiento')
          .select()
          .eq('tipo', 'manual')
          .eq('activo', true);
      
      if (widget.negocioId != null) {
        manualesQuery = manualesQuery.or('negocio_id.eq.${widget.negocioId},negocio_id.is.null');
      }
      
      if (widget.rolUsuario == 'cliente') {
        manualesQuery = manualesQuery.eq('visible_cliente', true);
      }
      
      final manualesRes = await manualesQuery.order('titulo');
      _manuales = List<Map<String, dynamic>>.from(manualesRes);
      
      // Cargar soluciones
      var solucionesQuery = AppSupabase.client
          .from('climas_base_conocimiento')
          .select()
          .eq('tipo', 'solucion')
          .eq('activo', true);
      
      if (widget.negocioId != null) {
        solucionesQuery = solucionesQuery.or('negocio_id.eq.${widget.negocioId},negocio_id.is.null');
      }
      
      if (widget.rolUsuario == 'cliente') {
        solucionesQuery = solucionesQuery.eq('visible_cliente', true);
      }
      
      final solucionesRes = await solucionesQuery.order('vistas', ascending: false);
      _soluciones = List<Map<String, dynamic>>.from(solucionesRes);
      
      // Extraer categorías y marcas únicas
      final todos = [..._articulos, ..._videos, ..._manuales, ..._soluciones];
      _categorias = todos
          .map((a) => a['categoria']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      
      _marcas = todos
          .map((a) => a['marca']?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      
      // Top 5 más vistos
      _populares = todos
        ..sort((a, b) => (b['vistas'] as int? ?? 0).compareTo(a['vistas'] as int? ?? 0));
      _populares = _populares.take(5).toList();
      
    } catch (e) {
      debugPrint('Error cargando base de conocimiento: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> items) {
    return items.where((item) {
      // Filtro de búsqueda
      if (_busqueda.isNotEmpty) {
        final titulo = item['titulo']?.toString().toLowerCase() ?? '';
        final descripcion = item['descripcion']?.toString().toLowerCase() ?? '';
        final tags = item['tags']?.toString().toLowerCase() ?? '';
        final query = _busqueda.toLowerCase();
        
        if (!titulo.contains(query) && 
            !descripcion.contains(query) && 
            !tags.contains(query)) {
          return false;
        }
      }
      
      // Filtro de categoría
      if (_categoriaSeleccionada != null && _categoriaSeleccionada!.isNotEmpty) {
        if (item['categoria'] != _categoriaSeleccionada) return false;
      }
      
      // Filtro de marca
      if (_marcaSeleccionada != null && _marcaSeleccionada!.isNotEmpty) {
        if (item['marca'] != _marcaSeleccionada) return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Base de Conocimientos',
      actions: [
        if (widget.rolUsuario != 'cliente')
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _mostrarFormularioNuevo,
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
              children: [
                // Búsqueda y filtros
                _buildBarraBusqueda(),
                
                // Tabs
                Container(
                  color: const Color(0xFF0D0D14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.cyan,
                    labelColor: Colors.cyan,
                    unselectedLabelColor: Colors.white54,
                    isScrollable: true,
                    tabs: [
                      Tab(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.article, size: 18),
                            const SizedBox(width: 4),
                            Text('Artículos (${_filtrar(_articulos).length})'),
                          ],
                        ),
                      ),
                      Tab(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle, size: 18),
                            const SizedBox(width: 4),
                            Text('Videos (${_filtrar(_videos).length})'),
                          ],
                        ),
                      ),
                      Tab(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book, size: 18),
                            const SizedBox(width: 4),
                            Text('Manuales (${_filtrar(_manuales).length})'),
                          ],
                        ),
                      ),
                      Tab(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb, size: 18),
                            const SizedBox(width: 4),
                            Text('Soluciones (${_filtrar(_soluciones).length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaArticulos(_filtrar(_articulos)),
                      _buildListaVideos(_filtrar(_videos)),
                      _buildListaManuales(_filtrar(_manuales)),
                      _buildListaSoluciones(_filtrar(_soluciones)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0D0D14),
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _busqueda = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar artículos, videos, manuales...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Icon(Icons.search, color: Colors.cyan),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _busqueda = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Categoría
                _buildFiltroDropdown(
                  'Categoría',
                  _categoriaSeleccionada,
                  _categorias,
                  (value) => setState(() => _categoriaSeleccionada = value),
                ),
                const SizedBox(width: 8),
                
                // Marca
                _buildFiltroDropdown(
                  'Marca',
                  _marcaSeleccionada,
                  _marcas,
                  (value) => setState(() => _marcaSeleccionada = value),
                ),
                const SizedBox(width: 8),
                
                // Limpiar filtros
                if (_categoriaSeleccionada != null || _marcaSeleccionada != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _categoriaSeleccionada = null;
                        _marcaSeleccionada = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.clear, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Limpiar', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroDropdown(
    String label, 
    String? valor, 
    List<String> opciones,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: valor != null ? Colors.cyan.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          hint: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          dropdownColor: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
          style: const TextStyle(color: Colors.cyan, fontSize: 12),
          items: [
            DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
            ...opciones.map((o) => DropdownMenuItem(value: o, child: Text(o))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildListaArticulos(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState('No hay artículos');
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildArticuloCard(items[index]),
      ),
    );
  }

  Widget _buildArticuloCard(Map<String, dynamic> articulo) {
    return GestureDetector(
      onTap: () => _abrirArticulo(articulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        articulo['titulo'] ?? 'Sin título',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (articulo['marca'] != null || articulo['modelo'] != null)
                        Text(
                          '${articulo['marca'] ?? ''} ${articulo['modelo'] ?? ''}'.trim(),
                          style: const TextStyle(color: Colors.cyan, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                _buildVistas(articulo['vistas'] ?? 0),
              ],
            ),
            if (articulo['descripcion'] != null) ...[
              const SizedBox(height: 12),
              Text(
                articulo['descripcion'],
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (articulo['tags'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: (articulo['tags'] as String).split(',').take(5).map((tag) =>
                    _buildTag(tag.trim())).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListaVideos(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState('No hay videos');
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildVideoCard(items[index]),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () => _abrirVideo(video),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.black,
                image: video['thumbnail_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(video['thumbnail_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                    ),
                  ),
                  if (video['duracion'] != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video['duracion'],
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          video['titulo'] ?? 'Sin título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildVistas(video['vistas'] ?? 0),
                    ],
                  ),
                  if (video['marca'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${video['marca']} ${video['modelo'] ?? ''}'.trim(),
                        style: const TextStyle(color: Colors.cyan, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaManuales(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState('No hay manuales');
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildManualCard(items[index]),
      ),
    );
  }

  Widget _buildManualCard(Map<String, dynamic> manual) {
    return GestureDetector(
      onTap: () => _descargarManual(manual),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manual['titulo'] ?? 'Sin título',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      if (manual['marca'] != null)
                        Text(
                          '${manual['marca']} ${manual['modelo'] ?? ''}'.trim(),
                          style: const TextStyle(color: Colors.cyan, fontSize: 11),
                        ),
                      if (manual['tamanio'] != null) ...[
                        const Text(' • ', style: TextStyle(color: Colors.white30)),
                        Text(
                          manual['tamanio'],
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.download, color: Colors.cyan),
          ],
        ),
      ),
    );
  }

  Widget _buildListaSoluciones(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState('No hay soluciones');
    
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildSolucionCard(items[index]),
      ),
    );
  }

  Widget _buildSolucionCard(Map<String, dynamic> solucion) {
    final dificultad = solucion['dificultad'] ?? 'media';
    Color dificultadColor = dificultad == 'facil' ? Colors.green 
                          : dificultad == 'media' ? Colors.orange 
                          : Colors.red;
    
    return GestureDetector(
      onTap: () => _abrirSolucion(solucion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solucion['titulo'] ?? 'Sin título',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: dificultadColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dificultad.toUpperCase(),
                              style: TextStyle(
                                color: dificultadColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (solucion['tiempo_estimado'] != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.timer, size: 12, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 2),
                            Text(
                              solucion['tiempo_estimado'],
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildVistas(solucion['vistas'] ?? 0),
              ],
            ),
            
            // Problema
            if (solucion['problema'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '❌ Problema:',
                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      solucion['problema'],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            
            // Solución resumida
            if (solucion['solucion_resumen'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Solución:',
                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      solucion['solucion_resumen'],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ver solución completa →',
                  style: TextStyle(color: Colors.cyan.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistas(int vistas) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility, size: 12, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 4),
        Text(
          '$vistas',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: const TextStyle(color: Colors.cyan, fontSize: 10),
      ),
    );
  }

  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(mensaje, style: TextStyle(color: Colors.white.withOpacity(0.4))),
          if (_busqueda.isNotEmpty || _categoriaSeleccionada != null || _marcaSeleccionada != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Intenta con otros filtros',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _abrirArticulo(Map<String, dynamic> articulo) {
    _registrarVista(articulo['id']);
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => _DetalleArticuloPage(articulo: articulo),
    ));
  }

  void _abrirVideo(Map<String, dynamic> video) async {
    _registrarVista(video['id']);
    
    final url = video['url'] ?? video['video_url'];
    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _descargarManual(Map<String, dynamic> manual) async {
    _registrarVista(manual['id']);
    
    final url = manual['url'] ?? manual['archivo_url'];
    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _abrirSolucion(Map<String, dynamic> solucion) {
    _registrarVista(solucion['id']);
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => _DetalleSolucionPage(solucion: solucion),
    ));
  }

  Future<void> _registrarVista(String? id) async {
    if (id == null) return;
    try {
      // Incrementar contador de vistas
      await AppSupabase.client.rpc('incrementar_vistas_conocimiento', params: {'articulo_id': id});
    } catch (e) {
      debugPrint('Error registrando vista: $e');
    }
  }

  void _mostrarFormularioNuevo() {
    Navigator.pushNamed(context, '/climas/conocimiento/nuevo');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PÁGINA DE DETALLE - ARTÍCULO
// ═══════════════════════════════════════════════════════════════════════════════

class _DetalleArticuloPage extends StatelessWidget {
  final Map<String, dynamic> articulo;
  
  const _DetalleArticuloPage({required this.articulo});

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Artículo',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              articulo['titulo'] ?? 'Sin título',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Meta info
            Row(
              children: [
                if (articulo['marca'] != null)
                  _buildChip(articulo['marca'], Colors.cyan),
                if (articulo['modelo'] != null) ...[
                  const SizedBox(width: 8),
                  _buildChip(articulo['modelo'], Colors.purple),
                ],
                if (articulo['categoria'] != null) ...[
                  const SizedBox(width: 8),
                  _buildChip(articulo['categoria'], Colors.orange),
                ],
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Contenido
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                articulo['contenido'] ?? articulo['descripcion'] ?? 'Sin contenido',
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PÁGINA DE DETALLE - SOLUCIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class _DetalleSolucionPage extends StatelessWidget {
  final Map<String, dynamic> solucion;
  
  const _DetalleSolucionPage({required this.solucion});

  @override
  Widget build(BuildContext context) {
    final pasos = solucion['pasos'] as List<dynamic>? ?? [];
    
    return PremiumScaffold(
      title: 'Solución',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              solucion['titulo'] ?? 'Sin título',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Problema
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PROBLEMA',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    solucion['problema'] ?? 'Sin descripción',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Pasos de solución
            const Text(
              'PASOS PARA RESOLVER',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            
            if (pasos.isNotEmpty)
              ...pasos.asMap().entries.map((e) => _buildPaso(e.key + 1, e.value.toString()))
            else if (solucion['solucion_completa'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  solucion['solucion_completa'],
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Herramientas requeridas
            if (solucion['herramientas'] != null) ...[
              const Text(
                'HERRAMIENTAS NECESARIAS',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  solucion['herramientas'],
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaso(int numero, String texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$numero',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                texto,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';

class SucursalesScreen extends StatefulWidget {
  const SucursalesScreen({super.key});

  @override
  State<SucursalesScreen> createState() => _SucursalesScreenState();
}

class _SucursalesScreenState extends State<SucursalesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _todosNegocios = []; // Lista de todos los negocios
  Map<String, dynamic>? _negocioActual;
  bool _cargando = true;
  String _filtro = 'todas'; // todas, activas, inactivas

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Estadísticas
  int _totalClientes = 0;
  int _totalEmpleados = 0;
  double _metaTotal = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _cargarDatos();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      
      // Verificar si es superadmin (puede ver todos los negocios)
      bool esSuperadmin = false;
      if (userId != null) {
        final rolRes = await AppSupabase.client
            .from('usuarios_roles')
            .select('roles(nombre)')
            .eq('usuario_id', userId);
        esSuperadmin = rolRes.any((r) => r['roles']?['nombre'] == 'superadmin');
      }
      
      // Cargar negocios según permisos
      List<dynamic> negociosRes;
      if (esSuperadmin) {
        // Superadmin ve todos los negocios
        negociosRes = await AppSupabase.client
            .from('negocios')
            .select()
            .order('nombre');
      } else {
        // Usuarios normales: negocios propios + donde tienen acceso
        negociosRes = await AppSupabase.client
            .from('negocios')
            .select()
            .or('propietario_id.eq.$userId')
            .order('nombre');
        
        // También buscar en usuarios_negocios
        final accesosRes = await AppSupabase.client
            .from('usuarios_negocios')
            .select('negocio_id, negocios(*)')
            .eq('usuario_id', userId ?? '')
            .eq('activo', true);
        
        // Agregar negocios por acceso que no estén ya en la lista
        for (var acceso in accesosRes) {
          if (acceso['negocios'] != null) {
            final negocio = acceso['negocios'];
            if (!negociosRes.any((n) => n['id'] == negocio['id'])) {
              negociosRes.add(negocio);
            }
          }
        }
      }
      
      _todosNegocios = List<Map<String, dynamic>>.from(negociosRes);
      
      if (_todosNegocios.isNotEmpty) {
        // Si no hay negocio seleccionado, usar el primero
        if (_negocioActual == null) {
          _negocioActual = _todosNegocios.first;
        } else {
          // Refrescar datos del negocio actual
          _negocioActual = _todosNegocios.firstWhere(
            (n) => n['id'] == _negocioActual!['id'],
            orElse: () => _todosNegocios.first,
          );
        }
        
        // Cargar sucursales del negocio seleccionado
        final sucursalesRes = await AppSupabase.client
            .from('sucursales')
            .select()
            .eq('negocio_id', _negocioActual!['id'])
            .order('nombre');
        
        _sucursales = List<Map<String, dynamic>>.from(sucursalesRes);

        // Cargar estadísticas
        await _cargarEstadisticas();
      } else {
        _negocioActual = null;
        _sucursales = [];
        _totalClientes = 0;
        _totalEmpleados = 0;
        _metaTotal = 0;
      }

      _animController.forward();
    } catch (e) {
      debugPrint('Error cargando sucursales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarEstadisticas() async {
    try {
      _totalClientes = 0;
      _totalEmpleados = 0;
      _metaTotal = 0;

      for (final suc in _sucursales) {
        // Contar clientes por sucursal
        final clientesCount = await AppSupabase.client
            .from('clientes')
            .select('id')
            .eq('sucursal_id', suc['id']);
        
        // Contar empleados por sucursal
        final empleadosCount = await AppSupabase.client
            .from('empleados')
            .select('id')
            .eq('sucursal_id', suc['id']);

        suc['_clientes_count'] = (clientesCount as List).length;
        suc['_empleados_count'] = (empleadosCount as List).length;
        
        _totalClientes += suc['_clientes_count'] as int;
        _totalEmpleados += suc['_empleados_count'] as int;
        _metaTotal += (suc['meta_mensual'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
    }
  }

  List<Map<String, dynamic>> get _sucursalesFiltradas {
    switch (_filtro) {
      case 'activas':
        return _sucursales.where((s) => s['activa'] == true).toList();
      case 'inactivas':
        return _sucursales.where((s) => s['activa'] != true).toList();
      default:
        return _sucursales;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinNegocio = _negocioActual == null;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sucursales', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                color: Colors.blueAccent,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header con info del negocio
                    SliverToBoxAdapter(child: _buildNegocioHeader()),
                    
                    // Estadísticas rápidas
                    SliverToBoxAdapter(child: _buildEstadisticas()),
                    
                    // Filtros
                    SliverToBoxAdapter(child: _buildFiltros()),
                    
                    // Lista de sucursales
                    _sucursalesFiltradas.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildSucursalCard(_sucursalesFiltradas[index], index),
                                childCount: _sucursalesFiltradas.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sinNegocio
            ? () => _mostrarFormularioNuevoNegocio()
            : () => _mostrarFormularioSucursal(),
        backgroundColor: sinNegocio ? Colors.greenAccent : Colors.blueAccent,
        icon: const Icon(Icons.add_business),
        label: Text(sinNegocio ? 'Crear Negocio' : 'Nueva Sucursal'),
      ),
    );
  }

  Widget _buildNegocioHeader() {
    if (_negocioActual == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orangeAccent.withOpacity(0.2),
              Colors.redAccent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.business_center,
                      color: Colors.orangeAccent, size: 32),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin negocios',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Crea tu primer negocio para comenzar',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _mostrarFormularioNuevoNegocio,
                icon: const Icon(Icons.add_business),
                label: const Text('Crear Negocio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.3), Colors.purpleAccent.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.business, color: Colors.blueAccent, size: 32),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _negocioActual?['nombre'] ?? 'Mi Negocio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getColorTipoNegocio(_negocioActual?['tipo']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            (_negocioActual?['tipo'] ?? 'fintech').toString().toUpperCase(),
                            style: TextStyle(color: _getColorTipoNegocio(_negocioActual?['tipo']), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_sucursales.length} sucursales',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF252536),
                onSelected: (value) {
                  if (value == 'editar') {
                    _editarNegocio();
                  } else if (value == 'agregar') {
                    _mostrarFormularioNuevoNegocio();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(children: [
                      Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text('Editar Negocio', style: TextStyle(color: Colors.white)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'agregar',
                    child: Row(children: [
                      Icon(Icons.add_business, size: 18, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text('Agregar Negocio', style: TextStyle(color: Colors.white)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          // Selector de negocios si hay más de uno
          if (_todosNegocios.length > 1) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cambiar negocio:',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _todosNegocios.map((negocio) {
                        final seleccionado = negocio['id'] == _negocioActual?['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _negocioActual = negocio);
                              _cargarDatos();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: seleccionado ? _getColorTipoNegocio(negocio['tipo']) : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: seleccionado ? _getColorTipoNegocio(negocio['tipo']) : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getIconTipoNegocio(negocio['tipo']),
                                    size: 16,
                                    color: seleccionado ? Colors.white : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    negocio['nombre'] ?? 'Sin nombre',
                                    style: TextStyle(
                                      color: seleccionado ? Colors.white : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_todosNegocios.length == 1) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _mostrarFormularioNuevoNegocio(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text(
                      'Agregar otro negocio',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColorTipoNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech': return Colors.blueAccent;
      case 'aires': return Colors.cyanAccent;
      case 'retail': return Colors.orangeAccent;
      case 'servicios': return Colors.purpleAccent;
      case 'restaurante': return Colors.redAccent;
      case 'salud': return Colors.greenAccent;
      default: return Colors.blueAccent;
    }
  }

  IconData _getIconTipoNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech': return Icons.account_balance;
      case 'aires': return Icons.ac_unit;
      case 'retail': return Icons.storefront;
      case 'servicios': return Icons.handyman;
      case 'restaurante': return Icons.restaurant;
      case 'salud': return Icons.medical_services;
      default: return Icons.business;
    }
  }

  Widget _buildEstadisticas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('👥', 'Clientes', '$_totalClientes', Colors.blueAccent)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('👔', 'Empleados', '$_totalEmpleados', Colors.orangeAccent)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('🎯', 'Meta Total', '\$${_metaTotal.toStringAsFixed(0)}', Colors.greenAccent)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('Filtrar:', style: TextStyle(color: Colors.white54)),
          const SizedBox(width: 10),
          _buildFilterChip('Todas', 'todas'),
          const SizedBox(width: 8),
          _buildFilterChip('Activas', 'activas'),
          const SizedBox(width: 8),
          _buildFilterChip('Inactivas', 'inactivas'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filtro == value;
    return InkWell(
      onTap: () => setState(() => _filtro = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.blueAccent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_negocioActual == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_center,
                size: 80, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 20),
            const Text(
              'No hay negocios',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un negocio para poder registrar sucursales',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _mostrarFormularioNuevoNegocio,
              icon: const Icon(Icons.add_business),
              label: const Text('Crear Negocio'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text(
            'No hay sucursales',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega tu primera sucursal para comenzar',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioSucursal(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Sucursal'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildSucursalCard(Map<String, dynamic> sucursal, int index) {
    final activa = sucursal['activa'] == true;
    final clientesCount = sucursal['_clientes_count'] ?? 0;
    final empleadosCount = sucursal['_empleados_count'] ?? 0;
    final meta = (sucursal['meta_mensual'] ?? 0).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activa ? Colors.greenAccent.withOpacity(0.3) : Colors.white12,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _mostrarDetallesSucursal(sucursal),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: activa ? Colors.greenAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.store,
                          color: activa ? Colors.greenAccent : Colors.grey,
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
                                Expanded(
                                  child: Text(
                                    sucursal['nombre'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: activa ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    activa ? 'Activa' : 'Inactiva',
                                    style: TextStyle(
                                      color: activa ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sucursal['codigo'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Código: ${sucursal['codigo']}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54),
                        color: const Color(0xFF252536),
                        onSelected: (value) => _accionSucursal(value, sucursal),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blueAccent), SizedBox(width: 8), Text('Editar', style: TextStyle(color: Colors.white))])),
                          PopupMenuItem(value: 'toggle', child: Row(children: [Icon(activa ? Icons.pause : Icons.play_arrow, size: 18, color: activa ? Colors.orangeAccent : Colors.greenAccent), SizedBox(width: 8), Text(activa ? 'Desactivar' : 'Activar', style: const TextStyle(color: Colors.white))])),
                          const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.white))])),
                        ],
                      ),
                    ],
                  ),
                  if (sucursal['direccion'] != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sucursal['direccion'],
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat(Icons.people, '$clientesCount', 'Clientes'),
                        Container(width: 1, height: 30, color: Colors.white12),
                        _buildMiniStat(Icons.badge, '$empleadosCount', 'Empleados'),
                        Container(width: 1, height: 30, color: Colors.white12),
                        _buildMiniStat(Icons.flag, '\$${meta.toStringAsFixed(0)}', 'Meta'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  void _mostrarDetallesSucursal(Map<String, dynamic> sucursal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.store, color: Colors.blueAccent, size: 32),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sucursal['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (sucursal['codigo'] != null)
                          Text('Código: ${sucursal['codigo']}', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              _buildDetalleItem(Icons.location_on, 'Dirección', sucursal['direccion'] ?? 'No especificada'),
              _buildDetalleItem(Icons.phone, 'Teléfono', sucursal['telefono'] ?? 'No especificado'),
              _buildDetalleItem(Icons.email, 'Email', sucursal['email'] ?? 'No especificado'),
              _buildDetalleItem(Icons.flag, 'Meta Mensual', '\$${(sucursal['meta_mensual'] ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarFormularioSucursal(sucursal: sucursal);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.all(15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(15),
                      ),
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

  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioSucursal({Map<String, dynamic>? sucursal}) {
    final esEdicion = sucursal != null;
    if (!esEdicion && _negocioActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea un negocio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final nombreCtrl = TextEditingController(text: sucursal?['nombre'] ?? '');
    final codigoCtrl = TextEditingController(text: sucursal?['codigo'] ?? '');
    final direccionCtrl = TextEditingController(text: sucursal?['direccion'] ?? '');
    final telefonoCtrl = TextEditingController(text: sucursal?['telefono'] ?? '');
    final emailCtrl = TextEditingController(text: sucursal?['email'] ?? '');
    final metaCtrl = TextEditingController(text: (sucursal?['meta_mensual'] ?? 0).toString());
    bool activa = sucursal?['activa'] ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(esEdicion ? Icons.edit : Icons.add_business, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Text(
                      esEdicion ? 'Editar Sucursal' : 'Nueva Sucursal',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildTextField(nombreCtrl, 'Nombre de la Sucursal *', Icons.store),
                _buildTextField(codigoCtrl, 'Código (opcional)', Icons.qr_code),
                _buildTextField(direccionCtrl, 'Dirección', Icons.location_on),
                _buildTextField(telefonoCtrl, 'Teléfono', Icons.phone, keyboardType: TextInputType.phone),
                _buildTextField(emailCtrl, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                _buildTextField(metaCtrl, 'Meta Mensual (\$)', Icons.flag, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: activa,
                  onChanged: (v) => setModalState(() => activa = v),
                  title: const Text('Sucursal Activa', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    activa ? 'Puede recibir clientes y operaciones' : 'No aparecerá en los listados',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeColor: Colors.greenAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    final datos = {
                      'nombre': nombreCtrl.text,
                      'codigo': codigoCtrl.text.isEmpty ? null : codigoCtrl.text,
                      'direccion': direccionCtrl.text.isEmpty ? null : direccionCtrl.text,
                      'telefono': telefonoCtrl.text.isEmpty ? null : telefonoCtrl.text,
                      'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                      'meta_mensual': double.tryParse(metaCtrl.text) ?? 0,
                      'activa': activa,
                      'negocio_id': _negocioActual!['id'],
                    };

                    try {
                      if (esEdicion) {
                        await AppSupabase.client
                            .from('sucursales')
                            .update(datos)
                            .eq('id', sucursal['id']);
                      } else {
                        await AppSupabase.client.from('sucursales').insert(datos);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(esEdicion ? '✅ Sucursal actualizada' : '✅ Sucursal creada'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _cargarDatos();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR SUCURSAL',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }

  void _accionSucursal(String accion, Map<String, dynamic> sucursal) async {
    switch (accion) {
      case 'editar':
        _mostrarFormularioSucursal(sucursal: sucursal);
        break;
      case 'toggle':
        final nuevoEstado = !(sucursal['activa'] == true);
        try {
          await AppSupabase.client
              .from('sucursales')
              .update({'activa': nuevoEstado})
              .eq('id', sucursal['id']);
          
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nuevoEstado ? '✅ Sucursal activada' : '⏸️ Sucursal desactivada'),
              backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
            ),
          );
          _cargarDatos();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
        break;
      case 'eliminar':
        _confirmarEliminar(sucursal);
        break;
    }
  }

  void _confirmarEliminar(Map<String, dynamic> sucursal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Eliminar Sucursal', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de eliminar "${sucursal['nombre']}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Los clientes y empleados asignados perderán su sucursal.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
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
              try {
                await AppSupabase.client
                    .from('sucursales')
                    .delete()
                    .eq('id', sucursal['id']);
                
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🗑️ Sucursal eliminada'), backgroundColor: Colors.red),
                );
                _cargarDatos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioNuevoNegocio() {
    final nombreCtrl = TextEditingController();
    final rfcCtrl = TextEditingController();
    final razonCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String tipoSeleccionado = 'fintech';
    
    final tiposNegocio = [
      {'valor': 'fintech', 'nombre': 'Fintech/Préstamos', 'icono': Icons.account_balance, 'color': Colors.blueAccent},
      {'valor': 'aires', 'nombre': 'Aires Acondicionados', 'icono': Icons.ac_unit, 'color': Colors.cyanAccent},
      {'valor': 'retail', 'nombre': 'Comercio/Retail', 'icono': Icons.storefront, 'color': Colors.orangeAccent},
      {'valor': 'servicios', 'nombre': 'Servicios', 'icono': Icons.handyman, 'color': Colors.purpleAccent},
      {'valor': 'restaurante', 'nombre': 'Restaurante', 'icono': Icons.restaurant, 'color': Colors.redAccent},
      {'valor': 'salud', 'nombre': 'Salud/Médico', 'icono': Icons.medical_services, 'color': Colors.greenAccent},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_business, color: Colors.greenAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Agregar Nuevo Negocio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Administra negocios separados', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                
                // Selector de tipo de negocio
                const Text('Tipo de Negocio *', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tiposNegocio.map((tipo) {
                    final seleccionado = tipoSeleccionado == tipo['valor'];
                    return InkWell(
                      onTap: () => setModalState(() => tipoSeleccionado = tipo['valor'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: seleccionado ? (tipo['color'] as Color).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: seleccionado ? tipo['color'] as Color : Colors.white24,
                            width: seleccionado ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tipo['icono'] as IconData, size: 18, color: tipo['color'] as Color),
                            const SizedBox(width: 6),
                            Text(
                              tipo['nombre'] as String,
                              style: TextStyle(
                                color: seleccionado ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                _buildTextField(nombreCtrl, 'Nombre del Negocio *', Icons.business),
                _buildTextField(rfcCtrl, 'RFC (opcional)', Icons.numbers),
                _buildTextField(razonCtrl, 'Razón Social (opcional)', Icons.article),
                _buildTextField(direccionCtrl, 'Dirección Fiscal (opcional)', Icons.location_city),
                _buildTextField(telefonoCtrl, 'Teléfono (opcional)', Icons.phone),
                _buildTextField(emailCtrl, 'Email (opcional)', Icons.email),
                
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cada negocio tendrá sus propios clientes, préstamos y datos completamente separados.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    try {
                      // Obtener el usuario actual
                      final userId = AppSupabase.client.auth.currentUser?.id;
                      if (userId == null) {
                        throw Exception('No hay sesión activa');
                      }

                      // Crear el nuevo negocio
                      final nuevoNegocio = await AppSupabase.client.from('negocios').insert({
                        'nombre': nombreCtrl.text,
                        'tipo': tipoSeleccionado,
                        'rfc': rfcCtrl.text.isEmpty ? null : rfcCtrl.text,
                        'razon_social': razonCtrl.text.isEmpty ? null : razonCtrl.text,
                        'direccion_fiscal': direccionCtrl.text.isEmpty ? null : direccionCtrl.text,
                        'telefono': telefonoCtrl.text.isEmpty ? null : telefonoCtrl.text,
                        'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                        'propietario_id': userId,
                        'activo': true,
                      }).select().single();

                      debugPrint('Nuevo negocio creado: $nuevoNegocio');

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Negocio "${nombreCtrl.text}" creado'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Cambiar al nuevo negocio
                        setState(() => _negocioActual = nuevoNegocio);
                        _cargarDatos();
                      }
                    } catch (e) {
                      debugPrint('Error creando negocio: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString().contains('policy') ? 'Sin permisos (RLS)' : e}'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_business),
                      SizedBox(width: 10),
                      Text('CREAR NEGOCIO', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editarNegocio() {
    final nombreCtrl = TextEditingController(text: _negocioActual?['nombre'] ?? '');
    final rfcCtrl = TextEditingController(text: _negocioActual?['rfc'] ?? '');
    final razonCtrl = TextEditingController(text: _negocioActual?['razon_social'] ?? '');
    final direccionCtrl = TextEditingController(text: _negocioActual?['direccion_fiscal'] ?? '');
    final telefonoCtrl = TextEditingController(text: _negocioActual?['telefono'] ?? '');
    final emailCtrl = TextEditingController(text: _negocioActual?['email'] ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.business, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Configurar Negocio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 25),
              _buildTextField(nombreCtrl, 'Nombre del Negocio *', Icons.business),
              _buildTextField(rfcCtrl, 'RFC', Icons.numbers),
              _buildTextField(razonCtrl, 'Razón Social', Icons.article),
              _buildTextField(direccionCtrl, 'Dirección Fiscal', Icons.location_city),
              _buildTextField(telefonoCtrl, 'Teléfono', Icons.phone),
              _buildTextField(emailCtrl, 'Email', Icons.email),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  try {
                    debugPrint('Actualizando negocio ID: ${_negocioActual!['id']}');
                    debugPrint('Nuevo nombre: ${nombreCtrl.text}');
                    
                    final response = await AppSupabase.client.from('negocios').update({
                      'nombre': nombreCtrl.text,
                      'rfc': rfcCtrl.text.isEmpty ? null : rfcCtrl.text,
                      'razon_social': razonCtrl.text.isEmpty ? null : razonCtrl.text,
                      'direccion_fiscal': direccionCtrl.text.isEmpty ? null : direccionCtrl.text,
                      'telefono': telefonoCtrl.text.isEmpty ? null : telefonoCtrl.text,
                      'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', _negocioActual!['id']).select();
                    
                    debugPrint('Respuesta update: $response');

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Negocio actualizado'), backgroundColor: Colors.green),
                      );
                      _cargarDatos();
                    }
                  } catch (e) {
                    debugPrint('Error actualizando negocio: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar: ${e.toString().contains('policy') ? 'Sin permisos (RLS)' : e}'),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

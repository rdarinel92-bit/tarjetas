// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';

/// Centro de Control Multi-Empresa
/// Permite gestionar múltiples negocios y sucursales desde un solo panel
class CentroControlMultiEmpresaScreen extends StatefulWidget {
  const CentroControlMultiEmpresaScreen({super.key});

  @override
  State<CentroControlMultiEmpresaScreen> createState() => _CentroControlMultiEmpresaScreenState();
}

class _CentroControlMultiEmpresaScreenState extends State<CentroControlMultiEmpresaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _negocios = [];
  List<Map<String, dynamic>> _sucursales = [];
  Map<String, dynamic>? _negocioActivo;
  Map<String, int> _sucursalesConteo = {};
  Map<String, bool> _modulosActivos = {};
  final Map<String, bool> _modulosDefault = {
    'prestamos': true,
    'cobranza': true,
    'clientes': true,
    'reportes': true,
    'tarjetas': false,
    'aires': false,
  };

  static const List<_ModuloConfig> _modulosConfigurables = [
    _ModuloConfig('prestamos', 'Prestamos', Icons.account_balance),
    _ModuloConfig('cobranza', 'Cobranza', Icons.payments),
    _ModuloConfig('clientes', 'Clientes', Icons.people),
    _ModuloConfig('reportes', 'Reportes', Icons.analytics),
    _ModuloConfig('tarjetas', 'Tarjetas Digitales', Icons.credit_card),
    _ModuloConfig('aires', 'Aires Acondicionados', Icons.ac_unit),
  ];

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
    if (mounted) {
      setState(() => _isLoading = true);
    }

    List<Map<String, dynamic>> negocios = [];
    List<Map<String, dynamic>> sucursales = [];
    Map<String, dynamic>? negocioActivo;
    Map<String, int> conteoSucursales = {};
    Map<String, bool> modulosActivos = Map<String, bool>.from(_modulosDefault);
    String? negocioActivoId;
    String? errorMsg;

    try {
      final negociosRes = await AppSupabase.client
          .from('negocios')
          .select(
            'id, nombre, tipo, activo, rfc, razon_social, direccion_fiscal, '
            'telefono, email, logo_url, color_primario, color_secundario',
          )
          .order('created_at');
      negocios = List<Map<String, dynamic>>.from(negociosRes);
    } catch (e) {
      errorMsg = 'Error cargando negocios';
      debugPrint('Error cargando negocios: $e');
    }

    try {
      final configRes = await AppSupabase.client
          .from('configuracion_global')
          .select('valor')
          .eq('clave', 'negocio_activo')
          .maybeSingle();
      if (configRes != null) {
        final valor = configRes['valor'];
        if (valor is Map && valor['id'] != null) {
          negocioActivoId = valor['id'].toString();
        } else if (valor is String) {
          negocioActivoId = valor;
        }
      }
    } catch (e) {
      debugPrint('Error cargando configuracion_global: $e');
    }

    try {
      final sucursalesRes = await AppSupabase.client
          .from('sucursales')
          .select('id, negocio_id');
      for (final s in (sucursalesRes as List)) {
        final id = s['negocio_id']?.toString();
        if (id == null) continue;
        conteoSucursales[id] = (conteoSucursales[id] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('Error contando sucursales: $e');
    }

    if (negocioActivoId != null) {
      for (final n in negocios) {
        if (n['id']?.toString() == negocioActivoId) {
          negocioActivo = n;
          break;
        }
      }
    }

    if (negocioActivo == null && negocios.isNotEmpty) {
      negocioActivo = negocios.first;
      final nuevoId = negocioActivo['id']?.toString();
      if (nuevoId != null) {
        negocioActivoId = nuevoId;
        try {
          await _guardarNegocioActivo(nuevoId);
        } catch (e) {
          debugPrint('Error guardando negocio activo: $e');
        }
      }
    }

    if (negocioActivoId != null) {
      try {
        final sucursalesRes = await AppSupabase.client
            .from('sucursales')
            .select()
            .eq('negocio_id', negocioActivoId)
            .order('nombre');
        sucursales = List<Map<String, dynamic>>.from(sucursalesRes);

        final Map<String, int> empleadosConteo = {};
        try {
          final empleadosRes = await AppSupabase.client
              .from('empleados')
              .select('id, sucursal_id')
              .eq('negocio_id', negocioActivoId);
          for (final e in (empleadosRes as List)) {
            final sucursalId = e['sucursal_id']?.toString();
            if (sucursalId == null) continue;
            empleadosConteo[sucursalId] = (empleadosConteo[sucursalId] ?? 0) + 1;
          }
        } catch (e) {
          debugPrint('Error contando empleados por sucursal: $e');
        }

        for (final suc in sucursales) {
          final id = suc['id']?.toString();
          if (id == null) continue;
          suc['empleados_count'] = empleadosConteo[id] ?? 0;
        }
      } catch (e) {
        debugPrint('Error cargando sucursales: $e');
      }

      try {
        modulosActivos = await _cargarModulosActivos(negocioActivoId);
      } catch (e) {
        debugPrint('Error cargando modulos: $e');
      }
    }

    if (mounted) {
      setState(() {
        _negocios = negocios;
        _sucursales = sucursales;
        _negocioActivo = negocioActivo;
        _sucursalesConteo = conteoSucursales;
        _modulosActivos = modulosActivos;
        _isLoading = false;
      });
    }

    if (errorMsg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Centro de Control",
      actions: [
        IconButton(
          icon: const Icon(Icons.add_business),
          onPressed: () => _mostrarDialogoNuevoNegocio(),
          tooltip: 'Crear Nuevo Negocio',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selector de negocio activo
                _buildSelectorNegocio(),
                const SizedBox(height: 15),
                
                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.orangeAccent,
                    labelColor: Colors.orangeAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.business), text: 'Negocios'),
                      Tab(icon: Icon(Icons.store), text: 'Sucursales'),
                      Tab(icon: Icon(Icons.settings), text: 'Config'),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                
                // Contenido de tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabNegocios(),
                      _buildTabSucursales(),
                      _buildTabConfiguracion(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectorNegocio() {
    return PremiumCard(
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.orangeAccent),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Negocio Activo', 
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text(
                  _negocioActivo?['nombre'] ?? 'Sin seleccionar',
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
            color: const Color(0xFF1E1E2C),
            onSelected: (id) => _cambiarNegocioActivo(id),
            itemBuilder: (context) => _negocios.map<PopupMenuEntry<String>>((n) => PopupMenuItem<String>(
              value: n['id']?.toString(),
              child: Row(
                children: [
                  Icon(
                    _getNegocioIcono(n['tipo']),
                    color: n['id'] == _negocioActivo?['id'] 
                        ? Colors.orangeAccent 
                        : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(n['nombre'], style: TextStyle(
                    color: n['id'] == _negocioActivo?['id'] 
                        ? Colors.orangeAccent 
                        : Colors.white,
                  )),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNegocios() {
    if (_negocios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_outlined, size: 60, color: Colors.white24),
            const SizedBox(height: 15),
            const Text('No hay negocios creados',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoNuevoNegocio(),
              icon: const Icon(Icons.add),
              label: const Text('Crear Primer Negocio'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _negocios.length,
      itemBuilder: (context, index) {
        final negocio = _negocios[index];
        final esActivo = negocio['id'] == _negocioActivo?['id'];
        final estaActivo = negocio['activo'] == true;
        final negocioId = negocio['id']?.toString();
        final totalSucursales = _sucursalesConteo[negocioId] ?? 0;
        
        return PremiumCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: esActivo 
                    ? Colors.orangeAccent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getNegocioIcono(negocio['tipo']),
                color: esActivo ? Colors.orangeAccent : Colors.white54,
              ),
            ),
            title: Row(
              children: [
                Text(negocio['nombre'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (esActivo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('ACTIVO', 
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(negocio['tipo'] ?? 'General',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _buildMiniStat(Icons.store, '$totalSucursales sucursales'),
                    const SizedBox(width: 15),
                    _buildMiniStat(
                      estaActivo ? Icons.check_circle : Icons.cancel,
                      estaActivo ? 'Activo' : 'Inactivo',
                      color: estaActivo ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: const Color(0xFF1E1E2C),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'sucursales', child: Text('Ver Sucursales')),
                PopupMenuItem(
                  value: 'activar',
                  child: Text(esActivo ? 'Ya es activo' : 'Activar'),
                  enabled: !esActivo,
                ),
                if (estaActivo)
                  const PopupMenuItem(
                    value: 'archivar',
                    child: Text('Archivar', style: TextStyle(color: Colors.redAccent)),
                  ),
                if (!estaActivo)
                  const PopupMenuItem(
                    value: 'reactivar',
                    child: Text('Reactivar', style: TextStyle(color: Colors.greenAccent)),
                  ),
              ],
              onSelected: (value) => _accionNegocio(negocio, value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSucursales() {
    if (_negocioActivo == null) {
      return const Center(
        child: Text('Selecciona un negocio primero',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        // Botón agregar sucursal
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _mostrarDialogoNuevaSucursal(),
              icon: const Icon(Icons.add_business),
              label: const Text('Agregar Sucursal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: const BorderSide(color: Colors.orangeAccent),
              ),
            ),
          ),
        ),
        
        // Lista de sucursales
        Expanded(
          child: _sucursales.isEmpty
              ? const Center(
                  child: Text('No hay sucursales', 
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  itemCount: _sucursales.length,
                  itemBuilder: (context, index) {
                    final sucursal = _sucursales[index];
                    return _buildSucursalCard(sucursal);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSucursalCard(Map<String, dynamic> sucursal) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store, color: Colors.blueAccent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sucursal['nombre'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(sucursal['direccion'] ?? 'Sin dirección',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: sucursal['activa'] ?? false,
                onChanged: (v) => _toggleSucursal(sucursal['id'], v),
                activeColor: Colors.greenAccent,
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSucursalStat(Icons.people, '${sucursal['empleados_count'] ?? 0}', 'Empleados'),
              _buildSucursalStat(Icons.attach_money, '\$${sucursal['meta_mensual'] ?? 0}', 'Meta'),
              _buildSucursalStat(Icons.phone, sucursal['telefono'] ?? 'N/A', 'Teléfono'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editarSucursal(sucursal),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _asignarEmpleados(sucursal),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Empleados'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabConfiguracion() {
    if (_negocioActivo == null) {
      return const Center(
        child: Text('Selecciona un negocio primero',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configuración general del negocio
          const Text('Configuración del Negocio',
              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          _buildConfigItem(
            Icons.business,
            'Datos de la Empresa',
            'RFC, razón social, dirección fiscal',
            () => _editarDatosEmpresa(),
          ),
          _buildConfigItem(
            Icons.palette,
            'Branding',
            'Logo, colores, nombre comercial',
            () => _editarBranding(),
          ),
          _buildConfigItem(
            Icons.receipt_long,
            'Facturación',
            'Configuración de facturación electrónica',
            () => _editarFacturacion(),
          ),
          
          const SizedBox(height: 25),
          const Text('Módulos del Negocio',
              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          ..._modulosConfigurables.map((modulo) => _buildModuloToggle(
                modulo.id,
                modulo.nombre,
                modulo.icono,
                _modulosActivos[modulo.id] ?? _modulosDefault[modulo.id] ?? false,
              )),
        ],
      ),
    );
  }

  Widget _buildConfigItem(IconData icon, String titulo, String subtitulo, VoidCallback onTap) {
    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  Widget _buildModuloToggle(String clave, String nombre, IconData icon, bool activo) {
    return PremiumCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: activo ? Colors.greenAccent : Colors.white38),
        title: Text(nombre, style: const TextStyle(color: Colors.white)),
        value: activo,
        onChanged: (v) => _toggleModulo(clave, v),
        activeColor: Colors.greenAccent,
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String texto, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white38),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(color: color ?? Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildSucursalStat(IconData icon, String valor, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  IconData _getNegocioIcono(String? tipo) {
    switch (tipo) {
      case 'fintech': return Icons.account_balance;
      case 'aires': return Icons.ac_unit;
      case 'climas': return Icons.ac_unit;
      case 'purificadora': return Icons.water_drop;
      case 'agua': return Icons.water_drop;
      case 'nice': return Icons.diamond;
      case 'retail': return Icons.shopping_cart;
      case 'servicios': return Icons.build;
      default: return Icons.business;
    }
  }

  // === ACCIONES ===

  Future<void> _cambiarNegocioActivo(String negocioId) async {
    try {
      await _guardarNegocioActivo(negocioId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Negocio activo cambiado')),
        );
      }
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mostrarDialogoNuevoNegocio() {
    final nombreController = TextEditingController();
    final rfcController = TextEditingController();
    String tipoSeleccionado = 'fintech';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Nuevo Negocio', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre del Negocio',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: rfcController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'RFC (opcional)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                dropdownColor: const Color(0xFF1E1E2C),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Negocio',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
                items: const [
                  DropdownMenuItem(value: 'fintech', child: Text('💰 Fintech/Préstamos')),
                  DropdownMenuItem(value: 'aires', child: Text('❄️ Aires Acondicionados')),
                  DropdownMenuItem(value: 'retail', child: Text('🛒 Retail/Ventas')),
                  DropdownMenuItem(value: 'servicios', child: Text('🔧 Servicios')),
                  DropdownMenuItem(value: 'purificadora', child: Text('💧 Purificadora/Agua')),
                  DropdownMenuItem(value: 'climas', child: Text('❄️ Climas')),
                  DropdownMenuItem(value: 'nice', child: Text('💎 Nice')),
                ],
                onChanged: (v) => tipoSeleccionado = v ?? 'fintech',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isEmpty) return;
              
              final userId = AppSupabase.client.auth.currentUser?.id;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No hay sesion activa')),
                );
                return;
              }

              try {
                final nuevo = await AppSupabase.client.from('negocios').insert({
                  'nombre': nombreController.text,
                  'rfc': rfcController.text.isEmpty ? null : rfcController.text,
                  'tipo': tipoSeleccionado,
                  'activo': true,
                  'propietario_id': userId,
                }).select('id').single();

                try {
                  await AppSupabase.client.from('usuarios_negocios').insert({
                    'usuario_id': userId,
                    'negocio_id': nuevo['id'],
                    'rol_negocio': 'propietario',
                    'activo': true,
                  });
                } catch (_) {}

                await _bootstrapModulosNegocio(nuevo['id'].toString());
                await _guardarNegocioActivo(nuevo['id'].toString());
                Navigator.pop(context);
                _cargarDatos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Negocio creado')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al crear negocio: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevaSucursal() {
    final nombreController = TextEditingController();
    final direccionController = TextEditingController();
    final telefonoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Nueva Sucursal', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Sucursal',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: direccionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: telefonoController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isEmpty) return;
              
              if (_negocioActivo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selecciona un negocio primero')),
                );
                return;
              }

              try {
                await AppSupabase.client.from('sucursales').insert({
                  'negocio_id': _negocioActivo!['id'],
                  'nombre': nombreController.text,
                  'direccion': direccionController.text,
                  'telefono': telefonoController.text,
                  'activa': true,
                });
                
                Navigator.pop(context);
                _cargarDatos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al crear sucursal: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _accionNegocio(Map<String, dynamic> negocio, String accion) {
    switch (accion) {
      case 'activar':
        _cambiarNegocioActivo(negocio['id']);
        break;
      case 'editar':
        _editarNegocio(negocio);
        break;
      case 'sucursales':
        _cambiarNegocioActivo(negocio['id']);
        _tabController.animateTo(1);
        break;
      case 'archivar':
        _confirmarArchivarNegocio(negocio);
        break;
      case 'reactivar':
        _confirmarReactivarNegocio(negocio);
        break;
    }
  }

  void _confirmarArchivarNegocio(Map<String, dynamic> negocio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Archivar negocio', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se desactivara "${negocio['nombre']}" sin borrar datos.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppSupabase.client
                  .from('negocios')
                  .update({'activo': false, 'updated_at': DateTime.now().toIso8601String()})
                  .eq('id', negocio['id']);
              Navigator.pop(context);
              _cargarDatos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
  }

  void _confirmarReactivarNegocio(Map<String, dynamic> negocio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Reactivar negocio', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se reactivara "${negocio['nombre']}".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await AppSupabase.client.from('negocios').update({
                  'logo_url': null,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', negocio['id']);

                Navigator.pop(context);
                _cargarDatos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logo eliminado')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al eliminar logo: $e')),
                );
              }
            },
            child: const Text('Eliminar Logo', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppSupabase.client
                  .from('negocios')
                  .update({'activo': true, 'updated_at': DateTime.now().toIso8601String()})
                  .eq('id', negocio['id']);
              Navigator.pop(context);
              _cargarDatos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSucursal(String id, bool activo) async {
    try {
      await AppSupabase.client
          .from('sucursales')
          .update({'activa': activo, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar sucursal: $e')),
      );
    }
  }

  void _editarSucursal(Map<String, dynamic> sucursal) {
    final nombreController = TextEditingController(text: sucursal['nombre'] ?? '');
    final direccionController = TextEditingController(text: sucursal['direccion'] ?? '');
    final telefonoController = TextEditingController(text: sucursal['telefono'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Editar Sucursal', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: direccionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Direccion',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AppSupabase.client.from('sucursales').update({
                  'nombre': nombreController.text.trim(),
                  'direccion': direccionController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', sucursal['id']);
                Navigator.pop(context);
                _cargarDatos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al editar sucursal: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _asignarEmpleados(Map<String, dynamic> sucursal) {
    Navigator.pushNamed(
      context,
      AppRoutes.empleados,
      arguments: {
        'sucursalId': sucursal['id'],
        'negocioId': _negocioActivo?['id'],
      },
    );
  }

  Future<void> _toggleModulo(String moduloId, bool activo) async {
    if (_negocioActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un negocio primero')),
      );
      return;
    }

    try {
      await AppSupabase.client.from('modulos_activos').upsert({
        'negocio_id': _negocioActivo!['id'],
        'modulo_id': moduloId,
        'tipo': 'gavetero',
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'negocio_id,modulo_id');

      if (mounted) {
        setState(() => _modulosActivos[moduloId] = activo);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activo ? 'Modulo activado' : 'Modulo desactivado'),
          backgroundColor: activo ? Colors.greenAccent : Colors.grey,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<Map<String, bool>> _cargarModulosActivos(String negocioId) async {
    final modulos = Map<String, bool>.from(_modulosDefault);
    try {
      final res = await AppSupabase.client
          .from('modulos_activos')
          .select('modulo_id, activo')
          .eq('negocio_id', negocioId);

      for (final row in (res as List)) {
        final id = row['modulo_id']?.toString();
        if (id == null) continue;
        modulos[id] = row['activo'] == true;
      }
    } catch (e) {
      debugPrint('Error cargando modulos: $e');
    }
    return modulos;
  }

  Future<void> _bootstrapModulosNegocio(String negocioId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final payload = _modulosDefault.entries.map((e) {
        return {
          'negocio_id': negocioId,
          'modulo_id': e.key,
          'tipo': 'gavetero',
          'activo': e.value,
          'updated_at': now,
        };
      }).toList();
      await AppSupabase.client
          .from('modulos_activos')
          .upsert(payload, onConflict: 'negocio_id,modulo_id');
    } catch (e) {
      debugPrint('Error inicializando modulos: $e');
    }
  }

  Future<void> _guardarNegocioActivo(String negocioId) async {
    await AppSupabase.client.from('configuracion_global').upsert({
      'clave': 'negocio_activo',
      'valor': {'id': negocioId},
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'clave');
  }

  void _editarNegocio(Map<String, dynamic> negocio) {
    _mostrarDialogoEditarNegocio(negocio);
  }

  void _editarDatosEmpresa() {
    if (_negocioActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un negocio primero')),
      );
      return;
    }
    _mostrarDialogoEditarNegocio(_negocioActivo!);
  }

  void _editarBranding() {
    if (_negocioActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un negocio primero')),
      );
      return;
    }
    _mostrarDialogoBranding(_negocioActivo!);
  }

  void _editarFacturacion() {
    Navigator.pushNamed(context, AppRoutes.facturacionConfig);
  }

  void _mostrarDialogoEditarNegocio(Map<String, dynamic> negocio) {
    final nombreController = TextEditingController(text: negocio['nombre'] ?? '');
    final rfcController = TextEditingController(text: negocio['rfc'] ?? '');
    final razonController = TextEditingController(text: negocio['razon_social'] ?? '');
    final direccionController = TextEditingController(text: negocio['direccion_fiscal'] ?? '');
    final telefonoController = TextEditingController(text: negocio['telefono'] ?? '');
    final emailController = TextEditingController(text: negocio['email'] ?? '');
    String tipoSeleccionado = (negocio['tipo'] ?? 'fintech').toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Editar Negocio', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rfcController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'RFC',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: razonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Razon Social',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Direccion Fiscal',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  dropdownColor: const Color(0xFF1E1E2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Negocio',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fintech', child: Text('Fintech/Prestamos')),
                    DropdownMenuItem(value: 'aires', child: Text('Aires Acondicionados')),
                    DropdownMenuItem(value: 'retail', child: Text('Retail/Ventas')),
                    DropdownMenuItem(value: 'servicios', child: Text('Servicios')),
                    DropdownMenuItem(value: 'purificadora', child: Text('Purificadora')),
                    DropdownMenuItem(value: 'climas', child: Text('Climas')),
                  ],
                  onChanged: (v) => setDialogState(() => tipoSeleccionado = v ?? 'fintech'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AppSupabase.client.from('negocios').update({
                    'nombre': nombreController.text.trim(),
                    'rfc': rfcController.text.trim().isEmpty ? null : rfcController.text.trim(),
                    'razon_social': razonController.text.trim().isEmpty ? null : razonController.text.trim(),
                    'direccion_fiscal': direccionController.text.trim().isEmpty ? null : direccionController.text.trim(),
                    'telefono': telefonoController.text.trim().isEmpty ? null : telefonoController.text.trim(),
                    'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    'tipo': tipoSeleccionado,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', negocio['id']);

                  Navigator.pop(context);
                  _cargarDatos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar negocio: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoBranding(Map<String, dynamic> negocio) {
    final logoController = TextEditingController(text: negocio['logo_url'] ?? '');
    final colorPrimarioController = TextEditingController(text: negocio['color_primario'] ?? '#FF9800');
    final colorSecundarioController = TextEditingController(text: negocio['color_secundario'] ?? '#1E1E2C');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Branding', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: logoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'URL Logo',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorPrimarioController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Color Primario (HEX)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorSecundarioController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Color Secundario (HEX)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AppSupabase.client.from('negocios').update({
                  'logo_url': logoController.text.trim().isEmpty ? null : logoController.text.trim(),
                  'color_primario': colorPrimarioController.text.trim().isEmpty ? null : colorPrimarioController.text.trim(),
                  'color_secundario': colorSecundarioController.text.trim().isEmpty ? null : colorSecundarioController.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', negocio['id']);

                Navigator.pop(context);
                _cargarDatos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar branding: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ModuloConfig {
  final String id;
  final String nombre;
  final IconData icono;
  const _ModuloConfig(this.id, this.nombre, this.icono);
}

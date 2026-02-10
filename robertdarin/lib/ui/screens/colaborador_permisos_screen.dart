// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/colaboradores_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE PERMISOS DE COLABORADOR
// Configurar permisos granulares por módulo
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradorPermisosScreen extends StatefulWidget {
  final String colaboradorId;
  
  const ColaboradorPermisosScreen({super.key, required this.colaboradorId});
  
  @override
  State<ColaboradorPermisosScreen> createState() => _ColaboradorPermisosScreenState();
}

class _ColaboradorPermisosScreenState extends State<ColaboradorPermisosScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  ColaboradorModel? _colaborador;
  
  // Lista de módulos disponibles
  final List<_ModuloPermiso> _modulos = [
    _ModuloPermiso('dashboard', 'Dashboard', Icons.dashboard, 'Ver panel principal'),
    _ModuloPermiso('clientes', 'Clientes', Icons.people, 'Gestión de clientes'),
    _ModuloPermiso('prestamos', 'Préstamos', Icons.attach_money, 'Préstamos y amortizaciones'),
    _ModuloPermiso('tandas', 'Tandas', Icons.group_work, 'Sistema de tandas'),
    _ModuloPermiso('pagos', 'Pagos', Icons.payments, 'Registro de pagos'),
    _ModuloPermiso('cobros', 'Cobros', Icons.receipt_long, 'Cobros pendientes'),
    _ModuloPermiso('facturacion', 'Facturación', Icons.receipt, 'Emitir facturas CFDI'),
    _ModuloPermiso('reportes', 'Reportes', Icons.analytics, 'Ver reportes'),
    _ModuloPermiso('empleados', 'Empleados', Icons.badge, 'Gestión de empleados'),
    _ModuloPermiso('calendario', 'Calendario', Icons.calendar_month, 'Eventos y citas'),
    _ModuloPermiso('chat', 'Chat', Icons.chat, 'Mensajería interna'),
    _ModuloPermiso('auditoria', 'Auditoría', Icons.security, 'Logs del sistema'),
  ];
  
  // Permisos actuales
  Map<String, ColaboradorPermisoModuloModel> _permisos = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar colaborador
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('id', widget.colaboradorId)
          .single();
      
      _colaborador = ColaboradorModel.fromMap(colabRes);

      // Cargar permisos existentes
      final permisosRes = await AppSupabase.client
          .from('colaborador_permisos_modulo')
          .select()
          .eq('colaborador_id', widget.colaboradorId);

      for (var p in permisosRes) {
        final permiso = ColaboradorPermisoModuloModel.fromMap(p);
        _permisos[permiso.modulo] = permiso;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar permisos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🔐 Permisos',
      actions: [
        if (!_isLoading)
          TextButton.icon(
            onPressed: _isSaving ? null : _guardarPermisos,
            icon: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, color: Colors.white),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con info del colaborador
          _buildHeader(),
          
          const SizedBox(height: 24),
          
          // Info sobre el tipo
          _buildTipoInfo(),
          
          const SizedBox(height: 24),
          
          // Lista de módulos
          const Text(
            'Permisos por Módulo',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Configura qué puede hacer en cada módulo',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          
          const SizedBox(height: 16),
          
          ..._modulos.map((modulo) => _buildModuloCard(modulo)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _colaborador?.iniciales ?? '?',
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _colaborador?.nombre ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _colaborador?.tipoNombre ?? _colaborador?.tipoCodigo ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Los permisos personalizados anulan los permisos por defecto del tipo de colaborador.',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuloCard(_ModuloPermiso modulo) {
    final permiso = _permisos[modulo.codigo];
    final habilitado = permiso?.puedeVer ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: habilitado 
            ? Border.all(color: const Color(0xFF10B981).withOpacity(0.5))
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: habilitado 
                  ? const Color(0xFF10B981).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              modulo.icono,
              color: habilitado ? const Color(0xFF10B981) : Colors.white54,
              size: 20,
            ),
          ),
          title: Text(
            modulo.nombre,
            style: TextStyle(
              color: habilitado ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            modulo.descripcion,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
          ),
          trailing: Switch(
            value: habilitado,
            onChanged: (v) => _toggleModulo(modulo.codigo, v),
            activeColor: const Color(0xFF10B981),
          ),
          children: [
            if (habilitado)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _buildPermisoSwitch(modulo.codigo, 'puede_crear', 'Puede crear', Icons.add),
                    _buildPermisoSwitch(modulo.codigo, 'puede_editar', 'Puede editar', Icons.edit),
                    _buildPermisoSwitch(modulo.codigo, 'puede_eliminar', 'Puede eliminar', Icons.delete),
                    _buildPermisoSwitch(modulo.codigo, 'puede_exportar', 'Puede exportar', Icons.download),
                    _buildPermisoSwitch(modulo.codigo, 'solo_propios', 'Solo sus registros', Icons.person, invertido: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermisoSwitch(String modulo, String campo, String label, IconData icono, {bool invertido = false}) {
    final permiso = _permisos[modulo];
    bool valor = false;
    
    switch (campo) {
      case 'puede_crear': valor = permiso?.puedeCrear ?? false; break;
      case 'puede_editar': valor = permiso?.puedeEditar ?? false; break;
      case 'puede_eliminar': valor = permiso?.puedeEliminar ?? false; break;
      case 'puede_exportar': valor = permiso?.puedeExportar ?? false; break;
      case 'solo_propios': valor = permiso?.soloPropios ?? true; break;
    }

    if (invertido) valor = !valor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))),
          Switch(
            value: valor,
            onChanged: (v) => _setPermiso(modulo, campo, invertido ? !v : v),
            activeColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  void _toggleModulo(String modulo, bool habilitado) {
    setState(() {
      if (habilitado) {
        _permisos[modulo] = ColaboradorPermisoModuloModel(
          id: _permisos[modulo]?.id ?? '',
          colaboradorId: widget.colaboradorId,
          modulo: modulo,
          puedeVer: true,
          puedeCrear: false,
          puedeEditar: false,
          puedeEliminar: false,
          puedeExportar: false,
          soloPropios: true,
        );
      } else {
        _permisos.remove(modulo);
      }
    });
  }

  void _setPermiso(String modulo, String campo, bool valor) {
    final permiso = _permisos[modulo];
    if (permiso == null) return;

    setState(() {
      _permisos[modulo] = ColaboradorPermisoModuloModel(
        id: permiso.id,
        colaboradorId: permiso.colaboradorId,
        modulo: permiso.modulo,
        puedeVer: permiso.puedeVer,
        puedeCrear: campo == 'puede_crear' ? valor : permiso.puedeCrear,
        puedeEditar: campo == 'puede_editar' ? valor : permiso.puedeEditar,
        puedeEliminar: campo == 'puede_eliminar' ? valor : permiso.puedeEliminar,
        puedeExportar: campo == 'puede_exportar' ? valor : permiso.puedeExportar,
        soloPropios: campo == 'solo_propios' ? valor : permiso.soloPropios,
      );
    });
  }

  Future<void> _guardarPermisos() async {
    setState(() => _isSaving = true);

    try {
      // Eliminar permisos anteriores
      await AppSupabase.client
          .from('colaborador_permisos_modulo')
          .delete()
          .eq('colaborador_id', widget.colaboradorId);

      // Insertar nuevos permisos
      for (var permiso in _permisos.values) {
        await AppSupabase.client
            .from('colaborador_permisos_modulo')
            .insert(permiso.toMapForInsert());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos guardados'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _ModuloPermiso {
  final String codigo;
  final String nombre;
  final IconData icono;
  final String descripcion;

  _ModuloPermiso(this.codigo, this.nombre, this.icono, this.descripcion);
}

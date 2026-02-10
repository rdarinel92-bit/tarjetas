import 'package:flutter/foundation.dart';
import '../../data/models/negocio_model.dart';
import '../../core/supabase_client.dart';

/// Provider global para gestionar el negocio activo del superadmin
/// Permite cambiar entre negocios y filtrar datos automáticamente
class NegocioActivoProvider extends ChangeNotifier {
  NegocioModel? _negocioActivo;
  List<NegocioModel> _misNegocios = [];
  bool _cargando = true;
  String? _error;
  
  // KPIs del negocio activo
  Map<String, dynamic> _kpis = {};

  // Getters
  NegocioModel? get negocioActivo => _negocioActivo;
  List<NegocioModel> get misNegocios => _misNegocios;
  bool get cargando => _cargando;
  String? get error => _error;
  Map<String, dynamic> get kpis => _kpis;
  
  /// ID del negocio activo (null = ver todos)
  String? get negocioId => _negocioActivo?.id;
  
  /// Nombre del negocio activo
  String get nombreNegocio => _negocioActivo?.nombre ?? 'Todos los Negocios';
  
  /// Icono del negocio activo
  String get iconoNegocio => _negocioActivo?.icono ?? '🏢';
  
  /// Tipo del negocio activo
  String get tipoNegocio => _negocioActivo?.tipo ?? 'global';
  
  /// ¿Está viendo todos los negocios?
  bool get esVistaGlobal => _negocioActivo == null;

  /// Cargar todos los negocios del superadmin
  Future<void> cargarNegocios() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await AppSupabase.client
          .from('negocios')
          .select()
          .eq('activo', true)
          .order('nombre');

      _misNegocios = (res as List)
          .map((e) => NegocioModel.fromMap(e))
          .toList();

      String? negocioActivoId;
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
      } catch (_) {}

      if (negocioActivoId != null) {
        for (final n in _misNegocios) {
          if (n.id == negocioActivoId) {
            _negocioActivo = n;
            break;
          }
        }
      }

      if (_negocioActivo == null && _misNegocios.isNotEmpty) {
        _negocioActivo = _misNegocios.first;
        try {
          await AppSupabase.client.from('configuracion_global').upsert({
            'clave': 'negocio_activo',
            'valor': {'id': _negocioActivo!.id},
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'clave');
        } catch (_) {}
      } else {
        _negocioActivo = null;
      }

      _cargando = false;
      notifyListeners();

      if (_negocioActivo != null) {
        await _cargarKPIsNegocio(_negocioActivo!.id);
      } else {
        await _cargarKPIsGlobales();
      }
    } catch (e) {
      _error = 'Error al cargar negocios: $e';
      _cargando = false;
      notifyListeners();
    }
  }

  /// Seleccionar un negocio activo
  Future<void> seleccionarNegocio(NegocioModel? negocio) async {
    _negocioActivo = negocio;
    notifyListeners();
    
    if (negocio != null) {
      await _cargarKPIsNegocio(negocio.id);
    } else {
      await _cargarKPIsGlobales();
    }
  }

  /// Cambiar al siguiente negocio (para swipe)
  void siguienteNegocio() {
    if (_misNegocios.isEmpty) return;
    
    if (_negocioActivo == null) {
      seleccionarNegocio(_misNegocios.first);
    } else {
      final idx = _misNegocios.indexWhere((n) => n.id == _negocioActivo!.id);
      if (idx < _misNegocios.length - 1) {
        seleccionarNegocio(_misNegocios[idx + 1]);
      } else {
        seleccionarNegocio(null); // Volver a vista global
      }
    }
  }

  /// Cambiar al negocio anterior (para swipe)
  void anteriorNegocio() {
    if (_misNegocios.isEmpty) return;
    
    if (_negocioActivo == null) {
      seleccionarNegocio(_misNegocios.last);
    } else {
      final idx = _misNegocios.indexWhere((n) => n.id == _negocioActivo!.id);
      if (idx > 0) {
        seleccionarNegocio(_misNegocios[idx - 1]);
      } else {
        seleccionarNegocio(null); // Volver a vista global
      }
    }
  }

  /// Cargar KPIs de un negocio específico
  Future<void> _cargarKPIsNegocio(String negocioId) async {
    try {
      // Clientes del negocio
      final clientesRes = await AppSupabase.client
          .from('clientes')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true);
      
      // Préstamos del negocio
      final prestamosRes = await AppSupabase.client
          .from('prestamos')
          .select('id, monto, estado')
          .eq('negocio_id', negocioId);
      
      // Tandas del negocio
      final tandasRes = await AppSupabase.client
          .from('tandas')
          .select('id, monto_por_persona, numero_participantes, estado')
          .eq('negocio_id', negocioId);
      
      // Sucursales del negocio
      final sucursalesRes = await AppSupabase.client
          .from('sucursales')
          .select('id')
          .eq('negocio_id', negocioId);
      
      // Empleados del negocio
      final empleadosRes = await AppSupabase.client
          .from('empleados')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true);

      // Calcular KPIs
      final prestamos = prestamosRes as List;
      final prestamosActivos = prestamos.where((p) => p['estado'] == 'activo').toList();
      final prestamosEnMora = prestamos.where((p) => p['estado'] == 'mora').toList();
      
      double carteraActiva = 0;
      for (var p in prestamosActivos) {
        carteraActiva += (p['monto'] as num?)?.toDouble() ?? 0;
      }

      final tandas = tandasRes as List;
      final tandasActivas = tandas.where((t) => t['estado'] == 'activa').toList();
      double bolsaTandas = 0;
      for (var t in tandasActivas) {
        final monto = (t['monto_por_persona'] as num?)?.toDouble() ?? 0;
        final participantes = (t['numero_participantes'] as num?)?.toInt() ?? 0;
        bolsaTandas += monto * participantes;
      }

      _kpis = {
        'clientes': (clientesRes as List).length,
        'prestamos_total': prestamos.length,
        'prestamos_activos': prestamosActivos.length,
        'prestamos_mora': prestamosEnMora.length,
        'cartera_activa': carteraActiva,
        'tandas_total': tandas.length,
        'tandas_activas': tandasActivas.length,
        'bolsa_tandas': bolsaTandas,
        'sucursales': (sucursalesRes as List).length,
        'empleados': (empleadosRes as List).length,
      };
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando KPIs: $e');
    }
  }

  /// Cargar KPIs globales (todos los negocios)
  Future<void> _cargarKPIsGlobales() async {
    try {
      final clientesRes = await AppSupabase.client
          .from('clientes')
          .select('id')
          .eq('activo', true);
      
      final prestamosRes = await AppSupabase.client
          .from('prestamos')
          .select('id, monto, estado');
      
      final tandasRes = await AppSupabase.client
          .from('tandas')
          .select('id, monto_por_persona, numero_participantes, estado');
      
      final negociosRes = await AppSupabase.client
          .from('negocios')
          .select('id')
          .eq('activo', true);

      final prestamos = prestamosRes as List;
      final prestamosActivos = prestamos.where((p) => p['estado'] == 'activo').toList();
      
      double carteraTotal = 0;
      for (var p in prestamos) {
        carteraTotal += (p['monto'] as num?)?.toDouble() ?? 0;
      }

      final tandas = tandasRes as List;
      double bolsaTotal = 0;
      for (var t in tandas) {
        final monto = (t['monto_por_persona'] as num?)?.toDouble() ?? 0;
        final participantes = (t['numero_participantes'] as num?)?.toInt() ?? 0;
        bolsaTotal += monto * participantes;
      }

      _kpis = {
        'negocios': (negociosRes as List).length,
        'clientes': (clientesRes as List).length,
        'prestamos_total': prestamos.length,
        'prestamos_activos': prestamosActivos.length,
        'cartera_total': carteraTotal,
        'tandas_total': tandas.length,
        'bolsa_total': bolsaTotal,
      };
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando KPIs globales: $e');
    }
  }

  /// Crear un nuevo negocio
  Future<bool> crearNegocio({
    required String nombre,
    required String tipo,
    String? descripcion,
    String? telefono,
    String? email,
  }) async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId == null) {
        _error = 'No hay sesión activa';
        notifyListeners();
        return false;
      }

      final nuevo = await AppSupabase.client.from('negocios').insert({
        'nombre': nombre,
        'tipo': tipo,
        'descripcion': descripcion,
        'telefono': telefono,
        'email': email,
        'activo': true,
        'propietario_id': userId,
      }).select('id').single();

      // Registrar acceso del creador al negocio
      try {
        await AppSupabase.client.from('usuarios_negocios').insert({
          'usuario_id': userId,
          'negocio_id': nuevo['id'],
          'rol_negocio': 'propietario',
          'activo': true,
        });
      } catch (_) {}

      await cargarNegocios();
      return true;
    } catch (e) {
      _error = 'Error al crear negocio: $e';
      notifyListeners();
      return false;
    }
  }

  /// Archivar (desactivar) un negocio sin borrar datos
  Future<bool> archivarNegocio(String negocioId) async {
    try {
      await AppSupabase.client
          .from('negocios')
          .update({'activo': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', negocioId);

      if (_negocioActivo?.id == negocioId) {
        _negocioActivo = null;
      }
      await cargarNegocios();
      return true;
    } catch (e) {
      _error = 'Error al archivar negocio: $e';
      notifyListeners();
      return false;
    }
  }

  /// Filtro SQL para consultas - retorna condición para negocio_id
  Map<String, dynamic>? getFiltroNegocio() {
    if (_negocioActivo == null) return null;
    return {'negocio_id': _negocioActivo!.id};
  }
}

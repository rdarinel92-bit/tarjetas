// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO NICE - Joyería y Accesorios
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../data/models/nice_models.dart';

class NiceService {
  static final _client = AppSupabase.client;

  // ═══════════════════════════════════════════════════════════════════════════
  // CATÁLOGOS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceCatalogo>> getCatalogos(String negocioId) async {
    try {
      final res = await _client
          .from('nice_catalogos')
          .select()
          .eq('negocio_id', negocioId)
          .order('orden');
      return (res as List).map((e) => NiceCatalogo.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getCatalogos: $e');
      return [];
    }
  }

  static Future<NiceCatalogo?> crearCatalogo(NiceCatalogo catalogo) async {
    try {
      final res = await _client
          .from('nice_catalogos')
          .insert(catalogo.toMapForInsert())
          .select()
          .single();
      return NiceCatalogo.fromMap(res);
    } catch (e) {
      debugPrint('Error crearCatalogo: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORÍAS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceCategoria>> getCategorias({String? negocioId}) async {
    try {
      var query = _client.from('nice_categorias').select();
      if (negocioId != null) {
        query = query.or('negocio_id.eq.$negocioId,negocio_id.is.null');
      }
      final res = await query.eq('activo', true).order('orden');
      return (res as List).map((e) => NiceCategoria.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getCategorias: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceProducto>> getProductos({
    required String negocioId,
    String? categoriaId,
    String? catalogoId,
    String? busqueda,
    bool soloDisponibles = false,
    bool soloDestacados = false,
  }) async {
    try {
      final res = await _client
          .from('v_nice_productos_completo')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('nombre');

      List<NiceProducto> productos = (res as List)
          .map((e) => NiceProducto.fromMap(e))
          .toList();

      // Filtros adicionales
      if (categoriaId != null) {
        productos = productos.where((p) => p.categoriaId == categoriaId).toList();
      }
      if (catalogoId != null) {
        productos = productos.where((p) => p.catalogoId == catalogoId).toList();
      }
      if (soloDisponibles) {
        productos = productos.where((p) => p.stock > 0).toList();
      }
      if (soloDestacados) {
        productos = productos.where((p) => p.esDestacado).toList();
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        final query = busqueda.toLowerCase();
        productos = productos.where((p) =>
            p.nombre.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            (p.descripcion?.toLowerCase().contains(query) ?? false)
        ).toList();
      }

      return productos;
    } catch (e) {
      debugPrint('Error getProductos: $e');
      return [];
    }
  }

  static Future<NiceProducto?> getProducto(String id) async {
    try {
      final res = await _client
          .from('v_nice_productos_completo')
          .select()
          .eq('id', id)
          .single();
      return NiceProducto.fromMap(res);
    } catch (e) {
      debugPrint('Error getProducto: $e');
      return null;
    }
  }

  static Future<NiceProducto?> crearProducto(NiceProducto producto) async {
    try {
      final res = await _client
          .from('nice_productos')
          .insert(producto.toMapForInsert())
          .select()
          .single();
      return NiceProducto.fromMap(res);
    } catch (e) {
      debugPrint('Error crearProducto: $e');
      return null;
    }
  }

  static Future<bool> actualizarProducto(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('nice_productos').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarProducto: $e');
      return false;
    }
  }

  static Future<bool> actualizarStock(String productoId, int nuevoStock, {String? motivo}) async {
    try {
      // Obtener stock actual
      final producto = await _client
          .from('nice_productos')
          .select('stock')
          .eq('id', productoId)
          .single();
      
      final stockAnterior = producto['stock'] ?? 0;

      // Actualizar stock
      await _client.from('nice_productos').update({
        'stock': nuevoStock,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productoId);

      // Registrar movimiento
      await _client.from('nice_inventario_movimientos').insert({
        'producto_id': productoId,
        'tipo': nuevoStock > stockAnterior ? 'entrada' : 'salida',
        'cantidad': (nuevoStock - stockAnterior).abs(),
        'stock_anterior': stockAnterior,
        'stock_nuevo': nuevoStock,
        'motivo': motivo ?? 'Ajuste manual',
      });

      return true;
    } catch (e) {
      debugPrint('Error actualizarStock: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVELES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceNivel>> getNiveles({String? negocioId}) async {
    try {
      var query = _client.from('nice_niveles').select();
      if (negocioId != null) {
        query = query.or('negocio_id.eq.$negocioId,negocio_id.is.null');
      }
      final res = await query.eq('activo', true).order('orden');
      return (res as List).map((e) => NiceNivel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getNiveles: $e');
      return [];
    }
  }

  static Future<NiceNivel?> getNivelInicial() async {
    try {
      final res = await _client
          .from('nice_niveles')
          .select()
          .eq('codigo', 'inicio')
          .single();
      return NiceNivel.fromMap(res);
    } catch (e) {
      debugPrint('Error getNivelInicial: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VENDEDORAS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceVendedora>> getVendedoras({
    required String negocioId,
    bool? soloActivas,
    String? patrocinadoraId,
  }) async {
    try {
      final res = await _client
          .from('v_nice_vendedoras_stats')
          .select()
          .eq('negocio_id', negocioId)
          .order('nombre');

      List<NiceVendedora> vendedoras = (res as List)
          .map((e) => NiceVendedora.fromMap(e))
          .toList();

      if (soloActivas == true) {
        vendedoras = vendedoras.where((v) => v.activo).toList();
      }
      if (patrocinadoraId != null) {
        vendedoras = vendedoras.where((v) => v.patrocinadoraId == patrocinadoraId).toList();
      }

      return vendedoras;
    } catch (e) {
      debugPrint('Error getVendedoras: $e');
      return [];
    }
  }

  static Future<NiceVendedora?> getVendedora(String id) async {
    try {
      final res = await _client
          .from('v_nice_vendedoras_stats')
          .select()
          .eq('id', id)
          .single();
      return NiceVendedora.fromMap(res);
    } catch (e) {
      debugPrint('Error getVendedora: $e');
      return null;
    }
  }

  static Future<NiceVendedora?> crearVendedora(NiceVendedora vendedora) async {
    try {
      // Obtener nivel inicial si no tiene
      String? nivelId = vendedora.nivelId;
      if (nivelId == null) {
        final nivelInicial = await getNivelInicial();
        nivelId = nivelInicial?.id;
      }

      final data = vendedora.toMapForInsert();
      data['nivel_id'] = nivelId;

      final res = await _client
          .from('nice_vendedoras')
          .insert(data)
          .select()
          .single();

      // Actualizar equipo directo de patrocinadora
      if (vendedora.patrocinadoraId != null) {
        // Se actualiza automáticamente en la vista
      }

      return NiceVendedora.fromMap(res);
    } catch (e) {
      debugPrint('Error crearVendedora: $e');
      return null;
    }
  }

  static Future<bool> actualizarVendedora(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('nice_vendedoras').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarVendedora: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getArbolEquipo(String vendedoraId) async {
    try {
      final res = await _client
          .from('v_nice_arbol_equipo')
          .select()
          .contains('ruta', [vendedoraId])
          .order('profundidad');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getArbolEquipo: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceCliente>> getClientes({
    required String negocioId,
    String? vendedoraId,
    bool? soloActivos,
    bool? soloVip,
  }) async {
    try {
      var query = _client
          .from('nice_clientes')
          .select()
          .eq('negocio_id', negocioId);

      if (vendedoraId != null) {
        query = query.eq('vendedora_id', vendedoraId);
      }
      if (soloActivos == true) {
        query = query.eq('activo', true);
      }
      if (soloVip == true) {
        query = query.eq('es_vip', true);
      }

      final res = await query.order('nombre');
      return (res as List).map((e) => NiceCliente.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getClientes: $e');
      return [];
    }
  }

  static Future<NiceCliente?> crearCliente(NiceCliente cliente) async {
    try {
      final res = await _client
          .from('nice_clientes')
          .insert(cliente.toMapForInsert())
          .select()
          .single();
      return NiceCliente.fromMap(res);
    } catch (e) {
      debugPrint('Error crearCliente: $e');
      return null;
    }
  }

  static Future<bool> actualizarCliente(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('nice_clientes').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarCliente: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PEDIDOS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NicePedido>> getPedidos({
    required String negocioId,
    String? vendedoraId,
    String? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      var query = _client
          .from('v_nice_pedidos_completo')
          .select()
          .eq('negocio_id', negocioId);

      if (vendedoraId != null) {
        query = query.eq('vendedora_id', vendedoraId);
      }
      if (estado != null) {
        query = query.eq('estado', estado);
      }

      final res = await query.order('fecha_pedido', ascending: false);
      
      List<NicePedido> pedidos = (res as List)
          .map((e) => NicePedido.fromMap(e))
          .toList();

      if (fechaInicio != null) {
        pedidos = pedidos.where((p) => !p.fechaPedido.isBefore(fechaInicio)).toList();
      }
      if (fechaFin != null) {
        pedidos = pedidos.where((p) => !p.fechaPedido.isAfter(fechaFin)).toList();
      }

      return pedidos;
    } catch (e) {
      debugPrint('Error getPedidos: $e');
      return [];
    }
  }

  static Future<NicePedido?> getPedido(String id) async {
    try {
      final res = await _client
          .from('v_nice_pedidos_completo')
          .select()
          .eq('id', id)
          .single();
      return NicePedido.fromMap(res);
    } catch (e) {
      debugPrint('Error getPedido: $e');
      return null;
    }
  }

  static Future<List<NicePedidoItem>> getPedidoItems(String pedidoId) async {
    try {
      final res = await _client
          .from('nice_pedido_items')
          .select()
          .eq('pedido_id', pedidoId)
          .order('created_at');
      return (res as List).map((e) => NicePedidoItem.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getPedidoItems: $e');
      return [];
    }
  }

  static Future<NicePedido?> crearPedido({
    required String negocioId,
    required String vendedoraId,
    String? clienteId,
    String? catalogoId,
    required List<Map<String, dynamic>> items,
    String tipoEnvio = 'recoger',
    String? direccionEnvio,
    String? clienteNombre,
    String? clienteTelefono,
    String? notas,
  }) async {
    try {
      // Calcular totales
      double subtotal = 0;
      double gananciaTotal = 0;

      for (var item in items) {
        subtotal += (item['precio_unitario'] ?? 0) * (item['cantidad'] ?? 1);
        gananciaTotal += (item['ganancia'] ?? 0) * (item['cantidad'] ?? 1);
      }

      // Crear pedido
      final pedidoData = {
        'negocio_id': negocioId,
        'vendedora_id': vendedoraId,
        'cliente_id': clienteId,
        'catalogo_id': catalogoId,
        'subtotal': subtotal,
        'total': subtotal, // Por ahora sin envío ni descuento
        'ganancia_vendedora': gananciaTotal, // Ganancia calculada
        'tipo_envio': tipoEnvio,
        'direccion_entrega': direccionEnvio,
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'notas_vendedora': notas,
      };

      final pedidoRes = await _client
          .from('nice_pedidos')
          .insert(pedidoData)
          .select()
          .single();

      final pedidoId = pedidoRes['id'];

      // Crear items
      for (var item in items) {
        item['pedido_id'] = pedidoId;
        await _client.from('nice_pedido_items').insert(item);
      }

      // Crear comisiones multinivel
      await _crearComisionesMultinivelNice(pedidoId);

      return NicePedido.fromMap(pedidoRes);
    } catch (e) {
      debugPrint('Error crearPedido: $e');
      return null;
    }
  }

  static Future<void> _crearComisionesMultinivelNice(String pedidoId) async {
    try {
      final existentes = await _client
          .from('nice_comisiones')
          .select('id')
          .eq('pedido_id', pedidoId)
          .limit(1);
      if ((existentes as List).isNotEmpty) return;

      final pedido = await _client
          .from('nice_pedidos')
          .select('id, vendedora_id, total, ganancia_vendedora')
          .eq('id', pedidoId)
          .single();

      final vendedora = await _client
          .from('nice_vendedoras')
          .select('id, nivel_id, patrocinadora_id')
          .eq('id', pedido['vendedora_id'])
          .single();

      final nivel = await _client
          .from('nice_niveles')
          .select(
              'comision_ventas, comision_equipo_n1, comision_equipo_n2, comision_equipo_n3, comision_porcentaje')
          .eq('id', vendedora['nivel_id'])
          .maybeSingle();

      final base = ((pedido['total'] ?? 0) as num).toDouble();
      final porcentajeDirecto =
          (nivel?['comision_ventas'] ?? nivel?['comision_porcentaje'] ?? 0) as num;
      final montoDirecto = (base * porcentajeDirecto / 100).toDouble();

      if (montoDirecto > 0) {
        await _client.from('nice_comisiones').insert({
          'vendedora_id': vendedora['id'],
          'pedido_id': pedidoId,
          'tipo': 'venta_directa',
          'monto': montoDirecto,
          'porcentaje': porcentajeDirecto,
          'descripcion': 'Comision venta directa',
          'estado': 'pendiente',
        });

        await _client
            .from('nice_pedidos')
            .update({'comision_vendedora': montoDirecto})
            .eq('id', pedidoId);
      }

      final niveles = [
        'comision_equipo_n1',
        'comision_equipo_n2',
        'comision_equipo_n3',
      ];

      String? patrocinadoraId = vendedora['patrocinadora_id'];
      for (var i = 0; i < niveles.length; i++) {
        if (patrocinadoraId == null) break;

        final sponsor = await _client
            .from('nice_vendedoras')
            .select('id, nivel_id, patrocinadora_id')
            .eq('id', patrocinadoraId)
            .maybeSingle();
        if (sponsor == null) break;

        final nivelSponsor = await _client
            .from('nice_niveles')
            .select('comision_equipo_n1, comision_equipo_n2, comision_equipo_n3')
            .eq('id', sponsor['nivel_id'])
            .maybeSingle();

        final porcentaje =
            (nivelSponsor?[niveles[i]] ?? 0) as num;
        final monto = (base * porcentaje / 100).toDouble();
        if (monto > 0) {
          await _client.from('nice_comisiones').insert({
            'vendedora_id': sponsor['id'],
            'pedido_id': pedidoId,
            'tipo': 'equipo_n${i + 1}',
            'monto': monto,
            'porcentaje': porcentaje,
            'descripcion': 'Comision equipo nivel ${i + 1}',
            'estado': 'pendiente',
          });
        }

        patrocinadoraId = sponsor['patrocinadora_id'];
      }
    } catch (e) {
      debugPrint('Error crearComisionesMultinivelNice: $e');
    }
  }

  static Future<bool> actualizarEstadoPedido(String pedidoId, String nuevoEstado) async {
    try {
      final data = <String, dynamic>{
        'estado': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Agregar fecha según estado
      switch (nuevoEstado) {
        case 'confirmado':
          break;
        case 'pagado':
          break;
        case 'enviado':
          break;
        case 'entregado':
          data['fecha_entrega_real'] = DateTime.now().toIso8601String();
          break;
      }

      await _client.from('nice_pedidos').update(data).eq('id', pedidoId);
      return true;
    } catch (e) {
      debugPrint('Error actualizarEstadoPedido: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMISIONES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<NiceComision>> getComisiones({
    required String negocioId,
    String? vendedoraId,
    String? periodo,
    String? estado,
  }) async {
    try {
      var query = _client.from('v_nice_comisiones_completo').select();

      if (negocioId.isNotEmpty) {
        final vendedoras = await _client
            .from('nice_vendedoras')
            .select('id')
            .eq('negocio_id', negocioId);
        final vendedoraIds =
            (vendedoras as List).map((v) => v['id'] as String).toList();
        if (vendedoraIds.isEmpty) return [];
        query = query.inFilter('vendedora_id', vendedoraIds);
      }

      if (vendedoraId != null) {
        query = query.eq('vendedora_id', vendedoraId);
      }
      if (periodo != null) {
        DateTime? inicio;
        try {
          if (periodo.length >= 10) {
            inicio = DateTime.parse(periodo);
          } else if (periodo.length >= 7) {
            inicio = DateTime.parse('${periodo}-01');
          }
        } catch (_) {
          inicio = null;
        }
        if (inicio != null) {
          final fin = DateTime(inicio.year, inicio.month + 1, 1);
          query = query
              .gte('created_at', inicio.toIso8601String())
              .lt('created_at', fin.toIso8601String());
        }
      }
      if (estado != null) {
        query = query.eq('estado', estado);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((e) => NiceComision.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getComisiones: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getResumenComisiones({
    required String vendedoraId,
    required String periodo,
  }) async {
    try {
      final comisiones = await getComisiones(
        negocioId: '', // Se filtra por vendedora
        vendedoraId: vendedoraId,
        periodo: periodo,
      );

      double totalVentasDirectas = 0;
      double totalEquipoN1 = 0;
      double totalEquipoN2 = 0;
      double totalEquipoN3 = 0;
      double totalBonos = 0;

      for (var c in comisiones) {
        switch (c.tipo) {
          case 'venta_directa':
            totalVentasDirectas += c.monto;
            break;
          case 'equipo_n1':
            totalEquipoN1 += c.monto;
            break;
          case 'equipo_n2':
            totalEquipoN2 += c.monto;
            break;
          case 'equipo_n3':
            totalEquipoN3 += c.monto;
            break;
          case 'bono_rango':
          case 'bono_meta':
            totalBonos += c.monto;
            break;
        }
      }

      return {
        'ventas_directas': totalVentasDirectas,
        'equipo_n1': totalEquipoN1,
        'equipo_n2': totalEquipoN2,
        'equipo_n3': totalEquipoN3,
        'bonos': totalBonos,
        'total': totalVentasDirectas + totalEquipoN1 + totalEquipoN2 + totalEquipoN3 + totalBonos,
        'cantidad_comisiones': comisiones.length,
      };
    } catch (e) {
      debugPrint('Error getResumenComisiones: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS Y REPORTES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getDashboardStats(String negocioId) async {
    try {
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1);
      final finMes = DateTime(now.year, now.month + 1, 0);

      // Vendedoras activas
      final vendedorasRes = await _client
          .from('nice_vendedoras')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true);
      final totalVendedoras = (vendedorasRes as List).length;

      // Pedidos del mes
      final pedidosRes = await _client
          .from('nice_pedidos')
          .select('id, total, estado')
          .eq('negocio_id', negocioId)
          .gte('fecha_pedido', inicioMes.toIso8601String().split('T')[0])
          .lte('fecha_pedido', finMes.toIso8601String().split('T')[0]);

      final pedidos = pedidosRes as List;
      final totalPedidos = pedidos.length;
      double ventasMes = 0;
      int pedidosPendientes = 0;

      for (var p in pedidos) {
        if (p['estado'] != 'cancelado') {
          ventasMes += (p['total'] ?? 0).toDouble();
        }
        if (p['estado'] == 'pendiente') {
          pedidosPendientes++;
        }
      }

      // Clientes totales
      final clientesRes = await _client
          .from('nice_clientes')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true);
      final totalClientes = (clientesRes as List).length;

      // Productos con stock bajo
      final stockBajoRes = await _client
          .from('nice_productos')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .lte('stock', 5);
      final productosStockBajo = (stockBajoRes as List).length;

      return {
        'total_vendedoras': totalVendedoras,
        'total_pedidos_mes': totalPedidos,
        'ventas_mes': ventasMes,
        'pedidos_pendientes': pedidosPendientes,
        'total_clientes': totalClientes,
        'productos_stock_bajo': productosStockBajo,
      };
    } catch (e) {
      debugPrint('Error getDashboardStats: $e');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getTopVendedoras({
    required String negocioId,
    int limite = 10,
  }) async {
    try {
      final res = await _client
          .from('v_nice_vendedoras_stats')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('ventas_mes', ascending: false)
          .limit(limite);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getTopVendedoras: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTopProductos({
    required String negocioId,
    int limite = 10,
  }) async {
    try {
      final res = await _client
          .from('nice_productos')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('veces_vendido', ascending: false)
          .limit(limite);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getTopProductos: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS ADICIONALES DE GESTIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Actualizar un pedido existente
  static Future<bool> actualizarPedido(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('nice_pedidos').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarPedido: $e');
      return false;
    }
  }

  /// Cambiar estado de un pedido
  static Future<bool> cambiarEstadoPedido(String pedidoId, String nuevoEstado) async {
    try {
      final data = <String, dynamic>{
        'estado': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Agregar fecha según el estado
      switch (nuevoEstado) {
        case 'confirmado':
          data['fecha_confirmacion'] = DateTime.now().toIso8601String();
          break;
        case 'pagado':
          data['fecha_pago'] = DateTime.now().toIso8601String();
          data['pagado'] = true;
          break;
        case 'enviado':
          data['fecha_envio'] = DateTime.now().toIso8601String();
          break;
        case 'entregado':
          data['fecha_entrega'] = DateTime.now().toIso8601String();
          break;
      }

      await _client.from('nice_pedidos').update(data).eq('id', pedidoId);
      return true;
    } catch (e) {
      debugPrint('Error cambiarEstadoPedido: $e');
      return false;
    }
  }

  /// Ajustar stock de producto (alias de actualizarStock)
  static Future<bool> ajustarStock(String productoId, int cantidad, {String? motivo}) async {
    return await actualizarStock(productoId, cantidad, motivo: motivo);
  }

  /// Crear categoría
  static Future<NiceCategoria?> crearCategoria(NiceCategoria categoria) async {
    try {
      final res = await _client
          .from('nice_categorias')
          .insert(categoria.toMap()..remove('id'))
          .select()
          .single();
      return NiceCategoria.fromMap(res);
    } catch (e) {
      debugPrint('Error crearCategoria: $e');
      return null;
    }
  }

  /// Actualizar categoría
  static Future<bool> actualizarCategoria(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('nice_categorias').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarCategoria: $e');
      return false;
    }
  }

  /// Actualizar catálogo
  static Future<bool> actualizarCatalogo(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('nice_catalogos').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error actualizarCatalogo: $e');
      return false;
    }
  }

  /// Obtener catálogos con opción de negocioId opcional
  static Future<List<NiceCatalogo>> getCatalogosOptional({String? negocioId}) async {
    try {
      var query = _client.from('nice_catalogos').select();
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      final res = await query.order('orden');
      return (res as List).map((e) => NiceCatalogo.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getCatalogosOptional: $e');
      return [];
    }
  }
}

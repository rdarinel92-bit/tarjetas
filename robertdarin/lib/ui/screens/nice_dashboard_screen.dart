// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL - MÓDULO NICE (Joyería y Accesorios)
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../navigation/app_routes.dart';
import '../../core/supabase_client.dart';
import '../../services/nice_service.dart';
import 'nice_vendedoras_screen.dart';
import 'nice_productos_screen.dart';
import 'nice_pedidos_screen.dart';
import 'nice_clientes_screen.dart';

class NiceDashboardScreen extends StatefulWidget {
  final String? negocioId;
  
  const NiceDashboardScreen({super.key, this.negocioId});

  @override
  State<NiceDashboardScreen> createState() => _NiceDashboardScreenState();
}

class _NiceDashboardScreenState extends State<NiceDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _negocioId;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topVendedoras = [];
  List<Map<String, dynamic>> _pedidosRecientes = [];
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _negocioId = widget.negocioId;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    setState(() => _isLoading = true);
    try {
      // Si viene negocioId vacío, intentar obtenerlo
      if (_negocioId == null || _negocioId!.isEmpty) {
        // Primero intentar del usuario actual mediante empleados
        final user = AppSupabase.client.auth.currentUser;
        if (user != null) {
          final empleado = await AppSupabase.client
              .from('empleados')
              .select('negocio_id')
              .eq('usuario_id', user.id)
              .maybeSingle();
          if (empleado != null) {
            _negocioId = empleado['negocio_id'];
          }
        }
      }
      
      // Si aún no hay negocioId, intentar de configuracion_global
      if (_negocioId == null || _negocioId!.isEmpty) {
        final configRes = await AppSupabase.client
            .from('configuracion_global')
            .select()
            .eq('clave', 'negocio_activo')
            .maybeSingle();

        if (configRes != null) {
          _negocioId = configRes['valor']?['id'];
        }
      }

      // Último intento: obtener el primer negocio
      if (_negocioId == null || _negocioId!.isEmpty) {
        final negociosRes = await AppSupabase.client
            .from('negocios')
            .select('id')
            .limit(1)
            .maybeSingle();
        _negocioId = negociosRes?['id'];
      }

      if (_negocioId != null) {
        // Cargar estadísticas
        _stats = await NiceService.getDashboardStats(_negocioId!);

        // Top vendedoras
        _topVendedoras = await NiceService.getTopVendedoras(
          negocioId: _negocioId!,
          limite: 5,
        );

        // Pedidos recientes
        final pedidos = await NiceService.getPedidos(
          negocioId: _negocioId!,
        );
        _pedidosRecientes = pedidos
            .take(5)
            .map((p) => {
                  'folio': p.folio,
                  'vendedora': p.vendedoraNombre ?? 'Sin vendedora',
                  'total': p.total,
                  'estado': p.estado,
                  'fecha': p.fechaPedido,
                })
            .toList();
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'NICE & BELLA',
      subtitle: 'Joyería y Accesorios',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarDatos,
          tooltip: 'Actualizar',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : (_negocioId == null || _negocioId!.isEmpty)
              ? _buildNoNegocioMessage()
              : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                color: Colors.pinkAccent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards
                      _buildStatsRow(),
                      const SizedBox(height: 20),

                      // Accesos rápidos
                      _buildAccesosRapidos(),
                      const SizedBox(height: 20),

                      // Top Vendedoras
                      _buildTopVendedoras(),
                      const SizedBox(height: 20),

                      // Pedidos recientes
                      _buildPedidosRecientes(),
                      const SizedBox(height: 20),

                      // Alertas
                      if (_stats['productos_stock_bajo'] != null && 
                          _stats['productos_stock_bajo'] > 0)
                        _buildAlertaStock(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNoNegocioMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.diamond_outlined,
                size: 80,
                color: Colors.pinkAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '💎 NICE & BELLA Joyería',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sin Negocio Configurado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.pinkAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Para comenzar a usar el módulo de joyería,\ncrea tu negocio NICE.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _crearNegocioNice,
              icon: const Icon(Icons.add_business),
              label: const Text('Crear Negocio NICE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _cargarDatos,
              icon: Icon(Icons.refresh, color: Colors.grey[400]),
              label: Text('Reintentar', style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearNegocioNice() async {
    final nombreController = TextEditingController(text: 'NICE & BELLA Joyería');
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.diamond, color: Colors.pinkAccent),
            ),
            const SizedBox(width: 12),
            const Text('Crear Negocio NICE', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre del Negocio',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.store, color: Colors.pinkAccent),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.phone, color: Colors.pinkAccent),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email (opcional)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.email, color: Colors.pinkAccent),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Crear'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
        );
        
        // Crear negocio
        final nuevoNegocio = await AppSupabase.client.from('negocios').insert({
          'nombre': nombreController.text.trim(),
          'tipo': 'retail',
          'telefono': telefonoController.text.trim().isEmpty ? null : telefonoController.text.trim(),
          'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          'color_primario': '#E91E63',
          'activo': true,
        }).select().single();
        
        final negocioId = nuevoNegocio['id'];
        
        // Vincular usuario al negocio
        final user = AppSupabase.client.auth.currentUser;
        if (user != null) {
          // Obtener usuario_id de la tabla usuarios
          final usuario = await AppSupabase.client
              .from('usuarios')
              .select('id')
              .eq('id', user.id)
              .maybeSingle();
          
          if (usuario != null) {
            // Verificar si ya existe la relación
            final existente = await AppSupabase.client
                .from('usuarios_negocios')
                .select('id')
                .eq('usuario_id', usuario['id'])
                .eq('negocio_id', negocioId)
                .maybeSingle();
            
            if (existente == null) {
              await AppSupabase.client.from('usuarios_negocios').insert({
                'usuario_id': usuario['id'],
                'negocio_id': negocioId,
                'rol_negocio': 'propietario',
                'activo': true,
              });
            }
          }
        }
        
        // Cerrar loading
        if (mounted) Navigator.pop(context);
        
        // Mostrar éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('¡Negocio "${nombreController.text}" creado!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Recargar datos
        _negocioId = negocioId;
        _cargarDatos();
        
      } catch (e) {
        // Cerrar loading
        if (mounted) Navigator.pop(context);
        
        debugPrint('Error creando negocio NICE: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Ventas del Mes',
                _formatCurrency.format(_stats['ventas_mes'] ?? 0),
                Icons.trending_up,
                Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pedidos',
                '${_stats['total_pedidos_mes'] ?? 0}',
                Icons.shopping_bag,
                Colors.pinkAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Vendedoras',
                '${_stats['total_vendedoras'] ?? 0}',
                Icons.people,
                Colors.purpleAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Clientes',
                '${_stats['total_clientes'] ?? 0}',
                Icons.person_pin,
                Colors.cyanAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_upward, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesosRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acceso Rápido',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccesoCard(
                'Vendedoras',
                Icons.people_outline,
                Colors.pinkAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NiceVendedorasScreen(negocioId: _negocioId!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccesoCard(
                'Catálogo',
                Icons.diamond_outlined,
                Colors.purpleAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NiceProductosScreen(negocioId: _negocioId!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccesoCard(
                'Pedidos',
                Icons.shopping_cart_outlined,
                Colors.orangeAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NicePedidosScreen(negocioId: _negocioId!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccesoCard(
                'Clientes',
                Icons.person_outline,
                Colors.cyanAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NiceClientesScreen(negocioId: _negocioId!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAccesoCard(
                'Tarjetas QR',
                Icons.qr_code_2,
                Colors.pinkAccent,
                () => Navigator.pushNamed(context, AppRoutes.niceTarjetasQr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccesoCard(
                'Facturas NICE',
                Icons.receipt_long,
                Colors.indigoAccent,
                () => Navigator.pushNamed(context, AppRoutes.niceFacturas),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccesoCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _negocioId != null ? onTap : null,
      child: PremiumCard(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopVendedoras() {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Top Vendedoras del Mes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _negocioId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NiceVendedorasScreen(negocioId: _negocioId!),
                            ),
                          )
                      : null,
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_topVendedoras.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aún no hay vendedoras registradas',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              ...List.generate(_topVendedoras.length, (index) {
                final vendedora = _topVendedoras[index];
                final ventasMes = (vendedora['ventas_mes'] ?? 0).toDouble();
                return _buildVendedoraItem(
                  index + 1,
                  vendedora['nombre'] ?? 'Sin nombre',
                  vendedora['nivel_nombre'] ?? 'Inicio',
                  vendedora['nivel_color'] ?? '#666666',
                  ventasMes,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildVendedoraItem(int posicion, String nombre, String nivel, String colorHex, double ventas) {
    Color medalColor;
    IconData medalIcon;
    
    switch (posicion) {
      case 1:
        medalColor = Colors.amber;
        medalIcon = Icons.looks_one;
        break;
      case 2:
        medalColor = Colors.grey.shade400;
        medalIcon = Icons.looks_two;
        break;
      case 3:
        medalColor = Colors.brown.shade400;
        medalIcon = Icons.looks_3;
        break;
      default:
        medalColor = Colors.white54;
        medalIcon = Icons.circle;
    }

    Color nivelColor;
    try {
      nivelColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    } catch (_) {
      nivelColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(medalIcon, color: medalColor, size: 28),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: nivelColor.withOpacity(0.2),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: TextStyle(
                color: nivelColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  nivel,
                  style: TextStyle(
                    color: nivelColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency.format(ventas),
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosRecientes() {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.orangeAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Pedidos Recientes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _negocioId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NicePedidosScreen(negocioId: _negocioId!),
                            ),
                          )
                      : null,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_pedidosRecientes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No hay pedidos recientes',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              ...List.generate(_pedidosRecientes.length, (index) {
                final pedido = _pedidosRecientes[index];
                return _buildPedidoItem(pedido);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoItem(Map<String, dynamic> pedido) {
    Color estadoColor;
    String estadoTexto;

    switch (pedido['estado']) {
      case 'pendiente':
        estadoColor = Colors.orangeAccent;
        estadoTexto = 'Pendiente';
        break;
      case 'confirmado':
        estadoColor = Colors.blueAccent;
        estadoTexto = 'Confirmado';
        break;
      case 'pagado':
        estadoColor = Colors.greenAccent;
        estadoTexto = 'Pagado';
        break;
      case 'enviado':
        estadoColor = Colors.purpleAccent;
        estadoTexto = 'Enviado';
        break;
      case 'entregado':
        estadoColor = Colors.tealAccent;
        estadoTexto = 'Entregado';
        break;
      case 'cancelado':
        estadoColor = Colors.redAccent;
        estadoTexto = 'Cancelado';
        break;
      default:
        estadoColor = Colors.grey;
        estadoTexto = pedido['estado'] ?? 'Desconocido';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt, color: estadoColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido['folio'] ?? 'Sin folio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pedido['vendedora'] ?? 'Sin vendedora',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency.format(pedido['total'] ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estadoTexto,
                  style: TextStyle(
                    color: estadoColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaStock() {
    return PremiumCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Bajo',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_stats['productos_stock_bajo']} productos con stock bajo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // Ir a productos con filtro de stock bajo
              },
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

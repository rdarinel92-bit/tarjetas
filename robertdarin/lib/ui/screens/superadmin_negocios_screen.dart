import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/negocio_activo_provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../data/models/negocio_model.dart';
import '../../core/supabase_client.dart';

/// Pantalla principal del Superadmin - Selector de Negocios
/// Muestra todos los negocios con KPIs y permite entrar a cada uno
class SuperadminNegociosScreen extends StatefulWidget {
  const SuperadminNegociosScreen({super.key});

  @override
  State<SuperadminNegociosScreen> createState() => _SuperadminNegociosScreenState();
}

class _SuperadminNegociosScreenState extends State<SuperadminNegociosScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  final _formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  // KPIs globales
  Map<String, dynamic> _kpisGlobales = {};
  bool _cargandoKpis = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NegocioActivoProvider>().cargarNegocios();
      _cargarKPIsGlobales();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _cargarKPIsGlobales() async {
    try {
      // Cargar KPIs de todos los negocios
      final negocios = await AppSupabase.client
          .from('negocios').select('id, nombre, tipo').eq('activo', true);
      
      final clientes = await AppSupabase.client
          .from('clientes').select('id').eq('activo', true);
      
      final prestamos = await AppSupabase.client
          .from('prestamos').select('id, monto, estado');
      
      final tandas = await AppSupabase.client
          .from('tandas').select('id, estado');

      double carteraTotal = 0;
      int prestamosActivos = 0;
      int prestamosEnMora = 0;
      
      for (var p in (prestamos as List)) {
        carteraTotal += (p['monto'] as num?)?.toDouble() ?? 0;
        if (p['estado'] == 'activo') prestamosActivos++;
        if (p['estado'] == 'mora') prestamosEnMora++;
      }

      int tandasActivas = 0;
      for (var t in (tandas as List)) {
        if (t['estado'] == 'activa') tandasActivas++;
      }

      if (mounted) {
        setState(() {
          _kpisGlobales = {
            'negocios': (negocios as List).length,
            'clientes': (clientes as List).length,
            'prestamos': prestamosActivos,
            'mora': prestamosEnMora,
            'tandas': tandasActivas,
            'cartera': carteraTotal,
          };
          _cargandoKpis = false;
        });
      }
    } catch (e) {
      debugPrint('Error KPIs: $e');
      if (mounted) setState(() => _cargandoKpis = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Premium con gradiente animado
          _buildPremiumHeader(authVm),
          
          // KPIs Globales
          SliverToBoxAdapter(child: _buildKPIsGlobales()),
          
          // Grid de Negocios
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _buildNegociosGrid(),
          ),
          
          // Espaciado final
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildPremiumHeader(AuthViewModel authVm) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0F),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar animado
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.8 + _pulseController.value * 0.2),
                                  Colors.orange.withOpacity(0.8 + _pulseController.value * 0.2),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3 + _pulseController.value * 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('👑', style: TextStyle(fontSize: 28)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bienvenido, ${authVm.usuarioActual?.userMetadata?['full_name'] ?? "Superadmin"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '⚡ SUPERADMINISTRADOR',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botón configuración
                      IconButton(
                        onPressed: () => Navigator.pushNamed(context, '/controlCenter'),
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Selecciona un negocio para administrar',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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

  Widget _buildKPIsGlobales() {
    if (_cargandoKpis) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              Colors.orange.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                const Text(
                  'RESUMEN GLOBAL',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy', 'es').format(DateTime.now()),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildKPIChip('🏢', '${_kpisGlobales['negocios'] ?? 0}', 'Negocios'),
                _buildKPIChip('👥', '${_kpisGlobales['clientes'] ?? 0}', 'Clientes'),
                _buildKPIChip('💳', '${_kpisGlobales['prestamos'] ?? 0}', 'Préstamos'),
                _buildKPIChip('🔄', '${_kpisGlobales['tandas'] ?? 0}', 'Tandas'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💰 Cartera Total',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    _formatoMoneda.format(_kpisGlobales['cartera'] ?? 0),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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

  Widget _buildKPIChip(String emoji, String valor, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNegociosGrid() {
    return Consumer<NegocioActivoProvider>(
      builder: (context, provider, _) {
        if (provider.cargando) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
          );
        }

        if (provider.misNegocios.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final negocio = provider.misNegocios[index];
              return _buildNegocioCard(negocio, index);
            },
            childCount: provider.misNegocios.length,
          ),
        );
      },
    );
  }

  Widget _buildNegocioCard(NegocioModel negocio, int index) {
    // Colores según tipo de negocio
    final colores = _getColoresNegocio(negocio.tipo);
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _entrarAlNegocio(negocio),
        onLongPress: () => _mostrarOpcionesNegocio(negocio),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colores,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colores[0].withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Patrón decorativo
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Contenido
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono grande
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          negocio.icono,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Nombre del negocio
                    Text(
                      negocio.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Tipo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getTipoLabel(negocio.tipo),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botón entrar
                    Row(
                      children: [
                        const Text(
                          'Entrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge activo
              if (negocio.activo)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getColoresNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'aires':
      case 'climas':
        return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
      case 'purificadora':
        return [const Color(0xFF00c6fb), const Color(0xFF005bea)];
      case 'ventas':
      case 'retail':
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case 'restaurante':
        return [const Color(0xFFff9a9e), const Color(0xFFfecfef)];
      case 'servicios':
        return [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)];
      default:
        return [const Color(0xFF434343), const Color(0xFF000000)];
    }
  }

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'fintech': return '💰 Finanzas';
      case 'aires':
      case 'climas': return '❄️ Climas';
      case 'purificadora': return '💧 Purificadora';
      case 'ventas':
      case 'retail': return '🛒 Ventas';
      case 'restaurante': return '🍽️ Restaurante';
      case 'servicios': return '🔧 Servicios';
      default: return '🏢 General';
    }
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text('🏢', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          const Text(
            'No hay negocios registrados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer negocio para comenzar',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _mostrarDialogoCrearNegocio,
            icon: const Icon(Icons.add),
            label: const Text('Crear Negocio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _mostrarDialogoCrearNegocio,
      backgroundColor: Colors.amber,
      foregroundColor: Colors.black,
      icon: const Icon(Icons.add_business),
      label: const Text('Nuevo Negocio', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _entrarAlNegocio(NegocioModel negocio) {
    HapticFeedback.mediumImpact();
    
    // Seleccionar el negocio activo
    context.read<NegocioActivoProvider>().seleccionarNegocio(negocio);
    
    // Navegar al dashboard del negocio
    Navigator.pushNamed(context, '/negocio-dashboard', arguments: negocio);
  }

  void _mostrarOpcionesNegocio(NegocioModel negocio) {
    HapticFeedback.heavyImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${negocio.icono} ${negocio.nombre}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOpcionSheet(Icons.dashboard, 'Ir al Dashboard', () {
              Navigator.pop(context);
              _entrarAlNegocio(negocio);
            }),
            _buildOpcionSheet(Icons.edit, 'Editar Negocio', () {
              Navigator.pop(context);
              _editarNegocio(negocio);
            }),
            _buildOpcionSheet(Icons.people, 'Ver Empleados', () {
              Navigator.pop(context);
              // Navegar a empleados filtrado
            }),
            _buildOpcionSheet(Icons.analytics, 'Ver Reportes', () {
              Navigator.pop(context);
              // Navegar a reportes filtrado
            }),
            _buildOpcionSheet(Icons.archive, 'Archivar Negocio', () {
              Navigator.pop(context);
              _confirmarArchivarNegocio(negocio);
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionSheet(IconData icono, String label, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: Colors.white),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }

  void _mostrarDialogoCrearNegocio() {
    final nombreController = TextEditingController();
    String tipoSeleccionado = 'fintech';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Text('🏢', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Text('Nuevo Negocio', style: TextStyle(color: Colors.white)),
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
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo de Negocio',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTipoChip('fintech', '💰 Finanzas', tipoSeleccionado, (t) {
                      setDialogState(() => tipoSeleccionado = t);
                    }),
                    _buildTipoChip('climas', '❄️ Climas', tipoSeleccionado, (t) {
                      setDialogState(() => tipoSeleccionado = t);
                    }),
                    _buildTipoChip('purificadora', '💧 Agua', tipoSeleccionado, (t) {
                      setDialogState(() => tipoSeleccionado = t);
                    }),
                    _buildTipoChip('ventas', '🛒 Ventas', tipoSeleccionado, (t) {
                      setDialogState(() => tipoSeleccionado = t);
                    }),
                    _buildTipoChip('servicios', '🔧 Servicios', tipoSeleccionado, (t) {
                      setDialogState(() => tipoSeleccionado = t);
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.trim().isEmpty) return;
                
                final exito = await context.read<NegocioActivoProvider>().crearNegocio(
                  nombre: nombreController.text.trim(),
                  tipo: tipoSeleccionado,
                );
                
                if (exito && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Negocio creado exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoChip(String tipo, String label, String seleccionado, Function(String) onTap) {
    final esSeleccionado = tipo == seleccionado;
    return GestureDetector(
      onTap: () => onTap(tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: esSeleccionado ? Colors.amber : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: esSeleccionado ? Colors.black : Colors.white70,
            fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _editarNegocio(NegocioModel negocio) {
    // TODO: Implementar edición
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente: Editar negocio')),
    );
  }

  void _confirmarArchivarNegocio(NegocioModel negocio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('¿Archivar negocio?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se desactivará "${negocio.nombre}" sin borrar datos. Podrás reactivarlo más adelante si lo necesitas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await context
                  .read<NegocioActivoProvider>()
                  .archivarNegocio(negocio.id);
              if (mounted) Navigator.pop(context);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Negocio archivado'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
  }
}

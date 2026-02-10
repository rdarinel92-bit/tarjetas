// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/tarjetas_service.dart';
import '../../data/models/tarjetas_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE TARJETAS VIRTUALES
// Robert Darin Platform v10.14
// ═══════════════════════════════════════════════════════════════════════════════

class TarjetasScreen extends StatefulWidget {
  final int? initialTabIndex;
  final bool abrirNuevaTarjeta;
  final String? tarjetaId;

  const TarjetasScreen({
    super.key,
    this.initialTabIndex,
    this.abrirNuevaTarjeta = false,
    this.tarjetaId,
  });

  @override
  State<TarjetasScreen> createState() => _TarjetasScreenState();
}

class _TarjetasScreenState extends State<TarjetasScreen> with SingleTickerProviderStateMixin {
  final _service = TarjetasService();
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  late TabController _tabController;
  bool _isLoading = true;
  String? _negocioId;
  TarjetasConfigModel? _config;
  bool _accionInicialEjecutada = false;
  
  List<TarjetaVirtualModel> _tarjetas = [];
  List<TarjetaTitularModel> _titulares = [];
  List<TarjetaTransaccionModel> _transacciones = [];
  Map<String, dynamic> _estadisticas = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final initialIndex = widget.initialTabIndex;
    if (initialIndex != null && initialIndex >= 0 && initialIndex < _tabController.length) {
      _tabController.index = initialIndex;
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // El usuario_id en la tabla usuarios ES el auth.uid
      final perfil = await AppSupabase.client
          .from('usuarios')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      // Obtener negocio_id desde empleados o usando el usuario directo
      if (perfil != null) {
        final empleado = await AppSupabase.client
            .from('empleados')
            .select('negocio_id')
            .eq('usuario_id', user.id)
            .maybeSingle();
        _negocioId = empleado?['negocio_id'];
      }

      // Si no hay negocio, buscar en negocios directamente (superadmin)
      if (_negocioId == null) {
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

      // Cargar configuración
      _config = await _service.obtenerConfiguracion(_negocioId!);

      // Cargar tarjetas
      _tarjetas = await _service.obtenerTarjetas(_negocioId!);

      // Cargar titulares
      _titulares = await _service.obtenerTitulares(_negocioId!);

      // Cargar transacciones recientes
      _transacciones = await _service.obtenerTransacciones(negocioId: _negocioId!, limite: 20);

      // Cargar estadísticas
      _estadisticas = await _service.obtenerEstadisticas(_negocioId!);

      if (mounted) setState(() => _isLoading = false);
      _ejecutarAccionInicial();
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ejecutarAccionInicial() {
    if (_accionInicialEjecutada) return;
    _accionInicialEjecutada = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.tarjetaId != null) {
        TarjetaVirtualModel? tarjeta;
        for (final item in _tarjetas) {
          if (item.id == widget.tarjetaId) {
            tarjeta = item;
            break;
          }
        }
        if (tarjeta != null) {
          _mostrarDetalleTarjeta(tarjeta);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró la tarjeta solicitada')),
          );
        }
        return;
      }

      if (widget.abrirNuevaTarjeta) {
        if (_titulares.isEmpty) {
          Navigator.pushNamed(context, '/tarjetas/titular/nuevo').then((_) => _cargarDatos());
        } else {
          _mostrarNuevaTarjeta();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '💳 Tarjetas Virtuales',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, '/tarjetas/config').then((_) => _cargarDatos()),
          tooltip: 'Configuración',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _config == null || !_config!.activo
              ? _buildConfiguracionRequerida()
              : _buildContenido(),
      floatingActionButton: _config != null && _config!.activo
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarNuevaTarjeta(),
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add_card),
              label: const Text('Nueva Tarjeta'),
            )
          : null,
    );
  }

  Widget _buildConfiguracionRequerida() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Icon(Icons.credit_card_off, size: 64, color: Colors.amber),
            ),
            const SizedBox(height: 24),
            const Text(
              'Configuración Requerida',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Para emitir tarjetas virtuales necesitas configurar\nun proveedor de emisión (Pomelo, Rapyd, Stripe, etc.)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/tarjetas/config').then((_) => _cargarDatos()),
              icon: const Icon(Icons.settings),
              label: const Text('Configurar Proveedor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    return Column(
      children: [
        // Estadísticas
        _buildEstadisticas(),
        
        // Tabs
        Container(
          color: const Color(0xFF1A1A2E),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF3B82F6),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Tarjetas', icon: Icon(Icons.credit_card, size: 20)),
              Tab(text: 'Titulares', icon: Icon(Icons.people, size: 20)),
              Tab(text: 'Transacciones', icon: Icon(Icons.receipt_long, size: 20)),
              Tab(text: 'Alertas', icon: Icon(Icons.notifications, size: 20)),
            ],
          ),
        ),
        
        // Contenido de tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListaTarjetas(),
              _buildListaTitulares(),
              _buildListaTransacciones(),
              _buildListaAlertas(),
            ],
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
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(
                'Tarjetas Activas',
                '${_estadisticas['tarjetas_activas'] ?? 0}',
                Icons.credit_card,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                'Saldo Total',
                _currencyFormat.format(_estadisticas['saldo_total'] ?? 0),
                Icons.account_balance_wallet,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(
                'Gastos del Mes',
                _currencyFormat.format(_estadisticas['gastos_mes'] ?? 0),
                Icons.trending_down,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                'Transacciones',
                '${_estadisticas['transacciones_mes'] ?? 0}',
                Icons.swap_horiz,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String titulo, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  valor,
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

  Widget _buildListaTarjetas() {
    if (_tarjetas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No hay tarjetas',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _mostrarNuevaTarjeta(),
              icon: const Icon(Icons.add_card),
              label: const Text('Crear primera tarjeta'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tarjetas.length,
        itemBuilder: (context, index) => _buildTarjetaCard(_tarjetas[index]),
      ),
    );
  }

  Widget _buildTarjetaCard(TarjetaVirtualModel tarjeta) {
    return GestureDetector(
      onTap: () => _mostrarDetalleTarjeta(tarjeta),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: tarjeta.estado == 'activa'
                ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                : [const Color(0xFF374151), const Color(0xFF4B5563)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tarjeta.red.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(tarjeta.estadoColor).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(tarjeta.estadoColor)),
                    ),
                    child: Text(
                      tarjeta.estadoTexto,
                      style: TextStyle(
                        color: Color(tarjeta.estadoColor),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Número de tarjeta
              Text(
                tarjeta.numeroTarjetaMasked ?? '**** **** **** ****',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              
              // Titular y saldo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TITULAR',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                      ),
                      Text(
                        tarjeta.titularNombreCompleto.isNotEmpty 
                            ? tarjeta.titularNombreCompleto.toUpperCase()
                            : tarjeta.nombreTarjeta?.toUpperCase() ?? 'SIN NOMBRE',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SALDO',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                      ),
                      Text(
                        _currencyFormat.format(tarjeta.saldoDisponible),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Etiqueta
              if (tarjeta.etiqueta != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tarjeta.etiqueta!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaTitulares() {
    if (_titulares.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No hay titulares registrados',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/tarjetas/titular/nuevo').then((_) => _cargarDatos()),
              icon: const Icon(Icons.person_add),
              label: const Text('Registrar titular'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _titulares.length,
        itemBuilder: (context, index) {
          final titular = _titulares[index];
          return Card(
            color: const Color(0xFF1A1A2E),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(titular.kycStatusColor).withOpacity(0.2),
                child: Icon(
                  titular.kycStatus == 'aprobado' ? Icons.verified : Icons.person,
                  color: Color(titular.kycStatusColor),
                ),
              ),
              title: Text(
                titular.nombreCompleto,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${titular.email} • KYC: ${titular.kycStatusTexto}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => _mostrarDetalleTitular(titular),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaTransacciones() {
    if (_transacciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin transacciones',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transacciones.length,
        itemBuilder: (context, index) {
          final tx = _transacciones[index];
          return Card(
            color: const Color(0xFF1A1A2E),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tx.esGasto 
                      ? Colors.red.withOpacity(0.2) 
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tx.tipoIcono, style: const TextStyle(fontSize: 20)),
              ),
              title: Text(
                tx.comercioNombre ?? tx.tipoTexto,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${tx.numeroTarjetaMasked ?? ''} • ${DateFormat('dd/MM HH:mm').format(tx.fechaTransaccion)}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              trailing: Text(
                '${tx.esGasto ? '-' : '+'}${_currencyFormat.format(tx.monto)}',
                style: TextStyle(
                  color: tx.esGasto ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaAlertas() {
    return FutureBuilder<List<TarjetaAlertaModel>>(
      future: _service.obtenerAlertas(_negocioId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final alertas = snapshot.data ?? [];
        
        if (alertas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Sin alertas',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alertas.length,
          itemBuilder: (context, index) {
            final alerta = alertas[index];
            return Card(
              color: alerta.leida 
                  ? const Color(0xFF1A1A2E) 
                  : const Color(0xFF1E3A8A).withOpacity(0.3),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Text(alerta.tipoIcono, style: const TextStyle(fontSize: 24)),
                title: Text(
                  alerta.titulo,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: alerta.leida ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  alerta.mensaje ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  DateFormat('dd/MM').format(alerta.createdAt),
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
                onTap: () async {
                  if (!alerta.leida) {
                    await _service.marcarAlertaLeida(alerta.id);
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarNuevaTarjeta() {
    if (_titulares.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Primero debes registrar un titular'),
          action: SnackBarAction(
            label: 'Registrar',
            onPressed: () => Navigator.pushNamed(context, '/tarjetas/titular/nuevo').then((_) => _cargarDatos()),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NuevaTarjetaSheet(
        titulares: _titulares,
        config: _config!,
        service: _service,
        onCreated: () {
          Navigator.pop(context);
          _cargarDatos();
        },
      ),
    );
  }

  void _mostrarDetalleTarjeta(TarjetaVirtualModel tarjeta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetalleTarjetaSheet(
        tarjeta: tarjeta,
        config: _config!,
        service: _service,
        onUpdated: () {
          Navigator.pop(context);
          _cargarDatos();
        },
      ),
    );
  }

  void _mostrarDetalleTitular(TarjetaTitularModel titular) {
    // TODO: Implementar pantalla de detalle de titular
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Titular: ${titular.nombreCompleto}')),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: NUEVA TARJETA
// ═══════════════════════════════════════════════════════════════════════════════

class _NuevaTarjetaSheet extends StatefulWidget {
  final List<TarjetaTitularModel> titulares;
  final TarjetasConfigModel config;
  final TarjetasService service;
  final VoidCallback onCreated;

  const _NuevaTarjetaSheet({
    required this.titulares,
    required this.config,
    required this.service,
    required this.onCreated,
  });

  @override
  State<_NuevaTarjetaSheet> createState() => _NuevaTarjetaSheetState();
}

class _NuevaTarjetaSheetState extends State<_NuevaTarjetaSheet> {
  TarjetaTitularModel? _titularSeleccionado;
  final _etiquetaController = TextEditingController();
  final _limiteController = TextEditingController(text: '10000');
  String _tipo = 'virtual';
  String _red = 'visa';
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.add_card, color: Color(0xFF3B82F6), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Nueva Tarjeta Virtual',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white12),
          
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titular
                  const Text('Titular *', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TarjetaTitularModel>(
                    value: _titularSeleccionado,
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: 'Seleccionar titular',
                      hintStyle: const TextStyle(color: Colors.white38),
                    ),
                    items: widget.titulares.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text('${t.nombreCompleto} (${t.kycStatusTexto})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _titularSeleccionado = v),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Tipo de tarjeta
                  const Text('Tipo de Tarjeta', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOpcionChip('Virtual', 'virtual', Icons.phone_android),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOpcionChip('Física', 'fisica', Icons.credit_card),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Red
                  const Text('Red', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildRedChip('VISA', 'visa')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRedChip('Mastercard', 'mastercard')),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Etiqueta
                  const Text('Etiqueta (opcional)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _etiquetaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: 'Ej: Gastos oficina, Viáticos...',
                      hintStyle: const TextStyle(color: Colors.white38),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Límite diario
                  const Text('Límite Diario', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _limiteController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Botón crear
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _titularSeleccionado == null || _isCreating ? null : _crearTarjeta,
                icon: _isCreating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_card),
                label: Text(_isCreating ? 'Creando...' : 'Crear Tarjeta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionChip(String label, String value, IconData icon) {
    final selected = _tipo == value;
    return GestureDetector(
      onTap: () => setState(() => _tipo = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? const Color(0xFF3B82F6) : Colors.white54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRedChip(String label, String value) {
    final selected = _red == value;
    return GestureDetector(
      onTap: () => setState(() => _red = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _crearTarjeta() async {
    setState(() => _isCreating = true);

    final tarjeta = TarjetaVirtualModel(
      id: '',
      negocioId: widget.config.negocioId,
      titularId: _titularSeleccionado!.id,
      tipo: _tipo,
      red: _red,
      nombreTarjeta: _titularSeleccionado!.nombreCompleto,
      etiqueta: _etiquetaController.text.isEmpty ? null : _etiquetaController.text,
      limiteDiario: double.tryParse(_limiteController.text) ?? 10000,
      createdAt: DateTime.now(),
    );

    final resultado = await widget.service.crearTarjeta(
      config: widget.config,
      tarjeta: tarjeta,
      titular: _titularSeleccionado!,
    );

    setState(() => _isCreating = false);

    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Tarjeta creada exitosamente'), backgroundColor: Colors.green),
      );
      widget.onCreated();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${resultado['error']}'), backgroundColor: Colors.red),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: DETALLE TARJETA
// ═══════════════════════════════════════════════════════════════════════════════

class _DetalleTarjetaSheet extends StatelessWidget {
  final TarjetaVirtualModel tarjeta;
  final TarjetasConfigModel config;
  final TarjetasService service;
  final VoidCallback onUpdated;
  
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  _DetalleTarjetaSheet({
    required this.tarjeta,
    required this.config,
    required this.service,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Tarjeta visual
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: tarjeta.estado == 'activa'
                      ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                      : [const Color(0xFF374151), const Color(0xFF4B5563)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tarjeta.red.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(tarjeta.estadoColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tarjeta.estadoTexto,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tarjeta.numeroTarjetaMasked ?? '**** **** **** ****',
                    style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 3),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tarjeta.titularNombreCompleto.toUpperCase(),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _currencyFormat.format(tarjeta.saldoDisponible),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Acciones rápidas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildAccionRapida(context, Icons.add, 'Recargar', Colors.green, () => _mostrarRecarga(context)),
                const SizedBox(width: 12),
                _buildAccionRapida(
                  context,
                  tarjeta.estado == 'activa' ? Icons.lock : Icons.lock_open,
                  tarjeta.estado == 'activa' ? 'Bloquear' : 'Desbloquear',
                  tarjeta.estado == 'activa' ? Colors.red : Colors.green,
                  () => _toggleBloqueo(context),
                ),
                const SizedBox(width: 12),
                _buildAccionRapida(context, Icons.visibility, 'Ver Datos', Colors.blue, () => _verDatosSensibles(context)),
                const SizedBox(width: 12),
                _buildAccionRapida(context, Icons.tune, 'Límites', Colors.orange, () => _editarLimites(context)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Info adicional
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildInfoTile('Tipo', tarjeta.tipoTexto),
                _buildInfoTile('Límite Diario', '${_currencyFormat.format(tarjeta.limiteDiario)} (Usado: ${_currencyFormat.format(tarjeta.usoDiario)})'),
                _buildInfoTile('Límite Mensual', '${_currencyFormat.format(tarjeta.limiteMensual)} (Usado: ${_currencyFormat.format(tarjeta.usoMensual)})'),
                _buildInfoTile('E-commerce', tarjeta.permitirEcommerce ? '✅ Permitido' : '❌ Bloqueado'),
                _buildInfoTile('Internacional', tarjeta.permitirInternacional ? '✅ Permitido' : '❌ Bloqueado'),
                if (tarjeta.etiqueta != null) _buildInfoTile('Etiqueta', tarjeta.etiqueta!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionRapida(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _mostrarRecarga(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Recargar Tarjeta', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: '\$ ',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final monto = double.tryParse(controller.text) ?? 0;
              if (monto > 0) {
                Navigator.pop(ctx);
                final resultado = await service.recargarTarjeta(
                  config: config,
                  tarjeta: tarjeta,
                  monto: monto,
                );
                if (resultado['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Recarga exitosa'), backgroundColor: Colors.green),
                  );
                  onUpdated();
                }
              }
            },
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  void _toggleBloqueo(BuildContext context) async {
    if (tarjeta.estado == 'activa') {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Bloquear Tarjeta', style: TextStyle(color: Colors.white)),
          content: const Text('¿Estás seguro de bloquear esta tarjeta?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Bloquear'),
            ),
          ],
        ),
      );
      
      if (confirmado == true) {
        await service.bloquearTarjeta(
          config: config,
          tarjeta: tarjeta,
          motivo: 'Bloqueado por usuario',
          usuarioId: '',
        );
        onUpdated();
      }
    } else {
      await service.desbloquearTarjeta(config: config, tarjeta: tarjeta);
      onUpdated();
    }
  }

  void _verDatosSensibles(BuildContext context) async {
    if (tarjeta.externalCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarjeta no vinculada al proveedor')),
      );
      return;
    }

    final resultado = await service.obtenerDatosSensibles(
      config: config,
      externalCardId: tarjeta.externalCardId!,
    );

    if (resultado['success'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Datos de Tarjeta', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDatoSensible('Número', resultado['pan'] ?? '****'),
              _buildDatoSensible('CVV', resultado['cvv'] ?? '***'),
              _buildDatoSensible('Vencimiento', resultado['expiry'] ?? 'MM/AA'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${resultado['error']}')),
      );
    }
  }

  Widget _buildDatoSensible(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 18, color: Colors.white54),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                    const SnackBar(content: Text('Copiado'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editarLimites(BuildContext context) {
    // TODO: Implementar edición de límites
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edición de límites - Próximamente')),
    );
  }
}

// Global key para navegación
final navigatorKey = GlobalKey<NavigatorState>();

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MIS TARJETAS - PANTALLA PARA CLIENTES V10.52
// Robert Darin Platform v10.22 → v10.52 MEJORADO GLOBAL
// 
// Pantalla completa para que los clientes vean y gestionen sus tarjetas.
// Incluye: visualización, datos sensibles, bloqueo, historial y solicitudes.
// ═══════════════════════════════════════════════════════════════════════════════

class MisTarjetasScreen extends StatefulWidget {
  const MisTarjetasScreen({super.key});

  @override
  State<MisTarjetasScreen> createState() => _MisTarjetasScreenState();
}

class _MisTarjetasScreenState extends State<MisTarjetasScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _misTarjetas = [];
  List<Map<String, dynamic>> _transacciones = [];
  String? _clienteId;
  String? _negocioId;
  int _tarjetaSeleccionadaIndex = 0;
  bool _mostrarDatosSensibles = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarMisTarjetas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarMisTarjetas() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Obtener el cliente_id del usuario actual (usando usuario_id)
      final clienteData = await AppSupabase.client
          .from('clientes')
          .select('id, negocio_id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (clienteData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _clienteId = clienteData['id'];
      _negocioId = clienteData['negocio_id'];

      // Cargar tarjetas del cliente
      final tarjetas = await AppSupabase.client
          .from('tarjetas_digitales')
          .select('*')
          .eq('cliente_id', _clienteId!)
          .order('created_at', ascending: false);

      _misTarjetas = List<Map<String, dynamic>>.from(tarjetas);

      // Cargar transacciones recientes (usar tarjetas_digitales_transacciones)
      if (_misTarjetas.isNotEmpty) {
        final tarjetaIds = _misTarjetas.map((t) => t['id']).toList();
        try {
          final trans = await AppSupabase.client
              .from('tarjetas_digitales_transacciones')
              .select('*')
              .inFilter('tarjeta_id', tarjetaIds)
              .order('fecha', ascending: false)
              .limit(50);
          _transacciones = List<Map<String, dynamic>>.from(trans);
        } catch (e) {
          // Si la tabla no existe aún, intentar con transacciones_tarjeta como fallback
          debugPrint('Usando fallback para transacciones: $e');
          try {
            final trans = await AppSupabase.client
                .from('transacciones_tarjeta')
                .select('*')
                .inFilter('tarjeta_id', tarjetaIds)
                .order('created_at', ascending: false)
                .limit(50);
            _transacciones = List<Map<String, dynamic>>.from(trans);
          } catch (_) {
            _transacciones = [];
          }
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar tarjetas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '💳 Mis Tarjetas',
      actions: [
        if (_misTarjetas.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _cargarMisTarjetas,
            tooltip: 'Actualizar',
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _misTarjetas.isEmpty
              ? _buildSinTarjetas()
              : _buildContenidoCompleto(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // SIN TARJETAS - Pantalla cuando no tiene tarjetas asignadas
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildSinTarjetas() {
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
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.credit_card_off, size: 64, color: Colors.blue),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes tarjetas asignadas',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Puedes solicitar una tarjeta virtual a tu administrador.\nLas tarjetas te permiten hacer compras en línea de forma segura.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _solicitarTarjeta,
              icon: const Icon(Icons.send),
              label: const Text('Solicitar Tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // CONTENIDO PRINCIPAL CON TABS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildContenidoCompleto() {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '💳 Tarjetas'),
              Tab(text: '📊 Movimientos'),
              Tab(text: 'ℹ️ Ayuda'),
            ],
          ),
        ),
        
        // Contenido
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabTarjetas(),
              _buildTabMovimientos(),
              _buildTabAyuda(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB 1: TARJETAS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabTarjetas() {
    return RefreshIndicator(
      onRefresh: _cargarMisTarjetas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Selector de tarjetas (si tiene más de una)
            if (_misTarjetas.length > 1) ...[
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _misTarjetas.length,
                  itemBuilder: (context, index) {
                    final tarjeta = _misTarjetas[index];
                    final isSelected = index == _tarjetaSeleccionadaIndex;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _tarjetaSeleccionadaIndex = index;
                        _mostrarDatosSensibles = false;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '•••• ${tarjeta['ultimos_4'] ?? '****'}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Tarjeta visual principal
            _buildTarjetaVisual(_misTarjetas[_tarjetaSeleccionadaIndex]),
            
            const SizedBox(height: 24),
            
            // Acciones rápidas
            _buildAccionesRapidas(_misTarjetas[_tarjetaSeleccionadaIndex]),
            
            const SizedBox(height: 24),
            
            // Info de la tarjeta
            _buildInfoTarjeta(_misTarjetas[_tarjetaSeleccionadaIndex]),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaVisual(Map<String, dynamic> tarjeta) {
    final marca = (tarjeta['marca'] ?? 'visa').toString().toUpperCase();
    final ultimos4 = tarjeta['ultimos_4'] ?? '****';
    final estado = tarjeta['estado'] ?? 'pendiente';
    final tipo = tarjeta['tipo'] ?? 'virtual';
    final saldo = (tarjeta['saldo_disponible'] ?? tarjeta['limite_diario'] ?? 0).toDouble();
    final fechaVencimiento = tarjeta['fecha_vencimiento'] != null
        ? DateTime.tryParse(tarjeta['fecha_vencimiento'].toString())
        : null;

    // Colores según la marca y estado
    List<Color> gradientColors;
    if (estado == 'bloqueada' || estado == 'cancelada') {
      gradientColors = [const Color(0xFF374151), const Color(0xFF4B5563)];
    } else if (marca == 'MASTERCARD') {
      gradientColors = [const Color(0xFFEB001B), const Color(0xFFF79E1B)];
    } else if (marca == 'AMEX') {
      gradientColors = [const Color(0xFF006FCF), const Color(0xFF00A3E0)];
    } else {
      gradientColors = [const Color(0xFF1A1F71), const Color(0xFF5C6BC0)]; // VISA
    }

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Patrón decorativo
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          
          // Contenido de la tarjeta
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tipo.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(estado),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getEstadoTexto(estado),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      marca,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Chip
                Container(
                  width: 50,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.memory, color: Color(0xFF8B6914), size: 22),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Número de tarjeta
                GestureDetector(
                  onTap: () => setState(() => _mostrarDatosSensibles = !_mostrarDatosSensibles),
                  child: Row(
                    children: [
                      Text(
                        _mostrarDatosSensibles 
                            ? '•••• •••• •••• $ultimos4'
                            : '•••• •••• •••• ••••',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _mostrarDatosSensibles ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info inferior
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VENCE', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          fechaVencimiento != null
                              ? DateFormat('MM/yy').format(fechaVencimiento)
                              : '--/--',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('DISPONIBLE', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          _currencyFormat.format(saldo),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas(Map<String, dynamic> tarjeta) {
    final estado = tarjeta['estado'] ?? 'activa';
    final estaActiva = estado == 'activa';
    
    return Row(
      children: [
        Expanded(
          child: _buildBotonAccion(
            icon: _mostrarDatosSensibles ? Icons.visibility_off : Icons.visibility,
            label: _mostrarDatosSensibles ? 'Ocultar' : 'Ver datos',
            color: Colors.blue,
            onTap: () => setState(() => _mostrarDatosSensibles = !_mostrarDatosSensibles),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBotonAccion(
            icon: estaActiva ? Icons.lock : Icons.lock_open,
            label: estaActiva ? 'Bloquear' : 'Desbloquear',
            color: estaActiva ? Colors.orange : Colors.green,
            onTap: () => _confirmarCambioEstado(tarjeta, estaActiva),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBotonAccion(
            icon: Icons.copy,
            label: 'Copiar',
            color: Colors.purple,
            onTap: () => _copiarDatosTarjeta(tarjeta),
          ),
        ),
      ],
    );
  }

  Widget _buildBotonAccion({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTarjeta(Map<String, dynamic> tarjeta) {
    final limiteDiario = (tarjeta['limite_diario'] ?? 0).toDouble();
    final limiteMensual = (tarjeta['limite_mensual'] ?? limiteDiario * 30).toDouble();
    final createdAt = tarjeta['created_at'] != null 
        ? DateTime.tryParse(tarjeta['created_at'].toString())
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Detalles de la Tarjeta', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFilaDetalle('Límite diario', _currencyFormat.format(limiteDiario)),
          _buildFilaDetalle('Límite mensual', _currencyFormat.format(limiteMensual)),
          if (createdAt != null)
            _buildFilaDetalle('Emitida', DateFormat('dd/MM/yyyy').format(createdAt)),
          _buildFilaDetalle('Tipo', (tarjeta['tipo'] ?? 'virtual').toString().toUpperCase()),
          _buildFilaDetalle('Red', (tarjeta['marca'] ?? 'VISA').toString().toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildFilaDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB 2: MOVIMIENTOS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabMovimientos() {
    if (_transacciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Sin movimientos', style: TextStyle(color: Colors.white70, fontSize: 18)),
            Text('Tus transacciones aparecerán aquí', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarMisTarjetas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transacciones.length,
        itemBuilder: (context, index) {
          return _buildTransaccionItem(_transacciones[index]);
        },
      ),
    );
  }

  Widget _buildTransaccionItem(Map<String, dynamic> trans) {
    final monto = (trans['monto'] ?? 0).toDouble();
    final tipo = trans['tipo'] ?? 'cargo';
    final descripcion = trans['descripcion'] ?? trans['comercio'] ?? 'Transacción';
    final fecha = trans['fecha'] != null 
        ? DateTime.tryParse(trans['fecha'].toString())
        : DateTime.now();
    final estado = trans['estado'] ?? 'completada';
    
    final esIngreso = tipo == 'abono' || tipo == 'reembolso' || tipo == 'recarga';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: esIngreso ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
              color: esIngreso ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      fecha != null ? DateFormat('dd MMM, HH:mm').format(fecha) : '',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if (estado != 'completada') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(estado.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${esIngreso ? '+' : '-'}${_currencyFormat.format(monto.abs())}',
            style: TextStyle(
              color: esIngreso ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB 3: AYUDA
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabAyuda() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionAyuda(
            '💳 ¿Cómo usar mi tarjeta?',
            'Tu tarjeta virtual funciona como cualquier tarjeta de débito/crédito. '
            'Puedes usarla para compras en línea ingresando el número, fecha de vencimiento y CVV.',
          ),
          _buildSeccionAyuda(
            '🔒 ¿Es seguro mostrar los datos?',
            'Los datos sensibles solo se muestran temporalmente cuando los solicitas. '
            'Nunca compartas estos datos con terceros.',
          ),
          _buildSeccionAyuda(
            '⚠️ ¿Qué hago si pierdo mi tarjeta física?',
            'Bloquea tu tarjeta inmediatamente desde esta app y contacta a tu administrador '
            'para solicitar una reposición.',
          ),
          _buildSeccionAyuda(
            '💰 ¿Cómo recargo saldo?',
            'El saldo de tu tarjeta es gestionado por tu administrador. '
            'Contacta con él para solicitar recargas.',
          ),
          const SizedBox(height: 24),
          
          // Botón de contacto
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/chat'),
              icon: const Icon(Icons.chat),
              label: const Text('Contactar Soporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionAyuda(String titulo, String contenido) {
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
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(contenido, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════════

  void _solicitarTarjeta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('📨 Solicitar Tarjeta', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas enviar una solicitud de tarjeta virtual a tu administrador?\n\n'
          'Recibirás una notificación cuando tu tarjeta esté lista.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _enviarSolicitudTarjeta();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarSolicitudTarjeta() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      
      // Crear solicitud formal en la tabla de solicitudes
      await AppSupabase.client.from('tarjetas_solicitudes').insert({
        'negocio_id': _negocioId,
        'cliente_id': _clienteId,
        'solicitante_id': user?.id,
        'tipo_tarjeta': 'virtual',
        'marca_preferida': 'visa',
        'motivo': 'Solicitud desde app móvil',
        'estado': 'pendiente',
      });

      // También crear notificación para el admin
      await AppSupabase.client.from('notificaciones').insert({
        'tipo': 'solicitud_tarjeta',
        'titulo': '📨 Nueva Solicitud de Tarjeta',
        'mensaje': 'Un cliente ha solicitado una tarjeta virtual. Revisa las solicitudes pendientes.',
        'negocio_id': _negocioId,
        'datos_extra': {'cliente_id': _clienteId, 'solicitante_id': user?.id},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud enviada correctamente. Serás notificado cuando sea aprobada.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al solicitar tarjeta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar solicitud: ${e.toString().split(':').last}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmarCambioEstado(Map<String, dynamic> tarjeta, bool estaActiva) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          estaActiva ? '🔒 Bloquear Tarjeta' : '🔓 Desbloquear Tarjeta',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          estaActiva
              ? '¿Deseas bloquear temporalmente tu tarjeta?\nNo podrás realizar compras hasta desbloquearla.'
              : '¿Deseas desbloquear tu tarjeta?\nPodrás volver a realizar compras.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cambiarEstadoTarjeta(tarjeta, estaActiva ? 'bloqueada' : 'activa');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: estaActiva ? Colors.orange : Colors.green,
            ),
            child: Text(estaActiva ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarEstadoTarjeta(Map<String, dynamic> tarjeta, String nuevoEstado) async {
    try {
      await AppSupabase.client
          .from('tarjetas_digitales')
          .update({'estado': nuevoEstado})
          .eq('id', tarjeta['id']);

      await _cargarMisTarjetas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevoEstado == 'bloqueada' 
                ? '🔒 Tarjeta bloqueada' 
                : '✅ Tarjeta desbloqueada'),
            backgroundColor: nuevoEstado == 'bloqueada' ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copiarDatosTarjeta(Map<String, dynamic> tarjeta) {
    final ultimos4 = tarjeta['ultimos_4'] ?? '****';
    Clipboard.setData(ClipboardData(text: '**** **** **** $ultimos4'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Número copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════════

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return Colors.green;
      case 'bloqueada':
        return Colors.orange;
      case 'pendiente':
        return Colors.blue;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return '✓ ACTIVA';
      case 'bloqueada':
        return '🔒 BLOQUEADA';
      case 'pendiente':
        return '⏳ PENDIENTE';
      case 'cancelada':
        return '✕ CANCELADA';
      default:
        return estado.toUpperCase();
    }
  }
}

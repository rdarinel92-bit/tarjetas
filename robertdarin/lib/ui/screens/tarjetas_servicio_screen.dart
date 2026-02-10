// ignore_for_file: deprecated_member_use, unused_import
// ═══════════════════════════════════════════════════════════════════════════════
// TARJETAS DE SERVICIO PROFESIONAL - V10.52
// Sistema completo para crear tarjetas de presentación con QR multi-negocio
// Soporta: Climas, Préstamos, Tandas, Servicios, General
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/supabase_client.dart';
import '../../services/deep_link_service.dart';

const double kTarjetaPrintWidthCm = 9;
const double kTarjetaPrintHeightCm = 5;
const int kTarjetaPrintDpi = 300;
const double kTarjetaPrintAspectRatio = kTarjetaPrintWidthCm / kTarjetaPrintHeightCm;
const String kTarjetaPrintLabel = 'Tamaño impresión: 9 x 5 cm (estándar MX)';

String? buildQrWebFallback({
  required String modulo,
  required String? negocioId,
  required String? tarjetaCodigo,
}) {
  final base = kQrWebBaseUrl.trim();
  if (base.isEmpty || base.contains('tudominio.com')) {
    return null;
  }
  if (negocioId == null || negocioId.isEmpty || tarjetaCodigo == null || tarjetaCodigo.isEmpty) {
    return null;
  }
  final uri = Uri.parse(base);
  final params = <String, String>{};
  params.addAll(uri.queryParameters);
  params['modulo'] = modulo;
  params['negocio'] = negocioId;
  params['codigo'] = tarjetaCodigo;  // Cambiado de 'tarjeta' a 'codigo' para coincidir con landing
  return uri.replace(queryParameters: params).toString();
}

String? resolveTarjetaQrLink(Map<String, dynamic> tarjeta) {
  final modulo = (tarjeta['modulo'] ?? 'general').toString();
  final negocioId = tarjeta['negocio_id']?.toString();
  final codigo = tarjeta['codigo']?.toString();
  final webFallback = tarjeta['qr_web_fallback']?.toString();
  if (webFallback != null && webFallback.isNotEmpty) {
    return webFallback;
  }
  final generatedFallback = buildQrWebFallback(
    modulo: modulo,
    negocioId: negocioId,
    tarjetaCodigo: codigo,
  );
  if (generatedFallback != null && generatedFallback.isNotEmpty) {
    return generatedFallback;
  }
  final deepLink = tarjeta['qr_deep_link']?.toString();
  if (deepLink != null && deepLink.isNotEmpty) {
    return deepLink;
  }
  if (negocioId == null || codigo == null) return null;
  return DeepLinkService.generarDeepLinkTarjetaServicio(
    modulo: modulo,
    negocioId: negocioId,
    tarjetaCodigo: codigo,
    tipo: 'formulario',
  );
}

class TarjetasServicioScreen extends StatefulWidget {
  final bool abrirCrear;
  final String? moduloInicial;
  final String? templateInicial;
  final String? negocioIdInicial;
  final List<String>? modulosPermitidos;

  const TarjetasServicioScreen({
    super.key,
    this.abrirCrear = false,
    this.moduloInicial,
    this.templateInicial,
    this.negocioIdInicial,
    this.modulosPermitidos,
  });

  @override
  State<TarjetasServicioScreen> createState() => _TarjetasServicioScreenState();
}

class _TarjetasServicioScreenState extends State<TarjetasServicioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _misTarjetas = [];
  List<Map<String, dynamic>> _misNegocios = [];
  List<Map<String, dynamic>> _templates = [];
  bool _abrioCreacion = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Cargar negocios del usuario (propios + accesos)
      _misNegocios = await _cargarNegociosUsuario(user.id);

      // Cargar tarjetas existentes
      final tarjetas = await AppSupabase.client
          .from('tarjetas_servicio')
          .select('*')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);
      _misTarjetas = List<Map<String, dynamic>>.from(tarjetas);
      final modulosPermitidos = _normalizarModulos(widget.modulosPermitidos);
      if (modulosPermitidos.isNotEmpty) {
        _misTarjetas = _misTarjetas.where((t) {
          final modulo = (t['modulo'] ?? 'general').toString().toLowerCase();
          return modulosPermitidos.contains(modulo);
        }).toList();
      }

      // Cargar templates
      final temps = await AppSupabase.client
          .from('tarjetas_templates')
          .select('*')
          .eq('activo', true)
          .order('orden');
      _templates = List<Map<String, dynamic>>.from(temps);

      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.abrirCrear && !_abrioCreacion) {
          _abrioCreacion = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mostrarDialogoCrear(
              moduloInicial: widget.moduloInicial,
              templateInicial: widget.templateInicial,
              negocioIdInicial: widget.negocioIdInicial,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '🎴 Tarjetas de Servicio',
      actions: [
        // Chat de visitantes (V10.55)
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.tarjetasChat),
          tooltip: 'Chat con Visitantes',
        ),
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.white),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.configuradorFormulariosQR,
          ),
          tooltip: 'Configurar Formularios QR',
        ),
        IconButton(
          icon: const Icon(Icons.add_card, color: Colors.white),
          onPressed: () => _mostrarDialogoCrear(),
          tooltip: 'Nueva Tarjeta',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '📋 Mis Tarjetas'),
                      Tab(text: '📊 Estadísticas'),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabMisTarjetas(),
                      _buildTabEstadisticas(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: MIS TARJETAS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabMisTarjetas() {
    if (_misTarjetas.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _misTarjetas.length,
        itemBuilder: (context, index) {
          return _buildTarjetaCard(_misTarjetas[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final sinNegocios = _misNegocios.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.2),
                    const Color(0xFF8B5CF6).withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2, size: 80, color: Color(0xFF00D9FF)),
            ),
            const SizedBox(height: 24),
            Text(
              sinNegocios ? 'Primero crea tu negocio' : 'Crea tu primera tarjeta!',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              sinNegocios
                  ? 'Necesitas un negocio real para generar tarjetas QR.'
                  : 'Genera tarjetas de presentacion profesionales\ncon QR para cada uno de tus servicios.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: sinNegocios
                  ? () => Navigator.pushNamed(context, AppRoutes.superadminNegocios)
                  : () => _mostrarDialogoCrear(),
              icon: Icon(sinNegocios ? Icons.add_business : Icons.add_card),
              label: Text(sinNegocios ? 'Crear negocio' : 'Crear Tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaCard(Map<String, dynamic> tarjeta) {
    final modulo = tarjeta['modulo'] ?? 'general';
    final escaneos = tarjeta['escaneos_total'] ?? 0;
    final activa = tarjeta['activa'] ?? true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            Color(int.parse((tarjeta['color_primario'] ?? '#00D9FF').replaceFirst('#', '0xFF'))).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? const Color(0xFF00D9FF).withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _getModuloIcon(modulo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tarjeta['nombre_tarjeta'] ?? 'Sin nombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getModuloColor(modulo).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              modulo.toUpperCase(),
                              style: TextStyle(
                                color: _getModuloColor(modulo),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!activa)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'INACTIVA',
                                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$escaneos',
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'escaneos',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Divider
          Container(height: 1, color: Colors.white10),
          
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  tarjeta['telefono_principal'] ?? 'Sin teléfono',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.qr_code, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  tarjeta['codigo'] ?? '---',
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(height: 1, color: Colors.white10),
          
          // Acciones - Primera fila
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildAccionBtn(Icons.visibility, 'Ver', () => _verTarjeta(tarjeta)),
                _buildAccionBtn(Icons.edit, 'Editar', () => _editarTarjeta(tarjeta)),
                _buildAccionBtn(Icons.qr_code_2, 'QR', () => _mostrarQR(tarjeta)),
                _buildAccionBtn(Icons.share, 'Compartir', () => _compartirTarjeta(tarjeta), color: const Color(0xFF25D366)),
                _buildAccionBtn(Icons.copy, 'Duplicar', () => _duplicarTarjeta(tarjeta), color: const Color(0xFF8B5CF6)),
              ],
            ),
          ),
          // Acciones - Segunda fila
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildAccionBtn(Icons.bar_chart, 'Stats', () => _verEstadisticas(tarjeta), color: const Color(0xFF00D9FF)),
                _buildAccionBtn(Icons.tune, 'Form', () => _configurarFormulario(tarjeta)),
                _buildAccionBtn(
                  activa ? Icons.pause : Icons.play_arrow,
                  activa ? 'Pausar' : 'Activar',
                  () => _toggleEstado(tarjeta),
                  color: activa ? Colors.orange : Colors.green,
                ),
                _buildAccionBtn(
                  Icons.delete_outline,
                  'Eliminar',
                  () => _eliminarTarjeta(tarjeta),
                  color: Colors.redAccent,
                ),
                const Expanded(child: SizedBox()), // Spacer
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? Colors.white54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color ?? Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TAB: ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildTabEstadisticas() {
    final totalEscaneos = _misTarjetas.fold<int>(0, (sum, t) => sum + ((t['escaneos_total'] ?? 0) as int));
    final tarjetasActivas = _misTarjetas.where((t) => t['activa'] == true).length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs
          Row(
            children: [
              Expanded(child: _buildKPICard('📊', 'Total Tarjetas', _misTarjetas.length.toString(), const Color(0xFF00D9FF))),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard('✅', 'Activas', tarjetasActivas.toString(), Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKPICard('👁️', 'Escaneos Total', totalEscaneos.toString(), const Color(0xFF8B5CF6))),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard('📱', 'Módulos', _contarModulos().toString(), Colors.orange)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Por módulo
          const Text(
            '📈 Escaneos por Módulo',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._buildEstadisticasPorModulo(),
          
          const SizedBox(height: 24),
          
          // Top tarjetas
          const Text(
            '🏆 Top Tarjetas',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._buildTopTarjetas(),
        ],
      ),
    );
  }

  Widget _buildKPICard(String emoji, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  List<Widget> _buildEstadisticasPorModulo() {
    final modulos = <String, int>{};
    for (final t in _misTarjetas) {
      final modulo = t['modulo'] ?? 'general';
      modulos[modulo] = (modulos[modulo] ?? 0) + ((t['escaneos_total'] ?? 0) as int);
    }
    
    if (modulos.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Sin datos aún', style: TextStyle(color: Colors.white54)),
          ),
        ),
      ];
    }
    
    final maxEscaneos = modulos.values.fold<int>(1, (max, v) => v > max ? v : max);
    
    return modulos.entries.map((e) {
      final porcentaje = e.value / maxEscaneos;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _getModuloIcon(e.key, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      e.key.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${e.value} escaneos',
                  style: const TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: porcentaje,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(_getModuloColor(e.key)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTopTarjetas() {
    final sorted = List<Map<String, dynamic>>.from(_misTarjetas)
      ..sort((a, b) => ((b['escaneos_total'] ?? 0) as int).compareTo((a['escaneos_total'] ?? 0) as int));
    
    final top5 = sorted.take(5).toList();
    
    if (top5.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Sin datos aún', style: TextStyle(color: Colors.white54)),
          ),
        ),
      ];
    }
    
    return top5.asMap().entries.map((entry) {
      final index = entry.key;
      final t = entry.value;
      final emoji = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}.';
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['nombre_tarjeta'] ?? 'Sin nombre',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    t['modulo']?.toString().toUpperCase() ?? 'GENERAL',
                    style: TextStyle(color: _getModuloColor(t['modulo'] ?? 'general'), fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              '${t['escaneos_total'] ?? 0}',
              style: const TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  int _contarModulos() {
    final modulos = _misTarjetas.map((t) => t['modulo'] ?? 'general').toSet();
    return modulos.length;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // DIÁLOGO CREAR TARJETA
  // ═══════════════════════════════════════════════════════════════════════════════

  void _mostrarDialogoCrear({
    String? moduloInicial,
    String? templateInicial,
    String? negocioIdInicial,
  }) {
    if (_misNegocios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aviso: Primero debes tener al menos un negocio registrado'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Crear',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.superadminNegocios),
          ),
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CrearTarjetaServicioScreen(
          negocios: _misNegocios,
          templates: _templates,
          moduloInicial: moduloInicial,
          templateInicial: templateInicial,
          negocioIdInicial: negocioIdInicial,
          modulosPermitidos: widget.modulosPermitidos,
          onCreated: () {
            _cargarDatos();
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════════

  void _verTarjeta(Map<String, dynamic> tarjeta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VistaPreviewTarjeta(tarjeta: tarjeta),
      ),
    );
  }

  void _editarTarjeta(Map<String, dynamic> tarjeta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CrearTarjetaServicioScreen(
          negocios: _misNegocios,
          templates: _templates,
          tarjetaExistente: tarjeta,
          modulosPermitidos: widget.modulosPermitidos,
          onCreated: () {
            _cargarDatos();
          },
        ),
      ),
    );
  }

  Future<bool> _esSuperadmin(String userId) async {
    try {
      final rolRes = await AppSupabase.client
          .from('usuarios_roles')
          .select('roles(nombre)')
          .eq('usuario_id', userId);
      return (rolRes as List).any((r) => r['roles']?['nombre'] == 'superadmin');
    } catch (_) {}
    return false;
  }

  Future<List<Map<String, dynamic>>> _cargarNegociosUsuario(String userId) async {
    final Map<String, Map<String, dynamic>> negocios = {};

    try {
      final esSuperadmin = await _esSuperadmin(userId);
      if (esSuperadmin) {
        final res = await AppSupabase.client
            .from('negocios')
            .select()
            .order('nombre');
        for (final row in (res as List)) {
          final id = row['id']?.toString();
          if (id == null) continue;
          negocios[id] = Map<String, dynamic>.from(row);
        }
      } else {
        final propiosRes = await AppSupabase.client
            .from('negocios')
            .select()
            .eq('propietario_id', userId)
            .order('nombre');
        for (final row in (propiosRes as List)) {
          final id = row['id']?.toString();
          if (id == null) continue;
          negocios[id] = Map<String, dynamic>.from(row);
        }

        final accesosRes = await AppSupabase.client
            .from('usuarios_negocios')
            .select('negocio_id, negocios(*)')
            .eq('usuario_id', userId)
            .eq('activo', true);
        for (final acceso in (accesosRes as List)) {
          final negocio = acceso['negocios'];
          if (negocio is Map) {
            final id = negocio['id']?.toString();
            if (id == null) continue;
            negocios[id] = Map<String, dynamic>.from(negocio);
          }
        }

        final empleadoRes = await AppSupabase.client
            .from('empleados')
            .select('negocio_id')
            .eq('usuario_id', userId)
            .maybeSingle();
        final empleadoNegocioId = empleadoRes?['negocio_id']?.toString();
        if (empleadoNegocioId != null && !negocios.containsKey(empleadoNegocioId)) {
          final negocioRes = await AppSupabase.client
              .from('negocios')
              .select()
              .eq('id', empleadoNegocioId)
              .maybeSingle();
          if (negocioRes != null) {
            negocios[empleadoNegocioId] = Map<String, dynamic>.from(negocioRes);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando negocios del usuario: $e');
    }

    final lista = negocios.values.toList();
    lista.sort((a, b) {
      final nombreA = (a['nombre'] ?? '').toString().toLowerCase();
      final nombreB = (b['nombre'] ?? '').toString().toLowerCase();
      return nombreA.compareTo(nombreB);
    });
    return lista;
  }

  List<String> _normalizarModulos(List<String>? modulos) {
    if (modulos == null) return const [];
    return modulos
        .map((m) => m.toLowerCase().trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
  }

  void _configurarFormulario(Map<String, dynamic> tarjeta) {
    Navigator.pushNamed(
      context,
      AppRoutes.configuradorFormulariosQR,
      arguments: {
        'negocioId': tarjeta['negocio_id']?.toString(),
        'tarjetaId': tarjeta['id']?.toString(),
        'modulo': (tarjeta['modulo'] ?? 'general').toString(),
      },
    );
  }

  void _mostrarQR(Map<String, dynamic> tarjeta) {
    showDialog(
      context: context,
      builder: (context) => _QRDialog(tarjeta: tarjeta),
    );
  }

  Future<void> _eliminarTarjeta(Map<String, dynamic> tarjeta) async {
    final codigo = tarjeta['codigo']?.toString() ?? '';
    final nombre = tarjeta['nombre_tarjeta']?.toString() ?? 'Tarjeta';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar tarjeta', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Seguro que quieres eliminar "$nombre"?\nCódigo: $codigo',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await AppSupabase.client
          .from('tarjetas_servicio')
          .delete()
          .eq('id', tarjeta['id']);
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Tarjeta eliminada'), backgroundColor: Colors.green),
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

  Future<void> _toggleEstado(Map<String, dynamic> tarjeta) async {
    final nuevoEstado = !(tarjeta['activa'] ?? true);
    
    try {
      await AppSupabase.client
          .from('tarjetas_servicio')
          .update({'activa': nuevoEstado})
          .eq('id', tarjeta['id']);
      
      await _cargarDatos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevoEstado ? '✅ Tarjeta activada' : '⏸️ Tarjeta pausada'),
            backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
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

  // V10.64: Compartir tarjeta por WhatsApp
  void _compartirTarjeta(Map<String, dynamic> tarjeta) {
    final qrLink = resolveTarjetaQrLink(tarjeta);
    final nombre = tarjeta['nombre_tarjeta'] ?? 'Mi Tarjeta';
    final negocio = tarjeta['nombre_negocio'] ?? '';
    final telefono = tarjeta['telefono_principal'] ?? '';
    
    final mensaje = '''
🎴 *$nombre*
${negocio.isNotEmpty ? '🏢 $negocio' : ''}
${telefono.isNotEmpty ? '📞 $telefono' : ''}

📲 Escanea el QR o visita:
$qrLink

_Tarjeta digital creada con Robert Darin_
''';
    
    // Usar Share para compartir
    Share.share(mensaje.trim(), subject: nombre);
  }

  // V10.64: Duplicar tarjeta existente
  Future<void> _duplicarTarjeta(Map<String, dynamic> tarjeta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('📋 Duplicar Tarjeta', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Crear una copia de "${tarjeta['nombre_tarjeta']}"?\n\nLa nueva tarjeta tendrá un código QR diferente.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) throw Exception('No autenticado');
      
      // Crear copia sin id ni codigo (se generarán automáticamente)
      final nuevaTarjeta = Map<String, dynamic>.from(tarjeta);
      nuevaTarjeta.remove('id');
      nuevaTarjeta.remove('codigo');
      nuevaTarjeta.remove('created_at');
      nuevaTarjeta.remove('updated_at');
      nuevaTarjeta.remove('escaneos_total');
      nuevaTarjeta.remove('ultimo_escaneo');
      nuevaTarjeta.remove('qr_web_fallback');
      nuevaTarjeta.remove('qr_deep_link');
      nuevaTarjeta['nombre_tarjeta'] = '${tarjeta['nombre_tarjeta']} (copia)';
      nuevaTarjeta['created_by'] = user.id;
      nuevaTarjeta['parent_id'] = tarjeta['id']; // Referencia al original
      
      await AppSupabase.client.from('tarjetas_servicio').insert(nuevaTarjeta);
      
      await _cargarDatos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tarjeta duplicada exitosamente'),
            backgroundColor: Color(0xFF8B5CF6),
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

  // V10.64: Ver estadísticas de la tarjeta
  void _verEstadisticas(Map<String, dynamic> tarjeta) {
    final tarjetaId = tarjeta['id'];
    final nombre = tarjeta['nombre_tarjeta'] ?? 'Tarjeta';
    final escaneos = tarjeta['escaneos_total'] ?? 0;
    final ultimoEscaneo = tarjeta['ultimo_escaneo'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bar_chart, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Estadísticas de rendimiento', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Stats Cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Card principal de escaneos
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF00D9FF).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$escaneos',
                            style: const TextStyle(
                              color: Color(0xFF00D9FF),
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Escaneos Totales', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          if (ultimoEscaneo != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Último: ${_formatearFecha(ultimoEscaneo)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Stats secundarias
                    Row(
                      children: [
                        _buildStatMiniCard('📱', 'Android', '--', const Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        _buildStatMiniCard('🍎', 'iOS', '--', const Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        _buildStatMiniCard('🌐', 'Web', '--', const Color(0xFFFBBF24)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatMiniCard('📞', 'Llamadas', '--', const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildStatMiniCard('💬', 'WhatsApp', '--', const Color(0xFF25D366)),
                        const SizedBox(width: 12),
                        _buildStatMiniCard('📧', 'Email', '--', const Color(0xFFEF4444)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Nota de próximamente
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El tracking detallado por dispositivo y acciones estará disponible próximamente.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '--';
    try {
      final dt = DateTime.parse(fecha.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return '--';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _getModuloIcon(String modulo, {double size = 24}) {
    IconData icon;
    Color color;
    
    switch (modulo.toLowerCase()) {
      case 'climas':
        icon = Icons.ac_unit;
        color = const Color(0xFF00D9FF);
        break;
      case 'prestamos':
        icon = Icons.account_balance;
        color = const Color(0xFF10B981);
        break;
      case 'tandas':
        icon = Icons.groups;
        color = const Color(0xFFFBBF24);
        break;
      case 'cobranza':
        icon = Icons.receipt_long;
        color = const Color(0xFFEF4444);
        break;
      case 'servicios':
        icon = Icons.build;
        color = const Color(0xFF8B5CF6);
        break;
      case 'purificadora':
      case 'agua':
        icon = Icons.water_drop;
        color = const Color(0xFF06B6D4);
        break;
      case 'nice':
        icon = Icons.diamond;
        color = const Color(0xFFEC4899);
        break;
      default:
        icon = Icons.business;
        color = Colors.white54;
    }
    
    return Container(
      padding: EdgeInsets.all(size * 0.4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  Color _getModuloColor(String modulo) {
    switch (modulo.toLowerCase()) {
      case 'climas':
        return const Color(0xFF00D9FF);
      case 'prestamos':
        return const Color(0xFF10B981);
      case 'tandas':
        return const Color(0xFFFBBF24);
      case 'cobranza':
        return const Color(0xFFEF4444);
      case 'servicios':
        return const Color(0xFF8B5CF6);
      case 'purificadora':
      case 'agua':
        return const Color(0xFF06B6D4);
      case 'nice':
        return const Color(0xFFEC4899);
      default:
        return Colors.white54;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CREAR/EDITAR TARJETA
// ═══════════════════════════════════════════════════════════════════════════════

class _CrearTarjetaServicioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> negocios;
  final List<Map<String, dynamic>> templates;
  final Map<String, dynamic>? tarjetaExistente;
  final String? moduloInicial;
  final String? templateInicial;
  final String? negocioIdInicial;
  final List<String>? modulosPermitidos;
  final VoidCallback onCreated;

  const _CrearTarjetaServicioScreen({
    required this.negocios,
    required this.templates,
    this.tarjetaExistente,
    this.moduloInicial,
    this.templateInicial,
    this.negocioIdInicial,
    this.modulosPermitidos,
    required this.onCreated,
  });

  @override
  State<_CrearTarjetaServicioScreen> createState() => _CrearTarjetaServicioScreenState();
}

class _CrearTarjetaServicioScreenState extends State<_CrearTarjetaServicioScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _currentStep = 0;
  bool _showBackPreview = false; // Para flip de la preview
  
  // Datos del formulario
  String? _negocioId;
  String _modulo = 'climas';
  String _nombreTarjeta = '';
  String _nombreNegocio = '';
  String _slogan = '';
  String _telefonoPrincipal = '';
  String _telefonoSecundario = '';
  String _whatsapp = '';
  String _email = '';
  String _direccion = '';
  String _ciudad = '';
  String _horario = '';
  String _colorPrimario = '#00D9FF';
  String _colorSecundario = '#8B5CF6';
  String _template = 'profesional';
  List<String> _servicios = [];
  final TextEditingController _servicioController = TextEditingController();
  String? _codigoTarjeta;
  String? _qrPreviewLink;
  
  // V10.60: Nuevos campos para HTML mejorado
  String _facebook = '';
  String _instagram = '';
  String _tiktok = '';
  String _youtube = '';
  String _sitioWeb = '';
  double? _latitud;
  double? _longitud;
  bool _promocionActiva = false;
  String _promocionTexto = '';
  int? _promocionDescuento;
  bool _permiteAgendar = false;
  
  // V10.64: Mejoras avanzadas del editor
  String _font = 'poppins';
  String _gradientType = 'none';
  String _backgroundTexture = 'none';
  String _textEffect = 'none';
  String _layout = 'horizontal';
  String? _logoUrl;
  DateTime? _promocionFechaInicio;
  DateTime? _promocionFechaFin;
  
  // Opciones disponibles
  static const List<Map<String, dynamic>> _fonts = [
    {'id': 'poppins', 'nombre': 'Poppins', 'preview': 'Aa'},
    {'id': 'roboto', 'nombre': 'Roboto', 'preview': 'Aa'},
    {'id': 'montserrat', 'nombre': 'Montserrat', 'preview': 'Aa'},
    {'id': 'playfair', 'nombre': 'Playfair', 'preview': 'Aa'},
    {'id': 'opensans', 'nombre': 'Open Sans', 'preview': 'Aa'},
  ];
  
  static const List<Map<String, dynamic>> _gradients = [
    {'id': 'none', 'nombre': 'Sin gradiente', 'colors': [0xFF1A1A2E, 0xFF1A1A2E]},
    {'id': 'linear', 'nombre': 'Lineal', 'colors': [0xFF667eea, 0xFF764ba2]},
    {'id': 'sunset', 'nombre': 'Atardecer', 'colors': [0xFFff7e5f, 0xFFfeb47b]},
    {'id': 'ocean', 'nombre': 'Océano', 'colors': [0xFF2E3192, 0xFF1BFFFF]},
    {'id': 'forest', 'nombre': 'Bosque', 'colors': [0xFF11998e, 0xFF38ef7d]},
    {'id': 'diagonal', 'nombre': 'Diagonal', 'colors': [0xFF8E2DE2, 0xFF4A00E0]},
  ];
  
  static const List<Map<String, dynamic>> _textures = [
    {'id': 'none', 'nombre': 'Sin textura', 'icon': Icons.block},
    {'id': 'marble', 'nombre': 'Mármol', 'icon': Icons.texture},
    {'id': 'wood', 'nombre': 'Madera', 'icon': Icons.park},
    {'id': 'metal', 'nombre': 'Metal', 'icon': Icons.hardware},
    {'id': 'leather', 'nombre': 'Cuero', 'icon': Icons.chair},
    {'id': 'carbon', 'nombre': 'Carbono', 'icon': Icons.grid_4x4},
  ];
  
  static const List<Map<String, dynamic>> _textEffects = [
    {'id': 'none', 'nombre': 'Normal', 'icon': Icons.text_fields},
    {'id': 'shadow', 'nombre': 'Sombra', 'icon': Icons.blur_on},
    {'id': 'glow', 'nombre': 'Brillo', 'icon': Icons.flare},
    {'id': 'outline', 'nombre': 'Contorno', 'icon': Icons.format_shapes},
    {'id': 'gold', 'nombre': 'Dorado', 'icon': Icons.auto_awesome},
  ];
  
  static const List<Map<String, dynamic>> _layouts = [
    {'id': 'horizontal', 'nombre': 'Horizontal', 'icon': Icons.crop_landscape},
    {'id': 'vertical', 'nombre': 'Vertical', 'icon': Icons.crop_portrait},
    {'id': 'centered', 'nombre': 'Centrado', 'icon': Icons.center_focus_strong},
    {'id': 'split', 'nombre': 'Dividido', 'icon': Icons.vertical_split},
    {'id': 'minimal', 'nombre': 'Minimal', 'icon': Icons.minimize},
    {'id': 'bold', 'nombre': 'Bold', 'icon': Icons.format_bold},
  ];

  late final List<String> _modulos;
  static const List<String> _fallbackTemplates = [
    'profesional',
    'moderno',
    'minimalista',
    'clasico',
    'premium',
    'corporativo',
    // V10.64: Nuevas plantillas
    'elegante',
    'creativo',
    'tech',
    'nature',
    'luxury',
    'retro',
    'neon',
    'gradient',
  ];
  final List<Map<String, dynamic>> _colores = [
    {'nombre': 'Cyan', 'color': '#00D9FF'},
    {'nombre': 'Púrpura', 'color': '#8B5CF6'},
    {'nombre': 'Verde', 'color': '#10B981'},
    {'nombre': 'Dorado', 'color': '#D4AF37'},
    {'nombre': 'Oro Rosa', 'color': '#B76E79'},
    {'nombre': 'Platino', 'color': '#E5E4E2'},
    {'nombre': 'Amarillo', 'color': '#FBBF24'},
    {'nombre': 'Rojo', 'color': '#EF4444'},
    {'nombre': 'Rosa', 'color': '#EC4899'},
    {'nombre': 'Azul', 'color': '#3B82F6'},
    {'nombre': 'Naranja', 'color': '#F97316'},
  ];

  @override
  void initState() {
    super.initState();
    _modulos = _resolverModulosPermitidos();
    if (_modulos.isNotEmpty) {
      _modulo = _modulos.first;
    }
    if (widget.tarjetaExistente != null) {
      _cargarDatosExistentes();
    } else if (widget.negocios.isNotEmpty) {
      _aplicarValoresIniciales();
    }
  }

  void _aplicarValoresIniciales() {
    if (widget.negocios.isEmpty) return;

    final negocioIdInicial = widget.negocioIdInicial;
    final negocio = negocioIdInicial != null
        ? widget.negocios.firstWhere(
            (n) => n['id'] == negocioIdInicial,
            orElse: () => widget.negocios.first,
          )
        : widget.negocios.first;
    _negocioId = negocio['id'];
    _nombreNegocio = negocio['nombre'] ?? '';

    final moduloInicial = widget.moduloInicial?.toLowerCase();
    if (moduloInicial != null && _modulos.contains(moduloInicial)) {
      _modulo = moduloInicial;
    } else if (_modulos.isNotEmpty && !_modulos.contains(_modulo)) {
      _modulo = _modulos.first;
    }

    final templateInicial = widget.templateInicial?.toLowerCase();
    if (templateInicial != null && templateInicial.isNotEmpty) {
      _template = templateInicial;
    }

    _asegurarTemplateDisponible();
  }

  List<Map<String, dynamic>> _templatesDisponibles() {
    if (widget.templates.isEmpty) {
      return _fallbackTemplates
          .map((t) => {'nombre': t, 'es_premium': t == 'premium'})
          .toList();
    }

    final filtrados = widget.templates.where((t) {
      final compatibles = (t['modulos_compatibles'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const <String>[];
      if (compatibles.isEmpty) return true;
      return compatibles.contains(_modulo.toLowerCase());
    }).toList();

    final list = (filtrados.isNotEmpty ? filtrados : widget.templates).toList();
    list.sort((a, b) {
      final ordenA = (a['orden'] as num?)?.toInt() ?? 0;
      final ordenB = (b['orden'] as num?)?.toInt() ?? 0;
      return ordenA.compareTo(ordenB);
    });
    return list;
  }

  void _asegurarTemplateDisponible() {
    final disponibles = _templatesDisponibles()
        .map((t) => (t['nombre'] ?? '').toString().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (disponibles.isEmpty) return;
    if (!disponibles.contains(_template.toLowerCase())) {
      _template = disponibles.first;
    }
  }

  void _cargarDatosExistentes() {
    final t = widget.tarjetaExistente!;
    _negocioId = t['negocio_id'];
    _modulo = (t['modulo'] ?? 'climas').toString().toLowerCase();
    _asegurarModuloEnLista(_modulo);
    _codigoTarjeta = t['codigo']?.toString();
    _qrPreviewLink = t['qr_web_fallback']?.toString();
    _qrPreviewLink ??= t['qr_deep_link']?.toString();
    _nombreTarjeta = t['nombre_tarjeta'] ?? '';
    _nombreNegocio = t['nombre_negocio'] ?? '';
    _slogan = t['slogan'] ?? '';
    _telefonoPrincipal = t['telefono_principal'] ?? '';
    _telefonoSecundario = t['telefono_secundario'] ?? '';
    _whatsapp = t['whatsapp'] ?? '';
    _email = t['email'] ?? '';
    _direccion = t['direccion'] ?? '';
    _ciudad = t['ciudad'] ?? '';
    _horario = t['horario_atencion'] ?? '';
    _colorPrimario = t['color_primario'] ?? '#00D9FF';
    _colorSecundario = t['color_secundario'] ?? '#8B5CF6';
    _template = (t['template'] ?? 'profesional').toString().toLowerCase();
    if (t['servicios'] != null) {
      _servicios = List<String>.from(t['servicios']);
    }
    // V10.60: Cargar nuevos campos
    _facebook = t['facebook'] ?? '';
    _instagram = t['instagram'] ?? '';
    _tiktok = t['tiktok'] ?? '';
    _youtube = t['youtube'] ?? '';
    _sitioWeb = t['sitio_web'] ?? '';
    _latitud = t['latitud'] != null ? double.tryParse(t['latitud'].toString()) : null;
    _longitud = t['longitud'] != null ? double.tryParse(t['longitud'].toString()) : null;
    _promocionActiva = t['promocion_activa'] ?? false;
    _promocionTexto = t['promocion_texto'] ?? '';
    _promocionDescuento = t['promocion_descuento'] != null ? int.tryParse(t['promocion_descuento'].toString()) : null;
    _permiteAgendar = t['permite_agendar'] ?? false;
    
    // V10.64: Cargar campos de mejoras avanzadas
    _font = t['font'] ?? 'poppins';
    _gradientType = t['gradient_type'] ?? 'none';
    _backgroundTexture = t['background_texture'] ?? 'none';
    _textEffect = t['text_effect'] ?? 'none';
    _layout = t['layout'] ?? 'horizontal';
    _logoUrl = t['logo_url'];
    if (t['promocion_fecha_inicio'] != null) {
      _promocionFechaInicio = DateTime.tryParse(t['promocion_fecha_inicio'].toString());
    }
    if (t['promocion_fecha_fin'] != null) {
      _promocionFechaFin = DateTime.tryParse(t['promocion_fecha_fin'].toString());
    }
  }

  List<String> _resolverModulosPermitidos() {
    const base = ['climas', 'prestamos', 'tandas', 'cobranza', 'servicios', 'general'];
    final permitidos = widget.modulosPermitidos;
    if (permitidos == null || permitidos.isEmpty) {
      return List<String>.from(base);
    }
    final permitidosSet = permitidos
        .map((m) => m.toLowerCase().trim())
        .where((m) => m.isNotEmpty)
        .toSet();
    if (permitidosSet.isEmpty) {
      return List<String>.from(base);
    }
    final result = <String>[];
    for (final modulo in base) {
      if (permitidosSet.contains(modulo)) {
        result.add(modulo);
      }
    }
    for (final modulo in permitidosSet) {
      if (!base.contains(modulo)) {
        result.add(modulo);
      }
    }
    if (result.isEmpty) {
      return List<String>.from(base);
    }
    return result;
  }

  void _asegurarModuloEnLista(String modulo) {
    if (_modulos.contains(modulo)) return;
    _modulos.insert(0, modulo);
  }

  @override
  void dispose() {
    _servicioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.tarjetaExistente != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800; // Tablets y desktop
    
    return PremiumScaffold(
      title: esEdicion ? '✏️ Editar Tarjeta' : '➕ Nueva Tarjeta',
      body: isWideScreen 
          ? _buildWideLayout(esEdicion) 
          : _buildMobileLayout(esEdicion),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // LAYOUT PARA PANTALLAS ANCHAS (Tablets/Desktop) - Estilo Zazzle
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildWideLayout(bool esEdicion) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ PANEL IZQUIERDO: Formulario ═══
        Expanded(
          flex: 45,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                // Header del panel
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personaliza tu diseño',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Edita el texto y la información',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Formulario scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: _buildCompactForm(),
                    ),
                  ),
                ),
                // Botones de acción
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        TextButton.icon(
                          onPressed: _retroceder,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Anterior'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : (_currentStep < 5 ? _continuar : _guardarTarjeta),
                        icon: _isLoading 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_currentStep < 5 ? Icons.arrow_forward : Icons.check, size: 18),
                        label: Text(_currentStep < 5 ? 'Siguiente' : 'Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentStep < 5 ? const Color(0xFF00D9FF) : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ═══ PANEL DERECHO: Preview en tiempo real ═══
        Expanded(
          flex: 55,
          child: Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Preview principal con flip
                Expanded(
                  child: Center(
                    child: _buildLivePreview(),
                  ),
                ),
                // Miniaturas Anverso/Reverso
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMiniThumbnail('Anverso', false),
                    const SizedBox(width: 16),
                    _buildMiniThumbnail('Reverso', true),
                  ],
                ),
                const SizedBox(height: 16),
                // Indicador de paso actual
                _buildStepIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // LAYOUT MÓVIL TIPO ZAZZLE - Diseño visual profesional
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(bool esEdicion) {
    return Column(
      children: [
        // ═══ ÁREA SUPERIOR: Vista de tarjeta + herramientas ═══
        Expanded(
          flex: 50,
          child: Row(
            children: [
              // Panel de herramientas lateral izquierdo
              _buildToolsPanel(),
              // Vista central de la tarjeta
              Expanded(
                child: Container(
                  color: const Color(0xFF16213E),
                  child: Column(
                    children: [
                      // Header con indicador de paso
                      _buildEditorHeader(),
                      // Tarjeta principal grande
                      Expanded(
                        child: Center(
                          child: _buildLargeCardPreview(),
                        ),
                      ),
                      // Miniaturas anverso/reverso
                      _buildThumbnailsRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ═══ ÁREA INFERIOR: Panel de edición deslizable ═══
        Expanded(
          flex: 50,
          child: _buildEditPanel(esEdicion),
        ),
      ],
    );
  }

  // ═══ PANEL DE HERRAMIENTAS LATERAL (tipo Zazzle) ═══
  Widget _buildToolsPanel() {
    final tools = [
      {'icon': Icons.edit_outlined, 'label': 'Editar', 'step': 0},
      {'icon': Icons.text_fields, 'label': 'Info', 'step': 1},
      {'icon': Icons.list_alt, 'label': 'Servicios', 'step': 2},
      {'icon': Icons.link, 'label': 'Extras', 'step': 3},
      {'icon': Icons.palette_outlined, 'label': 'Diseño', 'step': 4},
      {'icon': Icons.preview_outlined, 'label': 'Preview', 'step': 5},
    ];

    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...tools.map((tool) => _buildToolButton(
            icon: tool['icon'] as IconData,
            label: tool['label'] as String,
            step: tool['step'] as int,
          )),
          const Spacer(),
          // Botón guardar rápido
          Container(
            margin: const EdgeInsets.all(8),
            child: IconButton(
              onPressed: _isLoading ? null : _guardarTarjeta,
              icon: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
              tooltip: 'Guardar',
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required String label, required int step}) {
    final isActive = _currentStep == step;
    final isComplete = step < _currentStep;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => setState(() => _currentStep = step),
        child: Container(
          width: 56,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 7),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFF00D9FF).withOpacity(0.2)
                : isComplete 
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive 
                  ? const Color(0xFF00D9FF)
                  : isComplete 
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.transparent,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isComplete && !isActive ? Icons.check_circle : icon,
                color: isActive 
                    ? const Color(0xFF00D9FF)
                    : isComplete 
                        ? const Color(0xFF10B981)
                        : Colors.white54,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? const Color(0xFF00D9FF)
                      : isComplete 
                          ? const Color(0xFF10B981)
                          : Colors.white54,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ HEADER DEL EDITOR ═══
  Widget _buildEditorHeader() {
    final stepNames = ['Negocio', 'Información', 'Servicios', 'Extras', 'Diseño', 'Preview'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withOpacity(0.8),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1}/6',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stepNames[_currentStep],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          // Tooltip de ayuda
          IconButton(
            onPressed: _showHelpTooltip,
            icon: Icon(Icons.help_outline, color: Colors.white.withOpacity(0.6), size: 20),
            tooltip: 'Ayuda',
          ),
        ],
      ),
    );
  }

  void _showHelpTooltip() {
    final helpTexts = [
      'Selecciona el negocio y tipo de servicio para tu tarjeta QR',
      'Agrega los datos de contacto que verán tus clientes',
      'Lista los servicios que ofreces',
      'Añade redes sociales, ubicación y promociones',
      'Personaliza los colores y el estilo visual',
      'Revisa que todo esté correcto antes de guardar',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(helpTexts[_currentStep]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══ VISTA GRANDE DE TARJETA CON FLIP 3D ═══
  Widget _buildLargeCardPreview() {
    final qrPreview = _buildQrPreviewData();
    
    return GestureDetector(
      onTap: () => setState(() => _showBackPreview = !_showBackPreview),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -100 || details.primaryVelocity! > 100) {
            setState(() => _showBackPreview = !_showBackPreview);
          }
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _showBackPreview ? 180 : 0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutBack,
        builder: (context, value, child) {
          final showFront = value < 90;
          final rotationAngle = showFront ? value : (180 - value);
          
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(rotationAngle * 3.1416 / 180),
            child: Container(
              margin: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 200),
              child: AspectRatio(
                aspectRatio: kTarjetaPrintAspectRatio,
                child: Stack(
                  children: [
                    // Sombra detrás
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tarjeta
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: showFront
                          ? _TarjetaPreviewFrenteLive(
                              nombreNegocio: _nombreNegocio,
                              colorPrimario: _colorPrimario,
                            )
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(3.1416),
                              child: _TarjetaPreviewReversoLive(
                                nombreNegocio: _nombreNegocio,
                                slogan: _slogan,
                                telefono: _telefonoPrincipal,
                                email: _email,
                                ciudad: _ciudad,
                                qrData: qrPreview,
                                colorPrimario: _colorPrimario,
                              ),
                            ),
                    ),
                    // Indicador de swipe
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swipe, size: 14, color: Colors.white.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Text(
                                showFront ? 'Ver reverso' : 'Ver anverso',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══ MINIATURAS ANVERSO/REVERSO ═══
  Widget _buildThumbnailsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMiniThumbnailNew('Anverso', false),
          const SizedBox(width: 16),
          _buildMiniThumbnailNew('Reverso', true),
        ],
      ),
    );
  }

  Widget _buildMiniThumbnailNew(String label, bool isBack) {
    final isSelected = _showBackPreview == isBack;
    final primaryColor = _colorPrimario.isNotEmpty 
        ? Color(int.parse(_colorPrimario.replaceFirst('#', '0xFF'))) 
        : const Color(0xFFD4AF37);
    
    return GestureDetector(
      onTap: () => setState(() => _showBackPreview = isBack),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 44,
              decoration: BoxDecoration(
                gradient: isBack 
                    ? const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)])
                    : LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00D9FF) : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
              child: Center(
                child: isBack 
                    ? const Icon(Icons.qr_code_2, color: Colors.white60, size: 22)
                    : Text(
                        _getIniciales(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ PANEL DE EDICIÓN INFERIOR ═══
  Widget _buildEditPanel(bool esEdicion) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle para deslizar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header del panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getStepIcon(_currentStep),
                  color: const Color(0xFF00D9FF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _getStepTitle(_currentStep),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                // Navegación rápida
                if (_currentStep > 0)
                  IconButton(
                    onPressed: _retroceder,
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    color: Colors.white54,
                    tooltip: 'Anterior',
                  ),
                if (_currentStep < 5)
                  IconButton(
                    onPressed: _continuar,
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    color: const Color(0xFF00D9FF),
                    tooltip: 'Siguiente',
                  ),
              ],
            ),
          ),
          // Contenido del formulario
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Form(
                key: _formKey,
                child: _buildCurrentStepContent(),
              ),
            ),
          ),
          // Botón de acción principal
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0: return Icons.business;
      case 1: return Icons.contact_page;
      case 2: return Icons.list_alt;
      case 3: return Icons.language;
      case 4: return Icons.palette;
      case 5: return Icons.preview;
      default: return Icons.edit;
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Negocio y Módulo';
      case 1: return 'Información de Contacto';
      case 2: return 'Servicios Ofrecidos';
      case 3: return 'Extras Web';
      case 4: return 'Diseño y Colores';
      case 5: return 'Vista Previa Final';
      default: return 'Editar';
    }
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0: return _buildStepNegocio();
      case 1: return _buildStepInfo();
      case 2: return _buildStepServicios();
      case 3: return _buildStepExtras();
      case 4: return _buildStepDiseno();
      case 5: return _buildStepPreview();
      default: return const SizedBox();
    }
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Indicador de progreso
            Expanded(
              child: Row(
                children: List.generate(6, (index) {
                  final isComplete = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isComplete 
                            ? const Color(0xFF10B981)
                            : isCurrent 
                                ? const Color(0xFF00D9FF)
                                : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 16),
            // Botón principal
            ElevatedButton.icon(
              onPressed: _isLoading ? null : (_currentStep < 5 ? _continuar : _guardarTarjeta),
              icon: _isLoading 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_currentStep < 5 ? Icons.arrow_forward : Icons.check_circle, size: 18),
              label: Text(_currentStep < 5 ? 'Siguiente' : 'Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep < 5 ? const Color(0xFF00D9FF) : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // PREVIEW EN TIEMPO REAL CON ANIMACIÓN 3D FLIP
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildLivePreview() {
    final qrPreview = _buildQrPreviewData();
    
    return GestureDetector(
      onTap: () => setState(() => _showBackPreview = !_showBackPreview),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _showBackPreview ? 180 : 0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutBack,
        builder: (context, value, child) {
          // Determinar si mostrar frente o reverso basado en la rotación
          final showFront = value < 90;
          final rotationAngle = showFront ? value : (180 - value);
          
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspectiva
              ..rotateY(rotationAngle * 3.1416 / 180),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450, maxHeight: 280),
              child: AspectRatio(
                aspectRatio: kTarjetaPrintAspectRatio,
                child: showFront
                    ? _TarjetaPreviewFrenteLive(
                        nombreNegocio: _nombreNegocio,
                        colorPrimario: _colorPrimario,
                      )
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.1416), // Voltear horizontalmente
                        child: _TarjetaPreviewReversoLive(
                          nombreNegocio: _nombreNegocio,
                          slogan: _slogan,
                          telefono: _telefonoPrincipal,
                          email: _email,
                          ciudad: _ciudad,
                          qrData: qrPreview,
                          colorPrimario: _colorPrimario,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Mini thumbnail para seleccionar cara
  Widget _buildMiniThumbnail(String label, bool isBack) {
    final isSelected = _showBackPreview == isBack;
    
    return GestureDetector(
      onTap: () => setState(() => _showBackPreview = isBack),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              color: isBack ? const Color(0xFF1A1A1A) : const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF00D9FF) : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFF00D9FF).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ] : null,
            ),
            child: Center(
              child: isBack 
                  ? const Icon(Icons.qr_code, color: Colors.white54, size: 24)
                  : Text(
                      _getIniciales(),
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A).withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Indicador de pasos (para wide layout)
  Widget _buildStepIndicator() {
    final steps = ['Negocio', 'Info', 'Servicios', 'Extras', 'Diseño', 'Preview'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isComplete = index < _currentStep;
          
          return Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (index <= _currentStep || isComplete) {
                    setState(() => _currentStep = index);
                  }
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive 
                        ? const Color(0xFF00D9FF)
                        : isComplete 
                            ? const Color(0xFF10B981)
                            : Colors.white12,
                  ),
                  child: Center(
                    child: isComplete 
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              if (index < steps.length - 1)
                Container(
                  width: 20,
                  height: 2,
                  color: isComplete ? const Color(0xFF10B981) : Colors.white12,
                ),
            ],
          );
        }),
      ),
    );
  }

  // Preview flotante mini para móviles - MEJORADO con animación y tooltip
  Widget _buildFloatingMiniPreview() {
    return GestureDetector(
      onTap: () => setState(() => _showBackPreview = !_showBackPreview),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _showBackPreview ? 180 : 0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final showFront = value < 90;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY((showFront ? value : 180 - value) * 3.1416 / 180),
            child: Container(
              width: 120,
              height: 75,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: showFront 
                      ? [const Color(0xFFD4AF37), const Color(0xFFB8860B)]
                      : [const Color(0xFF1A1A2E), const Color(0xFF0D0D14)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D9FF),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Contenido principal
                  Center(
                    child: showFront 
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getIniciales(),
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1A).withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 30,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          )
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.1416),
                            child: const Icon(Icons.qr_code_2, color: Colors.white60, size: 32),
                          ),
                  ),
                  // Indicador "Toca para voltear"
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 10, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 3),
                            Text(
                              'Voltear',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getIniciales() {
    final palabras = _nombreNegocio.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'RD';
    if (palabras.length == 1) {
      return palabras[0].length >= 2 
          ? palabras[0].substring(0, 2).toUpperCase()
          : palabras[0].toUpperCase();
    }
    return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // FORMULARIO COMPACTO PARA WIDE LAYOUT (todos los campos en secciones)
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildCompactForm() {
    switch (_currentStep) {
      case 0:
        return _buildStepNegocio();
      case 1:
        return _buildStepInfo();
      case 2:
        return _buildStepServicios();
      case 3:
        return _buildStepExtras();
      case 4:
        return _buildStepDiseno();
      case 5:
        return _buildCompactPreviewInfo();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCompactPreviewInfo() {
    final qrPreview = _buildQrPreviewData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✅ Tu tarjeta está lista', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Text('Revisa la preview a la derecha y presiona Guardar cuando estés listo.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📋 Resumen:', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildResumenItem('Negocio', _nombreNegocio.isEmpty ? 'Sin nombre' : _nombreNegocio),
              _buildResumenItem('Módulo', _modulo.toUpperCase()),
              _buildResumenItem('Teléfono', _telefonoPrincipal.isEmpty ? 'Sin teléfono' : _telefonoPrincipal),
              _buildResumenItem('Servicios', '${_servicios.length} servicios'),
              if (_codigoTarjeta != null)
                _buildResumenItem('Código QR', _codigoTarjeta!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildControls(ControlsDetails details) {
    final isLast = _currentStep == 5;
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _isLoading ? null : details.onStepCancel,
              child: const Text('Anterior'),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : details.onStepContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? const Color(0xFF10B981) : const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(isLast ? '✅ Guardar Tarjeta' : 'Siguiente'),
          ),
        ],
      ),
    );
  }

  // Step 1: Negocio y Módulo
  Widget _buildStepNegocio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de negocio
        const Text('Negocio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _negocioId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              items: widget.negocios.map((n) {
                return DropdownMenuItem(
                  value: n['id'] as String,
                  child: Text(n['nombre'] ?? 'Sin nombre'),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _negocioId = v;
                  final negocio = widget.negocios.firstWhere((n) => n['id'] == v);
                  _nombreNegocio = negocio['nombre'] ?? '';
                });
              },
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Selector de módulo
        const Text('Tipo de Servicio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _modulos.map((m) {
            final isSelected = m == _modulo;
            return GestureDetector(
              onTap: () => setState(() {
                _modulo = m;
                _asegurarTemplateDisponible();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _getModuloColor(m).withOpacity(0.3) : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _getModuloColor(m) : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getModuloIconData(m), size: 18, color: _getModuloColor(m)),
                    const SizedBox(width: 8),
                    Text(
                      m.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        // Nombre de la tarjeta
        const Text('Nombre de la Tarjeta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _nombreTarjeta,
          decoration: _inputDecoration('Ej: Servicios de Aire Acondicionado'),
          onChanged: (v) => _nombreTarjeta = v,
          validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
        ),
      ],
    );
  }

  // Step 2: Información de contacto - MEJORADO con iconos
  Widget _buildStepInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        _buildSectionHeader('Datos del Negocio', Icons.store, 'Información que aparecerá en tu tarjeta'),
        const SizedBox(height: 16),
        
        TextFormField(
          initialValue: _nombreNegocio,
          decoration: _inputDecoration('Nombre del Negocio', icon: Icons.business),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: (v) => setState(() => _nombreNegocio = v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _slogan,
          decoration: _inputDecoration('Slogan (opcional)', icon: Icons.format_quote),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: (v) => _slogan = v,
        ),
        
        const SizedBox(height: 20),
        _buildSectionHeader('Contacto', Icons.contact_phone, 'Cómo pueden comunicarse contigo'),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _telefonoPrincipal,
                decoration: _inputDecoration('Teléfono Principal', icon: Icons.phone),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _telefonoPrincipal = v,
                validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _whatsapp,
                decoration: _inputDecoration('WhatsApp', icon: Icons.chat),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _whatsapp = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _email,
          decoration: _inputDecoration('Correo Electrónico', icon: Icons.email),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => _email = v,
        ),
        
        const SizedBox(height: 20),
        _buildSectionHeader('Ubicación', Icons.location_on, 'Dónde te pueden encontrar'),
        const SizedBox(height: 16),
        
        TextFormField(
          initialValue: _direccion,
          decoration: _inputDecoration('Dirección completa', icon: Icons.place),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          maxLines: 2,
          onChanged: (v) => _direccion = v,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _ciudad,
                decoration: _inputDecoration('Ciudad', icon: Icons.location_city),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (v) => _ciudad = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _horario,
                decoration: _inputDecoration('Horario', icon: Icons.schedule),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (v) => _horario = v,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget auxiliar para headers de sección
  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00D9FF).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00D9FF), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Servicios - MEJORADO con animaciones
  Widget _buildStepServicios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tus Servicios', Icons.auto_awesome, 'Lista lo que ofreces a tus clientes'),
        const SizedBox(height: 20),
        
        // Input para agregar servicio
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00D9FF).withOpacity(0.1), const Color(0xFF8B5CF6).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servicioController,
                      decoration: _inputDecoration('Escribe un servicio...', icon: Icons.add_box_outlined),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      onFieldSubmitted: (_) => _agregarServicio(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _agregarServicio,
                      icon: const Icon(Icons.add, color: Colors.white),
                      tooltip: 'Agregar servicio',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Presiona Enter o el botón + para agregar',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Contador de servicios
        Row(
          children: [
            Icon(Icons.checklist, color: Colors.white.withOpacity(0.6), size: 18),
            const SizedBox(width: 8),
            Text(
              '${_servicios.length} servicio${_servicios.length != 1 ? 's' : ''} agregado${_servicios.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Lista de servicios
        if (_servicios.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.playlist_add, size: 40, color: Colors.white.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin servicios agregados',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega servicios arriba o usa las sugerencias',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _servicios.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A1A2E), const Color(0xFF12121A)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withOpacity(0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9FF).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D9FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      entry.value,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _servicios.removeAt(entry.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        
        const SizedBox(height: 28),
        
        // Sugerencias según módulo - MEJORADO
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.withOpacity(0.8), size: 18),
                  const SizedBox(width: 8),
                  const Text('Sugerencias rápidas', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _getSugerenciasModulo().map((s) {
                  final yaExiste = _servicios.contains(s);
                  return GestureDetector(
                    onTap: yaExiste ? null : () {
                      setState(() => _servicios.add(s));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: yaExiste ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: yaExiste ? Colors.green.withOpacity(0.4) : Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            yaExiste ? Icons.check : Icons.add,
                            size: 14,
                            color: yaExiste ? Colors.green : Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s,
                            style: TextStyle(
                              color: yaExiste ? Colors.green : Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _agregarServicio() {
    final servicio = _servicioController.text.trim();
    if (servicio.isNotEmpty && !_servicios.contains(servicio)) {
      setState(() {
        _servicios.add(servicio);
        _servicioController.clear();
      });
    }
  }

  List<String> _getSugerenciasModulo() {
    switch (_modulo) {
      case 'climas':
        return ['Instalación', 'Mantenimiento', 'Reparación', 'Limpieza', 'Gas refrigerante', 'Cotización gratis'];
      case 'prestamos':
        return ['Préstamos personales', 'Préstamos grupales', 'Sin buró', 'Aprobación rápida', 'Tasas competitivas'];
      case 'tandas':
        return ['Tandas semanales', 'Tandas quincenales', 'Tandas mensuales', 'Grupos pequeños', 'Sin intereses'];
      case 'cobranza':
        return ['Cobro a domicilio', 'Cobro digital', 'Recordatorios', 'Planes de pago', 'Convenios'];
      case 'servicios':
        return ['Servicio a domicilio', 'Garantía', 'Presupuesto gratis', 'Emergencias 24/7'];
      default:
        return ['Atención personalizada', 'Precios competitivos', 'Experiencia'];
    }
  }

  // Step 4: Extras Web - MEJORADO con iconos y mejor diseño
  Widget _buildStepExtras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // V10.64: Sección Logo del Negocio
        _buildSectionHeader('Logo del Negocio', Icons.image, 'Imagen que aparecerá en tu tarjeta'),
        const SizedBox(height: 16),
        
        GestureDetector(
          onTap: _seleccionarLogo,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _logoUrl != null ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1),
                width: _logoUrl != null ? 2 : 1,
              ),
            ),
            child: _logoUrl != null && _logoUrl!.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _logoUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _logoUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildLogoPlaceholder(),
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Sección Redes Sociales
        _buildSectionHeader('Redes Sociales', Icons.share, 'Enlaces a tus perfiles (opcional)'),
        const SizedBox(height: 16),
        
        // Grid de redes sociales
        _buildSocialInput('Facebook', Icons.facebook, _facebook, (v) => _facebook = v, const Color(0xFF1877F2)),
        const SizedBox(height: 12),
        _buildSocialInput('Instagram', Icons.camera_alt, _instagram, (v) => _instagram = v, const Color(0xFFE4405F)),
        const SizedBox(height: 12),
        _buildSocialInput('TikTok', Icons.music_note, _tiktok, (v) => _tiktok = v, const Color(0xFF000000)),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(child: _buildSocialInput('YouTube', Icons.play_circle_fill, _youtube, (v) => _youtube = v, const Color(0xFFFF0000))),
            const SizedBox(width: 12),
            Expanded(child: _buildSocialInput('Sitio Web', Icons.language, _sitioWeb, (v) => _sitioWeb = v, const Color(0xFF00D9FF))),
          ],
        ),
        
        const SizedBox(height: 28),
        
        // Sección Ubicación
        _buildSectionHeader('Ubicación GPS', Icons.location_on, 'Para botones de Maps y Waze'),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _latitud?.toString() ?? '',
                      decoration: _inputDecoration('Latitud', icon: Icons.north),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (v) => _latitud = double.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _longitud?.toString() ?? '',
                      decoration: _inputDecoration('Longitud', icon: Icons.east),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (v) => _longitud = double.tryParse(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Tip: Busca tu negocio en Google Maps, haz clic derecho y copia las coordenadas',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Sección Promoción
        _buildSectionHeader('Promoción Especial', Icons.local_offer, 'Destaca ofertas en tu tarjeta'),
        const SizedBox(height: 16),
        
        _buildToggleCard(
          title: 'Mostrar banner de promoción',
          subtitle: 'Aparecerá destacado en tu tarjeta web',
          value: _promocionActiva,
          icon: Icons.campaign,
          color: Colors.orange,
          onChanged: (v) => setState(() => _promocionActiva = v),
        ),
        
        if (_promocionActiva) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                TextFormField(
                  initialValue: _promocionTexto,
                  decoration: _inputDecoration('Texto de la promoción', icon: Icons.text_fields),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  onChanged: (v) => _promocionTexto = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _promocionDescuento?.toString() ?? '',
                  decoration: _inputDecoration('Descuento %', icon: Icons.percent),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _promocionDescuento = int.tryParse(v),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 28),
        
        // Sección Agendar Cita
        _buildSectionHeader('Agendar Citas', Icons.calendar_today, 'Permite a clientes solicitar citas'),
        const SizedBox(height: 16),
        
        _buildToggleCard(
          title: 'Botón de agendar cita',
          subtitle: 'Los clientes podrán solicitar cita por WhatsApp',
          value: _permiteAgendar,
          icon: Icons.event_available,
          color: const Color(0xFF10B981),
          onChanged: (v) => setState(() => _permiteAgendar = v),
        ),
      ],
    );
  }
  
  // Input para redes sociales con color de marca
  Widget _buildSocialInput(String label, IconData icon, String value, Function(String) onChanged, Color brandColor) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFF12121A),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, size: 20, color: brandColor.withOpacity(0.8)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      keyboardType: TextInputType.url,
      onChanged: onChanged,
    );
  }
  
  // V10.64: Placeholder para logo
  Widget _buildLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, color: Colors.white.withOpacity(0.3), size: 40),
        const SizedBox(height: 8),
        Text(
          'Toca para agregar logo',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        ),
        Text(
          'PNG, JPG (máx 2MB)',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
        ),
      ],
    );
  }
  
  // V10.64: Seleccionar logo desde galería
  Future<void> _seleccionarLogo() async {
    // Por ahora solo permitir ingresar URL manualmente
    final controller = TextEditingController(text: _logoUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🖼️ Logo del Negocio', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa la URL de tu logo (puedes subirlo a Imgur, Google Drive, etc.)',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF12121A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.link, color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() => _logoUrl = result);
    }
  }
  
  // Card con toggle switch
  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.1) : const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? color.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: value ? color : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: Colors.white, fontWeight: value ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ),
        value: value,
        activeColor: color,
        onChanged: onChanged,
      ),
    );
  }

  // Step 5: Diseño - MEJORADO con selectores visuales
  Widget _buildStepDiseno() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildSectionHeader('Personaliza tu Tarjeta', Icons.palette, 'Elige los colores y estilo'),
        const SizedBox(height: 20),
        
        // Color primario con preview
        Row(
          children: [
            const Text('🎨 Color Principal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(int.parse(_colorPrimario.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildColorSelector(
          selectedColor: _colorPrimario,
          onColorSelected: (color) => setState(() => _colorPrimario = color),
        ),
        
        const SizedBox(height: 28),
        
        // Color secundario
        Row(
          children: [
            const Text('✨ Color Secundario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(int.parse(_colorSecundario.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildColorSelector(
          selectedColor: _colorSecundario,
          onColorSelected: (color) => setState(() => _colorSecundario = color),
        ),
        
        const SizedBox(height: 28),
        
        // Preview de colores combinados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(int.parse(_colorPrimario.replaceFirst('#', '0xFF'))).withOpacity(0.3),
                Color(int.parse(_colorSecundario.replaceFirst('#', '0xFF'))).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility, color: Colors.white.withOpacity(0.7), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vista previa de colores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Así se verá tu combinación', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Template
        const Text('📐 Estilo de Diseño', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _templatesDisponibles().map((t) {
              final nombre = (t['nombre'] ?? '').toString().toLowerCase();
              if (nombre.isEmpty) return const SizedBox.shrink();
              final isSelected = nombre == _template.toLowerCase();
              final esPremium = t['es_premium'] == true;
              return GestureDetector(
                onTap: () => setState(() => _template = nombre),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: isSelected 
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [const Color(0xFF00D9FF).withOpacity(0.3), const Color(0xFF8B5CF6).withOpacity(0.3)],
                          )
                        : null,
                    color: isSelected ? null : const Color(0xFF12121A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [BoxShadow(color: const Color(0xFF00D9FF).withOpacity(0.2), blurRadius: 12)]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getTemplateIcon(nombre),
                              color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              nombre.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (esPremium)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 28),
        
        // ═══ V10.64: NUEVO - Selector de Fuentes ═══
        const Text('🔤 Tipografía', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: _fonts.length,
            itemBuilder: (context, index) {
              final font = _fonts[index];
              final isSelected = font['id'] == _font;
              return GestureDetector(
                onTap: () => setState(() => _font = font['id']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00D9FF).withOpacity(0.2) : const Color(0xFF12121A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        font['preview'],
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        font['nombre'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 28),
        
        // ═══ V10.64: NUEVO - Selector de Gradientes ═══
        const Text('🌈 Fondo Gradiente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: _gradients.length,
            itemBuilder: (context, index) {
              final grad = _gradients[index];
              final isSelected = grad['id'] == _gradientType;
              final colors = (grad['colors'] as List).map((c) => Color(c)).toList();
              return GestureDetector(
                onTap: () => setState(() => _gradientType = grad['id']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  decoration: BoxDecoration(
                    gradient: grad['id'] == 'none' 
                        ? null 
                        : LinearGradient(colors: colors),
                    color: grad['id'] == 'none' ? const Color(0xFF12121A) : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (grad['id'] == 'none')
                          Icon(Icons.block, color: Colors.white54, size: 20)
                        else if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          grad['nombre'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(isSelected ? 1 : 0.6),
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 28),
        
        // ═══ V10.64: NUEVO - Selector de Texturas ═══
        const Text('🎭 Textura de Fondo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _textures.map((tex) {
            final isSelected = tex['id'] == _backgroundTexture;
            return GestureDetector(
              onTap: () => setState(() => _backgroundTexture = tex['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00D9FF).withOpacity(0.2) : const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00D9FF) : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tex['icon'],
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tex['nombre'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 28),
        
        // ═══ V10.64: NUEVO - Efectos de Texto ═══
        const Text('✨ Efectos de Texto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _textEffects.map((eff) {
            final isSelected = eff['id'] == _textEffect;
            return GestureDetector(
              onTap: () => setState(() => _textEffect = eff['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.2) : const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      eff['icon'],
                      color: isSelected ? const Color(0xFF8B5CF6) : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eff['nombre'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 28),
        
        // ═══ V10.64: NUEVO - Layouts ═══
        const Text('📐 Distribución', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _layouts.map((lay) {
            final isSelected = lay['id'] == _layout;
            return GestureDetector(
              onTap: () => setState(() => _layout = lay['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      lay['icon'],
                      color: isSelected ? const Color(0xFF10B981) : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lay['nombre'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  // Icono para cada template - AMPLIADO con más opciones
  IconData _getTemplateIcon(String template) {
    switch (template.toLowerCase()) {
      case 'profesional': return Icons.business_center;
      case 'moderno': return Icons.auto_awesome;
      case 'minimalista': return Icons.crop_square;
      case 'clasico': return Icons.style;
      case 'premium': return Icons.diamond;
      case 'corporativo': return Icons.account_balance;
      case 'elegante': return Icons.spa;
      case 'creativo': return Icons.brush;
      case 'tech': return Icons.computer;
      case 'nature': return Icons.eco;
      case 'luxury': return Icons.hotel_class;
      case 'retro': return Icons.camera;
      case 'neon': return Icons.lightbulb;
      case 'gradient': return Icons.gradient;
      default: return Icons.design_services;
    }
  }
  
  // Selector de colores mejorado
  Widget _buildColorSelector({
    required String selectedColor,
    required Function(String) onColorSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colores.map((c) {
        final isSelected = c['color'] == selectedColor;
        final color = Color(int.parse(c['color'].replaceFirst('#', '0xFF')));
        
        return GestureDetector(
          onTap: () => onColorSelected(c['color']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 52 : 44,
            height: isSelected ? 52 : 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(isSelected ? 14 : 10),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 4),
                    ]
                  : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white, size: 24, key: ValueKey('check'))
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Step 5: Preview
  Widget _buildStepPreview() {
    final qrPreview = _buildQrPreviewData();
    return Column(
      children: [
        // Preview de la tarjeta con tamaño estándar de impresión
        AspectRatio(
          aspectRatio: kTarjetaPrintAspectRatio,
          child: _TarjetaPreview(
            nombreTarjeta: _nombreTarjeta,
            nombreNegocio: _nombreNegocio,
            slogan: _slogan,
            telefono: _telefonoPrincipal,
            whatsapp: _whatsapp,
            email: _email,
            direccion: _direccion,
            ciudad: _ciudad,
            servicios: _servicios,
            colorPrimario: _colorPrimario,
            colorSecundario: _colorSecundario,
            modulo: _modulo,
            template: _template,
            qrData: qrPreview,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          kTarjetaPrintLabel,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 24),
        
        // Vista final con QR
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vista final con QR',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (qrPreview != null && qrPreview.isNotEmpty)
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _qrColorFromHex(_colorPrimario).withOpacity(0.35)),
                      ),
                      child: QrImageView(
                        data: qrPreview,
                        version: QrVersions.auto,
                        size: 140,
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFF2F4F7),
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black87,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR final listo para imprimir',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Modulo: ${_modulo.toUpperCase()}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                          if (_nombreNegocio.isNotEmpty)
                            Text(
                              'Negocio: $_nombreNegocio',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          if (_codigoTarjeta != null && _codigoTarjeta!.isNotEmpty)
                            Text(
                              'Codigo: $_codigoTarjeta',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, letterSpacing: 1.2),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'No se modifica: es el mismo QR que se asignara.',
                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Completa los datos para generar el QR final.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF12121A),
      prefixIcon: icon != null 
          ? Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, size: 20, color: const Color(0xFF00D9FF).withOpacity(0.7)),
            ) 
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      prefixText: prefixText,
      prefixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _continuar() {
    if (_currentStep < 5) {
      if (_currentStep == 0 && _nombreTarjeta.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un nombre para la tarjeta'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_currentStep == 1 && _telefonoPrincipal.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El teléfono principal es requerido'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_currentStep == 4 && widget.tarjetaExistente == null) {
        _asegurarCodigoPreview();
      }
      setState(() => _currentStep++);
    } else {
      _guardarTarjeta();
    }
  }

  void _retroceder() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _guardarTarjeta() async {
    setState(() => _isLoading = true);
    
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) throw Exception('No autenticado');
      if (widget.tarjetaExistente == null) {
        _asegurarCodigoPreview();
      }
      
      // V10.57: Si WhatsApp está vacío, usar teléfono principal
      final whatsappFinal = _whatsapp.isEmpty ? _telefonoPrincipal : _whatsapp;
      
      final datos = {
        'negocio_id': _negocioId,
        'nombre_tarjeta': _nombreTarjeta,
        'modulo': _modulo,
        'nombre_negocio': _nombreNegocio,
        'slogan': _slogan,
        'telefono_principal': _telefonoPrincipal,
        'telefono_secundario': _telefonoSecundario,
        'whatsapp': whatsappFinal,
        'email': _email,
        'direccion': _direccion,
        'ciudad': _ciudad,
        'horario_atencion': _horario,
        'color_primario': _colorPrimario,
        'color_secundario': _colorSecundario,
        'template': _template,
        'servicios': _servicios,
        'created_by': user.id,
        // V10.60: Nuevos campos
        'facebook': _facebook.isEmpty ? null : _facebook,
        'instagram': _instagram.isEmpty ? null : _instagram,
        'tiktok': _tiktok.isEmpty ? null : _tiktok,
        'youtube': _youtube.isEmpty ? null : _youtube,
        'sitio_web': _sitioWeb.isEmpty ? null : _sitioWeb,
        'latitud': _latitud,
        'longitud': _longitud,
        'promocion_activa': _promocionActiva,
        'promocion_texto': _promocionTexto.isEmpty ? null : _promocionTexto,
        'promocion_descuento': _promocionDescuento,
        'permite_agendar': _permiteAgendar,
        // V10.64: Campos de mejoras avanzadas
        'font': _font,
        'gradient_type': _gradientType,
        'background_texture': _backgroundTexture,
        'text_effect': _textEffect,
        'layout': _layout,
        'logo_url': _logoUrl,
        'promocion_fecha_inicio': _promocionFechaInicio?.toIso8601String().split('T').first,
        'promocion_fecha_fin': _promocionFechaFin?.toIso8601String().split('T').first,
      };
      final qrWebFallback = buildQrWebFallback(
        modulo: _modulo,
        negocioId: _negocioId?.toString(),
        tarjetaCodigo: _codigoTarjeta,
      );
      if (qrWebFallback != null) {
        datos['qr_web_fallback'] = qrWebFallback;
      }

      if (widget.tarjetaExistente != null) {
        // Actualizar
        await AppSupabase.client
            .from('tarjetas_servicio')
            .update(datos)
            .eq('id', widget.tarjetaExistente!['id']);
      } else {
        // Crear nueva
        if (_codigoTarjeta != null && _codigoTarjeta!.isNotEmpty) {
          datos['codigo'] = _codigoTarjeta;
        }
        await _insertarTarjetaConRetry(datos);
      }

      widget.onCreated();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.tarjetaExistente != null ? '✅ Tarjeta actualizada' : '✅ Tarjeta creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando tarjeta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _insertarTarjetaConRetry(Map<String, dynamic> datos) async {
    try {
      await AppSupabase.client.from('tarjetas_servicio').insert(datos);
    } catch (e) {
      if (!_esErrorCodigoDuplicado(e) || widget.tarjetaExistente != null) {
        rethrow;
      }
      _codigoTarjeta = _generarCodigoTarjeta();
      datos['codigo'] = _codigoTarjeta;
      final qrWebFallback = buildQrWebFallback(
        modulo: _modulo,
        negocioId: _negocioId?.toString(),
        tarjetaCodigo: _codigoTarjeta,
      );
      if (qrWebFallback != null) {
        datos['qr_web_fallback'] = qrWebFallback;
      }
      await AppSupabase.client.from('tarjetas_servicio').insert(datos);
    }
  }

  bool _esErrorCodigoDuplicado(Object e) {
    final mensaje = e.toString().toLowerCase();
    return mensaje.contains('codigo') && (mensaje.contains('duplicate') || mensaje.contains('unique'));
  }

  void _asegurarCodigoPreview() {
    if (_codigoTarjeta != null && _codigoTarjeta!.isNotEmpty) return;
    _codigoTarjeta = _generarCodigoTarjeta();
  }

  String _generarCodigoTarjeta() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String? _buildQrPreviewData() {
    final negocioId = _negocioId?.toString();
    final codigo = _codigoTarjeta;
    final fallback = buildQrWebFallback(
      modulo: _modulo,
      negocioId: negocioId,
      tarjetaCodigo: codigo,
    );
    if (_qrPreviewLink != null && _qrPreviewLink!.isNotEmpty) {
      final preview = _qrPreviewLink!;
      final isHttp = preview.startsWith('http://') || preview.startsWith('https://');
      if (!isHttp && fallback != null) {
        return fallback;
      }
      return preview;
    }
    if (fallback != null) {
      return fallback;
    }
    if (codigo != null && codigo.isNotEmpty && negocioId != null && negocioId.isNotEmpty) {
      return DeepLinkService.generarDeepLinkTarjetaServicio(
        modulo: _modulo,
        negocioId: negocioId,
        tarjetaCodigo: codigo,
        tipo: 'formulario',
      );
    }
    return null;
  }

  Color _qrColorFromHex(String hex) {
    final clean = hex.replaceAll('#', '');
    final base = Color(int.parse('FF$clean', radix: 16));
    return base.computeLuminance() > 0.6 ? Colors.black87 : base;
  }

  Color _getModuloColor(String modulo) {
    switch (modulo.toLowerCase()) {
      case 'climas': return const Color(0xFF00D9FF);
      case 'prestamos': return const Color(0xFF10B981);
      case 'tandas': return const Color(0xFFFBBF24);
      case 'cobranza': return const Color(0xFFEF4444);
      case 'servicios': return const Color(0xFF8B5CF6);
      case 'purificadora': return const Color(0xFF06B6D4);
      case 'agua': return const Color(0xFF06B6D4);
      case 'nice': return const Color(0xFFEC4899);
      default: return Colors.white54;
    }
  }

  IconData _getModuloIconData(String modulo) {
    switch (modulo.toLowerCase()) {
      case 'climas': return Icons.ac_unit;
      case 'prestamos': return Icons.account_balance;
      case 'tandas': return Icons.groups;
      case 'cobranza': return Icons.receipt_long;
      case 'servicios': return Icons.build;
      case 'purificadora': return Icons.water_drop;
      case 'agua': return Icons.water_drop;
      case 'nice': return Icons.diamond;
      default: return Icons.business;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: PREVIEW DE TARJETA PREMIUM
// ═══════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
// TARJETA PREMIUM V2.0 - Estilo Nova Austin con imágenes 3D de fondo
// ════════════════════════════════════════════════════════════════════════════
class _TarjetaPreview extends StatefulWidget {
  final String nombreTarjeta;
  final String nombreNegocio;
  final String slogan;
  final String telefono;
  final String whatsapp;
  final String email;
  final String direccion;
  final String ciudad;
  final List<String> servicios;
  final String colorPrimario;
  final String colorSecundario;
  final String modulo;
  final String template;
  final String? qrData;

  const _TarjetaPreview({
    required this.nombreTarjeta,
    required this.nombreNegocio,
    required this.slogan,
    required this.telefono,
    required this.whatsapp,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.servicios,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.modulo,
    required this.template,
    this.qrData,
  });

  @override
  State<_TarjetaPreview> createState() => _TarjetaPreviewState();
}

class _TarjetaPreviewState extends State<_TarjetaPreview> {
  bool _showBack = false;

  // Generar iniciales del negocio
  String get _iniciales {
    final palabras = widget.nombreNegocio.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'RD';
    if (palabras.length == 1) {
      return palabras[0].length >= 2 
          ? palabras[0].substring(0, 2).toUpperCase()
          : palabras[0].toUpperCase();
    }
    return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showBack = !_showBack),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _showBack 
            ? _buildReversoBusinessCard()
            : _buildFrenteBusinessCard(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FRENTE - Estilo Tarjeta de Presentación Dorada/Metálica
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFrenteBusinessCard() {
    return Container(
      key: const ValueKey('frente'),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        // Fondo dorado metálico con textura
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4AF37),  // Dorado claro
            Color(0xFFC9A227),  // Dorado medio
            Color(0xFFCFB53B),  // Dorado brillante
            Color(0xFFB8860B),  // Dorado oscuro
            Color(0xFFD4AF37),  // Dorado claro
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Efecto de brillo metálico
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Iniciales ENORMES
                Text(
                  _iniciales,
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF1A1A1A).withOpacity(0.85),
                    letterSpacing: 8,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.5),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Líneas decorativas alrededor del nombre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFF1A1A1A).withOpacity(0.3),
                    ),
                    const SizedBox(width: 12),
                    // Nombre del negocio
                    Text(
                      widget.nombreNegocio.isEmpty 
                          ? '• TU NEGOCIO •' 
                          : '• ${widget.nombreNegocio.toUpperCase()} •',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A).withOpacity(0.8),
                        letterSpacing: 2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFF1A1A1A).withOpacity(0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Indicador para voltear
          Positioned(
            bottom: 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 10, color: const Color(0xFF1A1A1A).withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  'Toca para ver QR',
                  style: TextStyle(fontSize: 8, color: const Color(0xFF1A1A1A).withOpacity(0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSO - Estilo Business Card Negro con QR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReversoBusinessCard() {
    final qrUrl = widget.qrData ?? 
        '$kQrWebBaseUrl?codigo=${widget.nombreTarjeta.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

    return Container(
      key: const ValueKey('reverso'),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ═══ LADO IZQUIERDO: Logo + Info de Contacto ═══
          Expanded(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo con marco decorativo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _iniciales,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              '• ${widget.nombreNegocio.split(' ').take(2).join(' ').toUpperCase()} •',
                              style: TextStyle(
                                fontSize: 5,
                                color: const Color(0xFFD4AF37).withOpacity(0.8),
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // "PROFESSIONAL" o slogan
                  Text(
                    widget.slogan.isEmpty ? 'PROFESSIONAL' : widget.slogan.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Estrellas
                  Row(
                    children: List.generate(5, (i) => const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(Icons.star, size: 8, color: Color(0xFFD4AF37)),
                    )),
                  ),
                  const Spacer(),
                  // Info de contacto - Solo mostrar si hay datos reales
                  if (widget.email.isNotEmpty)
                    _buildContactLine('✉', widget.email.toUpperCase()),
                  if (widget.telefono.isNotEmpty)
                    _buildContactLine('☎', widget.telefono),
                  if (widget.direccion.isNotEmpty)
                    _buildContactLine('', widget.direccion.length > 20 
                        ? widget.direccion.substring(0, 20).toUpperCase() 
                        : widget.direccion.toUpperCase()),
                  if (widget.ciudad.isNotEmpty)
                    _buildContactLine('', widget.ciudad.toUpperCase()),
                  const SizedBox(height: 8),
                  // Iconos de redes sociales
                  Row(
                    children: [
                      _buildSocialIcon(Icons.facebook),
                      _buildSocialIcon(Icons.camera_alt),
                      _buildSocialIcon(Icons.alternate_email),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ═══ LADO DERECHO: QR ═══
          Expanded(
            flex: 45,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // "SCAN ME"
                  const Text(
                    'SCAN ME',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // QR en fondo blanco
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: qrUrl,
                      version: QrVersions.auto,
                      size: 90,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1A1A1A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // @socialprofile
                  Text(
                    '@${widget.nombreNegocio.toLowerCase().replaceAll(' ', '')}',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactLine(String prefix, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          if (prefix.isNotEmpty) 
            Text(
              prefix,
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 7,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 10, color: const Color(0xFFD4AF37).withOpacity(0.7)),
    );
  }

  IconData _getModuloIcon() {
    switch (widget.modulo.toLowerCase()) {
      case 'climas': return Icons.ac_unit;
      case 'prestamos': return Icons.account_balance;
      case 'tandas': return Icons.groups;
      case 'cobranza': return Icons.receipt_long;
      case 'servicios': return Icons.build;
      default: return Icons.business;
    }
  }
}

class TarjetaPreviewCard extends StatelessWidget {
  final String nombreTarjeta;
  final String nombreNegocio;
  final String slogan;
  final String telefono;
  final String whatsapp;
  final String email;
  final String direccion;
  final String ciudad;
  final List<String> servicios;
  final String colorPrimario;
  final String colorSecundario;
  final String modulo;
  final String template;
  final String? qrData;

  const TarjetaPreviewCard({
    super.key,
    required this.nombreTarjeta,
    required this.nombreNegocio,
    required this.slogan,
    required this.telefono,
    required this.whatsapp,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.servicios,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.modulo,
    required this.template,
    this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    return _TarjetaPreview(
      nombreTarjeta: nombreTarjeta,
      nombreNegocio: nombreNegocio,
      slogan: slogan,
      telefono: telefono,
      whatsapp: whatsapp,
      email: email,
      direccion: direccion,
      ciudad: ciudad,
      servicios: servicios,
      colorPrimario: colorPrimario,
      colorSecundario: colorSecundario,
      modulo: modulo,
      template: template,
      qrData: qrData,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG: MOSTRAR QR
// ═══════════════════════════════════════════════════════════════════════════════

class _QRDialog extends StatefulWidget {
  final Map<String, dynamic> tarjeta;

  const _QRDialog({required this.tarjeta});

  @override
  State<_QRDialog> createState() => _QRDialogState();
}

class _QRDialogState extends State<_QRDialog> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final qrLink = resolveTarjetaQrLink(widget.tarjeta) ??
        'robertdarin://${widget.tarjeta['modulo'] ?? 'general'}/formulario?negocio=${widget.tarjeta['negocio_id']}&tarjeta=${widget.tarjeta['codigo']}';
    final colorPrimario = Color(int.parse((widget.tarjeta['color_primario'] ?? '#00D9FF').replaceFirst('#', '0xFF')));
    const qrColor = Colors.black87;
    const qrBackground = Color(0xFFF2F4F7);
    
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.tarjeta['nombre_tarjeta'] ?? 'Mi Tarjeta',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorPrimario.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.tarjeta['codigo'] ?? '---',
                style: TextStyle(color: colorPrimario, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // QR Code
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                decoration: BoxDecoration(
                  color: qrBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorPrimario.withOpacity(0.35)),
                ),
                child: QrImageView(
                  data: qrLink,
                  version: QrVersions.auto,
                  size: 200,
                  padding: EdgeInsets.zero,
                  backgroundColor: qrBackground,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: qrColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrColor,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Escanea para abrir el formulario',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            
            const SizedBox(height: 24),
            
            // Acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copiarLink(qrLink),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _compartirQR,
                    icon: _isExporting 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share, size: 18),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimario,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copiarLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Link copiado'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _compartirQR() async {
    setState(() => _isExporting = true);
    
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${widget.tarjeta['codigo']}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎴 ${widget.tarjeta['nombre_tarjeta']}\n📱 Código: ${widget.tarjeta['codigo']}',
      );
    } catch (e) {
      debugPrint('Error compartiendo QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA: VISTA PREVIA COMPLETA DE TARJETA
// ═══════════════════════════════════════════════════════════════════════════════

class _VistaPreviewTarjeta extends StatefulWidget {
  final Map<String, dynamic> tarjeta;

  const _VistaPreviewTarjeta({required this.tarjeta});

  @override
  State<_VistaPreviewTarjeta> createState() => _VistaPreviewTarjetaState();
}

class _VistaPreviewTarjetaState extends State<_VistaPreviewTarjeta> {
  final GlobalKey _cardKey = GlobalKey();
  bool _exportingPng = false;
  bool _exportingPdf = false;

  @override
  Widget build(BuildContext context) {
    final tarjeta = widget.tarjeta;
    final servicios = tarjeta['servicios'] != null
        ? List<String>.from(tarjeta['servicios'])
        : <String>[];
    final qrData = _resolveTarjetaDeepLink(tarjeta);
    
    return PremiumScaffold(
      title: '👁️ Vista Previa',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: AspectRatio(
                aspectRatio: kTarjetaPrintAspectRatio,
                child: _TarjetaPreview(
                  nombreTarjeta: tarjeta['nombre_tarjeta'] ?? '',
                  nombreNegocio: tarjeta['nombre_negocio'] ?? '',
                  slogan: tarjeta['slogan'] ?? '',
                  telefono: tarjeta['telefono_principal'] ?? '',
                  whatsapp: tarjeta['whatsapp'] ?? '',
                  email: tarjeta['email'] ?? '',
                  direccion: tarjeta['direccion'] ?? '',
                  ciudad: tarjeta['ciudad'] ?? '',
                  servicios: servicios,
                  colorPrimario: tarjeta['color_primario'] ?? '#00D9FF',
                  colorSecundario: tarjeta['color_secundario'] ?? '#8B5CF6',
                  modulo: tarjeta['modulo'] ?? 'general',
                  template: tarjeta['template'] ?? 'profesional',
                  qrData: qrData,
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            Text(
              kTarjetaPrintLabel,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            
            const SizedBox(height: 16),
            _buildExportButtons(tarjeta),
            const SizedBox(height: 24),
            
            // Detalles
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Detalles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDetalle('Código', tarjeta['codigo'] ?? '---'),
                  _buildDetalle('Módulo', (tarjeta['modulo'] ?? 'general').toUpperCase()),
                  _buildDetalle('Escaneos', '${tarjeta['escaneos_total'] ?? 0}'),
                  _buildDetalle('Estado', (tarjeta['activa'] ?? true) ? '✅ Activa' : '⏸️ Inactiva'),
                  if (tarjeta['ultimo_escaneo'] != null)
                    _buildDetalle('Último escaneo', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(tarjeta['ultimo_escaneo']))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String? _resolveTarjetaDeepLink(Map<String, dynamic> tarjeta) {
    return resolveTarjetaQrLink(tarjeta);
  }

  Widget _buildExportButtons(Map<String, dynamic> tarjeta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Exportar para imprenta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingPng ? null : () => _exportarPng(tarjeta, dpi: 600),
                  icon: _exportingPng
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: const Text('PNG 600 DPI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingPng ? null : () => _exportarPng(tarjeta, dpi: 300),
                  icon: _exportingPng
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: const Text('PNG 300 DPI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingPdf ? null : () => _exportarPdf(tarjeta),
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF 9x5 cm'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportingPng ? null : () => _exportarJpg(tarjeta, dpi: 600),
                  icon: _exportingPng
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo),
                  label: const Text('JPG 600 DPI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recomendado: 600 DPI para imprenta.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _renderTarjetaBytes({required int dpi}) async {
    final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final targetWidthPx = (kTarjetaPrintWidthCm / 2.54 * dpi);
    final pixelRatio = (targetWidthPx / boundary.size.width).clamp(1.0, 6.0);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _exportarPng(Map<String, dynamic> tarjeta, {required int dpi}) async {
    setState(() => _exportingPng = true);
    try {
      final pngBytes = await _renderTarjetaBytes(dpi: dpi);
      if (pngBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final codigo = tarjeta['codigo'] ?? 'tarjeta';
      final file = File('${tempDir.path}/tarjeta_${codigo}_${dpi}dpi.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tarjeta ${tarjeta['nombre_tarjeta'] ?? ''} (PNG ${dpi} DPI)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error PNG: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPng = false);
    }
  }

  Future<void> _exportarPdf(Map<String, dynamic> tarjeta) async {
    setState(() => _exportingPdf = true);
    try {
      final pngBytes = await _renderTarjetaBytes(dpi: kTarjetaPrintDpi);
      if (pngBytes == null) return;

      final pdf = pw.Document();
      final pageFormat = PdfPageFormat(
        (kTarjetaPrintWidthCm / 2.54) * PdfPageFormat.inch,
        (kTarjetaPrintHeightCm / 2.54) * PdfPageFormat.inch,
        marginAll: 0,
      );
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Center(
              child: pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final codigo = tarjeta['codigo'] ?? 'tarjeta';
      final file = File('${tempDir.path}/tarjeta_${codigo}_9x5cm.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tarjeta ${tarjeta['nombre_tarjeta'] ?? ''} (PDF 9x5 cm)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportarJpg(Map<String, dynamic> tarjeta, {required int dpi}) async {
    setState(() => _exportingPng = true);
    try {
      final pngBytes = await _renderTarjetaBytes(dpi: dpi);
      if (pngBytes == null) return;

      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) return;
      final jpgBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));

      final tempDir = await getTemporaryDirectory();
      final codigo = tarjeta['codigo'] ?? 'tarjeta';
      final file = File('${tempDir.path}/tarjeta_${codigo}_${dpi}dpi.jpg');
      await file.writeAsBytes(jpgBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tarjeta ${tarjeta['nombre_tarjeta'] ?? ''} (JPG ${dpi} DPI)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error JPG: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPng = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN PAINTER - Patrón decorativo de fondo
// ═══════════════════════════════════════════════════════════════════════════════
class _PatternPainter extends CustomPainter {
  final Color color;
  
  _PatternPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Líneas diagonales sutiles
    for (var i = 0; i < size.width + size.height; i += 25) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(0, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════
// CLASE AUXILIAR PARA CONFIGURACIÓN DE ICONOS 3D
// ══════════════════════════════════════════════════════════════════════════
class _IconoConfig {
  final IconData icon;
  final double x;
  final double y;
  final double size;
  final double rotation;

  _IconoConfig(this.icon, this.x, this.y, this.size, this.rotation);
}

// ══════════════════════════════════════════════════════════════════════════════════
// WIDGETS DE PREVIEW EN TIEMPO REAL - V10.61 Estilo Zazzle
// ══════════════════════════════════════════════════════════════════════════════════

/// Preview del FRENTE de la tarjeta (dorado metálico)
class _TarjetaPreviewFrenteLive extends StatelessWidget {
  final String nombreNegocio;
  final String colorPrimario;

  const _TarjetaPreviewFrenteLive({
    required this.nombreNegocio,
    required this.colorPrimario,
  });

  String get _iniciales {
    final palabras = nombreNegocio.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'RD';
    if (palabras.length == 1) {
      return palabras[0].length >= 2 
          ? palabras[0].substring(0, 2).toUpperCase()
          : palabras[0].toUpperCase();
    }
    return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4AF37),
            Color(0xFFC9A227),
            Color(0xFFCFB53B),
            Color(0xFFB8860B),
            Color(0xFFD4AF37),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Efecto brillo
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Contenido
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Iniciales grandes con estilo firma
                Text(
                  _iniciales,
                  style: TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.w200,
                    color: const Color(0xFF1A1A1A).withOpacity(0.85),
                    letterSpacing: 12,
                    fontFamily: 'serif',
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.6),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Líneas decorativas + nombre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF1A1A1A).withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      nombreNegocio.isEmpty 
                          ? '• TU NEGOCIO •' 
                          : '• ${nombreNegocio.toUpperCase()} •',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A).withOpacity(0.8),
                        letterSpacing: 3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A1A1A).withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tap hint
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rotate_right, size: 12, color: const Color(0xFF1A1A1A).withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  'Toca para girar',
                  style: TextStyle(fontSize: 10, color: const Color(0xFF1A1A1A).withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview del REVERSO de la tarjeta (negro con QR)
class _TarjetaPreviewReversoLive extends StatelessWidget {
  final String nombreNegocio;
  final String slogan;
  final String telefono;
  final String email;
  final String ciudad;
  final String? qrData;
  final String colorPrimario;

  const _TarjetaPreviewReversoLive({
    required this.nombreNegocio,
    required this.slogan,
    required this.telefono,
    required this.email,
    required this.ciudad,
    this.qrData,
    required this.colorPrimario,
  });

  String get _iniciales {
    final palabras = nombreNegocio.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'RD';
    if (palabras.length == 1) {
      return palabras[0].length >= 2 
          ? palabras[0].substring(0, 2).toUpperCase()
          : palabras[0].toUpperCase();
    }
    return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lado izquierdo: Info
          Expanded(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo mini
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                        ),
                        child: Text(
                          _iniciales,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreNegocio.isEmpty ? 'TU NEGOCIO' : nombreNegocio.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (slogan.isNotEmpty)
                              Text(
                                slogan,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Datos de contacto
                  if (telefono.isNotEmpty)
                    _buildContactRow(Icons.phone, telefono),
                  if (email.isNotEmpty)
                    _buildContactRow(Icons.email_outlined, email),
                  if (ciudad.isNotEmpty)
                    _buildContactRow(Icons.location_on_outlined, ciudad),
                ],
              ),
            ),
          ),
          // Lado derecho: QR
          Expanded(
            flex: 45,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: qrData != null && qrData!.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(
                          data: qrData!,
                          version: QrVersions.auto,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black87,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black87,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2, size: 50, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            'QR',
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

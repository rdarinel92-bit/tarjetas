// ═══════════════════════════════════════════════════════════════════════════════
// GENERADOR DE QR PARA TARJETA DE PRESENTACIÓN - CLIMAS V10.51
// Genera QR que abre directamente la app con el formulario de solicitud
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/deep_link_service.dart';
import '../../core/supabase_client.dart';

class ClimasGenerarQrTarjetaScreen extends StatefulWidget {
  final String? negocioId;
  
  const ClimasGenerarQrTarjetaScreen({
    super.key,
    this.negocioId,
  });

  @override
  State<ClimasGenerarQrTarjetaScreen> createState() => _ClimasGenerarQrTarjetaScreenState();
}

class _ClimasGenerarQrTarjetaScreenState extends State<ClimasGenerarQrTarjetaScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String? _negocioId;
  String _negocioNombre = 'Mi Negocio de Climas';
  String _deepLink = '';
  bool _isLoading = true;
  String? _errorMensaje;
  int _qrSize = 250;
  Color _qrColor = const Color(0xFF00D9FF);
  bool _conLogo = true;
  
  @override
  void initState() {
    super.initState();
    _cargarNegocio();
  }

  Future<void> _cargarNegocio() async {
    try {
      // Obtener el negocio activo o el primero de climas
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Buscar negocio de climas del usuario
      Map<String, dynamic>? res = await AppSupabase.client
          .from('negocios')
          .select('id, nombre, tipo')
          .eq('propietario_id', user.id)
          .ilike('tipo', '%clima%')
          .limit(1)
          .maybeSingle();

      if (res == null) {
        try {
          final accesosRes = await AppSupabase.client
              .from('usuarios_negocios')
              .select('negocios(id, nombre, tipo)')
              .eq('usuario_id', user.id)
              .eq('activo', true);
          for (final acceso in (accesosRes as List)) {
            final negocio = acceso['negocios'];
            if (negocio is Map) {
              final tipo = (negocio['tipo'] ?? '').toString().toLowerCase();
              if (tipo.contains('clima')) {
                res = Map<String, dynamic>.from(negocio);
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (res != null) {
        _negocioId = res['id'];
        _negocioNombre = res['nombre'] ?? 'Mi Negocio de Climas';
      } else if (widget.negocioId != null && widget.negocioId!.isNotEmpty) {
        _negocioId = widget.negocioId;
        final byId = await AppSupabase.client
            .from('negocios')
            .select('nombre')
            .eq('id', widget.negocioId!)
            .maybeSingle();
        if (byId != null) {
          _negocioNombre = byId['nombre'] ?? _negocioNombre;
        }
      } else {
        _errorMensaje = 'No se encontró un negocio de climas asociado a tu cuenta.';
      }

      _generarDeepLink();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error cargando negocio: $e');
      _errorMensaje = 'No fue posible cargar el negocio de climas.';
      _negocioId = widget.negocioId;
      _generarDeepLink();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _generarDeepLink() {
    if (_negocioId == null || _negocioId!.isEmpty) {
      _deepLink = '';
      return;
    }
    _deepLink = DeepLinkService.generarDeepLinkClimas(
      negocioId: _negocioId!,
      tipo: 'formulario',
    );
    debugPrint('🔗 Deep Link generado: $_deepLink');
  }

  Future<void> _compartirQR() async {
    try {
      if (_deepLink.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay QR válido para compartir.')),
        );
        return;
      }
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_climas_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR para solicitar servicio de climas - $_negocioNombre',
      );
    } catch (e) {
      debugPrint('Error compartiendo QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  Future<void> _guardarQR() async {
    try {
      if (_deepLink.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay QR válido para guardar.')),
        );
        return;
      }
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 4.0); // Alta resolución
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'QR_Climas_${_negocioNombre.replaceAll(' ', '_')}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ QR guardado en: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Generar QR para Tarjeta'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _deepLink.isEmpty ? null : _compartirQR,
            tooltip: 'Compartir',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _deepLink.isEmpty ? null : _guardarQR,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_errorMensaje != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMensaje!,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildPreviewCard(),
                      const SizedBox(height: 24),
                      _buildOpciones(),
                      const SizedBox(height: 24),
                      _buildInfoDeepLink(),
                      const SizedBox(height: 24),
                      _buildBotonesAccion(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _qrColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '📱 Vista Previa del QR',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (_conLogo) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_qrColor, const Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.ac_unit,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _negocioNombre,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_deepLink.isEmpty)
                    SizedBox(
                      height: _qrSize.toDouble(),
                      width: _qrSize.toDouble(),
                      child: Center(
                        child: Text(
                          'Sin negocio válido',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    QrImageView(
                      data: _deepLink,
                      version: QrVersions.auto,
                      size: _qrSize.toDouble(),
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: _qrColor,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black87,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '¡Escanea para solicitar servicio!',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpciones() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ Opciones de Diseño',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Tamaño
          Row(
            children: [
              const Text('Tamaño:', style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _qrSize.toDouble(),
                  min: 150,
                  max: 350,
                  divisions: 4,
                  label: '${_qrSize}px',
                  activeColor: _qrColor,
                  onChanged: (value) {
                    setState(() => _qrSize = value.toInt());
                  },
                ),
              ),
            ],
          ),
          // Color
          Row(
            children: [
              const Text('Color:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              ...[
                const Color(0xFF00D9FF), // Cyan
                const Color(0xFF8B5CF6), // Purple
                const Color(0xFF10B981), // Green
                const Color(0xFFEF4444), // Red
                const Color(0xFFFBBF24), // Yellow
              ].map((color) => GestureDetector(
                onTap: () => setState(() => _qrColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _qrColor == color
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Logo
          SwitchListTile(
            title: const Text('Incluir logo y nombre', style: TextStyle(color: Colors.white70)),
            value: _conLogo,
            activeColor: _qrColor,
            onChanged: (value) => setState(() => _conLogo = value),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDeepLink() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _qrColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: _qrColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Deep Link del QR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _deepLink.isEmpty
                ? Text(
                    'No hay deep link disponible.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  )
                : SelectableText(
                    _deepLink,
                    style: TextStyle(
                      color: _qrColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '📱 Cuando el cliente escanee este QR, se abrirá directamente '
            'el formulario de solicitud en la app.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _deepLink.isEmpty ? null : _compartirQR,
            style: ElevatedButton.styleFrom(
              backgroundColor: _qrColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.share),
            label: const Text(
              'Compartir QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deepLink.isEmpty ? null : _guardarQR,
            style: OutlinedButton.styleFrom(
              foregroundColor: _qrColor,
              side: BorderSide(color: _qrColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.download),
            label: const Text(
              'Guardar en Alta Resolución',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Usa el QR guardado para imprimirlo en tu tarjeta de presentación, '
                  'volantes o redes sociales.',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

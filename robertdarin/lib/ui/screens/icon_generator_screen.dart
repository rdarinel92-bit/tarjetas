import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Utilidad para generar ícono PNG del logo
/// Uso en debug para crear los assets de ícono de app
class IconGeneratorScreen extends StatefulWidget {
  const IconGeneratorScreen({super.key});

  @override
  State<IconGeneratorScreen> createState() => _IconGeneratorScreenState();
}

class _IconGeneratorScreenState extends State<IconGeneratorScreen> {
  final GlobalKey _iconKey = GlobalKey();
  bool _generando = false;
  Uint8List? _pngBytes;

  Future<void> _capturarIcono() async {
    setState(() => _generando = true);

    try {
      RenderRepaintBoundary boundary =
          _iconKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 4.0); // Alta resolución
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        setState(() {
          _pngBytes = byteData.buffer.asUint8List();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ícono generado: ${_pngBytes!.length} bytes'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _generando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        title: const Text('Generador de Ícono'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '📱 Vista previa del ícono de app',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),

            // Preview del ícono
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Ícono capturado
                  RepaintBoundary(
                    key: _iconKey,
                    child: Container(
                      width: 256,
                      height: 256,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D14),
                        borderRadius: BorderRadius.circular(56), // Adaptive icon style
                      ),
                      child: CustomPaint(
                        size: const Size(256, 256),
                        painter: _AppIconPainter(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Diferentes tamaños preview
                  const Text('Tamaños:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSizePreview(192, 'xxxhdpi'),
                      _buildSizePreview(144, 'xxhdpi'),
                      _buildSizePreview(96, 'xhdpi'),
                      _buildSizePreview(72, 'hdpi'),
                      _buildSizePreview(48, 'mdpi'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botón de generar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : _capturarIcono,
                icon: _generando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_generando ? 'Generando...' : 'Capturar PNG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (_pngBytes != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('PNG Generado',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tamaño: ${(_pngBytes!.length / 1024).toStringAsFixed(1)} KB\n'
                      'Para usar, exporta este PNG y usa flutter_launcher_icons',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Instrucciones:', 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    '1. Esta pantalla genera una vista previa del ícono\n'
                    '2. Para producción, usa flutter_launcher_icons\n'
                    '3. Coloca el PNG en assets/icons/app_icon.png\n'
                    '4. Ejecuta: dart run flutter_launcher_icons\n'
                    '5. Ver docs/GENERACION_ICONOS_APP.md para detalles',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizePreview(double size, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(size * 0.1),
            ),
            child: CustomPaint(
              painter: _AppIconPainter(),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Painter del ícono de app (versión simplificada para íconos pequeños)
class _AppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Fondo circular con gradiente
    final bgGradient = RadialGradient(
      colors: [
        const Color(0xFF1A1A2E),
        const Color(0xFF0D0D14),
      ],
      stops: const [0.4, 1.0],
    );

    final bgPaint = Paint()
      ..shader = bgGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, bgPaint);

    // Borde con gradiente
    final borderGradient = LinearGradient(
      colors: const [
        Color(0xFF00D9FF),
        Color(0xFF8B5CF6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;

    canvas.drawCircle(center, radius * 0.92, borderPaint);

    // Letras RD
    final letterGradient = LinearGradient(
      colors: const [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final letterPaint = Paint()
      ..shader = letterGradient.createShader(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Letra R
    final rPath = Path();
    final rStartX = center.dx - radius * 0.35;
    final rStartY = center.dy - radius * 0.3;
    final rHeight = radius * 0.6;
    final rWidth = radius * 0.32;

    rPath.moveTo(rStartX, rStartY + rHeight);
    rPath.lineTo(rStartX, rStartY);
    rPath.quadraticBezierTo(
      rStartX + rWidth * 1.2, rStartY,
      rStartX + rWidth, rStartY + rHeight * 0.22,
    );
    rPath.quadraticBezierTo(
      rStartX + rWidth * 0.8, rStartY + rHeight * 0.4,
      rStartX, rStartY + rHeight * 0.4,
    );
    rPath.moveTo(rStartX + rWidth * 0.25, rStartY + rHeight * 0.4);
    rPath.lineTo(rStartX + rWidth, rStartY + rHeight);

    canvas.drawPath(rPath, letterPaint);

    // Letra D
    final dPath = Path();
    final dStartX = center.dx + radius * 0.05;
    final dStartY = center.dy - radius * 0.3;
    final dHeight = radius * 0.6;
    final dWidth = radius * 0.32;

    dPath.moveTo(dStartX, dStartY + dHeight);
    dPath.lineTo(dStartX, dStartY);
    dPath.quadraticBezierTo(
      dStartX + dWidth * 1.3, dStartY,
      dStartX + dWidth * 1.2, dStartY + dHeight * 0.5,
    );
    dPath.quadraticBezierTo(
      dStartX + dWidth * 1.3, dStartY + dHeight,
      dStartX, dStartY + dHeight,
    );

    canvas.drawPath(dPath, letterPaint);

    // Punto decorativo
    final dotPaint = Paint()
      ..shader = letterGradient.createShader(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.05, center.dy + radius * 0.12),
      size.width * 0.02,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

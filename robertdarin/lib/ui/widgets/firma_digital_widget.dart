import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Widget de Firma Digital
/// Permite al usuario dibujar su firma en pantalla y guardarla
class FirmaDigitalWidget extends StatefulWidget {
  final Function(Uint8List? imageBytes)? onFirmaSaved;
  final Color penColor;
  final double penStrokeWidth;
  final Color backgroundColor;

  const FirmaDigitalWidget({
    super.key,
    this.onFirmaSaved,
    this.penColor = Colors.white,
    this.penStrokeWidth = 3.0,
    this.backgroundColor = const Color(0xFF1E1E2C),
  });

  @override
  State<FirmaDigitalWidget> createState() => _FirmaDigitalWidgetState();
}

class _FirmaDigitalWidgetState extends State<FirmaDigitalWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _firmando = false;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _firmando = true;
      _currentStroke = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke = [..._currentStroke, details.localPosition];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _firmando = false;
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
      }
      _currentStroke = [];
    });
  }

  void _limpiarFirma() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  bool get _tieneFirma => _strokes.isNotEmpty;

  Future<Uint8List?> _exportarFirma() async {
    if (!_tieneFirma) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // ignore: prefer_const_declarations
    final size = const Size(400, 200);

    // Fondo transparente o blanco
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Dibujar trazos
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = widget.penStrokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Área de firma
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _firmando ? Colors.blueAccent : Colors.white24,
              width: _firmando ? 2 : 1,
            ),
          ),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: _FirmaPainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
                penColor: widget.penColor,
                penStrokeWidth: widget.penStrokeWidth,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Instrucciones
        Text(
          _tieneFirma ? "✅ Firma registrada" : "Dibuja tu firma arriba",
          style: TextStyle(
            color: _tieneFirma ? Colors.greenAccent : Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 15),

        // Botones
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _limpiarFirma,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Limpiar"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _tieneFirma
                    ? () async {
                        final bytes = await _exportarFirma();
                        widget.onFirmaSaved?.call(bytes);
                      }
                    : null,
                icon: const Icon(Icons.check, size: 18),
                label: const Text("Guardar Firma"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FirmaPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penStrokeWidth;

  _FirmaPainter({
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeWidth = penStrokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Dibujar trazos guardados
    for (var stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Dibujar trazo actual
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) return;
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}

/// Modal para capturar firma digital
class FirmaDigitalModal extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final Function(Uint8List? imageBytes)? onFirmaSaved;

  const FirmaDigitalModal({
    super.key,
    this.titulo = "Firma Digital",
    this.descripcion = "Dibuja tu firma en el recuadro",
    this.onFirmaSaved,
  });

  static Future<Uint8List?> mostrar(
    BuildContext context, {
    String titulo = "Firma Digital",
    String descripcion = "Dibuja tu firma en el recuadro",
  }) async {
    Uint8List? resultado;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.draw, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            Text(descripcion,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            FirmaDigitalWidget(
              onFirmaSaved: (bytes) {
                resultado = bytes;
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 15),
            const Text(
              "⚖️ Al firmar, aceptas los términos del contrato de aval y te comprometes como garante del préstamo.",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );

    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

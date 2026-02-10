// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Logo profesional de Robert Darin Platform
/// Estilo: Moderno, minimalista, fintech premium
/// Colores: Cyan (#00D9FF) y Purple (#8B5CF6) como acentos
/// 
/// Uso:
/// ```dart
/// RobertDarinLogo(size: 120)
/// RobertDarinLogo.horizontal(height: 60)
/// RobertDarinLogo.icon(size: 48)
/// ```
class RobertDarinLogo extends StatelessWidget {
  final double size;
  final bool animated;
  final bool showText;
  final bool showTagline;

  const RobertDarinLogo({
    super.key,
    this.size = 100,
    this.animated = true,
    this.showText = true,
    this.showTagline = true,
  });

  /// Logo solo icono (para app icon, favicon)
  const RobertDarinLogo.icon({
    super.key,
    this.size = 48,
    this.animated = false,
  })  : showText = false,
        showTagline = false;

  /// Logo horizontal con texto al lado
  factory RobertDarinLogo.horizontal({
    Key? key,
    double height = 50,
    bool animated = false,
  }) {
    return RobertDarinLogo(
      key: key,
      size: height,
      animated: animated,
      showText: true,
      showTagline: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return _AnimatedLogo(
        size: size,
        showText: showText,
        showTagline: showTagline,
      );
    }

    return _StaticLogo(
      size: size,
      showText: showText,
      showTagline: showTagline,
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final bool showTagline;

  const _AnimatedLogo({
    required this.size,
    required this.showText,
    required this.showTagline,
  });

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: _StaticLogo(
            size: widget.size,
            showText: widget.showText,
            showTagline: widget.showTagline,
            glowIntensity: _glowAnimation.value,
          ),
        );
      },
    );
  }
}

class _StaticLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showTagline;
  final double glowIntensity;

  const _StaticLogo({
    required this.size,
    required this.showText,
    required this.showTagline,
    this.glowIntensity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(glowIntensity),
                blurRadius: size * 0.3,
                spreadRadius: size * 0.05,
              ),
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(glowIntensity * 0.5),
                blurRadius: size * 0.4,
                spreadRadius: size * 0.02,
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(size, size),
            painter: _LogoPainter(),
          ),
        ),

        if (showText) ...[
          SizedBox(height: size * 0.15),
          _buildLogoText(),
        ],

        if (showTagline) ...[
          SizedBox(height: size * 0.06),
          _buildTagline(),
        ],
      ],
    );
  }

  Widget _buildLogoText() {
    final fontSize = size * 0.32;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        "Uniko",
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: fontSize * 0.08,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    final fontSize = size * 0.1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.15,
        vertical: size * 0.04,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.15),
            const Color(0xFF8B5CF6).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        "M U L T I   S Y S T E M",
        style: TextStyle(
          color: const Color(0xFF00D9FF),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: fontSize * 0.3,
        ),
      ),
    );
  }
}

/// Custom Painter para el logo icono
/// Diseño: "RD" estilizado dentro de un hexágono con gradiente
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    // Gradiente de fondo
    final bgGradient = RadialGradient(
      colors: [
        const Color(0xFF1A1A2E),
        const Color(0xFF0D0D14),
      ],
      stops: const [0.3, 1.0],
    );

    // Círculo de fondo
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, bgPaint);

    // Borde con gradiente
    final borderGradient = SweepGradient(
      colors: const [
        Color(0xFF00D9FF),
        Color(0xFF8B5CF6),
        Color(0xFF00D9FF),
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;

    canvas.drawCircle(center, radius * 0.95, borderPaint);

    // Dibujar "RD" estilizado
    _drawRDLetters(canvas, size, center, radius);

    // Elementos decorativos
    _drawAccents(canvas, size, center, radius);
  }

  void _drawRDLetters(Canvas canvas, Size size, Offset center, double radius) {
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
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = letterGradient.createShader(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      )
      ..style = PaintingStyle.fill;

    // Letra R estilizada
    final rPath = Path();
    final rStartX = center.dx - radius * 0.35;
    final rStartY = center.dy - radius * 0.35;
    final rHeight = radius * 0.7;
    final rWidth = radius * 0.35;

    // Vertical de R
    rPath.moveTo(rStartX, rStartY + rHeight);
    rPath.lineTo(rStartX, rStartY);
    
    // Curva superior de R
    rPath.quadraticBezierTo(
      rStartX + rWidth * 1.2, rStartY,
      rStartX + rWidth, rStartY + rHeight * 0.25,
    );
    rPath.quadraticBezierTo(
      rStartX + rWidth * 0.8, rStartY + rHeight * 0.45,
      rStartX, rStartY + rHeight * 0.45,
    );
    
    // Diagonal de R
    rPath.moveTo(rStartX + rWidth * 0.3, rStartY + rHeight * 0.45);
    rPath.lineTo(rStartX + rWidth * 1.1, rStartY + rHeight);

    canvas.drawPath(rPath, letterPaint);

    // Letra D estilizada
    final dPath = Path();
    final dStartX = center.dx + radius * 0.05;
    final dStartY = center.dy - radius * 0.35;
    final dHeight = radius * 0.7;
    final dWidth = radius * 0.35;

    // Vertical de D
    dPath.moveTo(dStartX, dStartY + dHeight);
    dPath.lineTo(dStartX, dStartY);
    
    // Curva de D
    dPath.quadraticBezierTo(
      dStartX + dWidth * 1.4, dStartY,
      dStartX + dWidth * 1.3, dStartY + dHeight * 0.5,
    );
    dPath.quadraticBezierTo(
      dStartX + dWidth * 1.4, dStartY + dHeight,
      dStartX, dStartY + dHeight,
    );

    canvas.drawPath(dPath, letterPaint);

    // Punto decorativo entre R y D
    final dotCenter = Offset(center.dx - radius * 0.05, center.dy + radius * 0.15);
    canvas.drawCircle(dotCenter, size.width * 0.025, fillPaint);
  }

  void _drawAccents(Canvas canvas, Size size, Offset center, double radius) {
    // Pequeños puntos decorativos alrededor
    final accentPaint = Paint()
      ..color = const Color(0xFF00D9FF).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Punto superior
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.75),
      size.width * 0.015,
      accentPaint,
    );

    // Puntos laterales
    canvas.drawCircle(
      Offset(center.dx - radius * 0.65, center.dy - radius * 0.38),
      size.width * 0.012,
      accentPaint..color = const Color(0xFF8B5CF6).withOpacity(0.5),
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.65, center.dy - radius * 0.38),
      size.width * 0.012,
      accentPaint..color = const Color(0xFF8B5CF6).withOpacity(0.5),
    );

    // Arco inferior decorativo
    final arcPaint = Paint()
      ..color = const Color(0xFF00D9FF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.6);
    canvas.drawArc(arcRect, math.pi * 0.6, math.pi * 0.3, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget de logo simplificado para usar como ícono de app
/// Exportable como imagen para Android/iOS icons
class RobertDarinAppIcon extends StatelessWidget {
  final double size;
  final Color? backgroundColor;

  const RobertDarinAppIcon({
    super.key,
    this.size = 512,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(size * 0.22), // Android adaptive icon
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.8, size * 0.8),
          painter: _LogoPainter(),
        ),
      ),
    );
  }
}

/// Splash animado con el logo
class RobertDarinSplash extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;

  const RobertDarinSplash({
    super.key,
    this.onComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<RobertDarinSplash> createState() => _RobertDarinSplashState();
}

class _RobertDarinSplashState extends State<RobertDarinSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(
                scale: _scale.value,
                child: const RobertDarinLogo(
                  size: 140,
                  animated: false,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

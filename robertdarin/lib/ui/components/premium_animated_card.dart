import 'package:flutter/material.dart';

class PremiumAnimatedCard extends StatefulWidget {
  final Widget child;

  const PremiumAnimatedCard({super.key, required this.child});

  @override
  State<PremiumAnimatedCard> createState() => _PremiumAnimatedCardState();
}

class _PremiumAnimatedCardState extends State<PremiumAnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.98,
      upperBound: 1.0,
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

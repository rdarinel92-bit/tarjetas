import 'package:flutter/material.dart';

class PremiumIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const PremiumIcon({
    super.key,
    required this.icon,
    this.size = 26,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}

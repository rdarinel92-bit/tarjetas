import 'package:flutter/material.dart';
import '../../../../data/models/prestamo_model.dart';

class PrestamoCard extends StatelessWidget {
  final PrestamoModel prestamo;

  const PrestamoCard({super.key, required this.prestamo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Monto: \$${prestamo.monto}'),
        subtitle: Text('Interés: ${prestamo.interes}%'),
      ),
    );
  }
}

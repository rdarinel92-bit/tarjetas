import 'package:flutter/material.dart';
import '../../../../data/models/aval_model.dart';

class AvalCard extends StatelessWidget {
  final AvalModel aval;

  const AvalCard({super.key, required this.aval});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(aval.nombre),
        subtitle: Text(aval.telefono),
      ),
    );
  }
}

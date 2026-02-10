import 'package:flutter/material.dart';
import '../../../../data/models/tanda_model.dart';

class TandaCard extends StatelessWidget {
  final TandaModel tanda;

  const TandaCard({super.key, required this.tanda});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(tanda.nombre),
        subtitle: Text('Monto por persona: \$${tanda.montoPorPersona}'),
      ),
    );
  }
}

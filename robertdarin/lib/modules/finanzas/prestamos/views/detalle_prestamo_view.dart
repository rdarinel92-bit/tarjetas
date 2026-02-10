import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/prestamo_model.dart';
import '../../../../data/models/pago_model.dart';
import '../../../../data/models/comprobante_prestamo_model.dart';
import '../../../../data/services/storage_service.dart';
import '../controllers/prestamos_controller.dart';
import '../controllers/pagos_controller.dart';
import '../controllers/comprobantes_prestamo_controller.dart';


class DetallePrestamoView extends StatefulWidget {
  final PrestamoModel prestamo;
  final PrestamosController prestamosController;
  final PagosController pagosController;
  final ComprobantesPrestamoController comprobantesController;

  const DetallePrestamoView({
    super.key,
    required this.prestamo,
    required this.prestamosController,
    required this.pagosController,
    required this.comprobantesController,
  });

  @override
  State<DetallePrestamoView> createState() => _DetallePrestamoViewState();
}

class _DetallePrestamoViewState extends State<DetallePrestamoView> {
  final StorageService storageService = StorageService();

  double _calcularTotalPagado(List<PagoModel> pagos) {
    double total = 0;
    for (final p in pagos) {
      total += p.monto;
    }
    return total;
  }

  String _calcularEstado(double totalPagado, double montoTotal, String estadoBase) {
    if (totalPagado >= montoTotal) {
      return 'pagado';
    }
    if (totalPagado > 0 && totalPagado < montoTotal) {
      return 'parcial';
    }
    return estadoBase;
  }

  Future<void> _registrarPago(BuildContext context) async {
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    File? archivoSeleccionado;
    String comprobanteUrl = '';

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Registrar pago'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoCtrl,
                  decoration: const InputDecoration(labelText: 'Monto'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: notaCtrl,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
                TextField(
                  controller: latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitud'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitud'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final path = result.files.single.path;
                      if (path != null) {
                        archivoSeleccionado = File(path);
                      }
                    }
                  },
                  child: const Text('Seleccionar comprobante (INE, foto, etc.)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (archivoSeleccionado != null) {
                  final String nombreArchivo = '${widget.prestamo.id}_${DateTime.now().millisecondsSinceEpoch}';
                  final url = await storageService.subirArchivo(archivoSeleccionado!, nombreArchivo);
                  comprobanteUrl = url ?? '';
                }

                final pago = PagoModel(
                  id: '',
                  prestamoId: widget.prestamo.id,
                  monto: double.tryParse(montoCtrl.text) ?? 0,
                  fechaPago: DateTime.now(),
                  nota: notaCtrl.text,
                  latitud: latCtrl.text.isNotEmpty ? double.tryParse(latCtrl.text) : null,
                  longitud: lngCtrl.text.isNotEmpty ? double.tryParse(lngCtrl.text) : null,
                  comprobanteUrl: comprobanteUrl,
                  createdAt: DateTime.now(),
                );

                await widget.pagosController.crearPago(pago);
                if (comprobanteUrl.isNotEmpty) {
                  final comprobante = ComprobantePrestamoModel(
                    id: '',
                    prestamoId: widget.prestamo.id,
                    tipo: 'pago',
                    url: comprobanteUrl,
                    latitud: pago.latitud,
                    longitud: pago.longitud,
                    createdAt: DateTime.now(),
                  );
                  await widget.comprobantesController.crearComprobante(comprobante);
                }

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double montoTotal = widget.prestamo.monto;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Préstamo')),
      body: FutureBuilder(
        future: Future.wait([
          widget.pagosController.obtenerPagosPorPrestamo(widget.prestamo.id),
          widget.comprobantesController.obtenerComprobantesPorPrestamo(widget.prestamo.id),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List results = snapshot.data as List;
          final List<PagoModel> pagos = results[0] as List<PagoModel>;
          final List<ComprobantePrestamoModel> comprobantes = results[1] as List<ComprobantePrestamoModel>;

          final totalPagado = _calcularTotalPagado(pagos);
          final estadoCalculado = _calcularEstado(totalPagado, montoTotal, widget.prestamo.estado);
          final saldoPendiente = montoTotal - totalPagado;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monto: \$${widget.prestamo.monto}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Interés: ${widget.prestamo.interes}%'),
                Text('Plazo: ${widget.prestamo.plazoMeses} meses'),
                Text('Estado: $estadoCalculado'),
                const SizedBox(height: 10),
                Text('Total pagado: \$${totalPagado.toStringAsFixed(2)}'),
                Text('Saldo pendiente: \$${saldoPendiente.toStringAsFixed(2)}'),
                const SizedBox(height: 20),

                const Text('Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (pagos.isEmpty)
                  const Text('Sin pagos registrados'),
                if (pagos.isNotEmpty)
                  Column(
                    children: pagos.map((p) {
                      return ListTile(
                        title: Text('\$${p.monto.toStringAsFixed(2)}'),
                        subtitle: Text(p.fechaPago.toIso8601String()),
                        trailing: p.comprobanteUrl.isNotEmpty ? const Icon(Icons.attachment) : null,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await _registrarPago(context);
                  },
                  child: const Text('Registrar pago'),
                ),

                const SizedBox(height: 30),
                const Text('Comprobantes del préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (comprobantes.isEmpty)
                  const Text('Sin comprobantes'),
                if (comprobantes.isNotEmpty)
                  Column(
                    children: comprobantes.map((c) {
                      return ListTile(
                        title: Text(c.tipo),
                        subtitle: Text(c.url),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

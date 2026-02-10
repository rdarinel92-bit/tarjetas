// ═══════════════════════════════════════════════════════════════════════════════
// SCRIPT DE VERIFICACIÓN - CONEXIÓN SUPABASE TARJETAS
// Ejecutar desde la app o con: flutter run -d windows
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:robertdarin/core/supabase_client.dart';

/// Ejecutar esta función para verificar que las tablas de tarjetas existen
Future<Map<String, dynamic>> verificarTablasSupabase() async {
  final resultados = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'tablas': <String, dynamic>{},
    'errores': <String>[],
  };

  final tablasRequeridas = [
    'tarjetas_config',
    'tarjetas_digitales',
    'tarjetas_titulares',
    'tarjetas_transacciones',
    'tarjetas_recargas',
    'tarjetas_log',
  ];

  for (final tabla in tablasRequeridas) {
    try {
      final response = await AppSupabase.client
          .from(tabla)
          .select('id')
          .limit(1);
      
      resultados['tablas'][tabla] = {
        'existe': true,
        'accesible': true,
        'registros_ejemplo': response.length,
      };
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('does not exist')) {
        resultados['tablas'][tabla] = {
          'existe': false,
          'accesible': false,
          'error': 'Tabla no existe',
        };
        (resultados['errores'] as List).add('$tabla: No existe');
      } else if (errorMsg.contains('permission denied') || errorMsg.contains('policy')) {
        resultados['tablas'][tabla] = {
          'existe': true,
          'accesible': false,
          'error': 'Sin permisos (RLS)',
        };
      } else {
        resultados['tablas'][tabla] = {
          'existe': null,
          'accesible': false,
          'error': errorMsg,
        };
        (resultados['errores'] as List).add('$tabla: $errorMsg');
      }
    }
  }

  // Resumen
  final tablasOk = (resultados['tablas'] as Map).values
      .where((v) => v['existe'] == true)
      .length;
  
  resultados['resumen'] = {
    'tablas_verificadas': tablasRequeridas.length,
    'tablas_ok': tablasOk,
    'tablas_faltantes': tablasRequeridas.length - tablasOk,
    'estado': tablasOk == tablasRequeridas.length ? '✅ TODO OK' : '⚠️ FALTAN TABLAS',
  };

  return resultados;
}

/// Widget para mostrar resultados de verificación
class VerificacionTarjetasWidget extends StatefulWidget {
  const VerificacionTarjetasWidget({super.key});

  @override
  State<VerificacionTarjetasWidget> createState() => _VerificacionTarjetasWidgetState();
}

class _VerificacionTarjetasWidgetState extends State<VerificacionTarjetasWidget> {
  Map<String, dynamic>? _resultados;
  bool _verificando = false;

  Future<void> _verificar() async {
    setState(() => _verificando = true);
    try {
      final resultados = await verificarTablasSupabase();
      setState(() {
        _resultados = resultados;
        _verificando = false;
      });
    } catch (e) {
      setState(() {
        _resultados = {'error': e.toString()};
        _verificando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.cyan),
                const SizedBox(width: 8),
                const Text(
                  'Verificación Supabase - Tarjetas',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_verificando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.cyan),
                    onPressed: _verificar,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_resultados == null)
              ElevatedButton.icon(
                onPressed: _verificar,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ejecutar Verificación'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              )
            else if (_resultados!.containsKey('error'))
              Text('Error: ${_resultados!['error']}', style: const TextStyle(color: Colors.red))
            else ...[
              // Resumen
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _resultados!['resumen']['estado'].toString().contains('OK')
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _resultados!['resumen']['estado'].toString().contains('OK')
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _resultados!['resumen']['estado'].toString().contains('OK')
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_resultados!['resumen']['tablas_ok']}/${_resultados!['resumen']['tablas_verificadas']} tablas OK',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Detalle de tablas
              ...(_resultados!['tablas'] as Map).entries.map((e) {
                final existe = e.value['existe'] == true;
                final accesible = e.value['accesible'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        existe ? (accesible ? Icons.check : Icons.lock) : Icons.close,
                        color: existe ? (accesible ? Colors.green : Colors.orange) : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(e.key, style: const TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Text(
                        existe ? (accesible ? '✓ OK' : '🔒 RLS') : '✗ Falta',
                        style: TextStyle(
                          color: existe ? (accesible ? Colors.green : Colors.orange) : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

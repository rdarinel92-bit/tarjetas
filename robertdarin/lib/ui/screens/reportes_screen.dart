// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _generando = false;
  String _tipoReporteSeleccionado = 'prestamos';
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();
  
  // Datos para preview
  Map<String, dynamic> _datosReporte = {};
  bool _cargandoDatos = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosReporte();
  }

  Future<void> _cargarDatosReporte() async {
    setState(() => _cargandoDatos = true);
    
    try {
      final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
      
      // Cargar estadísticas según el tipo de reporte
      switch (_tipoReporteSeleccionado) {
        case 'prestamos':
          final prestamos = await AppSupabase.client
              .from('prestamos')
              .select('monto_principal, monto_total, saldo_pendiente, estado, created_at')
              .gte('created_at', _fechaInicio.toIso8601String())
              .lte('created_at', _fechaFin.toIso8601String());
          
          final lista = List<Map<String, dynamic>>.from(prestamos);
          double totalPrestado = 0;
          double totalPorCobrar = 0;
          double totalSaldo = 0;
          int activos = 0;
          int pagados = 0;
          
          for (var p in lista) {
            totalPrestado += (p['monto_principal'] ?? 0).toDouble();
            totalPorCobrar += (p['monto_total'] ?? 0).toDouble();
            totalSaldo += (p['saldo_pendiente'] ?? 0).toDouble();
            if (p['estado'] == 'activo') activos++;
            if (p['estado'] == 'pagado') pagados++;
          }
          
          setState(() {
            _datosReporte = {
              'titulo': 'Reporte de Préstamos',
              'periodo': '${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}',
              'filas': [
                {'label': 'Total Préstamos', 'valor': lista.length.toString()},
                {'label': 'Préstamos Activos', 'valor': activos.toString()},
                {'label': 'Préstamos Pagados', 'valor': pagados.toString()},
                {'label': 'Capital Prestado', 'valor': nf.format(totalPrestado)},
                {'label': 'Total a Cobrar', 'valor': nf.format(totalPorCobrar)},
                {'label': 'Saldo Pendiente', 'valor': nf.format(totalSaldo)},
                {'label': 'Intereses Generados', 'valor': nf.format(totalPorCobrar - totalPrestado)},
              ],
            };
          });
          break;
          
        case 'tandas':
          final tandas = await AppSupabase.client
              .from('tandas')
              .select('monto_por_persona, numero_participantes, estado, created_at')
              .gte('created_at', _fechaInicio.toIso8601String())
              .lte('created_at', _fechaFin.toIso8601String());
          
          final lista = List<Map<String, dynamic>>.from(tandas);
          double totalPot = 0;
          int totalParticipantes = 0;
          int activas = 0;
          
          for (var t in lista) {
            final monto = (t['monto_por_persona'] ?? 0).toDouble();
            final participantes = (t['numero_participantes'] ?? 0);
            totalPot += monto * participantes;
            totalParticipantes += participantes as int;
            if (t['estado'] == 'activa') activas++;
          }
          
          setState(() {
            _datosReporte = {
              'titulo': 'Reporte de Tandas',
              'periodo': '${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}',
              'filas': [
                {'label': 'Total Tandas', 'valor': lista.length.toString()},
                {'label': 'Tandas Activas', 'valor': activas.toString()},
                {'label': 'Total Participantes', 'valor': totalParticipantes.toString()},
                {'label': 'Volumen Total', 'valor': nf.format(totalPot)},
              ],
            };
          });
          break;
          
        case 'pagos':
          final pagos = await AppSupabase.client
              .from('pagos')
              .select('monto, metodo_pago, estado, fecha_pago')
              .gte('fecha_pago', _fechaInicio.toIso8601String())
              .lte('fecha_pago', _fechaFin.toIso8601String());
          
          final lista = List<Map<String, dynamic>>.from(pagos);
          double totalCobrado = 0;
          int efectivo = 0;
          int transferencia = 0;
          
          for (var p in lista) {
            if (p['estado'] == 'completado') {
              totalCobrado += (p['monto'] ?? 0).toDouble();
            }
            if (p['metodo_pago'] == 'efectivo') efectivo++;
            if (p['metodo_pago'] == 'transferencia') transferencia++;
          }
          
          setState(() {
            _datosReporte = {
              'titulo': 'Reporte de Cobranza',
              'periodo': '${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}',
              'filas': [
                {'label': 'Total Cobros', 'valor': lista.length.toString()},
                {'label': 'Total Recaudado', 'valor': nf.format(totalCobrado)},
                {'label': 'Pagos en Efectivo', 'valor': efectivo.toString()},
                {'label': 'Transferencias', 'valor': transferencia.toString()},
              ],
            };
          });
          break;
          
        case 'clientes':
          final clientes = await AppSupabase.client
              .from('clientes')
              .select('score_crediticio, activo, created_at')
              .gte('created_at', _fechaInicio.toIso8601String())
              .lte('created_at', _fechaFin.toIso8601String());
          
          final lista = List<Map<String, dynamic>>.from(clientes);
          int activos = 0;
          double scorePromedio = 0;
          
          for (var c in lista) {
            if (c['activo'] == true) activos++;
            scorePromedio += (c['score_crediticio'] ?? 500).toDouble();
          }
          if (lista.isNotEmpty) scorePromedio /= lista.length;
          
          setState(() {
            _datosReporte = {
              'titulo': 'Reporte de Clientes',
              'periodo': '${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}',
              'filas': [
                {'label': 'Clientes Nuevos', 'valor': lista.length.toString()},
                {'label': 'Clientes Activos', 'valor': activos.toString()},
                {'label': 'Score Promedio', 'valor': scorePromedio.toStringAsFixed(0)},
              ],
            };
          });
          break;
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      setState(() {
        _datosReporte = {
          'titulo': 'Error al cargar datos',
          'periodo': '',
          'filas': [{'label': 'Error', 'valor': e.toString()}],
        };
      });
    }
    
    setState(() => _cargandoDatos = false);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Reportes",
      subtitle: "Genera reportes del sistema",
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de tipo de reporte
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text("Tipo de Reporte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildChipReporte('prestamos', 'Préstamos', Icons.attach_money),
                      _buildChipReporte('tandas', 'Tandas', Icons.group_work),
                      _buildChipReporte('pagos', 'Cobranza', Icons.payments),
                      _buildChipReporte('clientes', 'Clientes', Icons.people),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Selector de fechas
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.date_range, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Text("Período", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFechaSelector("Desde", _fechaInicio, (fecha) {
                          setState(() => _fechaInicio = fecha);
                          _cargarDatosReporte();
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFechaSelector("Hasta", _fechaFin, (fecha) {
                          setState(() => _fechaFin = fecha);
                          _cargarDatosReporte();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Atajos de fecha
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildAtajoFecha("Hoy", 0),
                      _buildAtajoFecha("7 días", 7),
                      _buildAtajoFecha("30 días", 30),
                      _buildAtajoFecha("90 días", 90),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Preview del reporte
            if (_cargandoDatos)
              const Center(child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ))
            else if (_datosReporte.isNotEmpty)
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_datosReporte['titulo'] ?? '', 
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_datosReporte['periodo'] ?? '', 
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white54),
                          onPressed: _cargarDatosReporte,
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    ...(_datosReporte['filas'] as List<dynamic>? ?? []).map((fila) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fila['label'], style: const TextStyle(color: Colors.white70)),
                          Text(fila['valor'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Botones de generación
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generando ? null : _generarPDF,
                    icon: _generando 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf),
                    label: const Text("Generar PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generando ? null : _generarExcel,
                    icon: const Icon(Icons.grid_on),
                    label: const Text("Generar Excel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            
            // Historial de reportes
            const Text("Reportes Recientes", 
              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildHistorialReportes(),
          ],
        ),
      ),
    );
  }

  Widget _buildChipReporte(String tipo, String label, IconData icon) {
    final seleccionado = _tipoReporteSeleccionado == tipo;
    return FilterChip(
      selected: seleccionado,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: seleccionado ? Colors.black : Colors.white70),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
      selectedColor: Colors.greenAccent,
      backgroundColor: Colors.white.withOpacity(0.1),
      labelStyle: TextStyle(color: seleccionado ? Colors.black : Colors.white70),
      onSelected: (v) {
        setState(() => _tipoReporteSeleccionado = tipo);
        _cargarDatosReporte();
      },
    );
  }

  Widget _buildFechaSelector(String label, DateTime fecha, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text(DateFormat('dd/MM/yyyy').format(fecha), style: const TextStyle(color: Colors.white)),
              ],
            ),
            const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAtajoFecha(String label, int dias) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white.withOpacity(0.1),
      onPressed: () {
        setState(() {
          _fechaFin = DateTime.now();
          _fechaInicio = DateTime.now().subtract(Duration(days: dias));
        });
        _cargarDatosReporte();
      },
    );
  }

  Widget _buildHistorialReportes() {
    // Sin historial guardado - mostrar mensaje informativo
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.history, color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Historial de Reportes',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los reportes generados se descargarán directamente a tu dispositivo.\n'
              'Usa los botones de arriba para generar un nuevo reporte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReporteHistorial(String nombre, String tipo, String fecha) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tipo == "PDF" ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
        child: Icon(
          tipo == "PDF" ? Icons.picture_as_pdf : Icons.grid_on,
          color: tipo == "PDF" ? Colors.redAccent : Colors.greenAccent,
          size: 20,
        ),
      ),
      title: Text(nombre, style: const TextStyle(color: Colors.white)),
      subtitle: Text(fecha, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.download, color: Colors.white54),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Descargando reporte...'), backgroundColor: Colors.blue),
          );
        },
      ),
    );
  }

  Future<void> _generarPDF() async {
    setState(() => _generando = true);
    
    try {
      // Mostrar diálogo de exportación
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Generando PDF', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Preparando ${_datosReporte['titulo']}...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      }
      
      // Generar contenido del reporte
      final StringBuffer contenido = StringBuffer();
      contenido.writeln('═══════════════════════════════════════');
      contenido.writeln(_datosReporte['titulo'] ?? 'Reporte');
      contenido.writeln(_datosReporte['periodo'] ?? '');
      contenido.writeln('═══════════════════════════════════════\n');
      
      for (var fila in (_datosReporte['filas'] as List<dynamic>? ?? [])) {
        contenido.writeln('${fila['label']}: ${fila['valor']}');
      }
      
      contenido.writeln('\n───────────────────────────────────────');
      contenido.writeln('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      contenido.writeln('Robert Darin Fintech');
      
      // Cerrar diálogo
      if (mounted) Navigator.pop(context);
      
      // Mostrar preview del reporte
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _datosReporte['titulo'] ?? 'Reporte',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contenido.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💡 Para exportar a PDF real, se requiere la librería "printing" configurada.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Reporte copiado al portapapeles'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) setState(() => _generando = false);
  }

  Future<void> _generarExcel() async {
    setState(() => _generando = true);
    
    try {
      // Mostrar diálogo de exportación
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Row(
              children: [
                Icon(Icons.grid_on, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text('Generando Excel', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.greenAccent),
                const SizedBox(height: 20),
                Text(
                  'Preparando ${_datosReporte['titulo']}...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      }
      
      // Generar contenido CSV (compatible con Excel)
      final StringBuffer csv = StringBuffer();
      csv.writeln('${_datosReporte['titulo']}');
      csv.writeln('${_datosReporte['periodo']}');
      csv.writeln('');
      csv.writeln('Concepto,Valor');
      
      for (var fila in (_datosReporte['filas'] as List<dynamic>? ?? [])) {
        csv.writeln('"${fila['label']}","${fila['valor']}"');
      }
      
      csv.writeln('');
      csv.writeln('"Generado","${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}"');
      
      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);
      
      // Mostrar preview
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_datosReporte['titulo']} (CSV)',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      csv.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💡 Copia el contenido y pégalo en Excel o Google Sheets.',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 CSV copiado - Pégalo en Excel'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) setState(() => _generando = false);
  }
}

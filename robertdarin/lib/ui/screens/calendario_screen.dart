// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _fechaSeleccionada = DateTime.now();
  DateTime _mesActual = DateTime.now();
  bool _cargando = true;
  
  List<Map<String, dynamic>> _eventosDelMes = [];
  List<Map<String, dynamic>> _eventosDelDia = [];
  
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    setState(() => _cargando = true);
    try {
      final inicioMes = DateTime(_mesActual.year, _mesActual.month, 1);
      final finMes = DateTime(_mesActual.year, _mesActual.month + 1, 0, 23, 59, 59);
      
      List<Map<String, dynamic>> eventos = [];
      
      // 1. Cargar cuotas de préstamos (amortizaciones) del mes
      final amortizaciones = await AppSupabase.client
          .from('amortizaciones')
          .select('*, prestamos(clientes(nombre))')
          .gte('fecha_vencimiento', inicioMes.toIso8601String())
          .lte('fecha_vencimiento', finMes.toIso8601String())
          .eq('pagado', false);
      
      for (var a in amortizaciones) {
        eventos.add({
          'fecha': DateTime.parse(a['fecha_vencimiento']),
          'tipo': 'cuota',
          'titulo': 'Cuota préstamo',
          'subtitulo': a['prestamos']?['clientes']?['nombre'] ?? 'Cliente',
          'monto': a['monto_cuota'],
          'color': Colors.blueAccent,
          'icono': Icons.payments,
        });
      }
      
      // 2. Cargar pagos de tandas del mes
      final tandasPagos = await AppSupabase.client
          .from('tanda_pagos')
          .select('*, tanda_participantes(tandas(nombre), clientes(nombre))')
          .gte('fecha_programada', inicioMes.toIso8601String())
          .lte('fecha_programada', finMes.toIso8601String())
          .eq('estado', 'pendiente');
      
      for (var t in tandasPagos) {
        eventos.add({
          'fecha': DateTime.parse(t['fecha_programada']),
          'tipo': 'tanda',
          'titulo': t['tanda_participantes']?['tandas']?['nombre'] ?? 'Tanda',
          'subtitulo': t['tanda_participantes']?['clientes']?['nombre'] ?? 'Participante',
          'monto': t['monto'],
          'color': Colors.purpleAccent,
          'icono': Icons.group_work,
        });
      }
      
      // 3. Cargar pagos de propiedades del mes
      final pagosPropiedades = await AppSupabase.client
          .from('pagos_propiedades')
          .select('*, mis_propiedades(nombre)')
          .gte('fecha_programada', inicioMes.toIso8601String())
          .lte('fecha_programada', finMes.toIso8601String())
          .eq('estado', 'pendiente');
      
      for (var p in pagosPropiedades) {
        eventos.add({
          'fecha': DateTime.parse(p['fecha_programada']),
          'tipo': 'propiedad',
          'titulo': p['mis_propiedades']?['nombre'] ?? 'Propiedad',
          'subtitulo': 'Pago mensual',
          'monto': p['monto'],
          'color': Colors.tealAccent,
          'icono': Icons.landscape,
        });
      }
      
      // 4. Cargar recordatorios/eventos del mes
      try {
        final recordatorios = await AppSupabase.client
            .from('recordatorios')
            .select()
            .gte('fecha_recordatorio', inicioMes.toIso8601String())
            .lte('fecha_recordatorio', finMes.toIso8601String());
        
        for (var r in recordatorios) {
          eventos.add({
            'fecha': DateTime.parse(r['fecha_recordatorio']),
            'tipo': 'recordatorio',
            'titulo': r['titulo'] ?? 'Recordatorio',
            'subtitulo': r['descripcion'] ?? '',
            'monto': null,
            'color': Colors.orangeAccent,
            'icono': Icons.notifications,
          });
        }
      } catch (e) {
        // Tabla recordatorios puede no existir
      }
      
      setState(() {
        _eventosDelMes = eventos;
        _filtrarEventosDelDia();
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
      setState(() => _cargando = false);
    }
  }

  void _filtrarEventosDelDia() {
    _eventosDelDia = _eventosDelMes.where((e) {
      final fecha = e['fecha'] as DateTime;
      return fecha.year == _fechaSeleccionada.year &&
             fecha.month == _fechaSeleccionada.month &&
             fecha.day == _fechaSeleccionada.day;
    }).toList();
  }

  bool _tienEventos(DateTime dia) {
    return _eventosDelMes.any((e) {
      final fecha = e['fecha'] as DateTime;
      return fecha.year == dia.year && fecha.month == dia.month && fecha.day == dia.day;
    });
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + delta, 1);
    });
    _cargarEventos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Calendario', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.today), onPressed: () {
            setState(() {
              _mesActual = DateTime.now();
              _fechaSeleccionada = DateTime.now();
            });
            _cargarEventos();
          }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarEventos),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                // Header del mes
                _buildMesHeader(),
                
                // Días de la semana
                _buildDiasSemana(),
                
                // Calendario
                _buildCalendario(),
                
                const Divider(color: Colors.white24, height: 1),
                
                // Eventos del día seleccionado
                Expanded(child: _buildEventosDelDia()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevoEvento,
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildMesHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => _cambiarMes(-1),
          ),
          Text(
            DateFormat('MMMM yyyy', 'es').format(_mesActual).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _cambiarMes(1),
          ),
        ],
      ),
    );
  }

  Widget _buildDiasSemana() {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: dias.map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendario() {
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final ultimoDia = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final diasEnMes = ultimoDia.day;
    final diaInicioSemana = (primerDia.weekday - 1) % 7;
    
    List<Widget> filas = [];
    List<Widget> celdas = [];
    
    // Celdas vacías antes del primer día
    for (int i = 0; i < diaInicioSemana; i++) {
      celdas.add(const Expanded(child: SizedBox()));
    }
    
    // Días del mes
    for (int dia = 1; dia <= diasEnMes; dia++) {
      final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
      final esHoy = fecha.year == DateTime.now().year && 
                    fecha.month == DateTime.now().month && 
                    fecha.day == DateTime.now().day;
      final esSeleccionado = fecha.year == _fechaSeleccionada.year &&
                            fecha.month == _fechaSeleccionada.month &&
                            fecha.day == _fechaSeleccionada.day;
      final tieneEventos = _tienEventos(fecha);
      
      celdas.add(Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _fechaSeleccionada = fecha;
              _filtrarEventosDelDia();
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: esSeleccionado ? Colors.cyanAccent : (esHoy ? Colors.cyanAccent.withOpacity(0.2) : null),
              borderRadius: BorderRadius.circular(8),
              border: esHoy && !esSeleccionado ? Border.all(color: Colors.cyanAccent) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dia',
                  style: TextStyle(
                    color: esSeleccionado ? Colors.black : Colors.white,
                    fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (tieneEventos)
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: esSeleccionado ? Colors.black : Colors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
      
      if (celdas.length == 7) {
        filas.add(Row(children: celdas));
        celdas = [];
      }
    }
    
    // Completar última fila
    while (celdas.length < 7 && celdas.isNotEmpty) {
      celdas.add(const Expanded(child: SizedBox()));
    }
    if (celdas.isNotEmpty) {
      filas.add(Row(children: celdas));
    }
    
    return Container(
      height: 280,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: filas.map((f) => SizedBox(height: 45, child: f)).toList(),
      ),
    );
  }

  Widget _buildEventosDelDia() {
    final fechaStr = DateFormat('EEEE d MMMM', 'es').format(_fechaSeleccionada);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fechaStr.substring(0, 1).toUpperCase() + fechaStr.substring(1),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          if (_eventosDelDia.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No hay eventos para este día', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _eventosDelDia.length,
                itemBuilder: (context, index) {
                  final evento = _eventosDelDia[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (evento['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (evento['color'] as Color).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (evento['color'] as Color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(evento['icono'], color: evento['color'], size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(evento['titulo'], style: TextStyle(color: evento['color'], fontWeight: FontWeight.bold)),
                              Text(evento['subtitulo'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (evento['monto'] != null)
                          Text(
                            _currencyFormat.format(evento['monto']),
                            style: TextStyle(color: evento['color'], fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevoEvento() {
    final tituloCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    DateTime fechaEvento = _fechaSeleccionada;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nuevo Recordatorio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: tituloCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                title: Text(DateFormat('dd/MM/yyyy').format(fechaEvento), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.edit, color: Colors.white54),
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: fechaEvento,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (fecha != null) setModalState(() => fechaEvento = fecha);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (tituloCtrl.text.isEmpty) return;
                  try {
                    await AppSupabase.client.from('recordatorios').insert({
                      'titulo': tituloCtrl.text,
                      'descripcion': descripcionCtrl.text,
                      'fecha_recordatorio': fechaEvento.toIso8601String(),
                      'usuario_id': AppSupabase.client.auth.currentUser?.id,
                      'publico': false,
                    });
                    Navigator.pop(context);
                    _cargarEventos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recordatorio creado'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.all(16)),
                child: const Text('GUARDAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

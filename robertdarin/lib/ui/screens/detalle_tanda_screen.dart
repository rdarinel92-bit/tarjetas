// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/tanda_model.dart';
import '../../data/models/tanda_participante_model.dart';
import '../../data/repositories/tandas_repository.dart';
import '../../data/repositories/tanda_participantes_repository.dart';
import '../../modules/clientes/controllers/usuarios_controller.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../navigation/app_routes.dart';
import 'package:intl/intl.dart';

class DetalleTandaScreen extends StatefulWidget {
  final String tandaId;
  final bool abrirAgregarParticipante;

  const DetalleTandaScreen({
    super.key,
    required this.tandaId,
    this.abrirAgregarParticipante = false,
  });

  @override
  State<DetalleTandaScreen> createState() => _DetalleTandaScreenState();
}

class _DetalleTandaScreenState extends State<DetalleTandaScreen> {
  final TandasRepository _tandasRepo = TandasRepository();
  final TandaParticipantesRepository _participantesRepo = TandaParticipantesRepository();
  
  TandaModel? _tanda;
  List<TandaParticipanteModel> _participantes = [];
  bool _cargando = true;
  bool _abrirAgregarPendiente = false;

  @override
  void initState() {
    super.initState();
    _abrirAgregarPendiente = widget.abrirAgregarParticipante;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final tanda = await _tandasRepo.obtenerTandaPorId(widget.tandaId);
      final participantes = await _participantesRepo.obtenerParticipantesPorTanda(widget.tandaId);
      setState(() {
        _tanda = tanda;
        _participantes = participantes;
      });
      if (_abrirAgregarPendiente && _tanda != null && _tanda!.estado == 'activa') {
        _abrirAgregarPendiente = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mostrarDialogoAgregarParticipante();
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tanda == null) {
      return PremiumScaffold(
        title: "Detalle de Tanda",
        body: const Center(child: Text("Tanda no encontrada", style: TextStyle(color: Colors.white54))),
      );
    }

    final tanda = _tanda!;
    final formatCurrency = NumberFormat.simpleCurrency();
    final participanteActual = _participantes.isNotEmpty && tanda.turnoActual <= _participantes.length
        ? _participantes.firstWhere((p) => p.numeroTurno == tanda.turnoActual, orElse: () => _participantes.first)
        : null;

    return PremiumScaffold(
      title: tanda.nombre,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.amberAccent),
          onPressed: () async {
            final result = await Navigator.pushNamed(
              context,
              AppRoutes.editarTanda,
              arguments: widget.tandaId,
            );
            if (result == true) {
              _cargarDatos();
            }
          },
          tooltip: 'Editar Tanda',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ENCABEZADO CON ESTADO
              _buildHeaderCard(tanda, formatCurrency),
              const SizedBox(height: 20),

              // TURNO ACTUAL
              if (tanda.estado == 'activa' && participanteActual != null) ...[
                _buildTurnoActualCard(tanda, participanteActual, formatCurrency),
                const SizedBox(height: 20),
              ],

              // ACCIONES RÁPIDAS
              if (tanda.estado == 'activa') ...[
                _buildAccionesRapidas(tanda),
                const SizedBox(height: 20),
              ],

              // LISTA DE PARTICIPANTES
              _buildParticipantesList(tanda),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(TandaModel tanda, NumberFormat formatCurrency) {
    final Color estadoColor;
    final IconData estadoIcon;
    
    switch (tanda.estado) {
      case 'activa':
        estadoColor = Colors.green;
        estadoIcon = Icons.play_circle;
        break;
      case 'completada':
        estadoColor = Colors.blue;
        estadoIcon = Icons.check_circle;
        break;
      case 'cancelada':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help;
    }

    return PremiumCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: estadoColor.withOpacity(0.2),
                child: Icon(estadoIcon, color: estadoColor, size: 35),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tanda.nombre, 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(tanda.estado.toUpperCase(), 
                        style: TextStyle(color: estadoColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Cuota", formatCurrency.format(tanda.montoPorPersona), Icons.attach_money),
              _buildStatItem("Bolsa", formatCurrency.format(tanda.montoBolsa), Icons.savings),
              _buildStatItem("Turno", "${tanda.turnoActual}/${tanda.numeroParticipantes}", Icons.format_list_numbered),
            ],
          ),
          const SizedBox(height: 15),
          // Barra de progreso
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Progreso: ${(tanda.progreso * 100).toStringAsFixed(0)}%", 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(tanda.frecuencia, 
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: tanda.progreso,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    tanda.progreso >= 1 ? Colors.green : Colors.orangeAccent,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orangeAccent, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildTurnoActualCard(TandaModel tanda, TandaParticipanteModel participante, NumberFormat formatCurrency) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text("TURNO ACTUAL", 
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.amber,
              child: Text('${participante.numeroTurno}', 
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            title: Text(participante.clienteNombre ?? 'Cliente ${participante.clienteId.substring(0, 8)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text("Recibirá: ${formatCurrency.format(tanda.montoBolsa)}",
              style: const TextStyle(color: Colors.greenAccent)),
          ),
          const SizedBox(height: 10),
          // Estado de pagos del turno actual
          Text("Pagos recibidos: ${_participantes.where((p) => p.haPagadoCuotaActual).length}/${_participantes.length}",
            style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _participantes.isEmpty ? 0 : 
                _participantes.where((p) => p.haPagadoCuotaActual).length / _participantes.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas(TandaModel tanda) {
    final todosPagaron = _participantes.isNotEmpty && 
        _participantes.every((p) => p.haPagadoCuotaActual);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _mostrarDialogoAgregarParticipante(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text("Agregar", style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: todosPagaron ? () => _avanzarTurno(tanda) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: todosPagaron ? Colors.green : Colors.grey,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text("Avanzar", style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _entregarBolsa(tanda),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.card_giftcard, size: 18, color: Colors.black),
            label: const Text("Entregar", style: TextStyle(fontSize: 12, color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantesList(TandaModel tanda) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Participantes", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text("${_participantes.length}/${tanda.numeroParticipantes}",
              style: const TextStyle(color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 10),
        
        if (_participantes.isEmpty)
          PremiumCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 50, color: Colors.white24),
                    SizedBox(height: 10),
                    Text("No hay participantes", style: TextStyle(color: Colors.white38)),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_participantes.length, (index) {
            final p = _participantes[index];
            return _buildParticipanteItem(p, tanda);
          }),
      ],
    );
  }

  Widget _buildParticipanteItem(TandaParticipanteModel p, TandaModel tanda) {
    final bool esTurnoActual = p.numeroTurno == tanda.turnoActual;
    final bool yaRecibio = p.haRecibidoBolsa;

    Color turnoColor;
    IconData turnoIcon;

    if (yaRecibio) {
      turnoColor = Colors.green;
      turnoIcon = Icons.check_circle;
    } else if (esTurnoActual) {
      turnoColor = Colors.amber;
      turnoIcon = Icons.star;
    } else {
      turnoColor = Colors.white24;
      turnoIcon = Icons.circle_outlined;
    }

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: turnoColor.withOpacity(0.2),
              child: Text('${p.numeroTurno}', 
                style: TextStyle(color: turnoColor, fontWeight: FontWeight.bold)),
            ),
            if (esTurnoActual)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.star, size: 10, color: Colors.black),
                ),
              ),
          ],
        ),
        title: Text(p.clienteNombre ?? 'Cliente', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Row(
          children: [
            Icon(turnoIcon, size: 14, color: turnoColor),
            const SizedBox(width: 4),
            Text(
              yaRecibio 
                  ? 'Recibió bolsa ${p.fechaRecepcionBolsa != null ? DateFormat('dd/MM/yy').format(p.fechaRecepcionBolsa!) : ''}'
                  : esTurnoActual 
                      ? 'Turno actual' 
                      : 'Pendiente',
              style: TextStyle(color: turnoColor, fontSize: 12),
            ),
          ],
        ),
        trailing: tanda.estado == 'activa'
            ? Checkbox(
                value: p.haPagadoCuotaActual,
                activeColor: Colors.green,
                onChanged: (v) => _togglePagoCuota(p, v ?? false),
              )
            : Icon(turnoIcon, color: turnoColor),
      ),
    );
  }

  void _mostrarDialogoAgregarParticipante() async {
    if (_tanda == null) return;

    if (_participantes.length >= _tanda!.numeroParticipantes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La tanda ya está completa"), backgroundColor: Colors.orange),
      );
      return;
    }

    final usuariosCtrl = Provider.of<UsuariosController>(context, listen: false);
    // Usar obtenerUsuariosClientes para excluir superadmin/admin
    final usuarios = await usuariosCtrl.obtenerUsuariosClientes();

    // Filtrar usuarios que ya están en la tanda
    final disponibles = usuarios.where((u) => 
      !_participantes.any((p) => p.clienteId == u.id)
    ).toList();

    if (!mounted) return;

    String? selectedClienteId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("Agregar Participante"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              if (disponibles.isEmpty) {
                return const Text("No hay más clientes disponibles", 
                  style: TextStyle(color: Colors.white54));
              }

              return DropdownButtonFormField<String>(
                value: selectedClienteId,
                items: disponibles.map((u) => DropdownMenuItem(
                  value: u.id,
                  child: Text(u.nombreCompleto ?? u.email),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedClienteId = v),
                decoration: const InputDecoration(labelText: "Seleccionar Cliente"),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedClienteId != null) {
                  Navigator.pop(context);
                  await _agregarParticipante(selectedClienteId!);
                }
              },
              child: const Text("Agregar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _agregarParticipante(String clienteId) async {
    final siguienteTurno = await _participantesRepo.obtenerSiguienteTurno(widget.tandaId);
    
    final participante = TandaParticipanteModel(
      id: '',
      tandaId: widget.tandaId,
      clienteId: clienteId,
      numeroTurno: siguienteTurno,
    );

    final exito = await _participantesRepo.agregarParticipante(participante);

    if (exito) {
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Participante agregado"), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _togglePagoCuota(TandaParticipanteModel p, bool pagado) async {
    final exito = await _participantesRepo.marcarPagoCuota(p.id, pagado);
    if (exito) {
      await _cargarDatos();
    }
  }

  Future<void> _avanzarTurno(TandaModel tanda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Avanzar Turno"),
        content: Text(
          "¿Confirmas que todos pagaron y deseas avanzar al turno ${tanda.turnoActual + 1}?\n\n"
          "Esto reiniciará los pagos de cuota para el nuevo turno."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final nuevoTurno = tanda.turnoActual + 1;
    
    if (nuevoTurno > tanda.numeroParticipantes) {
      // Finalizar tanda
      await _tandasRepo.finalizarTanda(widget.tandaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Tanda completada! 🎉"), backgroundColor: Colors.green),
        );
      }
    } else {
      // Avanzar turno y reiniciar pagos
      await _tandasRepo.avanzarTurno(widget.tandaId, nuevoTurno);
      await _participantesRepo.reiniciarPagosCuota(widget.tandaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Avanzado al turno $nuevoTurno"), backgroundColor: Colors.green),
        );
      }
    }

    await _cargarDatos();
  }

  Future<void> _entregarBolsa(TandaModel tanda) async {
    final participanteActual = _participantes.firstWhere(
      (p) => p.numeroTurno == tanda.turnoActual,
      orElse: () => _participantes.first,
    );

    if (participanteActual.haRecibidoBolsa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este participante ya recibió la bolsa"), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Entregar Bolsa"),
        content: Text(
          "¿Confirmas la entrega de la bolsa a ${participanteActual.clienteNombre ?? 'el participante'}?\n\n"
          "Monto: ${NumberFormat.simpleCurrency().format(tanda.montoBolsa)}"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text("Entregar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final exito = await _participantesRepo.marcarBolsaEntregada(participanteActual.id);
    
    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bolsa entregada correctamente ✅"), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    }
  }
}

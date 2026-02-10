import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';
import '../../core/supabase_client.dart';
import 'package:intl/intl.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarLogsReales();
  }

  Future<void> _cargarLogsReales() async {
    try {
      final res = await AppSupabase.client
          .from('auditoria')
          .select('*, usuarios(nombre_completo)')
          .order('fecha', ascending: false)
          .limit(20);
      
      setState(() {
        _logs = res;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando auditoría: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Auditoría del Sistema",
      body: RefreshIndicator(
        onRefresh: _cargarLogsReales,
        child: Column(
          children: [
            const Text("Historial de Actividad Reciente",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_logs.isEmpty)
              const PremiumCard(child: Center(child: Text("No hay registros de actividad todavía.", style: TextStyle(color: Colors.white38))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildLogItem(
                    log['accion'] ?? 'Acción',
                    log['usuarios']?['nombre_completo'] ?? 'Sistema',
                    log['fecha'],
                    log['modulo'] ?? 'General'
                  );
                },
              ),
            
            const SizedBox(height: 25),
            PremiumButton(
              text: "Exportar Log Completo",
              icon: Icons.file_download_outlined,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Preparando descarga de logs...")),
                );
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String accion, String usuario, String fecha, String modulo) {
    final DateTime dt = DateTime.parse(fecha);
    final String hora = DateFormat('HH:mm').format(dt);
    final String dia = DateFormat('dd/MM').format(dt);

    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          accion.contains('Acceso') ? Icons.lock_clock : Icons.history_edu,
          color: accion.contains('Eliminar') ? Colors.redAccent : Colors.blueAccent,
        ),
        title: Text(accion, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Por: $usuario | Módulo: $modulo", style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(hora, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(dia, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

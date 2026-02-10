import 'package:supabase_flutter/supabase_flutter.dart';

class KpiRepository {
  final SupabaseClient supabase;

  KpiRepository(this.supabase);

  Future<int> contarClientes() async {
    final res = await supabase.from('clientes').select();
    return res.length;
  }

  Future<int> contarPrestamosActivos() async {
    final res = await supabase
        .from('prestamos')
        .select()
        .eq('estado', 'activo');
    return res.length;
  }

  Future<int> contarTandasActivas() async {
    final res = await supabase
        .from('tandas')
        .select()
        .eq('estado', 'activa');
    return res.length;
  }

  Future<int> contarEmpleados() async {
    final res = await supabase
        .from('empleados')
        .select();
    return res.length;
  }

  Future<int> contarPagosMesActual() async {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final res = await supabase
        .from('pagos')
        .select()
        .gte('fecha', inicioMes.toIso8601String());
    return res.length;
  }
}

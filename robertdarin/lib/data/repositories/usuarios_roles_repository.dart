import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_rol_model.dart';

class UsuariosRolesRepository {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<UsuarioRolModel?> obtenerRolDeUsuario(String usuarioId) async {
    final response = await supabase
        .from('usuarios_roles')
        .select()
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (response == null) return null;
    return UsuarioRolModel.fromMap(response);
  }

  Future<bool> asignarRolAUsuario(UsuarioRolModel ur) async {
    final response = await supabase
        .from('usuarios_roles')
        .insert(ur.toMap());

    return response != null;
  }

  Future<bool> cambiarRolDeUsuario(String usuarioId, String nuevoRolId) async {
    final response = await supabase
        .from('usuarios_roles')
        .update({'rol_id': nuevoRolId})
        .eq('usuario_id', usuarioId);

    return response != null;
  }
}

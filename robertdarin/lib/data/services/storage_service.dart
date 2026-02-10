import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class StorageService {
  final SupabaseClient client = ApiService.client;

  Future<String?> subirArchivo(File archivo, String ruta) async {
    final String path = 'comprobantes/$ruta';
    await client.storage.from('comprobantes').upload(path, archivo);
    final String publicUrl = client.storage.from('comprobantes').getPublicUrl(path);
    return publicUrl;
  }
}

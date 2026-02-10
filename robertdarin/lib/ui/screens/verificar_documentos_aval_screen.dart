// ignore_for_file: deprecated_member_use
/// ══════════════════════════════════════════════════════════════════════════════
/// VERIFICACIÓN DE DOCUMENTOS DE AVALES
/// Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Pantalla para que el admin/operador verifique los documentos subidos
/// por los avales (INE, comprobante domicilio, selfie, etc.)
/// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../services/push_notification_service.dart'; // V10.26 Push Notifications

class VerificarDocumentosAvalScreen extends StatefulWidget {
  const VerificarDocumentosAvalScreen({super.key});

  @override
  State<VerificarDocumentosAvalScreen> createState() => _VerificarDocumentosAvalScreenState();
}

class _VerificarDocumentosAvalScreenState extends State<VerificarDocumentosAvalScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _documentosPendientes = [];
  List<Map<String, dynamic>> _documentosVerificados = [];
  List<Map<String, dynamic>> _todosLosAvales = [];
  
  late TabController _tabController;
  String? _avalSeleccionado;
  
  final dateFormat = DateFormat('dd/MMM/yyyy HH:mm');

  // Mapeo de tipos a labels legibles
  final Map<String, Map<String, dynamic>> _tiposDoc = {
    'ine_frente': {'label': 'INE Frente', 'icon': Icons.badge},
    'ine_reverso': {'label': 'INE Reverso', 'icon': Icons.badge_outlined},
    'comprobante_domicilio': {'label': 'Comprobante Domicilio', 'icon': Icons.home},
    'selfie': {'label': 'Selfie Verificación', 'icon': Icons.face},
    'comprobante_ingresos': {'label': 'Comprobante Ingresos', 'icon': Icons.work},
    'contrato_garantia': {'label': 'Contrato Garantía', 'icon': Icons.description},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar todos los avales para el filtro
      final avalesRes = await AppSupabase.client
          .from('avales')
          .select('id, nombre, telefono, clientes(nombre_completo)')
          .order('nombre');
      
      _todosLosAvales = List<Map<String, dynamic>>.from(avalesRes);

      // Cargar documentos pendientes de verificación
      dynamic pendientesRes;
      if (_avalSeleccionado != null) {
        pendientesRes = await AppSupabase.client
            .from('documentos_aval')
            .select('*, avales(id, nombre, telefono, clientes(nombre_completo))')
            .eq('verificado', false)
            .eq('aval_id', _avalSeleccionado!)
            .order('created_at', ascending: false);
      } else {
        pendientesRes = await AppSupabase.client
            .from('documentos_aval')
            .select('*, avales(id, nombre, telefono, clientes(nombre_completo))')
            .eq('verificado', false)
            .order('created_at', ascending: false);
      }
      _documentosPendientes = List<Map<String, dynamic>>.from(pendientesRes);

      // Cargar documentos ya verificados
      dynamic verificadosRes;
      if (_avalSeleccionado != null) {
        verificadosRes = await AppSupabase.client
            .from('documentos_aval')
            .select('*, avales(id, nombre, telefono, clientes(nombre_completo)), usuarios:verificado_por(nombre)')
            .eq('verificado', true)
            .eq('aval_id', _avalSeleccionado!)
            .order('fecha_verificacion', ascending: false)
            .limit(50);
      } else {
        verificadosRes = await AppSupabase.client
            .from('documentos_aval')
            .select('*, avales(id, nombre, telefono, clientes(nombre_completo)), usuarios:verificado_por(nombre)')
            .eq('verificado', true)
            .order('fecha_verificacion', ascending: false)
            .limit(50);
      }
      _documentosVerificados = List<Map<String, dynamic>>.from(verificadosRes);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando documentos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Verificar Documentos",
      subtitle: "Documentos de avales pendientes",
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white70),
          onPressed: _mostrarFiltroAval,
        ),
      ],
      body: Column(
        children: [
          // KPIs
          _buildKPIs(),
          
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "Pendientes (${_documentosPendientes.length})"),
                Tab(text: "Verificados (${_documentosVerificados.length})"),
                const Tab(text: "Por Aval"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaPendientes(),
                      _buildListaVerificados(),
                      _buildVistaPorAval(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    // Contar por tipo
    final porTipo = <String, int>{};
    for (var doc in _documentosPendientes) {
      final tipo = doc['tipo'] ?? 'otro';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildKPIItem(
            "Pendientes",
            _documentosPendientes.length.toString(),
            Icons.hourglass_empty,
            Colors.orangeAccent,
          )),
          Container(width: 1, height: 50, color: Colors.white12),
          Expanded(child: _buildKPIItem(
            "Verificados",
            _documentosVerificados.length.toString(),
            Icons.check_circle,
            Colors.greenAccent,
          )),
          Container(width: 1, height: 50, color: Colors.white12),
          Expanded(child: _buildKPIItem(
            "Avales",
            _todosLosAvales.length.toString(),
            Icons.people,
            Colors.cyanAccent,
          )),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String label, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(height: 6),
        Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildListaPendientes() {
    if (_documentosPendientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.greenAccent.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text("¡Sin documentos pendientes!", 
              style: TextStyle(color: Colors.white54, fontSize: 16)),
            const Text("Todos los documentos han sido verificados",
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _documentosPendientes.length,
        itemBuilder: (context, index) => _buildDocumentoCard(_documentosPendientes[index], pendiente: true),
      ),
    );
  }

  Widget _buildListaVerificados() {
    if (_documentosVerificados.isEmpty) {
      return const Center(
        child: Text("No hay documentos verificados", style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _documentosVerificados.length,
        itemBuilder: (context, index) => _buildDocumentoCard(_documentosVerificados[index], pendiente: false),
      ),
    );
  }

  Widget _buildVistaPorAval() {
    if (_todosLosAvales.isEmpty) {
      return const Center(
        child: Text("No hay avales registrados", style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _todosLosAvales.length,
      itemBuilder: (context, index) {
        final aval = _todosLosAvales[index];
        return _buildAvalResumenCard(aval);
      },
    );
  }

  Widget _buildDocumentoCard(Map<String, dynamic> doc, {required bool pendiente}) {
    final aval = doc['avales'];
    final tipo = doc['tipo'] ?? 'otro';
    final tipoInfo = _tiposDoc[tipo] ?? {'label': tipo, 'icon': Icons.file_present};
    final fechaSubida = DateTime.tryParse(doc['created_at'] ?? '');
    final verificadoPor = doc['usuarios']?['nombre'];
    final fechaVerif = DateTime.tryParse(doc['fecha_verificacion'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: pendiente 
            ? Border.all(color: Colors.orangeAccent.withOpacity(0.3))
            : null,
      ),
      child: Column(
        children: [
          // Header con info del aval
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pendiente 
                  ? Colors.orangeAccent.withOpacity(0.1)
                  : Colors.greenAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: pendiente ? Colors.orangeAccent : Colors.greenAccent,
                  radius: 18,
                  child: Text(
                    (aval?['nombre'] ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aval?['nombre'] ?? 'Aval desconocido',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      if (aval?['telefono'] != null)
                        Text(
                          aval['telefono'],
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendiente ? Colors.orangeAccent : Colors.greenAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pendiente ? 'PENDIENTE' : 'VERIFICADO',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido del documento
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono del tipo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tipoInfo['icon'], color: Colors.purpleAccent, size: 28),
                ),
                const SizedBox(width: 16),
                
                // Info del documento
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipoInfo['label'],
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (fechaSubida != null)
                        Text(
                          "Subido: ${dateFormat.format(fechaSubida)}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      if (!pendiente && verificadoPor != null)
                        Text(
                          "Verificado por: $verificadoPor",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                        ),
                      if (!pendiente && fechaVerif != null)
                        Text(
                          "Fecha: ${dateFormat.format(fechaVerif)}",
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                
                // Botón ver
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.cyanAccent),
                  onPressed: () => _verDocumento(doc),
                ),
              ],
            ),
          ),
          
          // Botones de acción (solo si pendiente)
          if (pendiente) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rechazarDocumento(doc),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Rechazar"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _aprobarDocumento(doc),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Aprobar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvalResumenCard(Map<String, dynamic> aval) {
    // Contar documentos de este aval
    final docsPendientes = _documentosPendientes.where((d) => d['aval_id'] == aval['id']).length;
    final docsVerificados = _documentosVerificados.where((d) => d['aval_id'] == aval['id']).length;
    final totalDocs = docsPendientes + docsVerificados;
    
    final porcentaje = totalDocs > 0 ? (docsVerificados / 5 * 100).round() : 0;
    final color = porcentaje >= 100 ? Colors.greenAccent 
                : porcentaje >= 60 ? Colors.orangeAccent 
                : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            (aval['nombre'] ?? 'A')[0].toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          aval['nombre'] ?? 'Sin nombre',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aval['telefono'] != null)
              Text(aval['telefono'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            // Barra de progreso
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: porcentaje / 100,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "$docsVerificados/5",
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (docsPendientes > 0) ...[
                  Icon(Icons.hourglass_bottom, size: 12, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text("$docsPendientes pendientes", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          onPressed: () {
            setState(() => _avalSeleccionado = aval['id']);
            _cargarDatos();
            _tabController.animateTo(0);
          },
        ),
      ),
    );
  }

  void _mostrarFiltroAval() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.purpleAccent),
                const SizedBox(width: 10),
                const Text("Filtrar por Aval",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_avalSeleccionado != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _avalSeleccionado = null);
                      _cargarDatos();
                      Navigator.pop(context);
                    },
                    child: const Text("Limpiar", style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _todosLosAvales.length,
                itemBuilder: (context, index) {
                  final aval = _todosLosAvales[index];
                  final seleccionado = _avalSeleccionado == aval['id'];
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: seleccionado ? Colors.purpleAccent : Colors.white12,
                      child: Text(
                        (aval['nombre'] ?? 'A')[0].toUpperCase(),
                        style: TextStyle(color: seleccionado ? Colors.white : Colors.white54),
                      ),
                    ),
                    title: Text(
                      aval['nombre'] ?? 'Sin nombre',
                      style: TextStyle(
                        color: seleccionado ? Colors.purpleAccent : Colors.white,
                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: seleccionado 
                        ? const Icon(Icons.check_circle, color: Colors.purpleAccent)
                        : null,
                    onTap: () {
                      setState(() => _avalSeleccionado = aval['id']);
                      _cargarDatos();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verDocumento(Map<String, dynamic> doc) async {
    try {
      final url = AppSupabase.client.storage
          .from('documentos')
          .getPublicUrl(doc['archivo_url']);
      
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _aprobarDocumento(Map<String, dynamic> doc) async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVm.usuarioActual?.id;
    final tipoDoc = doc['tipo'] ?? 'documento';
    final tipoInfo = _tiposDoc[tipoDoc] ?? {'label': tipoDoc};
    final avalId = doc['aval_id'];
    
    try {
      // 1. Actualizar documento como verificado
      await AppSupabase.client.from('documentos_aval').update({
        'verificado': true,
        'verificado_por': userId,
        'fecha_verificacion': DateTime.now().toIso8601String(),
        'notas': 'Aprobado por admin',
      }).eq('id', doc['id']);

      // 2. Crear notificación para el aval
      await AppSupabase.client.from('notificaciones_documento_aval').insert({
        'aval_id': avalId,
        'documento_id': doc['id'],
        'tipo_documento': tipoDoc,
        'tipo_notificacion': 'aprobado',
        'mensaje': '✅ Tu ${tipoInfo['label']} ha sido verificado correctamente.',
        'creado_por': userId,
      });

      // 3. También crear notificación general para que aparezca en campanita
      await AppSupabase.client.from('notificaciones').insert({
        'usuario_id': await _obtenerUsuarioIdDeAval(avalId),
        'titulo': 'Documento Aprobado',
        'mensaje': 'Tu ${tipoInfo['label']} ha sido verificado y aprobado.',
        'tipo': 'success',
        'ruta_destino': '/dashboardAval',
      });

      // 4. V10.26 - ENVIAR PUSH NOTIFICATION REAL AL AVAL
      try {
        await PushNotificationService.notificarDocumentoAprobado(
          avalId: avalId,
          tipoDocumento: tipoInfo['label'] ?? tipoDoc,
        );
        debugPrint('✅ Push notification enviada al aval: $avalId');
      } catch (pushError) {
        debugPrint('⚠️ Error enviando push (no crítico): $pushError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Documento aprobado y aval notificado'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Obtener usuario_id del aval para notificaciones
  Future<String?> _obtenerUsuarioIdDeAval(String avalId) async {
    try {
      final res = await AppSupabase.client
          .from('avales')
          .select('usuario_id')
          .eq('id', avalId)
          .maybeSingle();
      return res?['usuario_id'];
    } catch (_) {
      return null;
    }
  }

  void _rechazarDocumento(Map<String, dynamic> doc) async {
    final motivoController = TextEditingController();
    final tipoDoc = doc['tipo'] ?? 'documento';
    final tipoInfo = _tiposDoc[tipoDoc] ?? {'label': tipoDoc};
    final avalId = doc['aval_id'];
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVm.usuarioActual?.id;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Rechazar Documento', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Por qué rechazas este documento? El aval podrá subir uno nuevo.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Imagen borrosa, documento vencido...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final motivo = motivoController.text.isNotEmpty 
        ? motivoController.text 
        : 'Documento no válido';

    try {
      // 1. Crear notificación ANTES de eliminar (para tener referencia)
      await AppSupabase.client.from('notificaciones_documento_aval').insert({
        'aval_id': avalId,
        'documento_id': null, // Se eliminará el documento
        'tipo_documento': tipoDoc,
        'tipo_notificacion': 'rechazado',
        'mensaje': '❌ Tu ${tipoInfo['label']} fue rechazado. Por favor sube uno nuevo.',
        'motivo_rechazo': motivo,
        'creado_por': userId,
      });

      // 2. Notificación general para campanita
      await AppSupabase.client.from('notificaciones').insert({
        'usuario_id': await _obtenerUsuarioIdDeAval(avalId),
        'titulo': 'Documento Rechazado',
        'mensaje': 'Tu ${tipoInfo['label']} fue rechazado: $motivo. Por favor sube uno nuevo.',
        'tipo': 'warning',
        'ruta_destino': '/dashboardAval',
      });

      // 2.5 V10.26 - ENVIAR PUSH NOTIFICATION REAL AL AVAL
      try {
        await PushNotificationService.notificarDocumentoRechazado(
          avalId: avalId,
          tipoDocumento: tipoInfo['label'] ?? tipoDoc,
          motivo: motivo,
        );
        debugPrint('✅ Push notification de rechazo enviada al aval: $avalId');
      } catch (pushError) {
        debugPrint('⚠️ Error enviando push de rechazo (no crítico): $pushError');
      }

      // 3. Eliminar el documento rechazado para que el aval pueda subir otro
      await AppSupabase.client
          .from('documentos_aval')
          .delete()
          .eq('id', doc['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento rechazado y aval notificado: $motivo'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/models/climas_qr_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// CHAT EN TIEMPO REAL - SOLICITUDES CLIMAS
/// Comunicación bidireccional entre cliente y negocio
/// ═══════════════════════════════════════════════════════════════════════════════
class ClimasChatSolicitudScreen extends StatefulWidget {
  final ClimasSolicitudQrModel solicitud;
  final bool esVistaCliente; // TRUE si lo abre el cliente (sin auth)
  final String? nombreCliente; // Para vista cliente
  
  const ClimasChatSolicitudScreen({
    super.key,
    required this.solicitud,
    this.esVistaCliente = false,
    this.nombreCliente,
  });

  @override
  State<ClimasChatSolicitudScreen> createState() => _ClimasChatSolicitudScreenState();
}

class _ClimasChatSolicitudScreenState extends State<ClimasChatSolicitudScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ClimasChatMensajeModel> _mensajes = [];
  bool _isLoading = true;
  bool _enviando = false;
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _cargarMensajes();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    try {
      final res = await AppSupabase.client
          .from('climas_chat_solicitud')
          .select()
          .eq('solicitud_id', widget.solicitud.id)
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _mensajes = (res as List).map((e) => ClimasChatMensajeModel.fromMap(e)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
        _marcarComoLeidos();
      }
    } catch (e) {
      debugPrint('Error cargando mensajes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _iniciarRealtime() {
    _subscription = AppSupabase.client
        .from('climas_chat_solicitud')
        .stream(primaryKey: ['id'])
        .eq('solicitud_id', widget.solicitud.id)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() {
          _mensajes = data.map((e) => ClimasChatMensajeModel.fromMap(e)).toList();
        });
        _scrollToBottom();
        _marcarComoLeidos();
      }
    });
  }

  Future<void> _marcarComoLeidos() async {
    if (!widget.esVistaCliente) {
      // Admin marca como leídos los mensajes del cliente
      await AppSupabase.client
          .from('climas_chat_solicitud')
          .update({'leido': true, 'fecha_leido': DateTime.now().toIso8601String()})
          .eq('solicitud_id', widget.solicitud.id)
          .eq('es_cliente', true)
          .eq('leido', false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensaje() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty || _enviando) return;
    
    setState(() => _enviando = true);
    
    try {
      final mensaje = ClimasChatMensajeModel(
        id: '',
        solicitudId: widget.solicitud.id,
        esCliente: widget.esVistaCliente,
        remitenteId: widget.esVistaCliente ? null : AppSupabase.client.auth.currentUser?.id,
        remitenteNombre: widget.esVistaCliente 
            ? (widget.nombreCliente ?? widget.solicitud.nombreCompleto)
            : 'Soporte Técnico',
        mensaje: texto,
      );
      
      await AppSupabase.client
          .from('climas_chat_solicitud')
          .insert(mensaje.toMapForInsert());
      
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enviando mensaje: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildInfoSolicitud(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                    ? _buildEmptyChat()
                    : _buildListaMensajes(),
          ),
          _buildInputMensaje(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                widget.solicitud.nombreCompleto.isNotEmpty 
                    ? widget.solicitud.nombreCompleto[0].toUpperCase() 
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.esVistaCliente ? 'Soporte Técnico' : widget.solicitud.nombreCompleto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'En línea',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.esVistaCliente)
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
            onPressed: () {
              // Llamar al cliente
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Llamando a ${widget.solicitud.telefono}...')),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onPressed: _mostrarOpciones,
        ),
      ],
    );
  }

  Widget _buildInfoSolicitud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getIconServicio(widget.solicitud.tipoServicio),
            color: const Color(0xFF00D9FF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.solicitud.tipoServicioDisplay,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getColorEstado(widget.solicitud.estado).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.solicitud.estadoDisplay,
              style: TextStyle(
                color: _getColorEstado(widget.solicitud.estado),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00D9FF), size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Inicia la conversación!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.esVistaCliente
                ? 'Escribe tu mensaje y te responderemos lo antes posible'
                : 'Contacta al cliente para darle seguimiento',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!widget.esVistaCliente) ...[
            ElevatedButton.icon(
              onPressed: () => _enviarMensajeRapido('¡Hola! Gracias por tu solicitud. ¿En qué podemos ayudarte?'),
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Enviar saludo rápido'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListaMensajes() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _mensajes.length,
      itemBuilder: (ctx, i) {
        final mensaje = _mensajes[i];
        final esMio = widget.esVistaCliente ? mensaje.esCliente : !mensaje.esCliente;
        final mostrarFecha = i == 0 || _esFechaDiferente(_mensajes[i - 1].createdAt, mensaje.createdAt);
        
        return Column(
          children: [
            if (mostrarFecha) _buildFechaSeparador(mensaje.createdAt),
            _buildMensajeBurbuja(mensaje, esMio),
          ],
        );
      },
    );
  }

  Widget _buildFechaSeparador(DateTime? fecha) {
    final texto = _getFechaTexto(fecha);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              texto,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  Widget _buildMensajeBurbuja(ClimasChatMensajeModel mensaje, bool esMio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.3),
              child: Text(
                mensaje.remitenteNombre.isNotEmpty ? mensaje.remitenteNombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: esMio
                    ? const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF0099CC)],
                      )
                    : null,
                color: esMio ? null : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esMio ? 16 : 4),
                  bottomRight: Radius.circular(esMio ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!esMio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        mensaje.remitenteNombre,
                        style: TextStyle(
                          color: const Color(0xFF8B5CF6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    mensaje.mensaje,
                    style: TextStyle(
                      color: esMio ? Colors.black : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getHora(mensaje.createdAt),
                        style: TextStyle(
                          color: esMio ? Colors.black54 : Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                      if (esMio) ...[
                        const SizedBox(width: 4),
                        Icon(
                          mensaje.leido ? Icons.done_all : Icons.done,
                          size: 14,
                          color: mensaje.leido ? Colors.blue[800] : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (esMio) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputMensaje() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón adjuntar
            IconButton(
              onPressed: _adjuntarArchivo,
              icon: const Icon(Icons.attach_file, color: Colors.white54),
            ),
            // Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón enviar
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: _enviando ? null : _enviarMensaje,
                icon: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!widget.esVistaCliente) ...[
              ListTile(
                leading: const Icon(Icons.phone, color: Color(0xFF10B981)),
                title: const Text('Llamar al cliente', style: TextStyle(color: Colors.white)),
                subtitle: Text(widget.solicitud.telefono, style: const TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Implementar llamada
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                title: const Text('Aprobar solicitud', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Aprobar
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF00D9FF)),
              title: const Text('Ver detalles solicitud', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarDetalles();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalles() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Detalles de Solicitud', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleItem('Nombre', widget.solicitud.nombreCompleto),
              _buildDetalleItem('Teléfono', widget.solicitud.telefono),
              _buildDetalleItem('Servicio', widget.solicitud.tipoServicioDisplay),
              _buildDetalleItem('Dirección', widget.solicitud.direccion),
              if (widget.solicitud.problemaReportado != null)
                _buildDetalleItem('Problema', widget.solicitud.problemaReportado!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  void _adjuntarArchivo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de adjuntar próximamente...')),
    );
  }

  void _enviarMensajeRapido(String texto) {
    _messageController.text = texto;
    _enviarMensaje();
  }

  // Helpers
  IconData _getIconServicio(String tipo) {
    switch (tipo) {
      case 'cotizacion': return Icons.request_quote;
      case 'instalacion': return Icons.build;
      case 'mantenimiento': return Icons.handyman;
      case 'reparacion': return Icons.construction;
      case 'emergencia': return Icons.emergency;
      default: return Icons.ac_unit;
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'nueva': return const Color(0xFF00D9FF);
      case 'revisando': return const Color(0xFFFBBF24);
      case 'contactado': return const Color(0xFF8B5CF6);
      case 'agendado': return const Color(0xFF06B6D4);
      case 'aprobado': return const Color(0xFF10B981);
      case 'rechazado': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  bool _esFechaDiferente(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  String _getFechaTexto(DateTime? fecha) {
    if (fecha == null) return '';
    final hoy = DateTime.now();
    if (fecha.day == hoy.day && fecha.month == hoy.month && fecha.year == hoy.year) {
      return 'Hoy';
    }
    final ayer = hoy.subtract(const Duration(days: 1));
    if (fecha.day == ayer.day && fecha.month == ayer.month && fecha.year == ayer.year) {
      return 'Ayer';
    }
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _getHora(DateTime? fecha) {
    if (fecha == null) return '';
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}

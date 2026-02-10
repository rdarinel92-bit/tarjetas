// ═══════════════════════════════════════════════════════════════════════════════
// COMPARTIR MASIVO QR - V10.54
// Envío por lotes: WhatsApp, Email, SMS + historial de envíos
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class CompartirMasivoQrScreen extends StatefulWidget {
  final String? tarjetaId;
  final String? qrUrl;
  final String? titulo;
  
  const CompartirMasivoQrScreen({
    super.key,
    this.tarjetaId,
    this.qrUrl,
    this.titulo,
  });

  @override
  State<CompartirMasivoQrScreen> createState() => _CompartirMasivoQrScreenState();
}

class _CompartirMasivoQrScreenState extends State<CompartirMasivoQrScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _enviando = false;
  int _enviados = 0;
  int _totalEnviar = 0;
  
  // Listas de contactos
  List<Map<String, dynamic>> _contactosSeleccionados = [];
  List<Map<String, dynamic>> _clientesDisponibles = [];
  
  // Mensaje personalizado
  final _mensajeController = TextEditingController();
  String _canalSeleccionado = 'whatsapp';
  
  // Historial
  List<Map<String, dynamic>> _historial = [];
  
  // Plantillas de mensajes
  final List<Map<String, String>> _plantillas = [
    {
      'nombre': 'Invitación General',
      'mensaje': '¡Hola! 👋\n\nTe invito a conocer nuestros servicios. Escanea el código QR o visita:\n{url}\n\n¡Te esperamos!',
    },
    {
      'nombre': 'Promoción',
      'mensaje': '🎉 ¡PROMOCIÓN ESPECIAL!\n\nNo te pierdas nuestras ofertas exclusivas.\n\nMás info aquí:\n{url}\n\n⏰ Por tiempo limitado',
    },
    {
      'nombre': 'Recordatorio',
      'mensaje': '📣 Recordatorio\n\nNo olvides visitarnos. Toda la info en:\n{url}\n\n¡Gracias por tu preferencia!',
    },
    {
      'nombre': 'Solicitud Info',
      'mensaje': 'Hola,\n\nPuedes solicitar información o cotización directamente aquí:\n{url}\n\nResponderemos a la brevedad.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _mensajeController.text = _plantillas[0]['mensaje']!;
    _cargarClientes();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final response = await AppSupabase.client
          .from('clientes')
          .select('id, nombre_completo, telefono, email, activo')
          .eq('activo', true)
          .order('nombre_completo');

      _clientesDisponibles = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarHistorial() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      // Intentar cargar de la tabla de historial si existe
      final response = await AppSupabase.client
          .from('formularios_qr_envios')
          .select('*, tarjetas_servicio(titulo)')
          .eq('tipo', 'masivo')
          .order('created_at', ascending: false)
          .limit(50);

      _historial = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // La tabla podría no tener el tipo 'masivo', ignorar
      debugPrint('Historial no disponible: $e');
    }
  }

  String get _mensajeFinal {
    final url = widget.qrUrl ?? 'https://robertdarin.app/qr/${widget.tarjetaId ?? 'demo'}';
    return _mensajeController.text.replaceAll('{url}', url);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Compartir Masivo',
      body: Column(
        children: [
          // Tabs
          Container(
            color: const Color(0xFF0D0D14),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyan,
              labelColor: Colors.cyan,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.group_add, size: 20), text: 'Contactos'),
                Tab(icon: Icon(Icons.message, size: 20), text: 'Mensaje'),
                Tab(icon: Icon(Icons.history, size: 20), text: 'Historial'),
              ],
            ),
          ),
          
          // Contenido
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactosTab(),
                _buildMensajeTab(),
                _buildHistorialTab(),
              ],
            ),
          ),
          
          // Botón de envío
          if (_contactosSeleccionados.isNotEmpty)
            _buildBotonEnvio(),
        ],
      ),
    );
  }

  Widget _buildContactosTab() {
    return Column(
      children: [
        // Header con contadores
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1A1A2E),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_contactosSeleccionados.length} seleccionados',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'de ${_clientesDisponibles.length} disponibles',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _seleccionarTodos,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Todos'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _contactosSeleccionados.clear()),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Ninguno'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
        
        // Lista de clientes
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
              : _clientesDisponibles.isEmpty
                  ? _buildEmptyClientes()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _clientesDisponibles.length,
                      itemBuilder: (context, index) => _buildContactoItem(_clientesDisponibles[index]),
                    ),
        ),
        
        // Agregar manual
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _agregarContactoManual,
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar contacto manual'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyan,
              side: const BorderSide(color: Colors.cyan),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyClientes() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No hay clientes registrados',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _agregarContactoManual,
            child: const Text('Agregar contacto manual'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactoItem(Map<String, dynamic> cliente) {
    final seleccionado = _contactosSeleccionados.any((c) => c['id'] == cliente['id']);
    final telefono = cliente['telefono']?.toString() ?? '';
    final email = cliente['email']?.toString() ?? '';
    final tieneWhatsApp = telefono.isNotEmpty;
    final tieneEmail = email.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: seleccionado ? Colors.cyan.withOpacity(0.1) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seleccionado ? Colors.cyan : Colors.white10,
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _toggleContacto(cliente),
        leading: CircleAvatar(
          backgroundColor: seleccionado ? Colors.cyan : Colors.white12,
          child: seleccionado
              ? const Icon(Icons.check, color: Colors.white)
              : Text(
                  (cliente['nombre_completo']?.toString() ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(
          cliente['nombre_completo'] ?? 'Sin nombre',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (tieneWhatsApp)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8, top: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat, color: Colors.green, size: 12),
                    const SizedBox(width: 4),
                    Text(telefono, style: const TextStyle(color: Colors.green, fontSize: 10)),
                  ],
                ),
              ),
            if (tieneEmail)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.email, color: Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      email.length > 15 ? '${email.substring(0, 15)}...' : email,
                      style: const TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!tieneWhatsApp && !tieneEmail)
              const Tooltip(
                message: 'Sin contacto',
                child: Icon(Icons.warning, color: Colors.amber, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMensajeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canal de envío
          const Text('Canal de envío', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCanalOption('whatsapp', 'WhatsApp', Icons.chat, Colors.green),
              const SizedBox(width: 12),
              _buildCanalOption('email', 'Email', Icons.email, Colors.orange),
              const SizedBox(width: 12),
              _buildCanalOption('sms', 'SMS', Icons.sms, Colors.blue),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Plantillas
          const Text('Plantillas rápidas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _plantillas.length,
              itemBuilder: (context, index) {
                final plantilla = _plantillas[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _mensajeController.text = plantilla['mensaje']!;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Text(
                        plantilla['nombre']!,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Editor de mensaje
          const Text('Mensaje personalizado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Usa {url} para insertar el enlace QR',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mensajeController,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escribe tu mensaje aquí...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.cyan),
              ),
            ),
            onChanged: (v) => setState(() {}),
          ),
          
          const SizedBox(height: 16),
          
          // Vista previa
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.preview, color: Colors.cyan, size: 16),
                    const SizedBox(width: 8),
                    const Text('Vista previa', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _mensajeFinal,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Estadísticas del envío
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstadistica(
                  _contactosSeleccionados.length.toString(),
                  'Contactos',
                  Icons.people,
                ),
                _buildEstadistica(
                  _canalSeleccionado == 'whatsapp'
                      ? _contactosSeleccionados.where((c) => (c['telefono'] ?? '').toString().isNotEmpty).length.toString()
                      : _canalSeleccionado == 'email'
                          ? _contactosSeleccionados.where((c) => (c['email'] ?? '').toString().isNotEmpty).length.toString()
                          : _contactosSeleccionados.where((c) => (c['telefono'] ?? '').toString().isNotEmpty).length.toString(),
                  'Con $_canalSeleccionado',
                  _canalSeleccionado == 'whatsapp' ? Icons.chat : _canalSeleccionado == 'email' ? Icons.email : Icons.sms,
                ),
                _buildEstadistica(
                  '~${(_mensajeFinal.length / 160).ceil()}',
                  'SMS equiv.',
                  Icons.message,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanalOption(String id, String label, IconData icon, Color color) {
    final seleccionado = _canalSeleccionado == id;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _canalSeleccionado = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: seleccionado ? color.withOpacity(0.2) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? color : Colors.white12,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: seleccionado ? color : Colors.white54),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: seleccionado ? color : Colors.white54,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadistica(String valor, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }

  Widget _buildHistorialTab() {
    if (_historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Sin envíos registrados',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí verás el historial de tus envíos masivos',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historial.length,
      itemBuilder: (context, index) {
        final envio = _historial[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envio['tarjetas_servicio']?['titulo'] ?? 'Envío masivo',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${envio['total_enviados'] ?? 0} contactos',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _formatearFecha(envio['created_at']),
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return '';
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildBotonEnvio() {
    final contactosValidos = _canalSeleccionado == 'email'
        ? _contactosSeleccionados.where((c) => (c['email'] ?? '').toString().isNotEmpty).length
        : _contactosSeleccionados.where((c) => (c['telefono'] ?? '').toString().isNotEmpty).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          if (_enviando)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _totalEnviar > 0 ? _enviados / _totalEnviar : 0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviando... $_enviados de $_totalEnviar',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: contactosValidos > 0 ? _iniciarEnvio : null,
                icon: Icon(
                  _canalSeleccionado == 'whatsapp' ? Icons.chat :
                  _canalSeleccionado == 'email' ? Icons.email : Icons.sms,
                ),
                label: Text(
                  'Enviar a $contactosValidos contactos por ${_canalSeleccionado.toUpperCase()}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canalSeleccionado == 'whatsapp' ? Colors.green :
                                   _canalSeleccionado == 'email' ? Colors.orange : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleContacto(Map<String, dynamic> cliente) {
    setState(() {
      final existe = _contactosSeleccionados.any((c) => c['id'] == cliente['id']);
      if (existe) {
        _contactosSeleccionados.removeWhere((c) => c['id'] == cliente['id']);
      } else {
        _contactosSeleccionados.add(cliente);
      }
    });
  }

  void _seleccionarTodos() {
    setState(() {
      _contactosSeleccionados = List.from(_clientesDisponibles);
    });
  }

  Future<void> _agregarContactoManual() async {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Agregar Contacto', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefonoController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (WhatsApp)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'nombre': nombreController.text,
                'telefono': telefonoController.text,
                'email': emailController.text,
              });
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado['nombre']!.isNotEmpty) {
      setState(() {
        _contactosSeleccionados.add({
          'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
          'nombre_completo': resultado['nombre'],
          'telefono': resultado['telefono'],
          'email': resultado['email'],
        });
      });
    }
  }

  Future<void> _iniciarEnvio() async {
    final contactosValidos = _canalSeleccionado == 'email'
        ? _contactosSeleccionados.where((c) => (c['email'] ?? '').toString().isNotEmpty).toList()
        : _contactosSeleccionados.where((c) => (c['telefono'] ?? '').toString().isNotEmpty).toList();

    if (contactosValidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay contactos válidos para el canal seleccionado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirmar envío
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar Envío', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Enviar mensaje a ${contactosValidos.length} contactos?',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _mensajeFinal.length > 100 ? '${_mensajeFinal.substring(0, 100)}...' : _mensajeFinal,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _enviando = true;
      _enviados = 0;
      _totalEnviar = contactosValidos.length;
    });

    // Proceso de envío según canal
    if (_canalSeleccionado == 'whatsapp') {
      await _enviarPorWhatsApp(contactosValidos);
    } else if (_canalSeleccionado == 'email') {
      await _enviarPorEmail(contactosValidos);
    } else {
      await _enviarPorSMS(contactosValidos);
    }

    setState(() => _enviando = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Envío completado: $_enviados de $_totalEnviar'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _enviarPorWhatsApp(List<Map<String, dynamic>> contactos) async {
    for (final contacto in contactos) {
      final telefono = contacto['telefono']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
      if (telefono.isEmpty) continue;

      final uri = Uri.parse('https://wa.me/$telefono?text=${Uri.encodeComponent(_mensajeFinal)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Esperar un momento para que el usuario envíe
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() => _enviados++);
    }
  }

  Future<void> _enviarPorEmail(List<Map<String, dynamic>> contactos) async {
    // Crear lista de emails
    final emails = contactos
        .map((c) => c['email']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .join(',');

    final uri = Uri.parse('mailto:$emails?subject=${Uri.encodeComponent(widget.titulo ?? 'Información importante')}&body=${Uri.encodeComponent(_mensajeFinal)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    setState(() => _enviados = contactos.length);
  }

  Future<void> _enviarPorSMS(List<Map<String, dynamic>> contactos) async {
    // Crear lista de teléfonos
    final telefonos = contactos
        .map((c) => c['telefono']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '')
        .where((t) => t.isNotEmpty)
        .join(',');

    final uri = Uri.parse('sms:$telefonos?body=${Uri.encodeComponent(_mensajeFinal)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    setState(() => _enviados = contactos.length);
  }
}

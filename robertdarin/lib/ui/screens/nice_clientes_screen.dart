// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CLIENTES - MÓDULO NICE
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../services/nice_service.dart';
import '../../data/models/nice_models.dart';

class NiceClientesScreen extends StatefulWidget {
  final String negocioId;

  const NiceClientesScreen({super.key, required this.negocioId});

  @override
  State<NiceClientesScreen> createState() => _NiceClientesScreenState();
}

class _NiceClientesScreenState extends State<NiceClientesScreen> {
  bool _isLoading = true;
  List<NiceCliente> _clientes = [];
  List<NiceVendedora> _vendedoras = [];
  String _busqueda = '';
  String? _filtroVendedora;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _formatDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      _clientes = await NiceService.getClientes(negocioId: widget.negocioId);
      _vendedoras = await NiceService.getVendedoras(negocioId: widget.negocioId, soloActivas: true);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<NiceCliente> get _clientesFiltrados {
    var lista = _clientes;

    if (_filtroVendedora != null) {
      lista = lista.where((c) => c.vendedoraId == _filtroVendedora).toList();
    }

    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      lista = lista.where((c) =>
          c.nombre.toLowerCase().contains(query) ||
          (c.apellidos?.toLowerCase().contains(query) ?? false) ||
          (c.email?.toLowerCase().contains(query) ?? false) ||
          (c.telefono?.contains(query) ?? false)
      ).toList();
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Clientes',
      subtitle: '${_clientes.length} clientes',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: () => _mostrarFormularioCliente(),
          tooltip: 'Nuevo cliente',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : Column(
              children: [
                // Stats
                Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard('Total', '${_clientes.length}', Colors.pinkAccent, Icons.people),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Activos',
                        '${_clientes.where((c) => c.activo).length}',
                        Colors.green,
                        Icons.check_circle,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Este mes',
                        '${_clientes.where((c) => c.createdAt?.month == DateTime.now().month).length}',
                        Colors.blue,
                        Icons.calendar_today,
                      ),
                    ],
                  ),
                ),
                // Búsqueda
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filtro por vendedora
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFiltroChip('Todas', null),
                      ..._vendedoras.map((v) => _buildFiltroChip(v.nombre, v.id)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Lista de clientes
                Expanded(
                  child: _clientesFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No hay clientes',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clientesFiltrados.length,
                          itemBuilder: (context, index) {
                            final cliente = _clientesFiltrados[index];
                            return _buildClienteCard(cliente);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String? vendedoraId) {
    final isSelected = _filtroVendedora == vendedoraId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() => _filtroVendedora = v ? vendedoraId : null),
        selectedColor: Colors.pinkAccent,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildClienteCard(NiceCliente cliente) {
    return GestureDetector(
      onTap: () => _mostrarDetalleCliente(cliente),
      child: PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                child: Text(
                  cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.pinkAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cliente.nombreCompleto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!cliente.activo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Inactivo',
                              style: TextStyle(color: Colors.red, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (cliente.vendedoraNombre != null)
                      Row(
                        children: [
                          const Icon(Icons.badge, color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            cliente.vendedoraNombre!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (cliente.telefono != null) ...[
                          const Icon(Icons.phone, color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            cliente.telefono!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (cliente.email != null) ...[
                          const Icon(Icons.email, color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.email!,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency.format(cliente.totalCompras),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'compras',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cliente.totalPedidos} pedidos',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleCliente(NiceCliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                    child: Text(
                      cliente.nombre[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreCompleto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (cliente.vendedoraNombre != null)
                          Row(
                            children: [
                              const Icon(Icons.badge, color: Colors.pinkAccent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Vendedora: ${cliente.vendedoraNombre}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cliente.activo
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cliente.activo ? 'Activo' : 'Inactivo',
                                style: TextStyle(
                                  color: cliente.activo ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      'Total Compras',
                      _formatCurrency.format(cliente.totalCompras),
                      Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'Pedidos',
                      '${cliente.totalPedidos}',
                      Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Contacto
              const Text(
                'Información de contacto',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (cliente.telefono != null)
                _buildContactoItem(Icons.phone, 'Teléfono', cliente.telefono!),
              if (cliente.whatsapp != null)
                _buildContactoItem(Icons.message, 'WhatsApp', cliente.whatsapp!),
              if (cliente.email != null)
                _buildContactoItem(Icons.email, 'Email', cliente.email!),
              if (cliente.direccion != null)
                _buildContactoItem(Icons.location_on, 'Dirección', cliente.direccion!),
              const SizedBox(height: 24),
              // Fechas
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Cliente desde',
                      cliente.createdAt != null ? _formatDate.format(cliente.createdAt!) : 'N/A',
                    ),
                  ),
                  if (cliente.fechaNacimiento != null)
                    Expanded(
                      child: _buildInfoItem(
                        Icons.cake,
                        'Cumpleaños',
                        _formatDate.format(cliente.fechaNacimiento!),
                      ),
                    ),
                ],
              ),
              if (cliente.notas != null && cliente.notas!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Notas',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cliente.notas!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Acciones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarFormularioCliente(cliente: cliente);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await NiceService.actualizarCliente(
                          cliente.id,
                          {'activo': !cliente.activo},
                        );
                        if (success && mounted) {
                          Navigator.pop(context);
                          _cargarDatos();
                        }
                      },
                      icon: Icon(cliente.activo ? Icons.block : Icons.check_circle),
                      label: Text(cliente.activo ? 'Desactivar' : 'Activar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cliente.activo ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildContactoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.pinkAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  void _mostrarFormularioCliente({NiceCliente? cliente}) {
    final nombreController = TextEditingController(text: cliente?.nombre);
    final apellidosController = TextEditingController(text: cliente?.apellidos);
    final emailController = TextEditingController(text: cliente?.email);
    final telefonoController = TextEditingController(text: cliente?.telefono);
    final whatsappController = TextEditingController(text: cliente?.whatsapp);
    final direccionController = TextEditingController(text: cliente?.direccion);
    final notasController = TextEditingController(text: cliente?.notas);
    String? vendedoraSeleccionada = cliente?.vendedoraId;
    DateTime? fechaNacimiento = cliente?.fechaNacimiento;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente == null ? 'Nuevo Cliente' : 'Editar Cliente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(nombreController, 'Nombre *', Icons.person),
                _buildTextField(apellidosController, 'Apellidos', Icons.person_outline),
                _buildTextField(emailController, 'Email', Icons.email,
                    keyboard: TextInputType.emailAddress),
                _buildTextField(telefonoController, 'Teléfono', Icons.phone,
                    keyboard: TextInputType.phone),
                _buildTextField(whatsappController, 'WhatsApp', Icons.message,
                    keyboard: TextInputType.phone),
                _buildTextField(direccionController, 'Dirección', Icons.location_on,
                    maxLines: 2),
                _buildTextField(notasController, 'Notas', Icons.note, maxLines: 2),
                const SizedBox(height: 12),
                // Vendedora
                DropdownButtonFormField<String>(
                  value: vendedoraSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Vendedora asignada',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.badge, color: Colors.pinkAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ..._vendedoras.map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.nombre} (${v.codigoVendedora})'),
                        )),
                  ],
                  onChanged: (v) => vendedoraSeleccionada = v,
                ),
                const SizedBox(height: 12),
                // Fecha de nacimiento
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake, color: Colors.pinkAccent),
                  title: const Text('Fecha de nacimiento',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  subtitle: Text(
                    fechaNacimiento != null
                        ? _formatDate.format(fechaNacimiento!)
                        : 'No especificada',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Colors.pinkAccent),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: fechaNacimiento ?? DateTime(1990),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setSheetState(() => fechaNacimiento = fecha);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nombreController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El nombre es requerido')),
                        );
                        return;
                      }

                      final data = {
                        'nombre': nombreController.text,
                        'apellidos':
                            apellidosController.text.isEmpty ? null : apellidosController.text,
                        'email': emailController.text.isEmpty ? null : emailController.text,
                        'telefono':
                            telefonoController.text.isEmpty ? null : telefonoController.text,
                        'whatsapp':
                            whatsappController.text.isEmpty ? null : whatsappController.text,
                        'direccion':
                            direccionController.text.isEmpty ? null : direccionController.text,
                        'notas': notasController.text.isEmpty ? null : notasController.text,
                        'vendedora_id': vendedoraSeleccionada,
                        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
                        'negocio_id': widget.negocioId,
                      };

                      bool success;
                      if (cliente == null) {
                        final nuevo = NiceCliente(
                          id: '',
                          nombre: data['nombre'] as String,
                          apellidos: data['apellidos'],
                          email: data['email'],
                          telefono: data['telefono'],
                          whatsapp: data['whatsapp'],
                          direccion: data['direccion'],
                          notas: data['notas'],
                          vendedoraId: vendedoraSeleccionada,
                          fechaNacimiento: fechaNacimiento,
                          negocioId: widget.negocioId,
                        );
                        success = (await NiceService.crearCliente(nuevo)) != null;
                      } else {
                        success = await NiceService.actualizarCliente(cliente.id, data);
                      }

                      if (success && mounted) {
                        Navigator.pop(context);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(cliente == null
                                ? 'Cliente creado'
                                : 'Cliente actualizado'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        Text(cliente == null ? 'Crear Cliente' : 'Guardar Cambios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.pinkAccent),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

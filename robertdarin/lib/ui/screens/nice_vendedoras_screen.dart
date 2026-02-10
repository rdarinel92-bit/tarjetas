// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA VENDEDORAS - MÓDULO NICE
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../services/nice_service.dart';
import '../../services/auth_creacion_service.dart';
import '../../data/models/nice_models.dart';

class NiceVendedorasScreen extends StatefulWidget {
  final String negocioId;

  const NiceVendedorasScreen({super.key, required this.negocioId});

  @override
  State<NiceVendedorasScreen> createState() => _NiceVendedorasScreenState();
}

class _NiceVendedorasScreenState extends State<NiceVendedorasScreen> {
  bool _isLoading = true;
  List<NiceVendedora> _vendedoras = [];
  List<NiceNivel> _niveles = [];
  String _busqueda = '';
  String? _filtroNivel;

  final _formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      _vendedoras = await NiceService.getVendedoras(
        negocioId: widget.negocioId,
        soloActivas: true,
      );
      _niveles = await NiceService.getNiveles(negocioId: widget.negocioId);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<NiceVendedora> get _vendedorasFiltradas {
    var lista = _vendedoras;
    
    if (_filtroNivel != null) {
      lista = lista.where((v) => v.nivelId == _filtroNivel).toList();
    }
    
    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      lista = lista.where((v) =>
          v.nombre.toLowerCase().contains(query) ||
          v.codigoVendedora.toLowerCase().contains(query) ||
          (v.email?.toLowerCase().contains(query) ?? false) ||
          (v.telefono?.contains(query) ?? false)
      ).toList();
    }
    
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Vendedoras',
      subtitle: '${_vendedoras.length} consultoras',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: () => _mostrarFormularioVendedora(),
          tooltip: 'Nueva vendedora',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : Column(
              children: [
                // Barra de búsqueda y filtros
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _busqueda = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar vendedora...',
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
                      const SizedBox(height: 12),
                      // Filtro por nivel
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFiltroChip('Todas', null),
                            ..._niveles.map((n) => _buildFiltroChip(n.nombre, n.id)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de vendedoras
                Expanded(
                  child: _vendedorasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, 
                                  size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No hay vendedoras',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _vendedorasFiltradas.length,
                          itemBuilder: (context, index) {
                            final vendedora = _vendedorasFiltradas[index];
                            return _buildVendedoraCard(vendedora);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltroChip(String label, String? nivelId) {
    final isSelected = _filtroNivel == nivelId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() => _filtroNivel = v ? nivelId : null),
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

  Widget _buildVendedoraCard(NiceVendedora vendedora) {
    Color nivelColor;
    try {
      nivelColor = Color(int.parse((vendedora.nivelColor ?? '#666666').replaceAll('#', '0xFF')));
    } catch (_) {
      nivelColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleVendedora(vendedora),
      child: PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: nivelColor.withOpacity(0.2),
                    backgroundImage: vendedora.fotoUrl != null
                        ? NetworkImage(vendedora.fotoUrl!)
                        : null,
                    child: vendedora.fotoUrl == null
                        ? Text(
                            vendedora.nombre.isNotEmpty 
                                ? vendedora.nombre[0].toUpperCase() 
                                : '?',
                            style: TextStyle(
                              color: nivelColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendedora.nombreCompleto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vendedora.codigoVendedora,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: nivelColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            vendedora.nivelNombre ?? 'Sin nivel',
                            style: TextStyle(
                              color: nivelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency.format(vendedora.ventasMes ?? 0),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'este mes',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mini stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.people, '${vendedora.totalClientes ?? 0}', 'Clientes'),
                  _buildMiniStat(Icons.groups, '${vendedora.equipoDirecto}', 'Equipo'),
                  _buildMiniStat(Icons.star, '${vendedora.puntosAcumulados}', 'Puntos'),
                  _buildMiniStat(Icons.pending_actions, '${vendedora.pedidosPendientes ?? 0}', 'Pendientes'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  void _mostrarDetalleVendedora(NiceVendedora vendedora) {
    Color nivelColor;
    try {
      nivelColor = Color(int.parse((vendedora.nivelColor ?? '#666666').replaceAll('#', '0xFF')));
    } catch (_) {
      nivelColor = Colors.grey;
    }

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
                    backgroundColor: nivelColor.withOpacity(0.2),
                    child: Text(
                      vendedora.nombre[0].toUpperCase(),
                      style: TextStyle(
                        color: nivelColor,
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
                          vendedora.nombreCompleto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vendedora.codigoVendedora,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: nivelColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            vendedora.nivelNombre ?? 'Sin nivel',
                            style: TextStyle(
                              color: nivelColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  Expanded(child: _buildStatBox('Ventas Totales', 
                      _formatCurrency.format(vendedora.ventasTotales), Colors.greenAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatBox('Comisiones', 
                      _formatCurrency.format(vendedora.comisionesTotales), Colors.purpleAccent)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatBox('Puntos', 
                      '${vendedora.puntosAcumulados}', Colors.amber)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatBox('Equipo', 
                      '${vendedora.equipoDirecto}', Colors.cyanAccent)),
                ],
              ),
              const SizedBox(height: 24),
              // Contacto
              const Text(
                'Contacto',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (vendedora.telefono != null)
                _buildContactoItem(Icons.phone, vendedora.telefono!),
              if (vendedora.email != null)
                _buildContactoItem(Icons.email, vendedora.email!),
              if (vendedora.whatsapp != null)
                _buildContactoItem(Icons.message, vendedora.whatsapp!),
              const SizedBox(height: 24),
              // Patrocinadora
              if (vendedora.patrocinadoraNombre != null) ...[
                const Text(
                  'Patrocinadora',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.pinkAccent),
                      const SizedBox(width: 12),
                      Text(
                        '${vendedora.patrocinadoraNombre} (${vendedora.patrocinadoraCodigo})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
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
                        _mostrarFormularioVendedora(vendedora: vendedora);
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
                      onPressed: () {
                        // Ver equipo
                      },
                      icon: const Icon(Icons.account_tree),
                      label: const Text('Equipo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
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

  Widget _buildContactoItem(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _mostrarFormularioVendedora({NiceVendedora? vendedora}) {
    final nombreController = TextEditingController(text: vendedora?.nombre);
    final apellidosController = TextEditingController(text: vendedora?.apellidos);
    final emailController = TextEditingController(text: vendedora?.email);
    final telefonoController = TextEditingController(text: vendedora?.telefono);
    final whatsappController = TextEditingController(text: vendedora?.whatsapp);
    String? nivelSeleccionado = vendedora?.nivelId;
    String? patrocinadoraSeleccionada = vendedora?.patrocinadoraId;
    
    // V10.22: Campos para crear cuenta de acceso
    final passwordController = TextEditingController();
    bool crearCuenta = false;
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                  vendedora == null ? 'Nueva Vendedora' : 'Editar Vendedora',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(nombreController, 'Nombre *', Icons.person),
                _buildTextField(apellidosController, 'Apellidos', Icons.person_outline),
                _buildTextField(emailController, 'Email', Icons.email, keyboard: TextInputType.emailAddress),
                _buildTextField(telefonoController, 'Teléfono', Icons.phone, keyboard: TextInputType.phone),
                _buildTextField(whatsappController, 'WhatsApp', Icons.message, keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                // Nivel
                DropdownButtonFormField<String>(
                  value: nivelSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Nivel',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.star, color: Colors.pinkAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: _niveles.map((n) => DropdownMenuItem(
                    value: n.id,
                    child: Text(n.nombre),
                  )).toList(),
                  onChanged: (v) => nivelSeleccionado = v,
                ),
                const SizedBox(height: 12),
                // Patrocinadora
                DropdownButtonFormField<String>(
                  value: patrocinadoraSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Patrocinadora',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.supervisor_account, color: Colors.pinkAccent),
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
                    const DropdownMenuItem(value: null, child: Text('Sin patrocinadora')),
                    ..._vendedoras
                        .where((v) => v.id != vendedora?.id)
                        .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text('${v.nombre} (${v.codigoVendedora})'),
                            )),
                  ],
                  onChanged: (v) => patrocinadoraSeleccionada = v,
                ),
              
                // V10.22: Sección de acceso a la app (solo para nuevas)
                if (vendedora == null) ...[
                  CamposAuthWidget(
                    emailController: emailController,
                    passwordController: passwordController,
                    crearCuenta: crearCuenta,
                    onCrearCuentaChanged: (v) => setModalState(() => crearCuenta = v),
                    tipoUsuario: 'vendedora_nice',
                  ),
                ],
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: guardando ? null : () async {
                      if (nombreController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El nombre es requerido')),
                        );
                        return;
                      }
                      
                      // V10.22: Validar si se va a crear cuenta
                      if (crearCuenta && vendedora == null) {
                        if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un email válido'), backgroundColor: Colors.orange));
                          return;
                        }
                        if (passwordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange));
                          return;
                        }
                      }
                      
                      setModalState(() => guardando = true);
                      
                      String? authUid;
                      
                      // V10.55: Crear cuenta de auth si se solicitó
                      if (crearCuenta && vendedora == null) {
                        authUid = await AuthCreacionService.crearCuentaAuth(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          nombreCompleto: '${nombreController.text} ${apellidosController.text}'.trim(),
                          tipoUsuario: 'vendedora_nice',
                          // Rol específico para vendedoras → ve dashboardVendedoraNice
                        );
                        
                        if (authUid == null) {
                          setModalState(() => guardando = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error al crear cuenta. El email puede estar en uso.'), backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }
                      }

                      final data = {
                        'nombre': nombreController.text,
                        'apellidos': apellidosController.text.isEmpty ? null : apellidosController.text,
                        'email': emailController.text.isEmpty ? null : emailController.text,
                        'telefono': telefonoController.text.isEmpty ? null : telefonoController.text,
                        'whatsapp': whatsappController.text.isEmpty ? null : whatsappController.text,
                        'nivel_id': nivelSeleccionado,
                        'patrocinadora_id': patrocinadoraSeleccionada,
                        'negocio_id': widget.negocioId,
                        if (crearCuenta && authUid != null) 'auth_uid': authUid,
                      };

                      bool success;
                      if (vendedora == null) {
                        final nueva = NiceVendedora(
                          id: '',
                          codigoVendedora: '',
                          nombre: data['nombre'] ?? '',
                          apellidos: data['apellidos'],
                          email: data['email'],
                          telefono: data['telefono'],
                          whatsapp: data['whatsapp'],
                          nivelId: data['nivel_id'],
                          patrocinadoraId: data['patrocinadora_id'],
                          negocioId: widget.negocioId,
                          authUid: authUid,
                        );
                        success = (await NiceService.crearVendedora(nueva)) != null;
                      } else {
                        success = await NiceService.actualizarVendedora(vendedora.id, data);
                      }

                      if (success && mounted) {
                        Navigator.pop(context);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(vendedora == null ? 'Vendedora creada' : 'Vendedora actualizada'),
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
                    child: Text(vendedora == null ? 'Crear Vendedora' : 'Guardar Cambios'),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
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

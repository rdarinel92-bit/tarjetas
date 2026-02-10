// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/colaboradores_models.dart';
import 'colaborador_permisos_screen.dart';
import 'colaborador_actividad_screen.dart';
import 'colaborador_inversiones_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE COLABORADORES
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradoresScreen extends StatefulWidget {
  const ColaboradoresScreen({super.key});
  @override
  State<ColaboradoresScreen> createState() => _ColaboradoresScreenState();
}

class _ColaboradoresScreenState extends State<ColaboradoresScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _negocioId;
  
  List<ColaboradorModel> _colaboradores = [];
  List<ColaboradorTipoModel> _tipos = [];
  List<ColaboradorInvitacionModel> _invitaciones = [];
  
  // Stats
  int _totalActivos = 0;
  int _totalInversionistas = 0;
  double _totalInvertido = 0;

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
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final perfil = await AppSupabase.client
          .from('usuarios')
          .select('negocio_id')
          .eq('auth_uid', user.id)
          .single();

      _negocioId = perfil['negocio_id'];

      // Cargar tipos
      final tiposRes = await AppSupabase.client
          .from('colaborador_tipos')
          .select()
          .eq('activo', true)
          .order('nivel_acceso', ascending: false);

      _tipos = (tiposRes as List).map((t) => ColaboradorTipoModel.fromMap(t)).toList();

      // Cargar colaboradores
      final colabRes = await AppSupabase.client
          .from('v_colaboradores_completos')
          .select()
          .eq('negocio_id', _negocioId!)
          .order('created_at', ascending: false);

      _colaboradores = (colabRes as List).map((c) => ColaboradorModel.fromMap(c)).toList();

      // Cargar invitaciones pendientes
      final invRes = await AppSupabase.client
          .from('colaborador_invitaciones')
          .select()
          .eq('negocio_id', _negocioId!)
          .eq('estado', 'pendiente')
          .order('fecha_envio', ascending: false);

      _invitaciones = (invRes as List).map((i) => ColaboradorInvitacionModel.fromMap(i)).toList();

      // Calcular stats
      _totalActivos = _colaboradores.where((c) => c.estado == 'activo').length;
      _totalInversionistas = _colaboradores.where((c) => c.esInversionista).length;
      _totalInvertido = _colaboradores
          .where((c) => c.esInversionista)
          .fold(0, (sum, c) => sum + c.montoInvertido);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error al cargar colaboradores: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '👥 Colaboradores',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.white),
          onPressed: () => _mostrarNuevoColaborador(),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStats(),
                _buildTabs(),
                Expanded(child: _buildTabContent()),
              ],
            ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Activos', _totalActivos.toString(), Icons.people, const Color(0xFF10B981)),
          const SizedBox(width: 12),
          _buildStatCard('Inversionistas', _totalInversionistas.toString(), Icons.trending_up, const Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Capital', _currencyFormat.format(_totalInvertido), Icons.account_balance_wallet, const Color(0xFF8B5CF6)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: [
          Tab(text: 'Todos (${_colaboradores.length})'),
          Tab(text: 'Inversionistas ($_totalInversionistas)'),
          Tab(text: 'Pendientes (${_invitaciones.length})'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListaColaboradores(_colaboradores),
        _buildListaColaboradores(_colaboradores.where((c) => c.esInversionista).toList()),
        _buildListaInvitaciones(),
      ],
    );
  }

  Widget _buildListaColaboradores(List<ColaboradorModel> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin colaboradores',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _mostrarNuevoColaborador(),
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar Colaborador'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final colab = lista[index];
          return _buildColaboradorCard(colab);
        },
      ),
    );
  }

  Widget _buildColaboradorCard(ColaboradorModel colab) {
    final tipo = _tipos.firstWhere(
      (t) => t.codigo == colab.tipoCodigo,
      orElse: () => ColaboradorTipoModel(id: '', codigo: '', nombre: 'Colaborador'),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: colab.tipoCodigo == 'co_superadmin'
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 1)
            : null,
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleColaborador(colab),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tipo.color.withOpacity(0.8), tipo.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    colab.iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
                            colab.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colab.estadoColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            colab.estadoTexto,
                            style: TextStyle(color: colab.estadoColor, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(tipo.icono, size: 14, color: tipo.color),
                        const SizedBox(width: 4),
                        Text(
                          colab.tipoNombre ?? tipo.nombre,
                          style: TextStyle(color: tipo.color, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      colab.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    if (colab.esInversionista) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              _currencyFormat.format(colab.montoInvertido),
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (colab.porcentajeParticipacion > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${colab.porcentajeParticipacion}%',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Cuenta activa indicator
              if (colab.tieneCuenta)
                const Icon(Icons.verified, color: Color(0xFF10B981), size: 20)
              else
                Icon(Icons.mail_outline, color: Colors.white.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaInvitaciones() {
    if (_invitaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin invitaciones pendientes',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invitaciones.length,
      itemBuilder: (context, index) {
        final inv = _invitaciones[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mail, color: Color(0xFFFBBF24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.nombre ?? inv.email,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      inv.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Text(
                      'Enviada: ${DateFormat('dd/MM/yyyy').format(inv.fechaEnvio)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: () => _reenviarInvitacion(inv),
                tooltip: 'Reenviar',
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarNuevoColaborador() {
    // Validar que tengamos datos necesarios
    if (_negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo obtener el negocio activo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_tipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No hay tipos de colaborador disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NuevoColaboradorSheet(
        negocioId: _negocioId!,
        tipos: _tipos,
        onCreado: () {
          Navigator.pop(context);
          _cargarDatos();
        },
      ),
    );
  }

  void _mostrarDetalleColaborador(ColaboradorModel colab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetalleColaboradorSheet(
        colaborador: colab,
        tipos: _tipos,
        onActualizado: () {
          Navigator.pop(context);
          _cargarDatos();
        },
      ),
    );
  }

  Future<void> _reenviarInvitacion(ColaboradorInvitacionModel inv) async {
    // TODO: Implementar reenvío de invitación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invitación reenviada'), backgroundColor: Colors.green),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: NUEVO COLABORADOR
// ═══════════════════════════════════════════════════════════════════════════════

class _NuevoColaboradorSheet extends StatefulWidget {
  final String negocioId;
  final List<ColaboradorTipoModel> tipos;
  final VoidCallback onCreado;

  const _NuevoColaboradorSheet({
    required this.negocioId,
    required this.tipos,
    required this.onCreado,
  });

  @override
  State<_NuevoColaboradorSheet> createState() => _NuevoColaboradorSheetState();
}

class _NuevoColaboradorSheetState extends State<_NuevoColaboradorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _montoController = TextEditingController(text: '0');
  final _porcentajeController = TextEditingController(text: '0');
  
  ColaboradorTipoModel? _tipoSeleccionado;
  bool _esInversionista = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _montoController.dispose();
    _porcentajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  const Text(
                    'Nuevo Colaborador',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de colaborador
                    const Text('Tipo de Colaborador', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.tipos.map((tipo) => ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tipo.icono, size: 16, color: _tipoSeleccionado?.id == tipo.id ? Colors.white : tipo.color),
                            const SizedBox(width: 6),
                            Text(tipo.nombre),
                          ],
                        ),
                        selected: _tipoSeleccionado?.id == tipo.id,
                        selectedColor: tipo.color,
                        backgroundColor: const Color(0xFF1A1A2E),
                        labelStyle: TextStyle(
                          color: _tipoSeleccionado?.id == tipo.id ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setState(() => _tipoSeleccionado = selected ? tipo : null);
                        },
                      )).toList(),
                    ),
                    
                    if (_tipoSeleccionado != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _tipoSeleccionado!.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tipoSeleccionado!.descripcion ?? '',
                          style: TextStyle(color: _tipoSeleccionado!.color, fontSize: 12),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Datos básicos
                    TextFormField(
                      controller: _nombreController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Nombre completo *'),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email *'),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Requerido';
                        if (!v!.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _telefonoController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Teléfono (opcional)'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // ¿Es inversionista?
                    SwitchListTile(
                      title: const Text('Es Inversionista', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        'Registrar capital invertido y porcentaje',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      value: _esInversionista,
                      onChanged: (v) => setState(() => _esInversionista = v),
                      activeColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    if (_esInversionista) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _montoController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Monto invertido'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _porcentajeController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('% Participación'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Botón guardar
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || _tipoSeleccionado == null ? null : _guardarColaborador,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar y Enviar Invitación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _guardarColaborador() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSeleccionado == null) return;

    setState(() => _isSaving = true);

    try {
      final user = AppSupabase.client.auth.currentUser;
      
      // Crear colaborador directamente en la tabla
      final colRes = await AppSupabase.client
          .from('colaboradores')
          .insert({
            'negocio_id': widget.negocioId,
            'tipo_id': _tipoSeleccionado!.id,
            'nombre': _nombreController.text,
            'email': _emailController.text.toLowerCase(),
            'telefono': _telefonoController.text.isEmpty ? null : _telefonoController.text,
            'es_inversionista': _esInversionista,
            'monto_invertido': double.tryParse(_montoController.text) ?? 0,
            'porcentaje_participacion': double.tryParse(_porcentajeController.text) ?? 0,
            'estado': 'activo',
            'fecha_inicio': DateTime.now().toIso8601String().split('T')[0],
          })
          .select()
          .single();

      // Crear invitación (opcional, para cuando el colaborador tenga cuenta)
      await AppSupabase.client.from('colaborador_invitaciones').insert({
        'negocio_id': widget.negocioId,
        'tipo_id': _tipoSeleccionado!.id,
        'email': _emailController.text.toLowerCase(),
        'nombre': _nombreController.text,
        'invitado_por': user?.id,
        'colaborador_creado_id': colRes['id'],
      });

      // Si es inversionista y tiene monto, registrar aportación inicial
      if (_esInversionista && (double.tryParse(_montoController.text) ?? 0) > 0) {
        await AppSupabase.client.from('colaborador_inversiones').insert({
          'negocio_id': widget.negocioId,
          'colaborador_id': colRes['id'],
          'tipo': 'aportacion',
          'monto': double.parse(_montoController.text),
          'descripcion': 'Aportación inicial',
          'aprobado_por': user?.id,
        });
      }

      widget.onCreado();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Colaborador agregado. Se enviará invitación por email.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET: DETALLE COLABORADOR
// ═══════════════════════════════════════════════════════════════════════════════

class _DetalleColaboradorSheet extends StatelessWidget {
  final ColaboradorModel colaborador;
  final List<ColaboradorTipoModel> tipos;
  final VoidCallback onActualizado;

  const _DetalleColaboradorSheet({
    required this.colaborador,
    required this.tipos,
    required this.onActualizado,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = tipos.firstWhere(
      (t) => t.codigo == colaborador.tipoCodigo,
      orElse: () => ColaboradorTipoModel(id: '', codigo: '', nombre: 'Colaborador'),
    );
    
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar grande
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tipo.color.withOpacity(0.8), tipo.color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        colaborador.iniciales,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    colaborador.nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: tipo.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tipo.icono, size: 14, color: tipo.color),
                        const SizedBox(width: 4),
                        Text(tipo.nombre, style: TextStyle(color: tipo.color, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Info cards
                  _buildInfoCard(Icons.email, 'Email', colaborador.email),
                  if (colaborador.telefono != null)
                    _buildInfoCard(Icons.phone, 'Teléfono', colaborador.telefono!),
                  _buildInfoCard(
                    colaborador.tieneCuenta ? Icons.verified : Icons.pending,
                    'Estado de cuenta',
                    colaborador.tieneCuenta ? 'Cuenta activa' : 'Pendiente de activar',
                  ),
                  
                  if (colaborador.esInversionista) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.2),
                            const Color(0xFF10B981).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_up, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text('Inversión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capital:', style: TextStyle(color: Colors.white70)),
                              Text(
                                currencyFormat.format(colaborador.montoInvertido),
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (colaborador.porcentajeParticipacion > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Participación:', style: TextStyle(color: Colors.white70)),
                                Text(
                                  '${colaborador.porcentajeParticipacion}%',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                          if (colaborador.rendimientoPactado != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Rendimiento pactado:', style: TextStyle(color: Colors.white70)),
                                Text(
                                  '${colaborador.rendimientoPactado}% anual',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Acciones rápidas
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Acciones',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildAccionBtn(
                          context,
                          'Permisos',
                          Icons.security,
                          const Color(0xFF3B82F6),
                          () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ColaboradorPermisosScreen(colaboradorId: colaborador.id),
                              ),
                            ).then((_) => onActualizado());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAccionBtn(
                          context,
                          'Actividad',
                          Icons.history,
                          const Color(0xFF8B5CF6),
                          () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ColaboradorActividadScreen(colaboradorId: colaborador.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  if (colaborador.esInversionista) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildAccionBtn(
                        context,
                        'Gestionar Inversiones',
                        Icons.trending_up,
                        const Color(0xFF10B981),
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ColaboradorInversionesScreen(colaboradorId: colaborador.id),
                            ),
                          ).then((_) => onActualizado());
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Acciones de estado
                  Row(
                    children: [
                      if (colaborador.estado != 'suspendido')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await AppSupabase.client
                                  .from('colaboradores')
                                  .update({'estado': 'suspendido'})
                                  .eq('id', colaborador.id);
                              onActualizado();
                            },
                            icon: const Icon(Icons.block, color: Colors.red),
                            label: const Text('Suspender', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await AppSupabase.client
                                  .from('colaboradores')
                                  .update({'estado': 'activo'})
                                  .eq('id', colaborador.id);
                              onActualizado();
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Reactivar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
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
        ],
      ),
    );
  }

  Widget _buildAccionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

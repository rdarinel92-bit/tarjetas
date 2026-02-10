// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// Pantalla para editar tandas existentes
class EditarTandaScreen extends StatefulWidget {
  final String tandaId;
  
  const EditarTandaScreen({super.key, required this.tandaId});

  @override
  State<EditarTandaScreen> createState() => _EditarTandaScreenState();
}

class _EditarTandaScreenState extends State<EditarTandaScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _tanda;
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
  
  // Controllers
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _notasController = TextEditingController();
  
  // Campos editables
  String _estado = 'activa';
  String? _sucursalId;
  int? _diaAportacion;
  bool _recordatoriosActivos = true;
  
  // Catálogos
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _participantes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar tanda
      final tandaRes = await AppSupabase.client
          .from('tandas')
          .select()
          .eq('id', widget.tandaId)
          .single();
      
      // Cargar participantes
      final participantesRes = await AppSupabase.client
          .from('tanda_participantes')
          .select('*, clientes(nombre_completo)')
          .eq('tanda_id', widget.tandaId)
          .order('numero_turno');
      
      // Cargar sucursales
      final sucursalesRes = await AppSupabase.client
          .from('sucursales')
          .select('id, nombre')
          .eq('activa', true)
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _tanda = tandaRes;
          _participantes = List<Map<String, dynamic>>.from(participantesRes);
          _sucursales = List<Map<String, dynamic>>.from(sucursalesRes);
          
          // Inicializar valores
          _nombreController.text = tandaRes['nombre'] ?? '';
          _descripcionController.text = tandaRes['descripcion'] ?? '';
          _notasController.text = tandaRes['notas'] ?? '';
          _estado = tandaRes['estado'] ?? 'activa';
          _sucursalId = tandaRes['sucursal_id'];
          _diaAportacion = tandaRes['dia_aportacion'];
          _recordatoriosActivos = tandaRes['recordatorios_activos'] ?? true;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando tanda: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      await AppSupabase.client
          .from('tandas')
          .update({
            'nombre': _nombreController.text.trim(),
            'descripcion': _descripcionController.text.trim(),
            'notas': _notasController.text.trim(),
            'estado': _estado,
            'sucursal_id': _sucursalId,
            'dia_aportacion': _diaAportacion,
            'recordatorios_activos': _recordatoriosActivos,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.tandaId);
      
      // Registrar en auditoría
      final user = AppSupabase.client.auth.currentUser;
      await AppSupabase.client.from('auditoria').insert({
        'tabla': 'tandas',
        'registro_id': widget.tandaId,
        'accion': 'UPDATE',
        'usuario_id': user?.id,
        'datos_nuevos': {
          'nombre': _nombreController.text.trim(),
          'estado': _estado,
        },
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tanda actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error guardando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PremiumScaffold(
        title: 'Editar Tanda',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_tanda == null) {
      return const PremiumScaffold(
        title: 'Editar Tanda',
        body: Center(
          child: Text('Tanda no encontrada', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return PremiumScaffold(
      title: 'Editar Tanda',
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            onPressed: _guardarCambios,
            tooltip: 'Guardar Cambios',
          ),
      ],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info de la tanda (solo lectura)
              _buildInfoCard(),
              const SizedBox(height: 20),
              
              // Participantes
              _buildParticipantesCard(),
              const SizedBox(height: 20),
              
              // Campos editables
              _buildSeccionTitulo('Información General'),
              _buildNombreField(),
              const SizedBox(height: 16),
              _buildDescripcionField(),
              
              const SizedBox(height: 24),
              _buildSeccionTitulo('Configuración'),
              _buildEstadoSelector(),
              const SizedBox(height: 16),
              _buildDiaAportacionSelector(),
              const SizedBox(height: 16),
              _buildRecordatoriosSwitch(),
              const SizedBox(height: 16),
              _buildSucursalSelector(),
              
              const SizedBox(height: 24),
              _buildSeccionTitulo('Notas'),
              _buildNotasField(),
              
              const SizedBox(height: 40),
              _buildGuardarButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.amberAccent.withOpacity(0.2),
                child: const Icon(Icons.group_work, color: Colors.amberAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tanda!['nombre'] ?? 'Tanda',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Frecuencia: ${_capitalize(_tanda!['frecuencia'] ?? 'semanal')}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getColorEstado(_estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _capitalize(_estado),
                  style: TextStyle(color: _getColorEstado(_estado), fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem('Monto Aportación', _currencyFormat.format(_tanda!['monto_aportacion'] ?? 0)),
              _buildInfoItem('Monto Total', _currencyFormat.format(_tanda!['monto_total'] ?? 0)),
              _buildInfoItem('Participantes', '${_tanda!['num_participantes'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantesCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Participantes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${_participantes.length} registrados',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          if (_participantes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sin participantes', style: TextStyle(color: Colors.white54)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participantes.length > 5 ? 5 : _participantes.length,
              itemBuilder: (context, index) {
                final p = _participantes[index];
                final cliente = p['clientes'];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: Text(
                      '${p['numero_turno'] ?? index + 1}',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    cliente?['nombre_completo'] ?? 'Participante ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    p['entrego'] == true ? '✅ Recibió' : '⏳ Pendiente',
                    style: TextStyle(
                      color: p['entrego'] == true ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          if (_participantes.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${_participantes.length - 5} más...',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        titulo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNombreField() {
    return TextFormField(
      controller: _nombreController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Nombre de la Tanda'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El nombre es requerido';
        }
        return null;
      },
    );
  }

  Widget _buildDescripcionField() {
    return TextFormField(
      controller: _descripcionController,
      maxLines: 2,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Descripción'),
    );
  }

  Widget _buildEstadoSelector() {
    return DropdownButtonFormField<String>(
      value: _estado,
      decoration: _inputDecoration('Estado de la Tanda'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: const [
        DropdownMenuItem(value: 'activa', child: Text('✅ Activa')),
        DropdownMenuItem(value: 'pausada', child: Text('⏸️ Pausada')),
        DropdownMenuItem(value: 'completada', child: Text('✔️ Completada')),
        DropdownMenuItem(value: 'cancelada', child: Text('❌ Cancelada')),
      ],
      onChanged: (value) => setState(() => _estado = value!),
    );
  }

  Widget _buildDiaAportacionSelector() {
    return DropdownButtonFormField<int?>(
      value: _diaAportacion,
      decoration: _inputDecoration('Día de Aportación'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(value: null, child: Text('Sin preferencia')),
        ...List.generate(28, (i) => i + 1).map((dia) =>
          DropdownMenuItem(value: dia, child: Text('Día $dia'))
        ),
      ],
      onChanged: (value) => setState(() => _diaAportacion = value),
    );
  }

  Widget _buildRecordatoriosSwitch() {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile(
        title: const Text('Recordatorios Activos', style: TextStyle(color: Colors.white)),
        subtitle: const Text(
          'Enviar recordatorios de pago a participantes',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        value: _recordatoriosActivos,
        activeColor: Colors.greenAccent,
        onChanged: (value) => setState(() => _recordatoriosActivos = value),
      ),
    );
  }

  Widget _buildSucursalSelector() {
    return DropdownButtonFormField<String?>(
      value: _sucursalId,
      decoration: _inputDecoration('Sucursal'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(value: null, child: Text('Sin asignar')),
        ..._sucursales.map((s) =>
          DropdownMenuItem(value: s['id'] as String, child: Text(s['nombre'] ?? ''))
        ),
      ],
      onChanged: (value) => setState(() => _sucursalId = value),
    );
  }

  Widget _buildNotasField() {
    return TextFormField(
      controller: _notasController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Notas Internas'),
    );
  }

  Widget _buildGuardarButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _guardarCambios,
        icon: _isSaving 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amberAccent),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'activa': return Colors.greenAccent;
      case 'pausada': return Colors.orangeAccent;
      case 'completada': return Colors.blueAccent;
      case 'cancelada': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

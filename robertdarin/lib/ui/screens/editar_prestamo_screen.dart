// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';

/// Pantalla para editar préstamos existentes
/// Solo permite modificar ciertos campos sin afectar la amortización
class EditarPrestamoScreen extends StatefulWidget {
  final String prestamoId;
  
  const EditarPrestamoScreen({super.key, required this.prestamoId});

  @override
  State<EditarPrestamoScreen> createState() => _EditarPrestamoScreenState();
}

class _EditarPrestamoScreenState extends State<EditarPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _prestamo;
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
  
  // Controllers
  final _notasController = TextEditingController();
  final _referenciaController = TextEditingController();
  
  // Campos editables
  String _estado = 'activo';
  int? _diaCobro;
  bool _domiciliacionActiva = false;
  String? _sucursalId;
  String? _cobradorAsignado;
  
  // Catálogos
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _cobradores = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _notasController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar préstamo
      final prestamoRes = await AppSupabase.client
          .from('prestamos')
          .select('*, clientes(nombre_completo, telefono)')
          .eq('id', widget.prestamoId)
          .single();
      
      // Cargar sucursales
      final sucursalesRes = await AppSupabase.client
          .from('sucursales')
          .select('id, nombre')
          .eq('activa', true)
          .order('nombre');
      
      // Cargar cobradores (empleados con rol cobrador)
      final cobradoresRes = await AppSupabase.client
          .from('empleados')
          .select('id, nombre')
          .eq('estado', 'activo')
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _prestamo = prestamoRes;
          _sucursales = List<Map<String, dynamic>>.from(sucursalesRes);
          _cobradores = List<Map<String, dynamic>>.from(cobradoresRes);
          
          // Inicializar valores
          _estado = prestamoRes['estado'] ?? 'activo';
          _diaCobro = prestamoRes['dia_cobro_preferido'];
          _domiciliacionActiva = prestamoRes['domiciliacion_activa'] ?? false;
          _sucursalId = prestamoRes['sucursal_id'];
          _cobradorAsignado = prestamoRes['cobrador_asignado'];
          _notasController.text = prestamoRes['notas'] ?? '';
          _referenciaController.text = prestamoRes['referencia_interna'] ?? '';
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando préstamo: $e');
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
          .from('prestamos')
          .update({
            'estado': _estado,
            'dia_cobro_preferido': _diaCobro,
            'domiciliacion_activa': _domiciliacionActiva,
            'sucursal_id': _sucursalId,
            'cobrador_asignado': _cobradorAsignado,
            'notas': _notasController.text.trim(),
            'referencia_interna': _referenciaController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.prestamoId);
      
      // Registrar en auditoría
      final user = AppSupabase.client.auth.currentUser;
      await AppSupabase.client.from('auditoria').insert({
        'tabla': 'prestamos',
        'registro_id': widget.prestamoId,
        'accion': 'UPDATE',
        'usuario_id': user?.id,
        'datos_nuevos': {
          'estado': _estado,
          'dia_cobro_preferido': _diaCobro,
          'domiciliacion_activa': _domiciliacionActiva,
          'notas': _notasController.text.trim(),
        },
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Préstamo actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retornar true para indicar cambios
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
        title: 'Editar Préstamo',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_prestamo == null) {
      return const PremiumScaffold(
        title: 'Editar Préstamo',
        body: Center(
          child: Text('Préstamo no encontrado', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return PremiumScaffold(
      title: 'Editar Préstamo',
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
              // Info del préstamo (solo lectura)
              _buildInfoCard(),
              const SizedBox(height: 20),
              
              // Campos editables
              _buildSeccionTitulo('Configuración del Préstamo'),
              _buildEstadoSelector(),
              const SizedBox(height: 16),
              _buildDiaCobroSelector(),
              const SizedBox(height: 16),
              _buildDomiciliacionSwitch(),
              
              const SizedBox(height: 24),
              _buildSeccionTitulo('Asignaciones'),
              _buildSucursalSelector(),
              const SizedBox(height: 16),
              _buildCobradorSelector(),
              
              const SizedBox(height: 24),
              _buildSeccionTitulo('Notas y Referencias'),
              _buildNotasField(),
              const SizedBox(height: 16),
              _buildReferenciaField(),
              
              const SizedBox(height: 40),
              _buildGuardarButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final cliente = _prestamo!['clientes'];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                child: const Icon(Icons.person, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente?['nombre_completo'] ?? 'Cliente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      cliente?['telefono'] ?? '',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem('Monto', _currencyFormat.format(_prestamo!['monto'] ?? 0)),
              _buildInfoItem('Plazo', '${_prestamo!['plazo_meses'] ?? 0} meses'),
              _buildInfoItem('Tasa', '${_prestamo!['tasa_interes'] ?? 0}%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem('Saldo', _currencyFormat.format(_prestamo!['saldo_pendiente'] ?? 0)),
              _buildInfoItem('Cuota', _currencyFormat.format(_prestamo!['cuota_mensual'] ?? 0)),
              _buildInfoItem('Frecuencia', _capitalize(_prestamo!['frecuencia_pago'] ?? 'mensual')),
            ],
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

  Widget _buildEstadoSelector() {
    return DropdownButtonFormField<String>(
      value: _estado,
      decoration: _inputDecoration('Estado del Préstamo'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: const [
        DropdownMenuItem(value: 'activo', child: Text('✅ Activo')),
        DropdownMenuItem(value: 'mora', child: Text('⚠️ En Mora')),
        DropdownMenuItem(value: 'liquidado', child: Text('✔️ Liquidado')),
        DropdownMenuItem(value: 'cancelado', child: Text('❌ Cancelado')),
        DropdownMenuItem(value: 'reestructurado', child: Text('🔄 Reestructurado')),
        DropdownMenuItem(value: 'legal', child: Text('⚖️ En Proceso Legal')),
      ],
      onChanged: (value) => setState(() => _estado = value!),
    );
  }

  Widget _buildDiaCobroSelector() {
    return DropdownButtonFormField<int?>(
      value: _diaCobro,
      decoration: _inputDecoration('Día de Cobro Preferido'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(value: null, child: Text('Sin preferencia')),
        ...List.generate(28, (i) => i + 1).map((dia) =>
          DropdownMenuItem(value: dia, child: Text('Día $dia'))
        ),
      ],
      onChanged: (value) => setState(() => _diaCobro = value),
    );
  }

  Widget _buildDomiciliacionSwitch() {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile(
        title: const Text('Domiciliación Activa', style: TextStyle(color: Colors.white)),
        subtitle: const Text(
          'Cobro automático vía Stripe',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        value: _domiciliacionActiva,
        activeColor: Colors.greenAccent,
        onChanged: (value) => setState(() => _domiciliacionActiva = value),
      ),
    );
  }

  Widget _buildSucursalSelector() {
    return DropdownButtonFormField<String?>(
      value: _sucursalId,
      decoration: _inputDecoration('Sucursal Asignada'),
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

  Widget _buildCobradorSelector() {
    return DropdownButtonFormField<String?>(
      value: _cobradorAsignado,
      decoration: _inputDecoration('Cobrador Asignado'),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(value: null, child: Text('Sin asignar')),
        ..._cobradores.map((c) =>
          DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] ?? ''))
        ),
      ],
      onChanged: (value) => setState(() => _cobradorAsignado = value),
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

  Widget _buildReferenciaField() {
    return TextFormField(
      controller: _referenciaController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Referencia Interna'),
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
          backgroundColor: Colors.greenAccent,
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
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

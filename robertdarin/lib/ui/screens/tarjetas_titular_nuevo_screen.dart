// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../services/tarjetas_service.dart';
import '../../data/models/tarjetas_models.dart';

class TarjetasTitularNuevoScreen extends StatefulWidget {
  const TarjetasTitularNuevoScreen({super.key});

  @override
  State<TarjetasTitularNuevoScreen> createState() => _TarjetasTitularNuevoScreenState();
}

class _TarjetasTitularNuevoScreenState extends State<TarjetasTitularNuevoScreen> {
  final _service = TarjetasService();
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apPatCtrl = TextEditingController();
  final _apMatCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();

  bool _isSaving = false;
  String? _negocioId;

  @override
  void initState() {
    super.initState();
    _resolverNegocio();
  }

  Future<void> _resolverNegocio() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        final empleado = await AppSupabase.client
            .from('empleados')
            .select('negocio_id')
            .eq('usuario_id', user.id)
            .maybeSingle();
        _negocioId = empleado?['negocio_id'];
      }
      if (_negocioId == null) {
        final negocio = await AppSupabase.client.from('negocios').select('id').limit(1).maybeSingle();
        _negocioId = negocio?['id'];
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPatCtrl.dispose();
    _apMatCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _rfcCtrl.dispose();
    _curpCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo determinar el negocio')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final titular = TarjetaTitularModel(
      id: '',
      negocioId: _negocioId!,
      nombre: _nombreCtrl.text.trim(),
      apellidoPaterno: _apPatCtrl.text.trim().isEmpty ? null : _apPatCtrl.text.trim(),
      apellidoMaterno: _apMatCtrl.text.trim().isEmpty ? null : _apMatCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      rfc: _rfcCtrl.text.trim().isEmpty ? null : _rfcCtrl.text.trim(),
      curp: _curpCtrl.text.trim().isEmpty ? null : _curpCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final res = await _service.crearTitular(titular);
    setState(() => _isSaving = false);

    if (res != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Titular creado'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el titular'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Nuevo Titular',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(_nombreCtrl, 'Nombre', required: true),
              const SizedBox(height: 12),
              _buildField(_apPatCtrl, 'Apellido Paterno'),
              const SizedBox(height: 12),
              _buildField(_apMatCtrl, 'Apellido Materno'),
              const SizedBox(height: 12),
              _buildField(_emailCtrl, 'Email', required: true, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField(_telefonoCtrl, 'Telefono', required: true, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField(_rfcCtrl, 'RFC'),
              const SizedBox(height: 12),
              _buildField(_curpCtrl, 'CURP'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(_isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
      ),
    );
  }
}

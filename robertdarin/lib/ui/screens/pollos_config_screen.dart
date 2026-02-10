// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../data/models/pollos_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PANTALLA DE CONFIGURACIÓN - POLLOS ASADOS
/// Configuración del negocio
/// ═══════════════════════════════════════════════════════════════════════════════
class PollosConfigScreen extends StatefulWidget {
  const PollosConfigScreen({super.key});

  @override
  State<PollosConfigScreen> createState() => _PollosConfigScreenState();
}

class _PollosConfigScreenState extends State<PollosConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  PollosConfigModel? _config;
  
  // Controladores
  final _nombreController = TextEditingController();
  final _sloganController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _horarioController = TextEditingController();
  final _costoDeliveryController = TextEditingController();
  final _tiempoPromedioController = TextEditingController();
  
  bool _abierto = true;
  bool _aceptaDelivery = true;

  @override
  void initState() {
    super.initState();
    _cargarConfig();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _sloganController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _horarioController.dispose();
    _costoDeliveryController.dispose();
    _tiempoPromedioController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('pollos_config')
          .select()
          .maybeSingle();

      if (res != null) {
        _config = PollosConfigModel.fromMap(res);
        _nombreController.text = _config!.nombreNegocio;
        _sloganController.text = _config!.slogan ?? '';
        _telefonoController.text = _config!.telefono ?? '';
        _direccionController.text = _config!.direccion ?? '';
        // Construir horario desde apertura/cierre
        final apertura = _config!.horarioApertura ?? '';
        final cierre = _config!.horarioCierre ?? '';
        _horarioController.text = apertura.isNotEmpty ? '$apertura - $cierre' : '';
        _costoDeliveryController.text = _config!.costoDelivery.toStringAsFixed(0);
        _tiempoPromedioController.text = _config!.tiempoPreparacionMin.toString();
        _abierto = _config!.activo;
        _aceptaDelivery = _config!.tieneDelivery;
      } else {
        // Crear configuración por defecto
        _nombreController.text = 'Pollos Asados';
        _sloganController.text = 'Los mejores pollos de la ciudad';
        _costoDeliveryController.text = '30';
        _tiempoPromedioController.text = '25';
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarConfig() async {
    if (_nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del negocio es obligatorio'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'nombre_negocio': _nombreController.text.trim(),
        'slogan': _sloganController.text.trim().isEmpty ? null : _sloganController.text.trim(),
        'telefono': _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim().isEmpty ? null : _direccionController.text.trim(),
        'horario_texto': _horarioController.text.trim().isEmpty ? null : _horarioController.text.trim(),
        'costo_delivery': double.tryParse(_costoDeliveryController.text) ?? 30,
        'tiempo_promedio_minutos': int.tryParse(_tiempoPromedioController.text) ?? 25,
        'abierto': _abierto,
        'acepta_delivery': _aceptaDelivery,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_config != null) {
        // Actualizar
        await AppSupabase.client
            .from('pollos_config')
            .update(data)
            .eq('id', _config!.id);
      } else {
        // Crear nuevo
        await AppSupabase.client
            .from('pollos_config')
            .insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _cargarConfig();
      }
    } catch (e) {
      debugPrint('Error guardando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: '⚙️ Configuración',
      subtitle: 'Pollos Asados',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del negocio
                  _buildSeccion(
                    titulo: '🏪 Estado del Negocio',
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: _abierto ? Icons.lock_open : Icons.lock,
                          iconColor: _abierto ? const Color(0xFF10B981) : Colors.red,
                          titulo: _abierto ? 'Negocio ABIERTO' : 'Negocio CERRADO',
                          subtitulo: _abierto 
                              ? 'Los clientes pueden hacer pedidos'
                              : 'Los clientes verán que estás cerrado',
                          valor: _abierto,
                          onChanged: (v) => setState(() => _abierto = v),
                        ),
                        const Divider(color: Colors.white12),
                        _buildSwitchTile(
                          icon: Icons.delivery_dining,
                          iconColor: _aceptaDelivery ? const Color(0xFFFF6B00) : Colors.grey,
                          titulo: 'Servicio a Domicilio',
                          subtitulo: _aceptaDelivery 
                              ? 'Se muestra opción de delivery'
                              : 'Solo recoger en local',
                          valor: _aceptaDelivery,
                          onChanged: (v) => setState(() => _aceptaDelivery = v),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Información del negocio
                  _buildSeccion(
                    titulo: '📋 Información del Negocio',
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nombreController,
                          label: 'Nombre del Negocio *',
                          icon: Icons.store,
                          hint: 'Ej: Pollos Don Pepe',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _sloganController,
                          label: 'Slogan (opcional)',
                          icon: Icons.format_quote,
                          hint: 'Ej: Los mejores pollos de la ciudad',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _telefonoController,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          hint: 'Ej: 555-123-4567',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _direccionController,
                          label: 'Dirección',
                          icon: Icons.location_on,
                          hint: 'Ej: Av. Principal #123, Col. Centro',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _horarioController,
                          label: 'Horario',
                          icon: Icons.schedule,
                          hint: 'Ej: Lun-Dom 10:00am - 9:00pm',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Configuración de servicio
                  _buildSeccion(
                    titulo: '🚗 Servicio y Entrega',
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _costoDeliveryController,
                          label: 'Costo de Envío (\$)',
                          icon: Icons.attach_money,
                          hint: '30',
                          keyboardType: TextInputType.number,
                          prefixText: '\$ ',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _tiempoPromedioController,
                          label: 'Tiempo de Preparación (min)',
                          icon: Icons.timer,
                          hint: '25',
                          keyboardType: TextInputType.number,
                          suffixText: ' min',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _guardarConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar Configuración',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Info de la página web
                  _buildSeccion(
                    titulo: '🌐 Página Web de Pedidos',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.public, color: Color(0xFF3B82F6), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tu página está activa:',
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                'https://rdarinel92-bit.github.io/tarjetas/pollos/',
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '💡 Comparte este link con tus clientes para que puedan hacer pedidos desde su celular.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildSeccion({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitulo,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: valor,
          onChanged: onChanged,
          activeColor: const Color(0xFFFF6B00),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 2),
        ),
      ),
    );
  }
}

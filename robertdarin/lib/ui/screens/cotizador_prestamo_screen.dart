import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';
import '../../ui/navigation/app_routes.dart';

class CotizadorPrestamoScreen extends StatefulWidget {
  const CotizadorPrestamoScreen({super.key});

  @override
  State<CotizadorPrestamoScreen> createState() => _CotizadorPrestamoScreenState();
}

class _CotizadorPrestamoScreenState extends State<CotizadorPrestamoScreen> {
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  final List<String> _frecuencias = ['Diario', 'Semanal', 'Quincenal', 'Mensual'];
  // Plazos en meses (el usuario elige plazo, no número de cuotas directamente)
  final List<int> _opcionesPlazos = [1, 2, 3, 6, 12, 18, 24, 36];

  // Controlador para monto editable
  final TextEditingController _montoController = TextEditingController(text: '10000');
  double _montoSeleccionado = 10000;
  int _plazoMeses = 12; // Plazo fijo en meses
  String _frecuenciaSeleccionada = 'Mensual';
  double _tasaInteresMensual = 10;

  // Paso actual del wizard (1 = monto, 2 = configuracion)
  int _pasoActual = 1;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _calcularResultados();

    return PremiumScaffold(
      title: 'Cotizador',
      actions: [
        IconButton(
          tooltip: 'Compartir',
          icon: const Icon(Icons.share, color: Color(0xFF00D9FF)),
          onPressed: () => _compartirCotizacion(resultados),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card principal estilo BanCoppel
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicador de pasos
                  _buildIndicadorPasos(),
                  const SizedBox(height: 24),

                  // Contenido segun el paso
                  if (_pasoActual == 1) _buildPaso1Monto(),
                  if (_pasoActual == 2) _buildPaso2Configuracion(),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 20),

                  // Detalle del prestamo
                  _buildDetallesPrestamo(resultados),

                  const SizedBox(height: 20),

                  // Botones de accion
                  _buildBotonesAccion(resultados),

                  const SizedBox(height: 16),

                  // Disclaimer
                  Text(
                    'La informacion mostrada es unicamente para efectos informativos e ilustrativos.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadorPasos() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCirculoPaso(1, _pasoActual >= 1),
        Container(
          width: 40,
          height: 2,
          color: _pasoActual >= 2 ? const Color(0xFF00D9FF) : Colors.grey[300],
        ),
        _buildCirculoPaso(2, _pasoActual >= 2),
      ],
    );
  }

  Widget _buildCirculoPaso(int numero, bool activo) {
    return GestureDetector(
      onTap: () => setState(() => _pasoActual = numero),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo ? const Color(0xFF00D9FF) : Colors.grey[300],
        ),
        child: Center(
          child: Text(
            '$numero',
            style: TextStyle(
              color: activo ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaso1Monto() {
    return Column(
      children: [
        const Text(
          'Personaliza tu prestamo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cuanto dinero necesitas?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),

        // Campo de monto editable
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00D9FF).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '\$ ',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              IntrinsicWidth(
                child: TextField(
                  controller: _montoController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D9FF),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: (valor) {
                    final numero = double.tryParse(valor) ?? 1000;
                    setState(() {
                      _montoSeleccionado = numero.clamp(1000, 500000);
                    });
                  },
                  onTap: () => _montoController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _montoController.text.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF00D9FF),
            inactiveTrackColor: const Color(0xFFE0E0E0),
            thumbColor: const Color(0xFF00D9FF),
            overlayColor: const Color(0xFF00D9FF).withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: _montoSeleccionado.clamp(1000, 500000),
            min: 1000,
            max: 500000,
            divisions: 499,
            onChanged: (valor) {
              HapticFeedback.selectionClick();
              setState(() {
                _montoSeleccionado = valor;
                _montoController.text = valor.toInt().toString();
              });
            },
          ),
        ),

        // Etiquetas min/max
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$1,000', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text('\$500,000', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Boton siguiente
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => _pasoActual = 2),
            child: const Text('Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaso2Configuracion() {
    final numeroCuotas = _calcularNumeroCuotas();
    
    return Column(
      children: [
        const Text(
          'Configura tu prestamo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 20),

        // Selector de PLAZO (en meses)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Plazo del prestamo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _opcionesPlazos.map((plazo) {
            final seleccionado = _plazoMeses == plazo;
            final textoPlaza = plazo == 1 ? '1 mes' : '$plazo meses';
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _plazoMeses = plazo);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: seleccionado ? const Color(0xFF00D9FF) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: seleccionado ? const Color(0xFF00D9FF) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  textoPlaza,
                  style: TextStyle(
                    color: seleccionado ? Colors.white : Colors.grey[700],
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Selector de frecuencia
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Frecuencia de pago', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _frecuenciaSeleccionada,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _frecuencias.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (valor) {
                if (valor != null) setState(() => _frecuenciaSeleccionada = valor);
              },
            ),
          ),
        ),
        
        // Info de cuotas resultantes
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Seran $numeroCuotas pagos ${_labelFrecuenciaPlural(_frecuenciaSeleccionada)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),

        const SizedBox(height: 12),

        // Selector de tasa
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Tasa de interes mensual', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF8B5CF6),
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                  thumbColor: const Color(0xFF8B5CF6),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _tasaInteresMensual,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (valor) => setState(() => _tasaInteresMensual = valor),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_tasaInteresMensual.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Boton regresar
        TextButton.icon(
          onPressed: () => setState(() => _pasoActual = 1),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Cambiar monto'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDetallesPrestamo(_ResultadosCotizacion resultados) {
    final numeroCuotas = _calcularNumeroCuotas();
    final textoFrecuencia = _frecuenciaSeleccionada == 'Diario' ? 'diario' : _frecuenciaSeleccionada.toLowerCase();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalle de tu Prestamo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),

        _buildFilaDetalle('Plazo', '$_plazoMeses ${_plazoMeses == 1 ? 'mes' : 'meses'}'),
        _buildFilaDetalle('Numero de pagos', '$numeroCuotas cuotas'),
        _buildFilaDetalle('Frecuencia', _frecuenciaSeleccionada),
        _buildFilaDetalle('Tasa de interes', '${_tasaInteresMensual.toStringAsFixed(1)}% mensual'),
        _buildFilaDetalle(
          'Pago $textoFrecuencia',
          _currencyFormatter.format(resultados.cuota),
          destacado: true,
        ),
        _buildFilaDetalle(
          'Monto total a pagar',
          _currencyFormatter.format(resultados.totalAPagar),
        ),
        _buildFilaDetalle(
          'Interes total',
          _currencyFormatter.format(resultados.interesTotal),
        ),
      ],
    );
  }

  /// Calcula cuántas cuotas corresponden según el plazo y la frecuencia
  int _calcularNumeroCuotas() {
    switch (_frecuenciaSeleccionada) {
      case 'Diario':
        return _plazoMeses * 30; // 30 días por mes
      case 'Semanal':
        return _plazoMeses * 4; // 4 semanas por mes (aprox)
      case 'Quincenal':
        return _plazoMeses * 2; // 2 quincenas por mes
      default: // Mensual
        return _plazoMeses;
    }
  }

  String _calcularDuracionTexto() {
    if (_plazoMeses == 1) {
      return '1 mes';
    }
    return '$_plazoMeses meses';
  }

  Widget _buildFilaDetalle(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: destacado ? const Color(0xFF10B981) : const Color(0xFF1A1A2E),
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              fontSize: destacado ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion(_ResultadosCotizacion resultados) {
    return Column(
      children: [
        // Boton principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // Guardar cotización en auditoría antes de ir al formulario
              _guardarCotizacionEnHistorial(resultados);
              
              Navigator.pushNamed(
                context,
                AppRoutes.formularioPrestamo,
                arguments: {
                  'monto': _montoSeleccionado,
                  'plazoMeses': _plazoMeses,
                  'numeroCuotas': _calcularNumeroCuotas(),
                  'interes': _tasaInteresMensual,
                  'frecuencia': _frecuenciaSeleccionada,
                  'esInteresCompuesto': false,
                },
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Crear Prestamo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),

        // Boton secundario compartir
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00D9FF),
              side: const BorderSide(color: Color(0xFF00D9FF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _compartirCotizacion(resultados),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir cotizacion'),
          ),
        ),
      ],
    );
  }

  _ResultadosCotizacion _calcularResultados() {
    final monto = _montoSeleccionado;
    final plazoMeses = _plazoMeses;
    final numeroCuotas = _calcularNumeroCuotas();

    // ═══════════════════════════════════════════════════════════════════════════
    // CÁLCULO CORRECTO DE INTERÉS SIMPLE
    // ═══════════════════════════════════════════════════════════════════════════
    // 
    // Fórmula de interés simple: I = C × r × t
    // Donde:
    //   C = Capital (monto)
    //   r = Tasa de interés mensual (en decimal)
    //   t = Tiempo en meses (PLAZO FIJO, NO depende de frecuencia)
    //
    // El PLAZO define el interés total
    // La FRECUENCIA solo divide el total en más o menos cuotas
    // ═══════════════════════════════════════════════════════════════════════════

    final tasaDecimal = _tasaInteresMensual / 100;
    final interesTotal = monto * tasaDecimal * plazoMeses;
    final totalAPagar = monto + interesTotal;
    final cuota = numeroCuotas > 0 ? totalAPagar / numeroCuotas : 0.0;

    return _ResultadosCotizacion(
      capital: monto,
      interesTotal: interesTotal,
      totalAPagar: totalAPagar,
      cuota: cuota,
      numeroCuotas: numeroCuotas,
      plazoMeses: plazoMeses,
    );
  }

  String _labelFrecuenciaPlural(String frecuencia) {
    switch (frecuencia) {
      case 'Diario':
        return 'diarios';
      case 'Semanal':
        return 'semanales';
      case 'Quincenal':
        return 'quincenales';
      default:
        return 'mensuales';
    }
  }

  void _compartirCotizacion(_ResultadosCotizacion resultados) {
    final numeroCuotas = _calcularNumeroCuotas();
    final duracion = _calcularDuracionTexto();
    final texto = 'COTIZACION DE PRESTAMO\n'
        '---------------------\n\n'
        'Monto: ${_currencyFormatter.format(_montoSeleccionado)}\n'
        'Plazo: $duracion\n'
        'Cuotas: $numeroCuotas pagos ${_labelFrecuenciaPlural(_frecuenciaSeleccionada)}\n'
        'Tasa: ${_tasaInteresMensual.toStringAsFixed(1)}% mensual\n\n'
        'Pago por cuota: ${_currencyFormatter.format(resultados.cuota)}\n'
        'Total intereses: ${_currencyFormatter.format(resultados.interesTotal)}\n'
        'Total a pagar: ${_currencyFormatter.format(resultados.totalAPagar)}\n\n'
        '---------------------\n'
        'Robert Darin Fintech';

    Share.share(texto);
  }

  /// Guarda la cotización en el historial de auditoría para tracking
  Future<void> _guardarCotizacionEnHistorial(_ResultadosCotizacion resultados) async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;
      
      final numeroCuotas = _calcularNumeroCuotas();
      
      await AppSupabase.client.from('auditoria').insert({
        'usuario_id': user.id,
        'accion': 'cotizacion_prestamo',
        'tabla_afectada': 'prestamos',
        'descripcion': 'Cotización: ${_currencyFormatter.format(_montoSeleccionado)} '
            'a $_plazoMeses meses ($numeroCuotas cuotas $_frecuenciaSeleccionada) '
            '(${_tasaInteresMensual.toStringAsFixed(1)}% mensual) = '
            '${_currencyFormatter.format(resultados.totalAPagar)} total',
        'datos_nuevos': {
          'monto': _montoSeleccionado,
          'plazo_meses': _plazoMeses,
          'numero_cuotas': numeroCuotas,
          'frecuencia': _frecuenciaSeleccionada,
          'tasa_interes': _tasaInteresMensual,
          'cuota_calculada': resultados.cuota,
          'interes_total': resultados.interesTotal,
          'total_a_pagar': resultados.totalAPagar,
        },
      });
    } catch (e) {
      debugPrint('Error guardando cotización en historial: $e');
    }
  }
}

class _ResultadosCotizacion {
  final double capital;
  final double interesTotal;
  final double totalAPagar;
  final double cuota;
  final int numeroCuotas;
  final int plazoMeses;

  const _ResultadosCotizacion({
    required this.capital,
    required this.interesTotal,
    required this.totalAPagar,
    required this.cuota,
    required this.numeroCuotas,
    required this.plazoMeses,
  });
}

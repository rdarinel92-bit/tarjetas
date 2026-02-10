// ═══════════════════════════════════════════════════════════════════════════════
// IMPRESIÓN PROFESIONAL QR - V10.54
// Formatos HD para imprentas: stickers, banners, tarjetas
// Exportación en múltiples resoluciones y formatos
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../components/premium_scaffold.dart';

class ImpresionProfesionalQrScreen extends StatefulWidget {
  final String? tarjetaId;
  final String? qrData;
  final String? titulo;
  final Map<String, dynamic>? templateDatos;
  
  const ImpresionProfesionalQrScreen({
    super.key,
    this.tarjetaId,
    this.qrData,
    this.titulo,
    this.templateDatos,
  });

  @override
  State<ImpresionProfesionalQrScreen> createState() => _ImpresionProfesionalQrScreenState();
}

class _ImpresionProfesionalQrScreenState extends State<ImpresionProfesionalQrScreen> {
  String _formatoSeleccionado = 'sticker_cuadrado';
  String _resolucionSeleccionada = 'alta';
  String _colorModo = 'color';
  bool _conMargenCorte = true;
  bool _conGuias = false;
  int _cantidad = 1;
  
  // Formatos disponibles para impresión
  final List<Map<String, dynamic>> _formatos = [
    // STICKERS
    {
      'id': 'sticker_cuadrado',
      'nombre': 'Sticker Cuadrado',
      'categoria': 'stickers',
      'dimensiones': '5x5 cm',
      'pixeles': '591x591 px',
      'descripcion': 'Ideal para productos y paquetes',
      'icono': Icons.crop_square,
      'aspectRatio': 1.0,
    },
    {
      'id': 'sticker_circular',
      'nombre': 'Sticker Circular',
      'categoria': 'stickers',
      'dimensiones': '5 cm diámetro',
      'pixeles': '591x591 px',
      'descripcion': 'Para sellos y etiquetas',
      'icono': Icons.circle_outlined,
      'aspectRatio': 1.0,
      'circular': true,
    },
    {
      'id': 'sticker_rectangular',
      'nombre': 'Sticker Rectangular',
      'categoria': 'stickers',
      'dimensiones': '8x3 cm',
      'pixeles': '945x354 px',
      'descripcion': 'Con espacio para texto',
      'icono': Icons.rectangle_outlined,
      'aspectRatio': 8/3,
    },
    
    // TARJETAS
    {
      'id': 'tarjeta_presentacion',
      'nombre': 'Tarjeta de Presentación',
      'categoria': 'tarjetas',
      'dimensiones': '9x5.5 cm',
      'pixeles': '1063x650 px',
      'descripcion': 'Tamaño estándar de negocios',
      'icono': Icons.credit_card,
      'aspectRatio': 9/5.5,
    },
    {
      'id': 'tarjeta_media',
      'nombre': 'Tarjeta Media Carta',
      'categoria': 'tarjetas',
      'dimensiones': '14x11 cm',
      'pixeles': '1654x1299 px',
      'descripcion': 'Para volantes pequeños',
      'icono': Icons.note,
      'aspectRatio': 14/11,
    },
    
    // BANNERS
    {
      'id': 'banner_mesa',
      'nombre': 'Banner de Mesa',
      'categoria': 'banners',
      'dimensiones': '20x15 cm',
      'pixeles': '2362x1772 px',
      'descripcion': 'Para mostrador o mesa',
      'icono': Icons.table_restaurant,
      'aspectRatio': 20/15,
    },
    {
      'id': 'banner_stand',
      'nombre': 'Roll-Up/Stand',
      'categoria': 'banners',
      'dimensiones': '80x200 cm',
      'pixeles': '2362x5906 px',
      'descripcion': 'Banner de piso grande',
      'icono': Icons.view_day,
      'aspectRatio': 80/200,
    },
    {
      'id': 'banner_pared',
      'nombre': 'Banner de Pared',
      'categoria': 'banners',
      'dimensiones': '100x70 cm',
      'pixeles': '2953x2067 px',
      'descripcion': 'Poster horizontal',
      'icono': Icons.panorama,
      'aspectRatio': 100/70,
    },
    
    // OTROS
    {
      'id': 'poster_a4',
      'nombre': 'Poster A4',
      'categoria': 'posters',
      'dimensiones': '21x29.7 cm',
      'pixeles': '2480x3508 px',
      'descripcion': 'Tamaño carta estándar',
      'icono': Icons.description,
      'aspectRatio': 21/29.7,
    },
    {
      'id': 'poster_a3',
      'nombre': 'Poster A3',
      'categoria': 'posters',
      'dimensiones': '29.7x42 cm',
      'pixeles': '3508x4961 px',
      'descripcion': 'Doble carta',
      'icono': Icons.article,
      'aspectRatio': 29.7/42,
    },
    {
      'id': 'lona_pequena',
      'nombre': 'Lona Pequeña',
      'categoria': 'lonas',
      'dimensiones': '1x0.5 m',
      'pixeles': '3000x1500 px',
      'descripcion': 'Para exterior',
      'icono': Icons.flag,
      'aspectRatio': 2.0,
    },
  ];

  final Map<String, Map<String, dynamic>> _resoluciones = {
    'web': {'nombre': 'Web/Pantalla', 'dpi': 72, 'descripcion': 'Para uso digital'},
    'media': {'nombre': 'Media', 'dpi': 150, 'descripcion': 'Impresión casera'},
    'alta': {'nombre': 'Alta Calidad', 'dpi': 300, 'descripcion': 'Impresión profesional'},
    'ultra': {'nombre': 'Ultra HD', 'dpi': 600, 'descripcion': 'Máxima definición'},
  };

  Map<String, dynamic> get _formatoActual {
    return _formatos.firstWhere(
      (f) => f['id'] == _formatoSeleccionado,
      orElse: () => _formatos[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Impresión Profesional',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white54),
          onPressed: _mostrarAyuda,
          tooltip: 'Ayuda',
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vista previa del formato
            _buildVistaPrevia(),
            
            const SizedBox(height: 24),
            
            // Selector de formato
            _buildSelectorFormato(),
            
            const SizedBox(height: 20),
            
            // Opciones de impresión
            _buildOpcionesImpresion(),
            
            const SizedBox(height: 20),
            
            // Resolución
            _buildSelectorResolucion(),
            
            const SizedBox(height: 20),
            
            // Cantidad
            _buildSelectorCantidad(),
            
            const SizedBox(height: 24),
            
            // Información del archivo
            _buildInfoArchivo(),
            
            const SizedBox(height: 24),
            
            // Botones de acción
            _buildBotonesAccion(),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaPrevia() {
    final formato = _formatoActual;
    final aspectRatio = formato['aspectRatio'] as double;
    final esCircular = formato['circular'] == true;
    final qrData = widget.qrData ?? 'https://robertdarin.app/qr/${widget.tarjetaId ?? 'demo'}';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Título
          Row(
            children: [
              Icon(formato['icono'] as IconData, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                formato['nombre'] as String,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formato['dimensiones'] as String,
                  style: const TextStyle(color: Colors.cyan, fontSize: 12),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Preview del formato
          Center(
            child: Container(
              width: aspectRatio > 1 ? 280 : 200 * aspectRatio,
              height: aspectRatio > 1 ? 280 / aspectRatio : 200,
              decoration: BoxDecoration(
                color: _colorModo == 'color' ? Colors.white : Colors.white,
                borderRadius: esCircular ? null : BorderRadius.circular(8),
                shape: esCircular ? BoxShape.circle : BoxShape.rectangle,
                border: _conMargenCorte
                    ? Border.all(color: Colors.red.withOpacity(0.3), width: 2, style: BorderStyle.solid)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Contenido
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        QrImageView(
                          data: qrData,
                          size: esCircular ? 80 : (aspectRatio > 1.5 ? 60 : 100),
                          backgroundColor: Colors.white,
                          foregroundColor: _colorModo == 'color' ? Colors.black : Colors.black,
                        ),
                        if (!esCircular && aspectRatio < 1.5) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.titulo ?? 'Escanéame',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: aspectRatio > 1 ? 10 : 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Guías de corte
                  if (_conGuias)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GuiasCorte(esCircular),
                      ),
                    ),
                  
                  // Indicador de margen
                  if (_conMargenCorte)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.crop_free, color: Colors.red.withOpacity(0.5), size: 16),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Info
          Text(
            formato['descripcion'] as String,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorFormato() {
    final categorias = ['stickers', 'tarjetas', 'banners', 'posters', 'lonas'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formato de Impresión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          ...categorias.map((categoria) {
            final formatosCategoria = _formatos.where((f) => f['categoria'] == categoria).toList();
            if (formatosCategoria.isEmpty) return const SizedBox.shrink();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    categoria.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: formatosCategoria.map((formato) {
                    final seleccionado = _formatoSeleccionado == formato['id'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _formatoSeleccionado = formato['id'] as String);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: seleccionado ? Colors.cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: seleccionado ? Colors.cyan : Colors.white12,
                            width: seleccionado ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              formato['icono'] as IconData,
                              color: seleccionado ? Colors.cyan : Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formato['nombre'] as String,
                              style: TextStyle(
                                color: seleccionado ? Colors.cyan : Colors.white70,
                                fontSize: 12,
                                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOpcionesImpresion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Opciones de Impresión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          // Modo de color
          Row(
            children: [
              const Text('Modo:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              _buildOpcionChip('Color', 'color', Icons.palette),
              const SizedBox(width: 8),
              _buildOpcionChip('B/N', 'bn', Icons.contrast),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Switches
          SwitchListTile(
            title: const Text('Margen de corte (3mm)', style: TextStyle(color: Colors.white70)),
            subtitle: Text(
              'Área segura para corte de imprenta',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
            value: _conMargenCorte,
            activeColor: Colors.cyan,
            onChanged: (v) => setState(() => _conMargenCorte = v),
            contentPadding: EdgeInsets.zero,
          ),
          
          SwitchListTile(
            title: const Text('Guías de corte', style: TextStyle(color: Colors.white70)),
            subtitle: Text(
              'Marcas en las esquinas para corte',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
            value: _conGuias,
            activeColor: Colors.cyan,
            onChanged: (v) => setState(() => _conGuias = v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionChip(String label, String valor, IconData icono) {
    final seleccionado = _colorModo == valor;
    return GestureDetector(
      onTap: () => setState(() => _colorModo = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? Colors.cyan : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: seleccionado ? Colors.cyan : Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.cyan : Colors.white54,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorResolucion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resolución',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          ...['web', 'media', 'alta', 'ultra'].map((res) {
            final info = _resoluciones[res]!;
            final seleccionado = _resolucionSeleccionada == res;
            
            return GestureDetector(
              onTap: () => setState(() => _resolucionSeleccionada = res),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: seleccionado ? Colors.cyan.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: seleccionado ? Colors.cyan : Colors.white12,
                    width: seleccionado ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: seleccionado ? Colors.cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${info['dpi']}',
                          style: TextStyle(
                            color: seleccionado ? Colors.cyan : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                            info['nombre'] as String,
                            style: TextStyle(
                              color: seleccionado ? Colors.cyan : Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            info['descripcion'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (seleccionado)
                      const Icon(Icons.check_circle, color: Colors.cyan, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSelectorCantidad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.content_copy, color: Colors.white54),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Copias por hoja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text(
                  'Optimiza el uso del papel',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          
          // Contador
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.cyan),
                onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
              ),
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_cantidad',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.cyan),
                onPressed: _cantidad < 20 ? () => setState(() => _cantidad++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoArchivo() {
    final formato = _formatoActual;
    final resolucion = _resoluciones[_resolucionSeleccionada]!;
    final dpi = resolucion['dpi'] as int;
    
    // Calcular tamaño estimado del archivo
    final pixelesBase = (formato['pixeles'] as String).split('x');
    final ancho = int.tryParse(pixelesBase[0].replaceAll(' px', '')) ?? 1000;
    final alto = int.tryParse(pixelesBase[1].replaceAll(' px', '')) ?? 1000;
    final factorDpi = dpi / 300;
    final pixelesFinal = (ancho * factorDpi * alto * factorDpi / 1000000).toStringAsFixed(1);
    final tamanoMB = (ancho * factorDpi * alto * factorDpi * 4 / 1024 / 1024).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.cyan.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.cyan),
              const SizedBox(width: 8),
              const Text(
                'Información del archivo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem('Megapíxeles', '$pixelesFinal MP', Icons.photo_size_select_large),
              _buildInfoItem('Tamaño est.', '~$tamanoMB MB', Icons.storage),
              _buildInfoItem('Formato', 'PNG', Icons.image),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String valor, IconData icono) {
    return Column(
      children: [
        Icon(icono, color: Colors.white38, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }

  Widget _buildBotonesAccion() {
    return Column(
      children: [
        // Botón principal de descarga
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generarArchivo,
            icon: const Icon(Icons.download),
            label: const Text('Generar archivo para imprenta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Opciones secundarias
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _enviarPorEmail,
                icon: const Icon(Icons.email),
                label: const Text('Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _guardarEnNube,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Nube'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Botón imprenta cercana
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _buscarImprentaCercana,
            icon: const Icon(Icons.location_on),
            label: const Text('Buscar imprenta cercana'),
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
          ),
        ),
      ],
    );
  }

  void _generarArchivo() {
    final formato = _formatoActual;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.cyan),
            const SizedBox(height: 20),
            const Text(
              'Generando archivo HD...',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '${formato['nombre']} - ${_resoluciones[_resolucionSeleccionada]!['dpi']} DPI',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );

    // Simular generación
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${formato['nombre']}.png guardado en Descargas'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Abrir',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    });
  }

  void _enviarPorEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparando archivo para enviar por email...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _guardarEnNube() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guardando en la nube...'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _buscarImprentaCercana() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando imprentas cercanas...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.cyan),
            SizedBox(width: 10),
            Text('Guía de Impresión', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAyudaItem(
                'Resolución recomendada',
                'Para impresión profesional usa 300 DPI. Para banners grandes 150 DPI es suficiente.',
              ),
              _buildAyudaItem(
                'Margen de corte',
                'El margen de 3mm asegura que no se corte contenido importante.',
              ),
              _buildAyudaItem(
                'Formato PNG',
                'Mejor calidad y soporta transparencias. Ideal para imprentas.',
              ),
              _buildAyudaItem(
                'Tamaño del QR',
                'El QR debe tener al menos 2cm para escanearse correctamente.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildAyudaItem(String titulo, String descripcion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Painter para guías de corte
class _GuiasCorte extends CustomPainter {
  final bool esCircular;
  
  _GuiasCorte(this.esCircular);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;

    const guiaLength = 15.0;
    const offset = 5.0;

    if (!esCircular) {
      // Esquina superior izquierda
      canvas.drawLine(const Offset(0, offset), Offset(guiaLength, offset), paint);
      canvas.drawLine(const Offset(offset, 0), Offset(offset, guiaLength), paint);

      // Esquina superior derecha
      canvas.drawLine(Offset(size.width - guiaLength, offset), Offset(size.width, offset), paint);
      canvas.drawLine(Offset(size.width - offset, 0), Offset(size.width - offset, guiaLength), paint);

      // Esquina inferior izquierda
      canvas.drawLine(Offset(0, size.height - offset), Offset(guiaLength, size.height - offset), paint);
      canvas.drawLine(Offset(offset, size.height - guiaLength), Offset(offset, size.height), paint);

      // Esquina inferior derecha
      canvas.drawLine(Offset(size.width - guiaLength, size.height - offset), Offset(size.width, size.height - offset), paint);
      canvas.drawLine(Offset(size.width - offset, size.height - guiaLength), Offset(size.width - offset, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

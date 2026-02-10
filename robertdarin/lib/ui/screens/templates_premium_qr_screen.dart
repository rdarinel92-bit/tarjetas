// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATES PREMIUM QR - V10.54
// Diseños profesionales para tarjetas QR: flyers, cupones, tarjetas elegantes
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../components/premium_scaffold.dart';

class TemplatesPremiumQrScreen extends StatefulWidget {
  final String? tarjetaId;
  final String? qrData;
  final String? titulo;
  
  const TemplatesPremiumQrScreen({
    super.key,
    this.tarjetaId,
    this.qrData,
    this.titulo,
  });

  @override
  State<TemplatesPremiumQrScreen> createState() => _TemplatesPremiumQrScreenState();
}

class _TemplatesPremiumQrScreenState extends State<TemplatesPremiumQrScreen> {
  String _categoriaSeleccionada = 'todos';
  String _templateSeleccionado = '';
  bool _isLoading = false;
  
  // Datos personalizables
  String _tituloPersonalizado = '';
  String _subtitulo = '';
  String _descripcion = '';
  String _oferta = '';
  String _telefono = '';
  Color _colorPrimario = const Color(0xFF667eea);
  Color _colorSecundario = const Color(0xFF764ba2);
  
  final List<Map<String, dynamic>> _templates = [
    // FLYERS PROMOCIONALES
    {
      'id': 'flyer_moderno',
      'nombre': 'Flyer Moderno',
      'categoria': 'flyers',
      'descripcion': 'Diseño limpio con gradientes vibrantes',
      'icono': Icons.article,
      'premium': false,
    },
    {
      'id': 'flyer_oferta',
      'nombre': 'Flyer Oferta Flash',
      'categoria': 'flyers',
      'descripcion': 'Ideal para promociones con descuento',
      'icono': Icons.local_offer,
      'premium': false,
    },
    {
      'id': 'flyer_evento',
      'nombre': 'Flyer Evento',
      'categoria': 'flyers',
      'descripcion': 'Para invitaciones y eventos especiales',
      'icono': Icons.event,
      'premium': true,
    },
    
    // CUPONES
    {
      'id': 'cupon_descuento',
      'nombre': 'Cupón Descuento',
      'categoria': 'cupones',
      'descripcion': 'Cupón clásico con línea de corte',
      'icono': Icons.confirmation_number,
      'premium': false,
    },
    {
      'id': 'cupon_regalo',
      'nombre': 'Gift Card',
      'categoria': 'cupones',
      'descripcion': 'Tarjeta de regalo elegante',
      'icono': Icons.card_giftcard,
      'premium': true,
    },
    {
      'id': 'cupon_2x1',
      'nombre': 'Cupón 2x1',
      'categoria': 'cupones',
      'descripcion': 'Promoción dos por uno llamativa',
      'icono': Icons.looks_two,
      'premium': false,
    },
    
    // TARJETAS ELEGANTES
    {
      'id': 'tarjeta_minimalista',
      'nombre': 'Tarjeta Minimalista',
      'categoria': 'tarjetas',
      'descripcion': 'Diseño simple y sofisticado',
      'icono': Icons.credit_card,
      'premium': false,
    },
    {
      'id': 'tarjeta_corporativa',
      'nombre': 'Tarjeta Corporativa',
      'categoria': 'tarjetas',
      'descripcion': 'Profesional para negocios',
      'icono': Icons.business,
      'premium': true,
    },
    {
      'id': 'tarjeta_personal',
      'nombre': 'Tarjeta Personal',
      'categoria': 'tarjetas',
      'descripcion': 'Estilo personal con foto',
      'icono': Icons.person,
      'premium': false,
    },
    
    // STICKERS
    {
      'id': 'sticker_circular',
      'nombre': 'Sticker Circular',
      'categoria': 'stickers',
      'descripcion': 'QR en formato redondo',
      'icono': Icons.circle,
      'premium': false,
    },
    {
      'id': 'sticker_badge',
      'nombre': 'Sticker Badge',
      'categoria': 'stickers',
      'descripcion': 'Insignia con QR integrado',
      'icono': Icons.verified,
      'premium': true,
    },
    
    // BANNERS
    {
      'id': 'banner_horizontal',
      'nombre': 'Banner Web',
      'categoria': 'banners',
      'descripcion': 'Para redes sociales y web',
      'icono': Icons.panorama,
      'premium': false,
    },
    {
      'id': 'banner_instagram',
      'nombre': 'Post Instagram',
      'categoria': 'banners',
      'descripcion': 'Formato cuadrado optimizado',
      'icono': Icons.camera_alt,
      'premium': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tituloPersonalizado = widget.titulo ?? 'Mi Negocio';
  }

  List<Map<String, dynamic>> get _templatesFiltrados {
    if (_categoriaSeleccionada == 'todos') return _templates;
    return _templates.where((t) => t['categoria'] == _categoriaSeleccionada).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Templates Premium',
      body: Column(
        children: [
          // Categorías
          _buildCategorias(),
          
          // Grid de templates
          Expanded(
            child: _templateSeleccionado.isEmpty
                ? _buildGridTemplates()
                : _buildEditorTemplate(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorias() {
    final categorias = [
      {'id': 'todos', 'label': 'Todos', 'icono': Icons.apps},
      {'id': 'flyers', 'label': 'Flyers', 'icono': Icons.article},
      {'id': 'cupones', 'label': 'Cupones', 'icono': Icons.confirmation_number},
      {'id': 'tarjetas', 'label': 'Tarjetas', 'icono': Icons.credit_card},
      {'id': 'stickers', 'label': 'Stickers', 'icono': Icons.sticky_note_2},
      {'id': 'banners', 'label': 'Banners', 'icono': Icons.panorama},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final seleccionada = _categoriaSeleccionada == cat['id'];
          
          return GestureDetector(
            onTap: () => setState(() => _categoriaSeleccionada = cat['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: seleccionada
                    ? const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])
                    : null,
                color: seleccionada ? null : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: seleccionada ? Colors.transparent : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(cat['icono'] as IconData, size: 16, color: seleccionada ? Colors.white : Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      color: seleccionada ? Colors.white : Colors.white54,
                      fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridTemplates() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _templatesFiltrados.length,
      itemBuilder: (context, index) {
        final template = _templatesFiltrados[index];
        final esPremium = template['premium'] as bool;
        
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _templateSeleccionado = template['id'] as String);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Preview del template
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_colorPrimario, _colorSecundario],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            template['icono'] as IconData,
                            size: 40,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                    
                    // Info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            template['nombre'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template['descripcion'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Badge Premium
                if (esPremium)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorTemplate() {
    final template = _templates.firstWhere((t) => t['id'] == _templateSeleccionado);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con botón volver
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _templateSeleccionado = ''),
              ),
              Expanded(
                child: Text(
                  'Personalizar: ${template['nombre']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Preview del template
          _buildPreviewTemplate(template),
          
          const SizedBox(height: 24),
          
          // Campos de personalización
          _buildCamposPersonalizacion(),
          
          const SizedBox(height: 24),
          
          // Selector de colores
          _buildSelectorColores(),
          
          const SizedBox(height: 24),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _descargarTemplate,
                  icon: const Icon(Icons.download),
                  label: const Text('Descargar PNG'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _compartirTemplate,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Botón imprimir HD
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _imprimirHD,
              icon: const Icon(Icons.print),
              label: const Text('Imprimir en Alta Calidad'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTemplate(Map<String, dynamic> template) {
    final categoria = template['categoria'] as String;
    final qrData = widget.qrData ?? 'https://robertdarin.app/qr/demo';
    
    switch (categoria) {
      case 'flyers':
        return _buildFlyerPreview(qrData);
      case 'cupones':
        return _buildCuponPreview(qrData);
      case 'tarjetas':
        return _buildTarjetaPreview(qrData);
      case 'stickers':
        return _buildStickerPreview(qrData);
      case 'banners':
        return _buildBannerPreview(qrData);
      default:
        return _buildFlyerPreview(qrData);
    }
  }

  Widget _buildFlyerPreview(String qrData) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_colorPrimario, _colorSecundario],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _colorPrimario.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Patrón de fondo
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _PatternPainter()),
            ),
          ),
          
          // Contenido
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_oferta.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _oferta,
                      style: TextStyle(
                        color: _colorPrimario,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                Text(
                  _tituloPersonalizado.isEmpty ? 'Tu Negocio' : _tituloPersonalizado,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    height: 1.2,
                  ),
                ),
                
                if (_subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _subtitulo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
                
                const Spacer(),
                
                // QR y contacto
                Row(
                  children: [
                    // QR
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: qrData,
                        size: 100,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Info contacto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Escanea y conoce más',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          if (_telefono.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _telefono,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuponPreview(String qrData) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del cupón
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_colorPrimario, _colorSecundario]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tituloPersonalizado.isEmpty ? 'CUPÓN DE DESCUENTO' : _tituloPersonalizado.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_subtitulo.isNotEmpty)
                        Text(
                          _subtitulo,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(data: qrData, size: 60),
                ),
              ],
            ),
          ),
          
          // Línea de corte
          Row(
            children: List.generate(
              20,
              (i) => Expanded(
                child: Container(
                  height: 2,
                  color: i % 2 == 0 ? Colors.grey[300] : Colors.transparent,
                ),
              ),
            ),
          ),
          
          // Contenido del cupón
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_oferta.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _colorPrimario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _colorPrimario, width: 2),
                    ),
                    child: Text(
                      _oferta,
                      style: TextStyle(
                        color: _colorPrimario,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _colorPrimario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _colorPrimario, width: 2),
                    ),
                    child: Text(
                      '20% OFF',
                      style: TextStyle(
                        color: _colorPrimario,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _descripcion.isEmpty
                        ? 'Válido en tu próxima compra. Presenta este cupón.'
                        : _descripcion,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPreview(String qrData) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorPrimario.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _tituloPersonalizado.isEmpty ? 'Nombre' : _tituloPersonalizado,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  if (_subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _subtitulo,
                      style: TextStyle(color: _colorPrimario, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_telefono.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.white.withOpacity(0.5), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _telefono,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // QR
          Container(
            width: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_colorPrimario, _colorSecundario]),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(data: qrData, size: 80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPreview(String qrData) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_colorPrimario, _colorSecundario],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _colorPrimario.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(data: qrData, size: 80),
          ),
          const SizedBox(height: 8),
          Text(
            _tituloPersonalizado.isEmpty ? 'ESCANÉAME' : _tituloPersonalizado,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPreview(String qrData) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_colorPrimario, _colorSecundario],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _tituloPersonalizado.isEmpty ? 'Tu Mensaje Aquí' : _tituloPersonalizado,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  if (_subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _subtitulo,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(data: qrData, size: 120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamposPersonalizacion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personalizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildCampoTexto('Título', _tituloPersonalizado, (v) => setState(() => _tituloPersonalizado = v)),
          _buildCampoTexto('Subtítulo', _subtitulo, (v) => setState(() => _subtitulo = v)),
          _buildCampoTexto('Oferta (ej: 20% OFF)', _oferta, (v) => setState(() => _oferta = v)),
          _buildCampoTexto('Teléfono', _telefono, (v) => setState(() => _telefono = v)),
          _buildCampoTexto('Descripción', _descripcion, (v) => setState(() => _descripcion = v), maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildCampoTexto(String label, String valor, Function(String) onChange, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: valor),
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChange,
      ),
    );
  }

  Widget _buildSelectorColores() {
    final colores = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF00D9FF), const Color(0xFF00FF88)],
      [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)],
      [const Color(0xFF4ECDC4), const Color(0xFF556270)],
      [const Color(0xFFFC466B), const Color(0xFF3F5EFB)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Colores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: colores.map((par) {
              final seleccionado = _colorPrimario == par[0];
              return GestureDetector(
                onTap: () => setState(() {
                  _colorPrimario = par[0];
                  _colorSecundario = par[1];
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: par),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: seleccionado ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: seleccionado
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _descargarTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template guardado en galería'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _compartirTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo opciones de compartir...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _imprimirHD() {
    Navigator.pushNamed(context, '/qr_impresion_profesional', arguments: {
      'template_id': _templateSeleccionado,
      'datos': {
        'titulo': _tituloPersonalizado,
        'subtitulo': _subtitulo,
        'oferta': _oferta,
        'telefono': _telefono,
        'descripcion': _descripcion,
        'color_primario': _colorPrimario.value,
        'color_secundario': _colorSecundario.value,
      },
      'qr_data': widget.qrData,
    });
  }
}

// Painter para patrón de fondo
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (var i = 0; i < size.width + size.height; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(0, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

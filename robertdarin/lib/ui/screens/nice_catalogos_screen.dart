// ignore_for_file: deprecated_member_use
// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CATÁLOGOS NICE - Gestión de Catálogos de Joyería
// Robert Darin Platform v10.22
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../components/premium_scaffold.dart';

class NiceCatalogosScreen extends StatefulWidget {
  final String negocioId;
  const NiceCatalogosScreen({super.key, this.negocioId = ''});

  @override
  State<NiceCatalogosScreen> createState() => _NiceCatalogosScreenState();
}

class _NiceCatalogosScreenState extends State<NiceCatalogosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _catalogos = [];
  final _formatDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppSupabase.client
          .from('nice_catalogos')
          .select()
          .eq('negocio_id', widget.negocioId)
          .order('orden', ascending: false);
      
      if (mounted) {
        setState(() {
          _catalogos = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando catálogos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getEstadoCatalogo(Map<String, dynamic> catalogo) {
    final activo = catalogo['activo'] ?? false;
    if (!activo) return 'inactivo';
    
    final hoy = DateTime.now();
    final inicio = catalogo['fecha_inicio'] != null 
        ? DateTime.parse(catalogo['fecha_inicio']) 
        : null;
    final fin = catalogo['fecha_fin'] != null 
        ? DateTime.parse(catalogo['fecha_fin']) 
        : null;
    
    if (inicio != null && hoy.isBefore(inicio)) return 'programado';
    if (fin != null && hoy.isAfter(fin)) return 'expirado';
    return 'vigente';
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'vigente':
        return const Color(0xFF10B981);
      case 'programado':
        return const Color(0xFF0EA5E9);
      case 'expirado':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Catálogos',
      subtitle: 'Gestiona tus catálogos de joyería',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          onPressed: _mostrarFormularioCatalogo,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
          : _catalogos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarCatalogos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _catalogos.length,
                    itemBuilder: (context, i) => _buildCatalogoCard(_catalogos[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin catálogos',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea catálogos para organizar tus temporadas',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioCatalogo,
            icon: const Icon(Icons.add),
            label: const Text('Crear Catálogo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogoCard(Map<String, dynamic> catalogo) {
    final estado = _getEstadoCatalogo(catalogo);
    final estadoColor = _getEstadoColor(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioCatalogo(catalogo: catalogo),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con imagen
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: catalogo['imagen_portada_url'] == null
                    ? LinearGradient(
                        colors: [estadoColor.withOpacity(0.3), estadoColor.withOpacity(0.1)],
                      )
                    : null,
                image: catalogo['imagen_portada_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(catalogo['imagen_portada_url']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: estadoColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        estado.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (catalogo['imagen_portada_url'] == null)
                    Center(
                      child: Icon(Icons.menu_book, size: 48, color: estadoColor),
                    ),
                ],
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          catalogo['codigo'] ?? 'SIN-COD',
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (catalogo['pdf_url'] != null)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
                          onPressed: () => _abrirPdf(catalogo['pdf_url']),
                          tooltip: 'Ver PDF',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalogo['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (catalogo['descripcion'] != null && catalogo['descripcion'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      catalogo['descripcion'],
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey[500], size: 14),
                      const SizedBox(width: 4),
                      Text(
                        catalogo['fecha_inicio'] != null
                            ? _formatDate.format(DateTime.parse(catalogo['fecha_inicio']))
                            : 'Sin fecha',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      if (catalogo['fecha_fin'] != null) ...[
                        Text(' - ', style: TextStyle(color: Colors.grey[500])),
                        Text(
                          _formatDate.format(DateTime.parse(catalogo['fecha_fin'])),
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirPdf(String url) {
    // TODO: Implementar apertura de PDF
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo PDF...')),
    );
  }

  void _mostrarFormularioCatalogo({Map<String, dynamic>? catalogo}) {
    final isEdit = catalogo != null;
    final codigoCtrl = TextEditingController(text: catalogo?['codigo'] ?? '');
    final nombreCtrl = TextEditingController(text: catalogo?['nombre'] ?? '');
    final descripcionCtrl = TextEditingController(text: catalogo?['descripcion'] ?? '');
    final imagenCtrl = TextEditingController(text: catalogo?['imagen_portada_url'] ?? '');
    final pdfCtrl = TextEditingController(text: catalogo?['pdf_url'] ?? '');
    DateTime? fechaInicio = catalogo?['fecha_inicio'] != null 
        ? DateTime.parse(catalogo!['fecha_inicio']) 
        : null;
    DateTime? fechaFin = catalogo?['fecha_fin'] != null 
        ? DateTime.parse(catalogo!['fecha_fin']) 
        : null;
    bool activo = catalogo?['activo'] ?? true;

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
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'Editar Catálogo' : 'Nuevo Catálogo',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(codigoCtrl, 'Código *', Icons.qr_code),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(nombreCtrl, 'Nombre *', Icons.menu_book),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(descripcionCtrl, 'Descripción', Icons.description, maxLines: 2),
                const SizedBox(height: 12),
                _buildTextField(imagenCtrl, 'URL Imagen Portada', Icons.image),
                const SizedBox(height: 12),
                _buildTextField(pdfCtrl, 'URL del PDF', Icons.picture_as_pdf),
                const SizedBox(height: 16),
                const Text('Vigencia del Catálogo', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setModalState(() => fechaInicio = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                fechaInicio != null 
                                    ? _formatDate.format(fechaInicio!) 
                                    : 'Fecha Inicio',
                                style: TextStyle(
                                  color: fechaInicio != null ? Colors.white : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: fechaFin ?? DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setModalState(() => fechaFin = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event, color: Colors.grey[600], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                fechaFin != null 
                                    ? _formatDate.format(fechaFin!) 
                                    : 'Fecha Fin',
                                style: TextStyle(
                                  color: fechaFin != null ? Colors.white : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: activo,
                  onChanged: (v) => setModalState(() => activo = v),
                  title: const Text('Catálogo Activo', style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _eliminarCatalogo(catalogo['id']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ),
                    if (isEdit) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _guardarCatalogo(
                          id: catalogo?['id'],
                          codigo: codigoCtrl.text,
                          nombre: nombreCtrl.text,
                          descripcion: descripcionCtrl.text,
                          imagenUrl: imagenCtrl.text,
                          pdfUrl: pdfCtrl.text,
                          fechaInicio: fechaInicio,
                          fechaFin: fechaFin,
                          activo: activo,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isEdit ? 'Actualizar' : 'Guardar',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _guardarCatalogo({
    String? id,
    required String codigo,
    required String nombre,
    String? descripcion,
    String? imagenUrl,
    String? pdfUrl,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    required bool activo,
  }) async {
    if (codigo.isEmpty || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código y nombre son requeridos'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final data = {
        'negocio_id': widget.negocioId,
        'codigo': codigo.toUpperCase(),
        'nombre': nombre,
        'descripcion': descripcion?.isNotEmpty == true ? descripcion : null,
        'imagen_portada_url': imagenUrl?.isNotEmpty == true ? imagenUrl : null,
        'pdf_url': pdfUrl?.isNotEmpty == true ? pdfUrl : null,
        'fecha_inicio': fechaInicio?.toIso8601String().split('T').first,
        'fecha_fin': fechaFin?.toIso8601String().split('T').first,
        'activo': activo,
        'orden': id == null ? _catalogos.length : null,
      };
      data.removeWhere((k, v) => v == null);

      if (id != null) {
        await AppSupabase.client.from('nice_catalogos').update(data).eq('id', id);
      } else {
        await AppSupabase.client.from('nice_catalogos').insert(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _cargarCatalogos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? 'Catálogo actualizado' : 'Catálogo creado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando catálogo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarCatalogo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar Catálogo', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro? Los productos asociados perderán la referencia al catálogo.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AppSupabase.client.from('nice_catalogos').delete().eq('id', id);
        if (mounted) {
          Navigator.pop(context);
          _cargarCatalogos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Catálogo eliminado'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

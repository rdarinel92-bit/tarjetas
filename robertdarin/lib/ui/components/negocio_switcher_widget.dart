import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/negocio_activo_provider.dart';

/// Widget para cambiar rápidamente entre negocios
/// Se puede usar en cualquier AppBar o Header
class NegocioSwitcherWidget extends StatelessWidget {
  final bool mostrarNombre;
  final bool compacto;
  final VoidCallback? onCambio;

  const NegocioSwitcherWidget({
    super.key,
    this.mostrarNombre = true,
    this.compacto = false,
    this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NegocioActivoProvider>(
      builder: (context, provider, _) {
        if (compacto) {
          return _buildCompacto(context, provider);
        }
        return _buildCompleto(context, provider);
      },
    );
  }

  Widget _buildCompacto(BuildContext context, NegocioActivoProvider provider) {
    return GestureDetector(
      onTap: () => _mostrarSelectorNegocios(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              provider.iconoNegocio,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleto(BuildContext context, NegocioActivoProvider provider) {
    final colores = _getColoresNegocio(provider.tipoNegocio);
    
    return GestureDetector(
      onTap: () => _mostrarSelectorNegocios(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colores[0].withOpacity(0.8), colores[1].withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colores[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  provider.iconoNegocio,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            if (mostrarNombre) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.nombreNegocio,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.esVistaGlobal ? 'Vista Global' : 'Negocio Activo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorNegocios(BuildContext context, NegocioActivoProvider provider) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SelectorNegociosSheet(
        provider: provider,
        onCambio: onCambio,
      ),
    );
  }

  List<Color> _getColoresNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'aires':
      case 'climas':
        return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
      case 'purificadora':
        return [const Color(0xFF00c6fb), const Color(0xFF005bea)];
      case 'ventas':
      case 'retail':
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      default:
        return [const Color(0xFFFFD700), const Color(0xFFFF8C00)];
    }
  }
}

/// Bottom sheet para seleccionar negocio
class _SelectorNegociosSheet extends StatelessWidget {
  final NegocioActivoProvider provider;
  final VoidCallback? onCambio;

  const _SelectorNegociosSheet({
    required this.provider,
    this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('🏢', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Seleccionar Negocio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),
          
          // Opción: Ver todos
          _buildOpcionNegocio(
            context,
            icono: '🌐',
            nombre: 'Todos los Negocios',
            subtitulo: 'Vista global de todos los datos',
            esSeleccionado: provider.esVistaGlobal,
            colores: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
            onTap: () {
              provider.seleccionarNegocio(null);
              Navigator.pop(context);
              onCambio?.call();
            },
          ),
          
          // Lista de negocios
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: provider.misNegocios.length,
              itemBuilder: (context, index) {
                final negocio = provider.misNegocios[index];
                final esSeleccionado = provider.negocioActivo?.id == negocio.id;
                final colores = _getColoresNegocio(negocio.tipo);
                
                return _buildOpcionNegocio(
                  context,
                  icono: negocio.icono,
                  nombre: negocio.nombre,
                  subtitulo: _getTipoLabel(negocio.tipo),
                  esSeleccionado: esSeleccionado,
                  colores: colores,
                  onTap: () {
                    provider.seleccionarNegocio(negocio);
                    Navigator.pop(context);
                    onCambio?.call();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionNegocio(
    BuildContext context, {
    required String icono,
    required String nombre,
    required String subtitulo,
    required bool esSeleccionado,
    required List<Color> colores,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: esSeleccionado
              ? LinearGradient(colors: colores)
              : null,
          color: esSeleccionado ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: esSeleccionado ? Colors.transparent : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: esSeleccionado
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icono, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (esSeleccionado)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getColoresNegocio(String? tipo) {
    switch (tipo) {
      case 'fintech':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'aires':
      case 'climas':
        return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
      case 'purificadora':
        return [const Color(0xFF00c6fb), const Color(0xFF005bea)];
      case 'ventas':
      case 'retail':
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      default:
        return [const Color(0xFF434343), const Color(0xFF000000)];
    }
  }

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'fintech': return '💰 Finanzas';
      case 'aires':
      case 'climas': return '❄️ Climas / Aires';
      case 'purificadora': return '💧 Purificadora';
      case 'ventas':
      case 'retail': return '🛒 Ventas';
      default: return '🏢 General';
    }
  }
}

/// AppBar con selector de negocio integrado
class NegocioAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final List<Widget>? actions;
  final bool mostrarSwitcher;

  const NegocioAppBar({
    super.key,
    required this.titulo,
    this.actions,
    this.mostrarSwitcher = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      title: mostrarSwitcher
          ? const NegocioSwitcherWidget(mostrarNombre: true)
          : Text(titulo, style: const TextStyle(color: Colors.white)),
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
    );
  }
}

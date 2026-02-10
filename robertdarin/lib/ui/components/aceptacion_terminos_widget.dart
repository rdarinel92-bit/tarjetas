// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE ACEPTACIÓN DE TÉRMINOS - UNIKO
// Checkbox con enlaces a documentos legales para registro
// V10.51 - Robert-Darin © 2026
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../screens/terminos_condiciones_screen.dart';
import '../screens/politica_privacidad_screen.dart';

class AceptacionTerminosWidget extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool?> onChanged;
  final bool mostrarError;

  const AceptacionTerminosWidget({
    super.key,
    required this.aceptado,
    required this.onChanged,
    this.mostrarError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mostrarError 
            ? const Color(0xFFEF4444).withOpacity(0.1)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mostrarError 
              ? const Color(0xFFEF4444)
              : const Color(0xFF2A2A4E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: aceptado,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF00D9FF),
                  checkColor: Colors.black,
                  side: BorderSide(
                    color: mostrarError 
                        ? const Color(0xFFEF4444)
                        : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'He leído y acepto los '),
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: const TextStyle(
                          color: Color(0xFF00D9FF),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _abrirTerminos(context),
                      ),
                      const TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _abrirPrivacidad(context),
                      ),
                      const TextSpan(text: ' de Uniko.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (mostrarError) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(width: 36),
                Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: 4),
                Text(
                  'Debes aceptar los términos para continuar',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _abrirTerminos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TerminosCondicionesScreen(),
      ),
    );
  }

  void _abrirPrivacidad(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PoliticaPrivacidadScreen(),
      ),
    );
  }
}

/// Widget compacto para mostrar en footer de pantallas
class FooterLegalWidget extends StatelessWidget {
  const FooterLegalWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildEnlaceLegal(
                context,
                'Términos',
                Icons.gavel,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TerminosCondicionesScreen(),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              _buildEnlaceLegal(
                context,
                'Privacidad',
                Icons.privacy_tip,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PoliticaPrivacidadScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '© 2026 Robert-Darin • Todos los derechos reservados',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEnlaceLegal(
    BuildContext context,
    String texto,
    IconData icono,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Text(
              texto,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

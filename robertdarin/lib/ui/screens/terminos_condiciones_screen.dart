// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE TÉRMINOS Y CONDICIONES - UNIKO
// Documentos legales con diseño profesional
// V10.51 - Robert-Darin © 2026
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

class TerminosCondicionesScreen extends StatelessWidget {
  final bool mostrarAceptar;
  final VoidCallback? onAceptar;
  
  const TerminosCondicionesScreen({
    super.key,
    this.mostrarAceptar = false,
    this.onAceptar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Términos y Condiciones'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSeccion(
                    '1. Aceptación de los Términos',
                    'Al descargar, instalar o usar la aplicación Uniko, usted acepta estos términos y condiciones en su totalidad. Si no está de acuerdo con alguno de estos términos, no debe usar la aplicación.',
                  ),
                  _buildSeccion(
                    '2. Descripción del Servicio',
                    '''Uniko es una plataforma integral de gestión empresarial que permite:

• Administrar préstamos personales y empresariales
• Gestionar tandas (ahorro grupal rotativo)
• Control de servicios de climatización
• Gestión de purificadoras de agua
• Administración de ventas y catálogos
• Registrar y dar seguimiento a cobros
• Generar reportes y contratos
• Administrar clientes y operaciones''',
                  ),
                  _buildSeccion(
                    '3. Requisitos de Uso',
                    '''Para usar la aplicación debe:

• Ser mayor de 18 años
• Proporcionar información veraz y actualizada
• Mantener la confidencialidad de sus credenciales
• Usar la aplicación de forma legal y ética
• Contar con un dispositivo compatible''',
                  ),
                  _buildSeccion(
                    '4. Cuenta de Usuario',
                    '''• Usted es responsable de toda actividad realizada en su cuenta
• Debe notificarnos inmediatamente si detecta uso no autorizado
• Nos reservamos el derecho de suspender cuentas por violaciones a estos términos
• Las credenciales son personales e intransferibles''',
                  ),
                  _buildSeccion(
                    '5. Uso Permitido',
                    '''La aplicación debe usarse únicamente para:

• Gestión legítima de operaciones financieras y empresariales
• Administración de negocios debidamente autorizados
• Propósitos personales de control financiero
• Generación de contratos y documentos legales''',
                  ),
                  _buildSeccion(
                    '6. Uso Prohibido',
                    '''Está estrictamente prohibido:

• Usar la app para actividades ilegales o fraudulentas
• Intentar acceder a datos de otros usuarios sin autorización
• Realizar ingeniería inversa del software
• Distribuir malware o código malicioso
• Usar la app para lavado de dinero
• Suplantar identidad de otros usuarios
• Violar derechos de propiedad intelectual''',
                  ),
                  _buildSeccion(
                    '7. Propiedad Intelectual',
                    '''• La aplicación Uniko y todo su contenido son propiedad de Robert-Darin
• Se otorga licencia limitada, no exclusiva y revocable de uso personal
• No puede copiar, modificar, distribuir ni comercializar el software
• Las marcas, logos y diseños están protegidos por ley
• El código fuente es propiedad exclusiva del desarrollador''',
                  ),
                  _buildSeccion(
                    '8. Privacidad y Datos',
                    '''• El uso de la aplicación está sujeto a nuestra Política de Privacidad
• Usted mantiene propiedad de sus datos personales
• Nos otorga licencia para procesar datos según la Política de Privacidad
• Es responsable de los datos de terceros que ingrese
• Implementamos medidas de seguridad para proteger su información''',
                  ),
                  _buildSeccion(
                    '9. Contratos y Documentos Legales',
                    '''• Los contratos generados por la aplicación tienen validez legal
• Los préstamos están sujetos a las leyes mexicanas aplicables
• Las firmas digitales tienen el mismo valor que las físicas
• El usuario es responsable de verificar la información antes de firmar
• Mantenemos registro de todos los documentos generados''',
                  ),
                  _buildSeccion(
                    '10. Limitación de Responsabilidad',
                    '''• La aplicación se proporciona "como está" sin garantías adicionales
• No somos responsables por pérdidas derivadas del uso incorrecto
• No garantizamos exactitud absoluta de cálculos financieros
• Usted es responsable de verificar toda información
• No somos responsables por interrupciones del servicio''',
                  ),
                  _buildSeccion(
                    '11. Indemnización',
                    '''Usted acepta indemnizar y mantener libre de responsabilidad a Robert-Darin por cualquier reclamación derivada de:

• Su uso de la aplicación
• Violación de estos términos
• Infracción de derechos de terceros
• Información falsa proporcionada''',
                  ),
                  _buildSeccion(
                    '12. Modificaciones',
                    '''• Podemos modificar estos términos en cualquier momento
• Le notificaremos cambios significativos mediante la aplicación
• El uso continuo después de cambios implica aceptación
• Las versiones anteriores estarán disponibles para consulta''',
                  ),
                  _buildSeccion(
                    '13. Terminación',
                    '''Podemos terminar o suspender su acceso sin previo aviso por:

• Violación de estos términos
• Solicitud de autoridades competentes
• Actividad sospechosa o fraudulenta
• Decisión comercial a nuestra discreción''',
                  ),
                  _buildSeccion(
                    '14. Ley Aplicable y Jurisdicción',
                    '''• Estos términos se rigen por las leyes de los Estados Unidos Mexicanos
• Cualquier disputa se resolverá en los tribunales competentes de Tabasco, México
• Las partes se someten expresamente a dicha jurisdicción
• Se aplicará la Ley Federal de Protección al Consumidor cuando corresponda''',
                  ),
                  _buildSeccion(
                    '15. Contacto',
                    '''Para cualquier consulta sobre estos términos:

📧 Email: soporte@uniko.app
📱 Teléfono: +52 (993) 123-4567
📍 Ubicación: Emiliano Zapata, Tabasco, México''',
                  ),
                  const SizedBox(height: 20),
                  _buildFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (mostrarAceptar) _buildBotonAceptar(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.gavel, color: Color(0xFF00D9FF), size: 48),
          const SizedBox(height: 12),
          const Text(
            'TÉRMINOS Y CONDICIONES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uniko - Multi System',
            style: TextStyle(color: Color(0xFF00D9FF), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Última actualización: 20 de Enero, 2026',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo, String contenido) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF00D9FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            contenido,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user, color: Color(0xFF8B5CF6), size: 32),
          const SizedBox(height: 8),
          const Text(
            '© 2026 Robert-Darin',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Todos los derechos reservados',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Documento legalmente vinculante bajo las leyes de México',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAceptar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Color(0xFF2A2A4E))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAceptar ?? () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ACEPTO LOS TÉRMINOS Y CONDICIONES',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

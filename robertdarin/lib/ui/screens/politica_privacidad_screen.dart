// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE POLÍTICA DE PRIVACIDAD - UNIKO
// Protección de datos personales con diseño premium
// V10.51 - Robert-Darin © 2026
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

class PoliticaPrivacidadScreen extends StatelessWidget {
  final bool mostrarAceptar;
  final VoidCallback? onAceptar;
  
  const PoliticaPrivacidadScreen({
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
        title: const Text('Política de Privacidad'),
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
                    '1. Información que Recopilamos',
                    '''Recopilamos los siguientes tipos de información:

📋 **Datos de identificación:**
• Nombre completo
• Correo electrónico
• Número telefónico
• Dirección física
• Identificación oficial (INE/Pasaporte)

💼 **Datos financieros:**
• Información de préstamos
• Historial de pagos
• Participación en tandas
• Datos de avales

📱 **Datos técnicos:**
• Identificador del dispositivo
• Sistema operativo
• Dirección IP
• Datos de ubicación (con permiso)''',
                  ),
                  _buildSeccion(
                    '2. Cómo Usamos su Información',
                    '''Utilizamos sus datos para:

• Proporcionar nuestros servicios de gestión empresarial
• Procesar préstamos y pagos
• Verificar su identidad
• Comunicarnos con usted sobre su cuenta
• Generar contratos y documentos legales
• Mejorar nuestros servicios
• Cumplir con obligaciones legales
• Prevenir fraudes y actividades ilícitas
• Enviar notificaciones relevantes''',
                  ),
                  _buildSeccion(
                    '3. Base Legal para el Tratamiento',
                    '''Procesamos sus datos personales bajo las siguientes bases legales:

• **Consentimiento:** Al aceptar esta política
• **Contrato:** Para ejecutar los servicios acordados
• **Obligación legal:** Cumplimiento normativo fiscal y financiero
• **Interés legítimo:** Prevención de fraude y seguridad''',
                  ),
                  _buildSeccion(
                    '4. Compartición de Datos',
                    '''Podemos compartir su información con:

• **Proveedores de servicios:** Almacenamiento en la nube, análisis
• **Autoridades:** Cuando lo requiera la ley
• **Avales:** Información necesaria para el préstamo
• **Participantes de tandas:** Solo datos necesarios para el grupo

❌ **NUNCA vendemos sus datos personales a terceros**''',
                  ),
                  _buildSeccion(
                    '5. Almacenamiento y Seguridad',
                    '''Protegemos su información mediante:

🔐 **Medidas técnicas:**
• Encriptación de datos en tránsito y reposo (AES-256)
• Autenticación segura
• Copias de seguridad regulares
• Monitoreo continuo de seguridad

🏢 **Almacenamiento:**
• Servidores seguros con certificación SOC 2
• Ubicados en centros de datos certificados
• Acceso restringido al personal autorizado''',
                  ),
                  _buildSeccion(
                    '6. Sus Derechos ARCO',
                    '''Conforme a la Ley Federal de Protección de Datos Personales, usted tiene derecho a:

🔍 **Acceso:** Conocer qué datos tenemos de usted
📝 **Rectificación:** Corregir datos incorrectos
🗑️ **Cancelación:** Solicitar eliminación de sus datos
🚫 **Oposición:** Oponerse al tratamiento de sus datos

Para ejercer estos derechos, contacte a: privacidad@uniko.app''',
                  ),
                  _buildSeccion(
                    '7. Retención de Datos',
                    '''Conservamos sus datos durante:

• **Datos de cuenta:** Mientras mantenga cuenta activa + 5 años
• **Datos financieros:** 10 años (requisito fiscal)
• **Contratos:** Tiempo que dure la relación + 10 años
• **Datos técnicos:** 2 años máximo

Después del período de retención, los datos se eliminan de forma segura.''',
                  ),
                  _buildSeccion(
                    '8. Cookies y Tecnologías Similares',
                    '''La aplicación móvil utiliza:

• **Almacenamiento local:** Para preferencias y sesión
• **Datos de análisis:** Para mejorar la experiencia
• **Notificaciones push:** Con su consentimiento

No usamos cookies de seguimiento de terceros.''',
                  ),
                  _buildSeccion(
                    '9. Menores de Edad',
                    '''• La aplicación está destinada a mayores de 18 años
• No recopilamos intencionalmente datos de menores
• Si detectamos datos de menores, los eliminaremos
• Padres o tutores pueden contactarnos para eliminar datos''',
                  ),
                  _buildSeccion(
                    '10. Transferencias Internacionales',
                    '''Sus datos pueden transferirse a servidores ubicados en:
• Estados Unidos (Amazon Web Services)
• Unión Europea (respaldo)

Todas las transferencias cumplen con la legislación mexicana y el RGPD europeo.''',
                  ),
                  _buildSeccion(
                    '11. Cambios a esta Política',
                    '''• Podemos actualizar esta política periódicamente
• Le notificaremos cambios significativos mediante la app
• La fecha de "última actualización" se modificará
• El uso continuo implica aceptación de cambios''',
                  ),
                  _buildSeccion(
                    '12. Contacto y Quejas',
                    '''Para consultas sobre privacidad:

📧 **Email:** privacidad@uniko.app
📱 **Teléfono:** +52 (993) 123-4567
📍 **Dirección:** Emiliano Zapata, Tabasco, México

**Autoridad de Protección de Datos:**
Instituto Nacional de Transparencia, Acceso a la Información y Protección de Datos Personales (INAI)
www.inai.org.mx''',
                  ),
                  const SizedBox(height: 20),
                  _buildDerechosResumen(),
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
            const Color(0xFF8B5CF6).withOpacity(0.1),
            const Color(0xFF00D9FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.privacy_tip, color: Color(0xFF8B5CF6), size: 48),
          const SizedBox(height: 12),
          const Text(
            'POLÍTICA DE PRIVACIDAD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Protección de Datos Personales',
            style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14),
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
              color: Color(0xFF8B5CF6),
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

  Widget _buildDerechosResumen() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF00D9FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 8),
              Text(
                'SUS DERECHOS EN RESUMEN',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildDerechoChip('Acceso', Icons.visibility),
              _buildDerechoChip('Rectificación', Icons.edit),
              _buildDerechoChip('Cancelación', Icons.delete),
              _buildDerechoChip('Oposición', Icons.block),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDerechoChip(String texto, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            'Comprometidos con la protección de sus datos',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Conforme a la LFPDPPP y regulaciones aplicables',
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
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ACEPTO LA POLÍTICA DE PRIVACIDAD',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';

class ClimasTarjetasQrScreen extends StatelessWidget {
  const ClimasTarjetasQrScreen({super.key});

  static const List<String> _modulosPermitidos = ['climas'];

  void _abrirCrear(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.tarjetasServicio,
      arguments: {
        'abrirCrear': true,
        'modulo': 'climas',
        'modulosPermitidos': _modulosPermitidos,
      },
    );
  }

  void _verTarjetas(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.tarjetasServicio,
      arguments: {
        'abrirCrear': false,
        'modulosPermitidos': _modulosPermitidos,
      },
    );
  }

  void _verSolicitudes(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.climasSolicitudesAdmin);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Tarjetas QR Climas',
      subtitle: 'Aires acondicionados',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              icon: Icons.ac_unit,
              title: 'Crear tarjeta QR',
              subtitle: 'Tarjeta de presentacion con QR para solicitudes de climas.',
              color: const Color(0xFF00D9FF),
              onTap: () => _abrirCrear(context),
            ),
            const SizedBox(height: 16),
            _buildSecondaryAction(
              context,
              icon: Icons.qr_code_2,
              label: 'Ver mis tarjetas QR',
              onTap: () => _verTarjetas(context),
            ),
            const SizedBox(height: 12),
            _buildSecondaryAction(
              context,
              icon: Icons.inbox_rounded,
              label: 'Ver solicitudes recibidas',
              onTap: () => _verSolicitudes(context),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_2, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarjetas QR para Climas',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Crea tarjetas de presentacion con QR para tu negocio de climas.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white54, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las tarjetas QR de Climas no se mezclan con otros modulos.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

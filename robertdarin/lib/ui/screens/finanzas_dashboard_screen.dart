import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../navigation/app_routes.dart';

class FinanzasDashboardScreen extends StatelessWidget {
  const FinanzasDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ModuloItem(Icons.people, 'Clientes', AppRoutes.clientes, const Color(0xFF10B981)),
      _ModuloItem(Icons.attach_money, 'Prestamos', AppRoutes.prestamos, const Color(0xFF22C55E)),
      _ModuloItem(Icons.autorenew, 'Tandas', AppRoutes.tandas, const Color(0xFF0EA5E9)),
      _ModuloItem(Icons.verified_user, 'Avales', AppRoutes.avales, const Color(0xFF6366F1)),
      _ModuloItem(Icons.payments, 'Pagos', AppRoutes.pagos, const Color(0xFF38BDF8)),
      _ModuloItem(Icons.assignment_turned_in, 'Cobros', AppRoutes.cobrosPendientes, const Color(0xFFF59E0B)),
      _ModuloItem(Icons.warning_amber, 'Moras', AppRoutes.moras, const Color(0xFFEF4444)),
      _ModuloItem(Icons.calculate, 'Cotizador', AppRoutes.cotizadorPrestamo, const Color(0xFF8B5CF6)),
      _ModuloItem(Icons.fact_check, 'Verificar avales', AppRoutes.verificarDocumentosAval, const Color(0xFF14B8A6)),
      _ModuloItem(Icons.savings, 'Aportaciones', AppRoutes.aportaciones, const Color(0xFF0F766E)),
      _ModuloItem(Icons.receipt_long, 'Comprobantes', AppRoutes.comprobantes, const Color(0xFF3B82F6)),
      _ModuloItem(Icons.qr_code_2, 'Tarjetas QR', AppRoutes.finanzasTarjetasQr, const Color(0xFF06B6D4)),
      _ModuloItem(Icons.receipt_long, 'Facturas', AppRoutes.finanzasFacturas, const Color(0xFF4F46E5)),
      _ModuloItem(Icons.receipt, 'Config. Facturas', AppRoutes.facturacionConfig, const Color(0xFF6366F1)),
    ];

    return PremiumScaffold(
      title: 'Finanzas',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildCard(context, items[index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro de Finanzas',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Prestamos, tandas, avales y pagos en un solo lugar',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _ModuloItem item) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuloItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _ModuloItem(this.icon, this.label, this.route, this.color);
}

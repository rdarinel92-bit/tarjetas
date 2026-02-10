// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../../core/supabase_client.dart';
import '../../services/auditoria_legal_service.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// PANEL DE AUDITORÍA LEGAL Y GESTIÓN DE EVIDENCIAS
/// ══════════════════════════════════════════════════════════════════════════════
/// - Ver cartera vencida con estado legal
/// - Generar expedientes para juicio
/// - Revisar evidencias disponibles
/// - Seguimiento de procesos judiciales
/// ══════════════════════════════════════════════════════════════════════════════

class AuditoriaLegalScreen extends StatefulWidget {
  const AuditoriaLegalScreen({super.key});

  @override
  State<AuditoriaLegalScreen> createState() => _AuditoriaLegalScreenState();
}

class _AuditoriaLegalScreenState extends State<AuditoriaLegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  final _auditoriaService = AuditoriaLegalService();
  
  List<ReporteMoroso> _carteraVencida = [];
  List<Map<String, dynamic>> _expedientes = [];
  Map<String, dynamic>? _estadisticas;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar cartera vencida
      _carteraVencida = await _auditoriaService.generarReporteCarteraVencida(
        diasMinMora: 1,
        montoMinimo: 0,
      );
      
      // Cargar expedientes existentes
      final expRes = await AppSupabase.client
          .from('expedientes_legales')
          .select('*, prestamos(monto, clientes(nombre_completo))')
          .order('created_at', ascending: false)
          .limit(50);
      _expedientes = List<Map<String, dynamic>>.from(expRes);
      
      // Calcular estadísticas
      _estadisticas = {
        'total_morosos': _carteraVencida.length,
        'monto_total_vencido': _carteraVencida.fold<double>(0, (sum, m) => sum + m.saldoPendiente),
        'listos_demanda': _carteraVencida.where((m) => m.estadoLegal == 'LISTO_PARA_DEMANDA').length,
        'expedientes_activos': _expedientes.where((e) => e['estado'] != 'sentencia').length,
        'en_proceso_judicial': _expedientes.where((e) => e['estado'] == 'en_demanda').length,
      };
      
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Auditoría Legal",
      subtitle: "Evidencias y Expedientes",
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Estadísticas rápidas
                _buildEstadisticasRapidas(),
                
                // Tabs
                Container(
                  color: const Color(0xFF1E1E2C),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.orangeAccent,
                    labelColor: Colors.orangeAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.warning), text: "Cartera Vencida"),
                      Tab(icon: Icon(Icons.folder), text: "Expedientes"),
                      Tab(icon: Icon(Icons.gavel), text: "En Juicio"),
                      Tab(icon: Icon(Icons.checklist), text: "Checklist"),
                    ],
                  ),
                ),
                
                // Contenido
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabCarteraVencida(),
                      _buildTabExpedientes(),
                      _buildTabEnJuicio(),
                      _buildTabChecklist(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEstadisticasRapidas() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatMini(
            '${_estadisticas?['total_morosos'] ?? 0}',
            'Morosos',
            Colors.redAccent,
          )),
          Expanded(child: _buildStatMini(
            '\$${_formatMonto(_estadisticas?['monto_total_vencido'] ?? 0)}',
            'Vencido',
            Colors.orangeAccent,
          )),
          Expanded(child: _buildStatMini(
            '${_estadisticas?['listos_demanda'] ?? 0}',
            'Listos Demanda',
            Colors.purpleAccent,
          )),
          Expanded(child: _buildStatMini(
            '${_estadisticas?['en_proceso_judicial'] ?? 0}',
            'En Juicio',
            Colors.blueAccent,
          )),
        ],
      ),
    );
  }

  Widget _buildStatMini(String valor, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          )),
          Text(label, style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB: CARTERA VENCIDA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCarteraVencida() {
    if (_carteraVencida.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
            SizedBox(height: 15),
            Text('¡Sin cartera vencida!', 
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text('Todos los préstamos están al corriente',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _carteraVencida.length,
        itemBuilder: (context, index) {
          final moroso = _carteraVencida[index];
          return _buildMorosoCard(moroso);
        },
      ),
    );
  }

  Widget _buildMorosoCard(ReporteMoroso moroso) {
    final estadoColor = _getColorEstado(moroso.estadoLegal);
    
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: estadoColor.withOpacity(0.2),
                child: Text(
                  moroso.clienteNombre.isNotEmpty 
                      ? moroso.clienteNombre[0].toUpperCase() 
                      : '?',
                  style: TextStyle(color: estadoColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moroso.clienteNombre,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(moroso.clienteTelefono,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${moroso.diasMora} días',
                  style: TextStyle(color: estadoColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Info financiera
          Row(
            children: [
              Expanded(child: _buildInfoItem('Saldo', '\$${_formatMonto(moroso.saldoPendiente)}')),
              Expanded(child: _buildInfoItem('Intentos', '${moroso.intentosCobro}')),
              Expanded(child: _buildInfoItem('CURP', moroso.clienteCurp.isNotEmpty ? '✓' : '✗')),
            ],
          ),
          const SizedBox(height: 10),
          
          // Estado legal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_getIconEstado(moroso.estadoLegal), color: estadoColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLabelEstado(moroso.estadoLegal),
                    style: TextStyle(color: estadoColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          
          // Acciones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _verEvidencias(moroso.prestamoId),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Evidencias'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _generarExpediente(moroso),
                  icon: const Icon(Icons.gavel, size: 16),
                  label: const Text('Expediente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: estadoColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String valor) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB: EXPEDIENTES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabExpedientes() {
    if (_expedientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, color: Colors.white24, size: 60),
            const SizedBox(height: 15),
            const Text('Sin expedientes generados',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.add),
              label: const Text('Generar desde Cartera Vencida'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expedientes.length,
      itemBuilder: (context, index) {
        final exp = _expedientes[index];
        return _buildExpedienteCard(exp);
      },
    );
  }

  Widget _buildExpedienteCard(Map<String, dynamic> exp) {
    final estado = exp['estado'] ?? 'generado';
    final estadoColor = _getColorEstadoExpediente(estado);
    
    return PremiumCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: estadoColor.withOpacity(0.2),
          child: Icon(Icons.folder, color: estadoColor),
        ),
        title: Text(
          exp['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adeudo: \$${_formatMonto(exp['total_adeudado'] ?? 0)} • ${exp['dias_mora'] ?? 0} días mora',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                estado.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(color: estadoColor, fontSize: 10),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download, color: Colors.orangeAccent),
          onPressed: () => _descargarExpediente(exp),
        ),
        onTap: () => _verDetalleExpediente(exp),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB: EN JUICIO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabEnJuicio() {
    final enJuicio = _expedientes.where((e) => 
      e['estado'] == 'en_demanda' || e['estado'] == 'enviado_abogado'
    ).toList();

    if (enJuicio.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, color: Colors.white24, size: 60),
            SizedBox(height: 15),
            Text('Sin procesos judiciales activos',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: enJuicio.length,
      itemBuilder: (context, index) {
        final exp = enJuicio[index];
        return _buildJuicioCard(exp);
      },
    );
  }

  Widget _buildJuicioCard(Map<String, dynamic> exp) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: Colors.purpleAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exp['prestamos']?['clientes']?['nombre_completo'] ?? 'Cliente',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildJuicioInfo('Expediente Judicial', exp['numero_expediente_judicial'] ?? 'Pendiente'),
          _buildJuicioInfo('Juzgado', exp['juzgado'] ?? 'Por asignar'),
          _buildJuicioInfo('Abogado', exp['abogado_asignado'] ?? 'Sin asignar'),
          _buildJuicioInfo('Monto', '\$${_formatMonto(exp['total_adeudado'] ?? 0)}'),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _verSeguimiento(exp),
              icon: const Icon(Icons.timeline),
              label: const Text('Ver Seguimiento'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuicioInfo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB: CHECKLIST DE EVIDENCIAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabChecklist() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Checklist de Evidencias para Juicio',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Documentos y registros necesarios para presentar una demanda judicial exitosa:',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          
          _buildChecklistSection('📄 Documentos del Préstamo', [
            ChecklistItem('Contrato de préstamo firmado', 'Con firma digital y timestamp', true),
            ChecklistItem('Pagaré firmado', 'Título ejecutivo para cobro rápido', true),
            ChecklistItem('Tabla de amortización', 'Fechas y montos acordados', true),
            ChecklistItem('Comprobante de depósito', 'Prueba de entrega del dinero', true),
          ]),
          
          _buildChecklistSection('👤 Identificación del Cliente', [
            ChecklistItem('INE/IFE escaneada', 'Frente y reverso', true),
            ChecklistItem('CURP', 'Para identificación única', true),
            ChecklistItem('Comprobante de domicilio', 'Reciente, máximo 3 meses', true),
            ChecklistItem('RFC (opcional)', 'Para deducciones fiscales', false),
          ]),
          
          _buildChecklistSection('💰 Historial de Pagos', [
            ChecklistItem('Registro de todos los pagos', 'Con fecha, monto y método', true),
            ChecklistItem('Comprobantes de transferencia', 'Screenshots o PDFs bancarios', true),
            ChecklistItem('Estado de cuenta actualizado', 'Mostrando saldo pendiente', true),
            ChecklistItem('Cálculo de intereses moratorios', 'Según contrato', true),
          ]),
          
          _buildChecklistSection('📞 Gestiones de Cobro', [
            ChecklistItem('Registro de llamadas', 'Fecha, hora, resultado', true),
            ChecklistItem('Notificaciones de mora', 'Al menos 3 enviadas', true),
            ChecklistItem('Mensajes de cobranza', 'Chat, WhatsApp, SMS', true),
            ChecklistItem('Visitas documentadas', 'Con geolocalización', false),
            ChecklistItem('Promesas de pago incumplidas', 'Fechas y montos', false),
          ]),
          
          _buildChecklistSection('👥 Avales/Fiadores', [
            ChecklistItem('Carta de aval firmada', 'Aceptación de responsabilidad', true),
            ChecklistItem('INE del aval', 'Identificación oficial', true),
            ChecklistItem('Datos de contacto verificados', 'Teléfono, dirección', true),
            ChecklistItem('Notificaciones al aval', 'Informándole de la mora', true),
          ]),
          
          _buildChecklistSection('🔒 Integridad de Datos', [
            ChecklistItem('Hash SHA-256 de documentos', 'Prueba de no alteración', true),
            ChecklistItem('Timestamps certificados', 'Fecha/hora verificables', true),
            ChecklistItem('Registro de IP de firmas', 'Trazabilidad de acciones', true),
            ChecklistItem('Auditoría de acceso', 'Quién vio/modificó qué', true),
          ]),
          
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.greenAccent),
                    SizedBox(width: 10),
                    Text('Recomendación Legal',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Para una demanda efectiva, asegúrate de tener al menos:\n'
                  '• Contrato O pagaré firmado\n'
                  '• 3+ intentos de cobro documentados\n'
                  '• 2+ notificaciones de mora\n'
                  '• Estado de cuenta con cálculo de adeudo\n\n'
                  'El sistema genera automáticamente el hash SHA-256 de todos los documentos '
                  'para garantizar su integridad ante un juez.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(String titulo, List<ChecklistItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(titulo, style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 10),
        ...items.map((item) => _buildChecklistItem(item)),
      ],
    );
  }

  Widget _buildChecklistItem(ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252536),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            item.requerido ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.requerido ? Colors.greenAccent : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, style: const TextStyle(color: Colors.white)),
                Text(item.descripcion, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (item.requerido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Requerido',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _verEvidencias(String prestamoId) async {
    final resumen = await _auditoriaService.obtenerResumenEvidencias(prestamoId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open, color: Colors.orangeAccent),
                const SizedBox(width: 10),
                const Text('Resumen de Evidencias',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: resumen.listoParaDemanda 
                        ? Colors.greenAccent.withOpacity(0.2)
                        : Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${resumen.porcentajeCompletitud.toStringAsFixed(0)}% Completo',
                    style: TextStyle(
                      color: resumen.listoParaDemanda ? Colors.greenAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildEvidenciaRow('Contrato firmado', resumen.contratoFirmado),
            _buildEvidenciaRow('Pagaré firmado', resumen.pagareFirmado),
            _buildEvidenciaRow('INE del cliente', resumen.tieneIneCliente),
            _buildEvidenciaRow('Comprobante domicilio', resumen.tieneComprobanteDomicilio),
            _buildEvidenciaRow('Intentos de cobro (3+)', resumen.numIntentosCobro >= 3),
            _buildEvidenciaRow('Notificaciones mora (2+)', resumen.numNotificacionesMora >= 2),
            _buildEvidenciaRow('Avales con documentos', resumen.avalesConDocumentos > 0),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: resumen.listoParaDemanda ? () {
                  Navigator.pop(context);
                  // Generar expediente
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(resumen.listoParaDemanda 
                    ? 'Listo para Demanda ✓' 
                    : 'Faltan evidencias'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenciaRow(String label, bool tiene) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            tiene ? Icons.check_circle : Icons.cancel,
            color: tiene ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(
            color: tiene ? Colors.white : Colors.white54,
          )),
        ],
      ),
    );
  }

  Future<void> _generarExpediente(ReporteMoroso moroso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Generar Expediente Legal',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Generar expediente legal para ${moroso.clienteNombre}?\n\n'
          'Esto recopilará toda la evidencia disponible y generará un hash '
          'de integridad para uso en juicio.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Generar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Necesitamos el cliente_id - por ahora usamos el prestamoId para buscarlo
      final prestamo = await AppSupabase.client
          .from('prestamos')
          .select('cliente_id')
          .eq('id', moroso.prestamoId)
          .single();
      
      final expediente = await _auditoriaService.generarExpedienteLegal(
        prestamoId: moroso.prestamoId,
        clienteId: prestamo['cliente_id'],
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Expediente generado\nHash: ${expediente.hashExpediente?.substring(0, 16)}...'),
          backgroundColor: Colors.greenAccent,
          duration: const Duration(seconds: 5),
        ),
      );

      _cargarDatos(); // Recargar
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _descargarExpediente(Map<String, dynamic> exp) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando PDF del expediente...')),
    );
    // TODO: Implementar generación de PDF
  }

  void _verDetalleExpediente(Map<String, dynamic> exp) {
    // TODO: Navegar a detalle
  }

  void _verSeguimiento(Map<String, dynamic> exp) {
    // TODO: Mostrar timeline de seguimiento
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _formatMonto(double monto) {
    return monto.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'LISTO_PARA_DEMANDA': return Colors.redAccent;
      case 'PREPARAR_EXPEDIENTE': return Colors.purpleAccent;
      case 'COBRANZA_PREJUDICIAL': return Colors.orangeAccent;
      case 'COBRANZA_EXTRAJUDICIAL': return Colors.amber;
      default: return Colors.blueAccent;
    }
  }

  IconData _getIconEstado(String estado) {
    switch (estado) {
      case 'LISTO_PARA_DEMANDA': return Icons.gavel;
      case 'PREPARAR_EXPEDIENTE': return Icons.folder_special;
      case 'COBRANZA_PREJUDICIAL': return Icons.warning;
      case 'COBRANZA_EXTRAJUDICIAL': return Icons.phone;
      default: return Icons.schedule;
    }
  }

  String _getLabelEstado(String estado) {
    switch (estado) {
      case 'LISTO_PARA_DEMANDA': return 'Listo para presentar demanda';
      case 'PREPARAR_EXPEDIENTE': return 'Preparar expediente legal';
      case 'COBRANZA_PREJUDICIAL': return 'Cobranza prejudicial';
      case 'COBRANZA_EXTRAJUDICIAL': return 'Cobranza extrajudicial';
      default: return 'Cobranza administrativa';
    }
  }

  Color _getColorEstadoExpediente(String estado) {
    switch (estado) {
      case 'en_demanda': return Colors.redAccent;
      case 'enviado_abogado': return Colors.purpleAccent;
      case 'sentencia': return Colors.greenAccent;
      default: return Colors.orangeAccent;
    }
  }
}

class ChecklistItem {
  final String nombre;
  final String descripcion;
  final bool requerido;

  ChecklistItem(this.nombre, this.descripcion, this.requerido);
}

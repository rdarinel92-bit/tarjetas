// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

/// Generic table viewer for simple admin routes.
class SimpleTableScreen extends StatefulWidget {
  final String title;
  final String table;
  final Map<String, dynamic>? filters;
  final String? orderBy;
  final bool ascending;
  final int limit;
  final String? emptyMessage;

  const SimpleTableScreen({
    super.key,
    required this.title,
    required this.table,
    this.filters,
    this.orderBy,
    this.ascending = false,
    this.limit = 200,
    this.emptyMessage,
  });

  @override
  State<SimpleTableScreen> createState() => _SimpleTableScreenState();
}

class _SimpleTableScreenState extends State<SimpleTableScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final query = AppSupabase.client.from(widget.table).select();
      if (widget.filters != null) {
        for (final entry in widget.filters!.entries) {
          query.eq(entry.key, entry.value);
        }
      }
      if (widget.orderBy != null) {
        query.order(widget.orderBy!, ascending: widget.ascending);
      }
      if (widget.limit > 0) {
        query.limit(widget.limit);
      }

      final res = await query;
      _rows = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _primaryText(Map<String, dynamic> row) {
    const keys = [
      'titulo',
      'nombre',
      'folio',
      'numero',
      'codigo',
      'descripcion',
      'id',
    ];
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return row.isNotEmpty ? row.values.first.toString() : 'Registro';
  }

  String _secondaryText(Map<String, dynamic> row) {
    final estado = row['estado'] ?? row['status'] ?? row['tipo'];
    final fecha = row['fecha'] ?? row['created_at'] ?? row['fecha_programada'];
    final fechaTxt = _formatFecha(fecha);
    if (estado != null && fechaTxt != null) {
      return '$estado • $fechaTxt';
    }
    if (estado != null) return estado.toString();
    if (fechaTxt != null) return fechaTxt;
    return '';
  }

  String? _formatFecha(dynamic value) {
    if (value == null) return null;
    try {
      final dt = DateTime.parse(value.toString());
      return _dateFormat.format(dt);
    } catch (_) {
      return null;
    }
  }

  void _mostrarDetalle(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: row.entries.map((entry) {
          final value = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    entry.key,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
                Expanded(
                  child: Text(
                    value == null ? '-' : value.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: widget.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _cargar,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.withOpacity(0.8)),
                  ),
                )
              : _rows.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyMessage ?? 'Sin registros',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final subtitle = _secondaryText(row);
                        return Card(
                          color: const Color(0xFF1A1A2E),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              _primaryText(row),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: subtitle.isEmpty
                                ? null
                                : Text(
                                    subtitle,
                                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => _mostrarDetalle(row),
                          ),
                        );
                      },
                    ),
    );
  }
}

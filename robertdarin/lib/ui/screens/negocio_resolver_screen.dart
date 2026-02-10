// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';

/// Resolves a negocio_id before showing a target screen.
class NegocioResolverScreen extends StatefulWidget {
  final Widget Function(String negocioId) builder;
  final String? title;

  const NegocioResolverScreen({
    super.key,
    required this.builder,
    this.title,
  });

  @override
  State<NegocioResolverScreen> createState() => _NegocioResolverScreenState();
}

class _NegocioResolverScreenState extends State<NegocioResolverScreen> {
  bool _loading = true;
  String? _negocioId;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user != null) {
        final empleado = await AppSupabase.client
            .from('empleados')
            .select('negocio_id')
            .eq('usuario_id', user.id)
            .maybeSingle();
        _negocioId = empleado?['negocio_id'];
      }

      if (_negocioId == null) {
        final negocio = await AppSupabase.client
            .from('negocios')
            .select('id')
            .limit(1)
            .maybeSingle();
        _negocioId = negocio?['id'];
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: widget.title != null ? AppBar(title: Text(widget.title!)) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_negocioId == null) {
      return Scaffold(
        appBar: widget.title != null ? AppBar(title: Text(widget.title!)) : null,
        body: const Center(child: Text('No se pudo determinar el negocio.')),
      );
    }

    return widget.builder(_negocioId!);
  }
}

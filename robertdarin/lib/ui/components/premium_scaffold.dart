import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

class PremiumScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool wrapInScrollView; // NUEVO: control para envolver en scroll

  const PremiumScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.showBackButton = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.wrapInScrollView = false, // Por defecto NO envolver (las pantallas manejan su scroll)
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final parentScaffold = Scaffold.maybeOf(context);
    final hasDrawer = parentScaffold?.hasDrawer ?? false;

    // Determinar el leading widget
    Widget? leadingWidget;
    if (hasDrawer) {
      // Si hay drawer padre, mostrar boton de menu
      leadingWidget = IconButton(
        icon: const Icon(Icons.menu, color: Colors.orangeAccent, size: 26),
        onPressed: () => parentScaffold?.openDrawer(),
      );
    } else if (canPop && showBackButton) {
      // Si puede hacer pop, mostrar back button
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    // Widget del body - solo envolver si se solicita explícitamente
    Widget bodyContent = wrapInScrollView 
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: body,
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: body,
          );

    // Si estamos dentro de un Scaffold con drawer (AppShell), 
    // no crear otro Scaffold, solo retornar el contenido con AppBar
    if (hasDrawer) {
      return Column(
        children: [
          // Custom AppBar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 8,
              right: 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                // Menu button
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.orangeAccent, size: 26),
                  onPressed: () => parentScaffold?.openDrawer(),
                ),
                // Title
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                // Actions
                ...?actions,
                IconButton(
                  tooltip: "Cerrar Sesion",
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                  onPressed: () {
                    Provider.of<AuthViewModel>(context, listen: false).cerrarSesion(context);
                  },
                ),
              ],
            ),
          ),
          // Body - NO envolver automáticamente en scroll
          Expanded(child: bodyContent),
        ],
      );
    }

    // Si no hay drawer padre, usar Scaffold normal
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: leadingWidget,
        title: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
          ],
        ),
        actions: [
          ...?actions,
          IconButton(
            tooltip: "Cerrar Sesion",
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              Provider.of<AuthViewModel>(context, listen: false).cerrarSesion(context);
            },
          ),
        ],
      ),
      body: SafeArea(child: bodyContent),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

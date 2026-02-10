// ignore_for_file: deprecated_member_use
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // V10.50 OAuth
import '../viewmodels/auth_viewmodel.dart';
import '../components/robert_darin_logo.dart'; // V10.52 Logo profesional
import '../../core/supabase_client.dart';

/// Pantalla de Login Premium para Uniko
/// Incluye: Login elegante, recuperación de contraseña, animaciones W11
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _cargandoLogin = false;
  bool _mostrarAnimacionCarga = false;
  String? _errorMsg;

  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de pulso
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void mostrarError(String mensaje) {
    setState(() => _errorMsg = mensaje);
  }

  Future<void> iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargandoLogin = true;
      _errorMsg = null;
    });

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final email = emailController.text.trim();
    final password = passwordController.text;

    await authViewModel.iniciarSesion(email, password, context);

    if (authViewModel.error != null && mounted) {
      setState(() {
        _errorMsg = authViewModel.error;
        _cargandoLogin = false;
      });
    } else if (mounted) {
      // Mostrar animación de carga estilo Windows 11
      setState(() => _mostrarAnimacionCarga = true);

      // Esperar un momento para mostrar la animación
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        await authViewModel.navegarSegunRol(context);
      }
    }
  }

  Future<void> _recuperarContrasena() async {
    final emailRecuperar = TextEditingController(text: emailController.text);

    // PASO 1: Solicitar email
    final confirmarEmail = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text("Recuperar Contraseña", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ingresa tu correo electrónico y te enviaremos un código de 6 dígitos para verificar tu identidad.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailRecuperar,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Correo electrónico",
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Colors.cyanAccent),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text("Enviar código"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmarEmail != true || emailRecuperar.text.isEmpty) return;
    
    final email = emailRecuperar.text.trim();

    // Mostrar loading mientras envía OTP
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent)),
    );

    try {
      // Enviar OTP por email usando Supabase
      await AppSupabase.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // No crear usuario nuevo, solo recuperar
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      // PASO 2: Solicitar código OTP
      final otpController = TextEditingController();
      final codigoValido = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.pin, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text("Ingresa el código", 
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enviamos un código de 6 dígitos a:\n$email",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                "⏱️ El código expira en 10 minutos",
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 28, 
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "000000",
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
                  counterText: "",
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text("Verificar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );

      if (codigoValido != true || otpController.text.length != 6) return;

      // Mostrar loading mientras verifica
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );

      // Verificar OTP con Supabase
      final response = await AppSupabase.client.auth.verifyOTP(
        email: email,
        token: otpController.text,
        type: OtpType.email,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (response.session != null) {
        // PASO 3: OTP válido, solicitar nueva contraseña
        final nuevaPassController = TextEditingController();
        final confirmarPassController = TextEditingController();
        bool obscure1 = true;
        bool obscure2 = true;

        final cambiarPass = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_open, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Nueva Contraseña", 
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "✅ Código verificado. Ahora crea tu nueva contraseña.",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nuevaPassController,
                    obscureText: obscure1,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nueva contraseña",
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyanAccent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure1 ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white38,
                        ),
                        onPressed: () => setDialogState(() => obscure1 = !obscure1),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmarPassController,
                    obscureText: obscure2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Confirmar contraseña",
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyanAccent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure2 ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white38,
                        ),
                        onPressed: () => setDialogState(() => obscure2 = !obscure2),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Mínimo 6 caracteres",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (nuevaPassController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("La contraseña debe tener mínimo 6 caracteres"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (nuevaPassController.text != confirmarPassController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Las contraseñas no coinciden"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        );

        if (cambiarPass != true) {
          // Cerrar sesión si cancela
          await AppSupabase.client.auth.signOut();
          return;
        }

        // Actualizar contraseña
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent)),
        );

        await AppSupabase.client.auth.updateUser(
          UserAttributes(password: nuevaPassController.text),
        );

        // Cerrar sesión después de cambiar contraseña
        await AppSupabase.client.auth.signOut();

        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(child: Text("¡Contraseña actualizada! Ya puedes iniciar sesión")),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        throw Exception("Código inválido o expirado");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading si hay error
        String errorMsg = e.toString();
        if (errorMsg.contains("User not found")) {
          errorMsg = "No existe una cuenta con este correo";
        } else if (errorMsg.contains("invalid") || errorMsg.contains("expired")) {
          errorMsg = "Código inválido o expirado. Intenta de nuevo.";
        } else if (errorMsg.contains("rate limit")) {
          errorMsg = "Demasiados intentos. Espera unos minutos.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está mostrando animación de carga
    if (_mostrarAnimacionCarga) {
      return _buildPantallaCargaW11();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Logo profesional Robert Darin V10.52
                  const RobertDarinLogo(
                    size: 100,
                    animated: true,
                    showText: true,
                    showTagline: true,
                  ),

                  const SizedBox(height: 45),

                  // Campo Email
                  _buildTextField(
                    controller: emailController,
                    label: "Correo electrónico",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Ingresa tu correo";
                      if (!v.contains('@')) return "Correo inválido";
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Campo Password
                  _buildTextField(
                    controller: passwordController,
                    label: "Contraseña",
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white38,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return "Ingresa tu contraseña";
                      if (v.length < 4) return "Mínimo 4 caracteres";
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // Olvidé mi contraseña
                  Center(
                    child: TextButton(
                      onPressed: _recuperarContrasena,
                      child: const Text(
                        "¿Olvidaste tu contraseña?",
                        style:
                            TextStyle(color: Colors.cyanAccent, fontSize: 13),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMsg != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Botón Login
                  _buildLoginButton(),

                  const SizedBox(height: 20),
                  
                  // Link para colaboradores
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_alt_outlined, color: Color(0xFF3B82F6), size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              "¿Eres colaborador?",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/registro-colaborador'),
                          child: const Text(
                            "Registrarme con código de invitación",
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Enlaces legales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/terminos-condiciones'),
                        child: const Text(
                          "Términos",
                          style: TextStyle(
                            color: Colors.white38, 
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(" • ", style: TextStyle(color: Colors.white24, fontSize: 11)),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/politica-privacidad'),
                        child: const Text(
                          "Privacidad",
                          style: TextStyle(
                            color: Colors.white38, 
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Footer
                  const Text(
                    "© 2026 Robert-Darin • Todos los derechos reservados",
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _cargandoLogin ? null : iniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          foregroundColor: const Color(0xFF0F172A),
          disabledBackgroundColor: Colors.cyanAccent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          shadowColor: Colors.cyanAccent.withOpacity(0.5),
        ),
        child: _cargandoLogin
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF0F172A),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "INICIAR SESIÓN",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Pantalla de carga estilo Windows 11
  Widget _buildPantallaCargaW11() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo con animación de carga
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Círculo exterior girando
                    Transform.rotate(
                      angle: _rotateController.value * 2 * 3.14159,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              const Color(0xFF00D9FF).withOpacity(0),
                              const Color(0xFF00D9FF),
                              const Color(0xFF8B5CF6),
                              const Color(0xFF00D9FF).withOpacity(0),
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Círculo interior con logo
                    Container(
                      width: 115,
                      height: 115,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0D0D14),
                      ),
                      child: const Center(
                        child: RobertDarinLogo.icon(size: 80),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              "Iniciando sesión...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            // Puntos de carga animados
            _buildDotsLoader(),
          ],
        ),
      ),
    );
  }

  Widget _buildDotsLoader() {
    return SizedBox(
      width: 60,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 200)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withOpacity(0.3 + (value * 0.7)),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // V10.50 - LOGIN SOCIAL (Google, Apple, etc.)
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildSocialDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white24, Colors.transparent],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "O continuar con",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white24, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Google
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          label: "Google",
          color: const Color(0xFFDB4437),
          onTap: _loginWithGoogle,
        ),
        const SizedBox(width: 16),
        // Apple (solo iOS/macOS)
        if (_isAppleAvailable)
          _buildSocialButton(
            icon: Icons.apple,
            label: "Apple",
            color: Colors.white,
            onTap: _loginWithApple,
          ),
      ],
    );
  }

  bool get _isAppleAvailable {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _cargandoLogin = true;
      _errorMsg = null;
    });

    try {
      await AppSupabase.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.robertdarin://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
      // El flujo OAuth redirige automáticamente
      // La sesión se detectará en el AuthViewModel
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = "Error al iniciar sesión con Google: $e";
          _cargandoLogin = false;
        });
      }
    }
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _cargandoLogin = true;
      _errorMsg = null;
    });

    try {
      await AppSupabase.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'io.supabase.robertdarin://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = "Error al iniciar sesión con Apple: $e";
          _cargandoLogin = false;
        });
      }
    }
  }
}

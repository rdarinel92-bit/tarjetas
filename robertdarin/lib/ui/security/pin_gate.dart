import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_navigator.dart';
import '../../core/supabase_client.dart';
import '../navigation/app_routes.dart';
import 'pin_lock_service.dart';

class PinGate extends StatefulWidget {
  const PinGate({super.key, required this.child});

  final Widget child;

  @override
  State<PinGate> createState() => _PinGateState();
}

enum PinGateMode { setup, unlock }

class _PinGateState extends State<PinGate> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  bool _showLock = false;
  bool _authenticated = false;
  String? _userId;
  String? _email;
  PinGateMode _mode = PinGateMode.unlock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _handleAuthChange(event);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLockState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncLockState();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _authenticated = false;
    }
  }

  Future<void> _handleAuthChange(AuthState event) async {
    if (!mounted) return;
    if (event.event == AuthChangeEvent.signedOut) {
      setState(() {
        _showLock = false;
        _authenticated = false;
        _userId = null;
        _email = null;
      });
      return;
    }
    await _syncLockState();
  }

  Future<void> _syncLockState() async {
    if (!mounted) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (_showLock) {
        setState(() {
          _showLock = false;
          _authenticated = false;
          _userId = null;
          _email = null;
        });
      }
      return;
    }

    _userId = user.id;
    _email = user.email;

    final hasPin = await PinLockService.instance.isPinSet(user.id);
    if (!hasPin) {
      setState(() {
        _mode = PinGateMode.setup;
        _showLock = true;
        _authenticated = false;
      });
      return;
    }

    if (!_authenticated) {
      setState(() {
        _mode = PinGateMode.unlock;
        _showLock = true;
      });
    }
  }

  void _onUnlocked() {
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _showLock = false;
    });
  }

  Future<void> _onSignOut() async {
    Object? error;
    try {
      await AppSupabase.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      error = e;
    }

    final session = AppSupabase.client.auth.currentSession;
    if (session != null) {
      throw error ?? Exception('No se pudo cerrar sesion.');
    }

    if (!mounted) return;
    setState(() {
      _showLock = false;
      _authenticated = false;
      _userId = null;
      _email = null;
    });

    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showLock && _userId != null)
          Positioned.fill(
            child: PinLockOverlay(
              userId: _userId!,
              email: _email,
              mode: _mode,
              onUnlocked: _onUnlocked,
              onSignOut: _onSignOut,
            ),
          ),
      ],
    );
  }
}

class PinLockOverlay extends StatefulWidget {
  const PinLockOverlay({
    super.key,
    required this.userId,
    required this.mode,
    required this.onUnlocked,
    required this.onSignOut,
    this.email,
  });

  final String userId;
  final String? email;
  final PinGateMode mode;
  final VoidCallback onUnlocked;
  final Future<void> Function() onSignOut;

  @override
  State<PinLockOverlay> createState() => _PinLockOverlayState();
}

class _PinLockOverlayState extends State<PinLockOverlay> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const int _pinMinLength = 4;
  static const int _pinMaxLength = 6;

  bool _loading = false;
  String? _error;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  int _attempts = 0;
  DateTime? _blockedUntil;

  PinGateMode _mode = PinGateMode.unlock;
  bool _confirmStep = false;
  String? _firstPin;
  final List<String> _digits = <String>[];
  DateTime? _inputLockedUntil;
  bool _autoBioAttempted = false;

  bool get _isSetup => _mode == PinGateMode.setup;
  bool get _isConfirmStep => _isSetup && _confirmStep;
  String get _pinValue => _digits.join();
  bool get _isBlocked => _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);
  bool get _inputLocked =>
      _inputLockedUntil != null && DateTime.now().isBefore(_inputLockedUntil!);
  bool get _keypadEnabled => !_loading && !_isBlocked && !_inputLocked;
  bool get _canSubmit => _pinValue.length >= _pinMinLength && _keypadEnabled;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _initBiometrics();
  }

  @override
  void didUpdateWidget(covariant PinLockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      setState(() {
        _mode = widget.mode;
        _resetFlow();
      });
      _autoBioAttempted = false;
      _maybeAutoBiometric();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final enabled = await PinLockService.instance.isBiometricEnabled(widget.userId);
      if (!mounted) return;
      setState(() {
        _bioAvailable = supported && canCheck;
        _bioEnabled = enabled;
      });
      _maybeAutoBiometric();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bioAvailable = false;
        _bioEnabled = false;
      });
    }
  }

  void _maybeAutoBiometric() {
    if (_autoBioAttempted) return;
    if (_isSetup) return;
    if (!_bioAvailable || !_bioEnabled) return;
    _autoBioAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryBiometricUnlock();
    });
  }

  void _resetFlow() {
    _error = null;
    _firstPin = null;
    _confirmStep = false;
    _digits.clear();
    _attempts = 0;
    _blockedUntil = null;
    _inputLockedUntil = null;
  }

  void _lockInputBriefly([Duration duration = const Duration(milliseconds: 180)]) {
    _inputLockedUntil = DateTime.now().add(duration);
    Future.delayed(duration, () {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _tryBiometricUnlock() async {
    if (!_bioAvailable || !_bioEnabled) return;
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Desbloquear con biometria',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'No se pudo verificar la biometria.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Biometria no disponible.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (!_bioAvailable) return;
    if (!value) {
      await PinLockService.instance.setBiometricEnabled(widget.userId, false);
      if (!mounted) return;
      setState(() => _bioEnabled = false);
      return;
    }
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Activar biometria',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        await PinLockService.instance.setBiometricEnabled(widget.userId, true);
        if (!mounted) return;
        setState(() => _bioEnabled = true);
      } else {
        setState(() => _error = 'No se pudo activar biometria.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Biometria no disponible.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  Future<void> _unlockWithPin() async {
    final now = DateTime.now();
    if (_isBlocked) {
      final seconds = _blockedUntil!.difference(now).inSeconds;
      _setError('Bloqueado $seconds s por intentos fallidos.');
      return;
    }

    final pin = _pinValue;
    if (pin.length < _pinMinLength || pin.length > _pinMaxLength) {
      _setError('PIN debe tener 4 a 6 digitos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await PinLockService.instance.verifyPin(widget.userId, pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }

    _attempts += 1;
    if (_attempts >= 5) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _attempts = 0;
      setState(() {
        _loading = false;
        _error = 'Demasiados intentos. Espera 30 segundos.';
        _digits.clear();
      });
      return;
    }

    setState(() {
      _loading = false;
      _error = 'PIN incorrecto.';
      _digits.clear();
    });
  }

  Future<void> _savePin() async {
    final pin = _pinValue;
    if (pin.length < _pinMinLength || pin.length > _pinMaxLength) {
      _setError('PIN debe tener 4 a 6 digitos.');
      return;
    }

    if (!_confirmStep) {
      setState(() {
        _firstPin = pin;
        _confirmStep = true;
        _error = null;
        _digits.clear();
      });
      _lockInputBriefly();
      return;
    }

    if (_firstPin != pin) {
      setState(() {
        _error = 'Los PIN no coinciden.';
        _firstPin = null;
        _confirmStep = false;
        _digits.clear();
      });
      _lockInputBriefly();
      return;
    }

    setState(() => _loading = true);
    try {
      await PinLockService.instance.savePin(
        widget.userId,
        pin,
        biometricsEnabled: _bioEnabled,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo guardar el PIN.';
        _digits.clear();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onUnlocked();
  }

  Future<void> _reauthAndResetPin() async {
    if (_loading) return;

    final email = widget.email?.trim();
    if (email == null || email.isEmpty) {
      setState(() => _error = 'No hay email disponible para reautenticar.');
      return;
    }

    final passCtrl = TextEditingController();
    final dialogContext = appNavigatorKey.currentContext ?? context;
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        title: const Text('Reautenticar'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Contrasena'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    final password = passCtrl.text;
    passCtrl.dispose();

    if (confirmed != true) return;
    if (password.isEmpty) {
      _setError('Ingresa tu contrasena.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await AppSupabase.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        throw const AuthException('Credenciales invalidas');
      }
      await PinLockService.instance.clearPin(widget.userId);
      if (!mounted) return;
      setState(() {
        _mode = PinGateMode.setup;
        _bioEnabled = false;
        _resetFlow();
      });
      _lockInputBriefly();
    } on AuthException {
      if (!mounted) return;
      setState(() => _error = 'Contrasena incorrecta.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo verificar la contrasena.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cerrar sesion.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _appendDigit(String digit) {
    if (!_keypadEnabled || _digits.length >= _pinMaxLength) return;
    setState(() {
      _digits.add(digit);
      _error = null;
    });
  }

  void _removeDigit() {
    if (!_keypadEnabled || _digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  void _clearPinInput() {
    if (!_keypadEnabled || _digits.isEmpty) return;
    setState(() {
      _digits.clear();
      _error = null;
    });
  }

  Widget _buildPinDots() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinMaxLength, (index) {
          final filled = index < _digits.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: filled ? Colors.cyanAccent : Colors.white24,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeyButton({
    String? label,
    IconData? icon,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) {
    return SizedBox(
      height: 52,
      child: TextButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.06),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: icon != null
            ? Icon(icon)
            : Text(
                label ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildKeypad() {
    return AbsorbPointer(
      absorbing: !_keypadEnabled,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKeyButton(label: '1', onPressed: () => _appendDigit('1'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '2', onPressed: () => _appendDigit('2'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '3', onPressed: () => _appendDigit('3'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildKeyButton(label: '4', onPressed: () => _appendDigit('4'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '5', onPressed: () => _appendDigit('5'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '6', onPressed: () => _appendDigit('6'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildKeyButton(label: '7', onPressed: () => _appendDigit('7'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '8', onPressed: () => _appendDigit('8'))),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '9', onPressed: () => _appendDigit('9'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: SizedBox(height: 52)),
              const SizedBox(width: 8),
              Expanded(child: _buildKeyButton(label: '0', onPressed: () => _appendDigit('0'))),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKeyButton(
                  label: 'DEL',
                  onPressed: _removeDigit,
                  onLongPress: _clearPinInput,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSetup ? 'Configura tu PIN' : 'Bloqueo de seguridad';
    final subtitle = _isSetup
        ? (_isConfirmStep ? 'Confirma tu PIN' : 'Crea un PIN de 4 a 6 digitos')
        : 'Ingresa tu PIN para continuar';

    return Material(
      color: const Color(0xFF0F172A).withOpacity(0.95),
      child: WillPopScope(
        onWillPop: () async => false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 48, color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildPinDots(),
                    const SizedBox(height: 12),
                    _buildKeypad(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isSetup && _bioAvailable)
                      SwitchListTile.adaptive(
                        value: _bioEnabled,
                        onChanged: _loading ? null : _toggleBiometrics,
                        title: const Text(
                          'Usar biometria',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Huella o FaceID si esta disponible',
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                        activeColor: Colors.cyanAccent,
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canSubmit
                            ? (_isSetup ? _savePin : _unlockWithPin)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isSetup ? 'Guardar PIN' : 'Desbloquear'),
                      ),
                    ),
                    if (!_isSetup && _bioAvailable && _bioEnabled) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _tryBiometricUnlock,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Usar biometria'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            side: const BorderSide(color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                    ],
                    if (!_isSetup) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : _reauthAndResetPin,
                        child: const Text('Olvide mi PIN', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _handleSignOut,
                        child: const Text('Cerrar sesion', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

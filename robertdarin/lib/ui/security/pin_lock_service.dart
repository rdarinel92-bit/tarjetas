import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLockService {
  PinLockService._();

  static final PinLockService instance = PinLockService._();

  static const _storage = FlutterSecureStorage();
  final Random _rng = Random.secure();
  bool _fallbackToPrefs = false;

  String _saltKey(String userId) => 'pin_salt_$userId';
  String _hashKey(String userId) => 'pin_hash_$userId';
  String _bioKey(String userId) => 'pin_bio_$userId';

  Future<bool> isPinSet(String userId) async {
    final hash = await _read(_hashKey(userId));
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePin(
    String userId,
    String pin, {
    bool biometricsEnabled = false,
  }) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _write(_saltKey(userId), salt);
    await _write(_hashKey(userId), hash);
    await _write(_bioKey(userId), biometricsEnabled ? '1' : '0');
  }

  Future<bool> verifyPin(String userId, String pin) async {
    final salt = await _read(_saltKey(userId));
    final hash = await _read(_hashKey(userId));
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) return false;
    final candidate = _hashPin(pin, salt);
    return candidate == hash;
  }

  Future<void> clearPin(String userId) async {
    await _delete(_saltKey(userId));
    await _delete(_hashKey(userId));
    await _delete(_bioKey(userId));
  }

  Future<bool> isBiometricEnabled(String userId) async {
    final raw = await _read(_bioKey(userId));
    return raw == '1';
  }

  Future<void> setBiometricEnabled(String userId, bool enabled) async {
    await _write(_bioKey(userId), enabled ? '1' : '0');
  }

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<String?> _read(String key) async {
    if (!_fallbackToPrefs) {
      try {
        return await _storage.read(key: key);
      } catch (_) {
        _fallbackToPrefs = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _write(String key, String value) async {
    if (!_fallbackToPrefs) {
      try {
        await _storage.write(key: key, value: value);
        return;
      } catch (_) {
        _fallbackToPrefs = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _delete(String key) async {
    if (!_fallbackToPrefs) {
      try {
        await _storage.delete(key: key);
        return;
      } catch (_) {
        _fallbackToPrefs = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

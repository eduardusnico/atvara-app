import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Generates a stable browser fingerprint using device/browser properties.
/// The fingerprint is SHA-256 hashed and cached for the session.
class FingerprintService {
  static String? _cached;

  static Future<String> getFingerprint() async {
    if (_cached != null) return _cached!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final webInfo = await deviceInfo.webBrowserInfo;

      final components = [
        webInfo.userAgent ?? 'unknown_ua',
        webInfo.language ?? 'unknown_lang',
        webInfo.platform ?? 'unknown_platform',
        webInfo.vendor ?? 'unknown_vendor',
        (webInfo.hardwareConcurrency ?? 0).toString(),
        (webInfo.maxTouchPoints ?? 0).toString(),
        webInfo.appVersion ?? 'unknown_version',
      ].join('|||');

      final bytes = utf8.encode(components);
      final hash = sha256.convert(bytes);
      _cached = hash.toString();
    } catch (_) {
      // Fallback fingerprint if device info fails
      final fallback = DateTime.now().millisecondsSinceEpoch.toString();
      _cached = sha256.convert(utf8.encode(fallback)).toString();
    }

    return _cached!;
  }
}

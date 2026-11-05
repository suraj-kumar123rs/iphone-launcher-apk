import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the Kotlin side (MainActivity.kt).
class Native {
  static const _ch = MethodChannel('lumen/native');
  static VoidCallback? onHome;
  static VoidCallback? onAppsChanged;

  static void init() {
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'home':
          onHome?.call();
        case 'appsChanged':
          onAppsChanged?.call();
      }
      return null;
    });
  }

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('Native.$method failed: $e');
      return null;
    }
  }

  static Future<List<Map<String, Object?>>> getApps() async {
    final r = await _call<List<Object?>>('getApps');
    return (r ?? const []).map((e) => Map<String, Object?>.from(e as Map)).toList();
  }

  static Future<List<String>> defaults() async =>
      ((await _call<List<Object?>>('defaults')) ?? const []).map((e) => '$e').toList();

  static Future<bool> launch(String pkg, [Rect? from]) async {
    final args = <String, Object?>{'pkg': pkg};
    if (from != null) {
      args.addAll({'x': from.left, 'y': from.top, 'w': from.width, 'h': from.height});
    }
    return (await _call<bool>('launch', args)) ?? false;
  }

  static Future<void> appInfo(String pkg) => _call('appInfo', {'pkg': pkg});
  static Future<void> uninstall(String pkg) => _call('uninstall', {'pkg': pkg});
  static Future<bool> expandNotifications() async => (await _call<bool>('expandNotifications')) ?? false;
  static Future<void> homeSettings() => _call('homeSettings');
  static Future<bool> isDefault() async => (await _call<bool>('isDefault')) ?? false;
  static Future<String?> pickWallpaper() => _call<String>('pickWallpaper');

  static Future<Map<String, Object?>> battery() async {
    final r = await _call<Map<Object?, Object?>>('battery');
    return r == null ? {} : r.map((k, v) => MapEntry('$k', v));
  }

  static Future<Map<String, Object?>> status() async {
    final r = await _call<Map<Object?, Object?>>('status');
    return r == null ? {} : r.map((k, v) => MapEntry('$k', v));
  }

  static Future<bool> setTorch(bool on) async => (await _call<bool>('setTorch', {'on': on})) ?? false;
  static Future<bool> setBrightness(double v) async => (await _call<bool>('setBrightness', {'v': v})) ?? false;
  static Future<void> requestWrite() => _call('requestWrite');
  static Future<void> setVolume(double v) => _call('setVolume', {'v': v});
  static Future<void> mediaKey(String key) => _call('mediaKey', {'key': key});
  static Future<bool> openPanel(String kind) async => (await _call<bool>('openPanel', {'kind': kind})) ?? false;
  static Future<bool> openShortcut(String kind) async => (await _call<bool>('openShortcut', {'kind': kind})) ?? false;
  static Future<bool> openUrl(String url) async => (await _call<bool>('openUrl', {'url': url})) ?? false;
  static Future<bool> webSearch(String q) async => (await _call<bool>('webSearch', {'q': q})) ?? false;
}

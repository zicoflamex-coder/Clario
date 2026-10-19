import 'dart:io';

import 'package:flutter/services.dart';

// پل ارتباطی با اندروید برای آلارم واقعی و دسترسی‌ها
class Native {
  static const MethodChannel _ch = MethodChannel('clario/native');
  static bool get ok => Platform.isAndroid;

  static Future<void> schedule(int id, DateTime when, String title) async {
    if (!ok) return;
    try {
      await _ch.invokeMethod('schedule',
          {'id': id, 'at': when.millisecondsSinceEpoch, 'title': title});
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    if (!ok) return;
    try {
      await _ch.invokeMethod('cancel', {'id': id});
    } catch (_) {}
  }

  static Future<Map<String, bool>> status() async {
    if (!ok) return {};
    try {
      final m = await _ch.invokeMethod<Map>('status');
      return {
        for (final e in (m ?? {}).entries) e.key.toString(): e.value == true
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> requestNotif() async {
    if (!ok) return;
    try {
      await _ch.invokeMethod('requestNotif');
    } catch (_) {}
  }

  static Future<void> open(String what) async {
    if (!ok) return;
    try {
      await _ch.invokeMethod('open', {'what': what});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> pickFile() async {
    if (!ok) return null;
    try {
      final m = await _ch.invokeMethod<Map>('pickFile');
      if (m == null) return null;
      return {'uri': m['uri'].toString(), 'name': m['name'].toString()};
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openFile(String uri) async {
    if (!ok) return false;
    try {
      return (await _ch.invokeMethod<bool>('openFile', {'uri': uri})) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveFile(String name, String text) async {
    if (!ok) return false;
    try {
      return (await _ch.invokeMethod<bool>('saveFile', {'name': name, 'text': text})) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> readFile() async {
    if (!ok) return null;
    try {
      return await _ch.invokeMethod<String>('readFile');
    } catch (_) {
      return null;
    }
  }

  static Future<void> setIcon(String name) async {
    if (!ok) return;
    try {
      await _ch.invokeMethod('setIcon', {'name': name});
    } catch (_) {}
  }

  static Future<String> getIcon() async {
    if (!ok) return 'blue';
    try {
      return (await _ch.invokeMethod<String>('getIcon')) ?? 'blue';
    } catch (_) {
      return 'blue';
    }
  }

  static Future<bool> openUrl(String url) async {
    if (!ok) return false;
    try {
      return (await _ch.invokeMethod<bool>('openUrl', {'url': url})) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> alarmCount() async {
    if (!ok) return 0;
    try {
      return (await _ch.invokeMethod<int>('alarmCount')) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

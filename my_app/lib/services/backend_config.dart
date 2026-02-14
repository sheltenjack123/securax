import 'package:flutter/foundation.dart';

class BackendConfig {
  // Override at runtime, for example:
  // flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.20:5000
  static const String _overrideBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );
  static const String _androidLanBaseUrl = String.fromEnvironment(
    'BACKEND_ANDROID_LAN_URL',
    defaultValue: 'http://172.29.76.50:5000',
  );

  // Default behavior:
  // - Web: use current browser host at port 5000
  // - Native/Desktop: use localhost:5000
  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:5000';
      }
      return 'http://$host:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidLanBaseUrl;
    }

    return 'http://127.0.0.1:5000';
  }
}

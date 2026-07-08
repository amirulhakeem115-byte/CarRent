import 'package:web/web.dart' as web;

String getBrowserDeviceInfo() {
  try {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    var browser = 'Unknown Browser';
    if (userAgent.contains('chrome')) {
      browser = 'Chrome';
    } else if (userAgent.contains('firefox')) {
      browser = 'Firefox';
    } else if (userAgent.contains('safari') && !userAgent.contains('chrome')) {
      browser = 'Safari';
    } else if (userAgent.contains('edge')) {
      browser = 'Edge';
    }

    var os = 'Unknown OS';
    if (userAgent.contains('windows')) {
      os = 'Windows';
    } else if (userAgent.contains('macintosh') ||
        userAgent.contains('mac os x')) {
      os = 'macOS';
    } else if (userAgent.contains('linux')) {
      os = 'Linux';
    } else if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
      os = 'iOS';
    } else if (userAgent.contains('android')) {
      os = 'Android';
    }
    return '$browser on $os';
  } catch (_) {
    return 'Web Browser';
  }
}

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Opens a generic URL in external browser or app
  static Future<bool> launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return false;
    String cleanUrl = urlString.trim();
    if (!cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://') &&
        !cleanUrl.startsWith('mailto:') &&
        !cleanUrl.startsWith('tel:')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null) return false;

    try {
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('[UrlLauncherHelper] Primary launchUrl failed ($cleanUrl): $e');
    }

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('[UrlLauncherHelper] Fallback launchUrl failed ($cleanUrl): $e');
    }
    return false;
  }

  /// Opens a WhatsApp chat for a phone number or URL
  static Future<bool> openWhatsApp(String rawNumberOrUrl) async {
    if (rawNumberOrUrl.trim().isEmpty) return false;
    final String clean = rawNumberOrUrl.trim();

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return launchURL(clean);
    }

    // Sanitize phone number: strip non-digits
    String digitsOnly = clean.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return false;

    // Use api.whatsapp.com redirect format which reliably opens WhatsApp Web / mobile app
    final String waUrl = 'https://api.whatsapp.com/send?phone=$digitsOnly';
    return launchURL(waUrl);
  }

  /// Opens telephone dialer
  static Future<bool> openPhoneCall(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) return false;
    final String clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: clean);
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('[UrlLauncherHelper] Error opening phone ($clean): $e');
    }
    return false;
  }

  /// Opens email app
  static Future<bool> openEmail(String emailAddress, {String? subject}) async {
    if (emailAddress.trim().isEmpty) return false;
    final Uri uri = Uri(
      scheme: 'mailto',
      path: emailAddress.trim(),
      queryParameters: subject != null ? {'subject': subject} : null,
    );
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('[UrlLauncherHelper] Error opening email: $e');
    }
    return false;
  }
}

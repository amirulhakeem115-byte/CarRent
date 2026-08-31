import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/company_settings_provider.dart';
import '../utils/url_launcher_helper.dart';
import '../l10n/app_translations.dart';
import 'app_logo.dart';

/// A premium, highly customizable loading widget.
/// Supports inline spinner, centered card with message, and fullscreen overlay modes with optional WhatsApp support access.
class LoadingWidget extends StatelessWidget {
  /// The loading message to display below the spinner.
  final String? message;

  /// Whether the widget should occupy the full screen/container as an overlay.
  final bool isFullScreen;

  /// The size of the spinner.
  final double size;

  /// Custom color for the spinner. If null, uses [AppColors.primaryOrange].
  final Color? color;

  /// Whether to display a quick WhatsApp support button.
  final bool showSupportLink;

  const LoadingWidget({
    super.key,
    this.message,
    this.isFullScreen = false,
    this.size = 40.0,
    this.color,
    this.showSupportLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = color ?? AppColors.primaryOrange;
    final companySettings = context.watch<CompanySettingsProvider>();
    final socialLinks = companySettings.socialMediaLinks;
    final String waNumber = (socialLinks['whatsapp'] ??
            companySettings.supportContactInfo['whatsapp'] ??
            companySettings.companyPhone)
        .toString();

    final widgetContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message != null) ...[
          const AppLogo(size: 64, fallbackColor: AppColors.primaryOrange),
          const SizedBox(height: 24),
        ],
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            strokeWidth: 3.5,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.lightText,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (showSupportLink || isFullScreen) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text(
              'Need Help? Chat on WhatsApp'.tr(context),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              UrlLauncherHelper.openWhatsApp(waNumber);
            },
          ),
        ],
      ],
    );

    if (isFullScreen) {
      return Container(
        color: Colors.white.withValues(alpha: 0.9),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widgetContent,
          ),
        ),
      );
    }

    return Center(child: widgetContent);
  }
}

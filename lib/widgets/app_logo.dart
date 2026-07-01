import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/company_settings_provider.dart';
import 'app_image.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? fallbackColor;

  const AppLogo({super.key, this.size = 40, this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    final logoSrc = context.watch<CompanySettingsProvider>().companyLogo;

    if (logoSrc.trim().isEmpty) {
      return Icon(
        Icons.directions_car_filled_rounded,
        size: size,
        color: fallbackColor ?? Theme.of(context).colorScheme.primary,
      );
    }

    return AppImage(
      imageSrc: logoSrc,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: Icon(
        Icons.directions_car_filled_rounded,
        size: size,
        color: fallbackColor ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A premium, highly customizable loading widget.
/// Supports inline spinner, centered card with message, and fullscreen overlay modes.
class LoadingWidget extends StatelessWidget {
  /// The loading message to display below the spinner.
  final String? message;

  /// Whether the widget should occupy the full screen/container as an overlay.
  final bool isFullScreen;

  /// The size of the spinner.
  final double size;

  /// Custom color for the spinner. If null, uses [AppColors.primaryOrange].
  final Color? color;

  const LoadingWidget({
    super.key,
    this.message,
    this.isFullScreen = false,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = color ?? AppColors.primaryOrange;

    final widgetContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
      ],
    );

    if (isFullScreen) {
      return Container(
        color: Colors.white.withValues(alpha: 0.85),
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

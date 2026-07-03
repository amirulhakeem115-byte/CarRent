import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class AIFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isOpen;

  const AIFloatingButton({
    super.key,
    required this.onTap,
    required this.isOpen,
  });

  @override
  State<AIFloatingButton> createState() => _AIFloatingButtonState();
}

class _AIFloatingButtonState extends State<AIFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse Glow Ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 58 + (_pulseController.value * 12),
                    height: 58 + (_pulseController.value * 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryOrange.withValues(
                        alpha: 0.25 * (1.0 - _pulseController.value),
                      ),
                    ),
                  );
                },
              ),
              // Main Button Circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryOrange,
                      Color(0xFFEA580C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  turns: widget.isOpen ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutBack,
                  child: Icon(
                    widget.isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

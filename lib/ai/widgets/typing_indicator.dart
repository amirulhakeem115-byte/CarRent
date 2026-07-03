import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingIndicator({
    super.key,
    this.color,
    this.dotSize = 6.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (index) {
      final double start = index * 0.2;
      final double end = start + 0.6;
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.primaryOrange
            : AppColors.primaryOrange);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: _animations[index].value),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

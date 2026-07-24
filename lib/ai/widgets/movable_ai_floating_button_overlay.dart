import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ai_floating_button.dart';

/// Places the AI button in a draggable overlay so users can move it away from
/// content that it may obstruct.
class MovableAIFloatingButtonOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isOpen;
  final bool isVisible;
  final EdgeInsets margin;
  final double buttonSize;
  final double extraBottomPadding;

  const MovableAIFloatingButtonOverlay({
    super.key,
    required this.child,
    required this.onTap,
    required this.isOpen,
    this.isVisible = true,
    this.margin = const EdgeInsets.all(20),
    this.buttonSize = 64,
    this.extraBottomPadding = 0,
  });

  @override
  State<MovableAIFloatingButtonOverlay> createState() =>
      _MovableAIFloatingButtonOverlayState();
}

class _MovableAIFloatingButtonOverlayState
    extends State<MovableAIFloatingButtonOverlay> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    if (!widget.isVisible) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minX = widget.margin.left;
        final maxX = math.max(
          minX,
          constraints.maxWidth - widget.buttonSize - widget.margin.right,
        );

        final minY = widget.margin.top + mediaQuery.padding.top;
        final maxY = math.max(
          minY,
          constraints.maxHeight -
              widget.buttonSize -
              widget.margin.bottom -
              mediaQuery.padding.bottom -
              widget.extraBottomPadding,
        );

        _position ??= Offset(maxX, maxY);
        _position = Offset(
          _position!.dx.clamp(minX, maxX).toDouble(),
          _position!.dy.clamp(minY, maxY).toDouble(),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              left: _position!.dx,
              top: _position!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final nextX = (_position!.dx + details.delta.dx)
                        .clamp(minX, maxX)
                        .toDouble();
                    final nextY = (_position!.dy + details.delta.dy)
                        .clamp(minY, maxY)
                        .toDouble();
                    _position = Offset(nextX, nextY);
                  });
                },
                child: AIFloatingButton(
                  onTap: widget.onTap,
                  isOpen: widget.isOpen,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

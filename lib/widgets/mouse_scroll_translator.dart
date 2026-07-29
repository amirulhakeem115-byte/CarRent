import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A helper widget that translates vertical mouse wheel or trackpad scroll gestures (dy)
/// into horizontal scrolling for a [ScrollController].
/// This makes it easy for desktop users to scroll horizontal lists/tables using a standard
/// vertical mouse wheel or a vertical swipe gesture on their trackpad/mousepad.
class MouseScrollTranslator extends StatefulWidget {
  final ScrollController? controller;
  final Widget Function(BuildContext context, ScrollController controller) builder;

  const MouseScrollTranslator({
    super.key,
    this.controller,
    required this.builder,
  });

  @override
  State<MouseScrollTranslator> createState() => _MouseScrollTranslatorState();
}

class _MouseScrollTranslatorState extends State<MouseScrollTranslator> {
  ScrollController? _internalController;

  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final double dy = pointerSignal.scrollDelta.dy;
          if (dy != 0 && controller.hasClients) {
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (event) {
                final newOffset = controller.offset + dy;
                controller.jumpTo(
                  newOffset.clamp(
                    0.0,
                    controller.position.maxScrollExtent,
                  ),
                );
              },
            );
          }
        }
      },
      child: widget.builder(context, controller),
    );
  }
}

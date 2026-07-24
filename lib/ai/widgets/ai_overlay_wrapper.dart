import 'package:flutter/material.dart';
import 'movable_ai_floating_button_overlay.dart';
import 'ai_chat_panel.dart';

/// Wraps the given [child] and adds the AI Assistant floating action button.
///
/// This widget must live INSIDE the MaterialApp widget tree (i.e. inside a
/// route, not in MaterialApp.builder) so that Overlay is available.
///
/// The chat panel itself is shown via [showAIChatModal], which uses the root
/// Navigator and properly inserts into the Overlay stack — eliminating the
/// "No Overlay widget found" error.
class AIOverlayWrapper extends StatefulWidget {
  final Widget child;

  const AIOverlayWrapper({super.key, required this.child});

  @override
  State<AIOverlayWrapper> createState() => _AIOverlayWrapperState();
}

class _AIOverlayWrapperState extends State<AIOverlayWrapper> {
  bool _isOpen = false;

  void _open() {
    setState(() => _isOpen = true);
    showAIChatModal(context).then((_) {
      if (mounted) setState(() => _isOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return MovableAIFloatingButtonOverlay(
      onTap: _open,
      isOpen: _isOpen,
      extraBottomPadding: bottomPadding,
      child: widget.child,
    );
  }
}

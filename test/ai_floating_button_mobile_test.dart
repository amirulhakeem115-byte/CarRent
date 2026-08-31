import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/ai/widgets/ai_floating_button.dart';
import 'package:carrent_system/ai/widgets/movable_ai_floating_button_overlay.dart';

void main() {
  testWidgets('shows AI floating button on small mobile screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MovableAIFloatingButtonOverlay(
            onTap: () {},
            isOpen: false,
            isVisible: true,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(AIFloatingButton), findsOneWidget);
  });
}

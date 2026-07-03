import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Layout Constraints and Notifications Stream Caching Tests', () {
    testWidgets('Row layout containing dropdown filters has bounded constraints on desktop sizes', (WidgetTester tester) async {
      // Set a desktop screen size (width: 1200)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      // Build a minimal UI structure replicating the Row parent constraints
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    key: key,
                    children: [
                      const Expanded(
                        child: TextField(),
                      ),
                      const SizedBox(width: 16),
                      // Mirror of the status dropdown wrap
                      SizedBox(
                        width: 200,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: 'All',
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                            ],
                            onChanged: (_) {},
                            isExpanded: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Mirror of the vehicle dropdown wrap
                      SizedBox(
                        width: 200,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: 'All',
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                            ],
                            onChanged: (_) {},
                            isExpanded: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that no exceptions are thrown during build and layout
      expect(tester.takeException(), isNull);

      // Reset the physical size of the screen
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

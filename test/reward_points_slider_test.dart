import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/widgets/reward_points_slider.dart';
import 'package:carrent_system/ai/services/intent_engine.dart';
import 'package:carrent_system/ai/models/ai_intent.dart';

void main() {
  group('RewardPointsSlider Widget Tests', () {
    testWidgets('Should display correct limits, balances, and values', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardPointsSlider(
              initialValue: 50,
              availablePoints: 320,
              maxPointsLimit: 1000,
            ),
          ),
        ),
      );

      // Verify header texts
      expect(find.text('Redeem Points'), findsOneWidget);
      expect(find.text('Available Balance: 320 pts'), findsOneWidget);
      expect(find.text('Limit: 1000'), findsOneWidget);

      // Verify preview stats values
      expect(find.text('Points Selected'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Equivalent Discount'), findsOneWidget);
      expect(find.text('RM 5.00'), findsOneWidget); // 50 * 0.10
      expect(find.text('Remaining Balance'), findsOneWidget);
      expect(find.text('270 pts'), findsOneWidget); // 320 - 50
    });

    testWidgets('Quick buttons should update the selected value correctly', (WidgetTester tester) async {
      int? updatedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardPointsSlider(
              initialValue: 0,
              availablePoints: 320,
              maxPointsLimit: 200, // Clamp at 200 max points
              onChanged: (val) {
                updatedValue = val;
              },
            ),
          ),
        ),
      );

      // Tap +50 quick button
      await tester.tap(find.text('+50'));
      await tester.pump();
      expect(updatedValue, 50);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('270 pts'), findsOneWidget); // remaining balance: 320 - 50

      // Tap +100 quick button
      await tester.tap(find.text('+100'));
      await tester.pump();
      expect(updatedValue, 150);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('170 pts'), findsOneWidget);

      // Tap Max quick button (should clamp to maxPointsLimit, which is 200)
      await tester.tap(find.text('Max'));
      await tester.pump();
      expect(updatedValue, 200);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(updatedValue, 0);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('320 pts'), findsOneWidget);
    });

    testWidgets('Step buttons should increment and decrement by 1 point', (WidgetTester tester) async {
      int? updatedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardPointsSlider(
              initialValue: 10,
              availablePoints: 320,
              maxPointsLimit: 1000,
              onChanged: (val) {
                updatedValue = val;
              },
            ),
          ),
        ),
      );

      // Tap plus step button (Icons.add_circle_outline)
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(updatedValue, 11);
      expect(find.text('11'), findsOneWidget);

      // Tap minus step button (Icons.remove_circle_outline)
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(updatedValue, 10);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Confirm button should trigger onConfirmed callback', (WidgetTester tester) async {
      int? confirmedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardPointsSlider(
              initialValue: 100,
              availablePoints: 320,
              maxPointsLimit: 1000,
              showConfirmButton: true,
              confirmButtonLabel: 'Apply Discount',
              onConfirmed: (val) {
                confirmedValue = val;
              },
            ),
          ),
        ),
      );

      // Verify confirm button text
      expect(find.text('Apply Discount'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('Apply Discount'));
      await tester.pump();
      expect(confirmedValue, 100);
    });
  });

  group('IntentEngine Rewards Matcher Tests', () {
    final engine = IntentEngine();

    test('Redemption queries should resolve to RewardIntent', () {
      final queries = [
        'I want to use my reward points',
        'redeem reward points',
        'apply loyalty points',
        'use reward points',
      ];

      for (final text in queries) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<RewardIntent>(), reason: 'Failed on: $text');
      }
    });
  });
}

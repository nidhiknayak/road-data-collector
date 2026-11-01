import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/core/models/road_rating.dart';
import 'package:road_data_collector/features/sessions/rating_sheet.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    void Function(RoadRating?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  onResult(
                    await showModalBottomSheet<RoadRating>(
                      context: context,
                      isDismissible: false,
                      enableDrag: false,
                      isScrollControlled: true,
                      builder: (_) => const RatingSheet(),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final rating in RoadRating.values) {
    testWidgets('selecting ${rating.label} returns its rating', (tester) async {
      RoadRating? result;
      await openSheet(tester, (value) => result = value);
      await tester.tap(find.text(rating.label));
      await tester.pumpAndSettle();
      expect(result, rating);
      expect(find.byType(RatingSheet), findsNothing);
    });
  }

  testWidgets('outside taps and dragging keep prompt open; skip returns null', (
    tester,
  ) async {
    var completed = false;
    RoadRating? result = RoadRating.good;
    await openSheet(tester, (value) {
      completed = true;
      result = value;
    });
    await tester.tapAt(const Offset(790, 10));
    await tester.pumpAndSettle();
    await tester.drag(find.text('How was the road?'), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.byType(RatingSheet), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('small screens can scroll to skip without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSheet(tester, (_) {});
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingSheet), findsNothing);
  });
}

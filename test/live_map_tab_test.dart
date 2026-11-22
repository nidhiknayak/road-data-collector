import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_data_collector/features/home/home_page.dart';

void main() {
  testWidgets('home keeps collection and offers the live road map tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('Live road map'), findsOneWidget);
    await tester.tap(find.text('Live road map'));
    await tester.pumpAndSettle();
    expect(find.text('Start live mapping'), findsOneWidget);
    expect(find.text('Experimental camera estimates'), findsOneWidget);
    expect(find.text('Camera position'), findsOneWidget);
    expect(find.text('Pending / uncertain'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

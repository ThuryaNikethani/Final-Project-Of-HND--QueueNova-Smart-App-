import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/main.dart' as app;

void main() {
  // Initialize for testing
  TestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('QueueNova app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const app.QueueNovaApp(),
      ),
    );

    // Verify that the splash screen is shown first
    expect(find.text('QueueNova'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
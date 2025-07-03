// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_down/app.dart';
import 'package:live_down/core/configs/app_config.dart';
import 'package:live_down/features/download/download_repository.dart';
import 'package:live_down/features/download/services/download_manager_service.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Initialize AppConfig singleton
    await AppConfig.initialize();

    // Create test dependencies
    final downloadManager = DownloadManagerService();
    final downloadRepository = DownloadRepository(downloadManager: downloadManager);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      downloadRepository: downloadRepository,
    ));

    // Verify that the app starts without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

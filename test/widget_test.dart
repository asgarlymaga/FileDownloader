import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pitch_shifter_432hz/main.dart';

void main() {
  testWidgets('App main screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: PitchShifterApp(),
      ),
    );

    // Verify that the title of our screen is visible
    expect(find.text('Pitch Shifter & Streamer'), findsOneWidget);

    // Verify that we can find our navigation items
    expect(find.byIcon(Icons.music_note_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
  });
}

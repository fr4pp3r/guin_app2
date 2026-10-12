import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the wiring used by main.dart: the app-wide offline overlay is a
/// `Stack` (with a `Row`-based pill) injected via `MaterialApp.builder`. That
/// requires an ambient `Directionality`, which MaterialApp must provide above
/// the builder. If that ever stops being true, this fails instead of the app
/// asserting at runtime while offline.
void main() {
  testWidgets('MaterialApp.builder overlay has Directionality available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.wifi_off_rounded), Text('overlay')],
              ),
            ),
          ],
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('overlay'), findsOneWidget);
  });
}

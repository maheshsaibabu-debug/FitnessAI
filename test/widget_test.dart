import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitness_companion/app.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:fitness_companion/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    // Avoid touching the filesystem / Supabase in tests — the app must be
    // constructible without them per the offline-first launch requirement.
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test-anon-key
APP_ENV=development
''');
    // Each test intentionally opens its own throwaway in-memory database —
    // that's not the accidental-duplicate-instance mistake this warning
    // exists to catch.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  /// A fresh in-memory database per test — this is what the router's
  /// onboarding-completion redirect reads, so tests need a real (if
  /// throwaway) Drift instance rather than hitting the filesystem via
  /// path_provider, which isn't available in the widget-test environment.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory()))],
      child: const FitnessCompanionApp(),
    ));
    await tester.pumpAndSettle();
  }

  /// Drift's watch-stream teardown (used by the router's onboarding-status
  /// listener) schedules a zero-duration Timer when its subscription is
  /// cancelled. flutter_test asserts no timers are pending at the end of a
  /// test, so each test must force its tree to unmount and pump once more
  /// *before returning*, rather than leaving Flutter to tear it down at
  /// the start of the next test (which attributes the pending timer to the
  /// wrong test and fails it).
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('a fresh install with no profile lands on onboarding, not home', (tester) async {
    await pumpApp(tester);

    expect(find.text('Fitness Companion'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await unmountAndFlush(tester);
  });

  testWidgets('Get started opens the onboarding wizard, not the home shell directly', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('About you'), findsOneWidget); // step 1's heading
    expect(find.text('Personal (1/7)'), findsOneWidget);
    // Home shell must not be reachable yet — onboarding isn't done.
    expect(find.byType(NavigationBar), findsNothing);

    await unmountAndFlush(tester);
  });

  testWidgets('Next is disabled on step 1 until the required personal fields are filled', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    final nextButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    expect(nextButton.onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada');
    await tester.tap(find.text('Female'));
    await tester.pump();

    // Date of birth still missing -> still disabled.
    final stillDisabled = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    expect(stillDisabled.onPressed, isNull);

    await unmountAndFlush(tester);
  });
}

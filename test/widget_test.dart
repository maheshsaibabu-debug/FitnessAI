import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_companion/app.dart';

void main() {
  setUpAll(() {
    // Avoid touching the filesystem / Supabase in tests — the app must be
    // constructible without them per the offline-first launch requirement.
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test-anon-key
APP_ENV=development
''');
  });

  testWidgets('app launches to the onboarding screen with no network', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessCompanionApp()));
    await tester.pumpAndSettle();

    expect(find.text('Fitness Companion'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Get started navigates to the home shell with bottom nav', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessCompanionApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No plan yet'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

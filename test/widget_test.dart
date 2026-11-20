import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngiga/auth_screen.dart';
import 'package:ngiga/auth_policy_sheet.dart';
import 'package:ngiga/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('auth screens and searchable program selection fit the phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(onLogin: _noop)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your campus stockroom'), findsOneWidget);
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Enter Your Email'), findsOneWidget);
    final rememberBox = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(rememberBox).value, false);
    await tester.tap(rememberBox);
    await tester.pump();
    expect(tester.widget<Checkbox>(rememberBox).value, true);
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Student ID'), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    await tester.tap(find.text('Program'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bachelor of Science in Computer Science'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search program'),
      'cyber',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bachelor of Science in Cybersecurity'), findsOneWidget);
    expect(find.text('Bachelor of Science in Computer Science'), findsNothing);
    await tester.tap(find.text('Bachelor of Science in Cybersecurity'));
    await tester.pumpAndSettle();
    expect(find.text('Bachelor of Science in Cybersecurity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Remember me stores only opted-in sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionStore();
    await sessions.save('remembered-token', remember: true);
    expect(await sessions.restore(), 'remembered-token');
    await sessions.save('temporary-token', remember: false);
    expect(await sessions.restore(), isEmpty);
    await sessions.save('remembered-again', remember: true);
    await sessions.clear();
    expect(await sessions.restore(), isEmpty);
  });

  testWidgets('Terms and Privacy use the detailed bottom sheets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showAuthPolicy(context, privacy: false),
                  child: const Text('Terms'),
                ),
                TextButton(
                  onPressed: () => showAuthPolicy(context, privacy: true),
                  child: const Text('Privacy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();
    expect(find.text('Borrowing equipment'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Camera and barcode scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop(bool _) {}

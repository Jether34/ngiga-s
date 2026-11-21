import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngiga/app_notice.dart';
import 'package:ngiga/auth_screen.dart';
import 'package:ngiga/app_slide_route.dart';
import 'package:ngiga/auth_policy_sheet.dart';
import 'package:ngiga/session_store.dart';
import 'package:ngiga/main.dart' show api;
import 'package:ngiga/notification_page.dart';
import 'package:ngiga/leaderboard_page.dart';
import 'package:ngiga/skeleton_loading.dart';
import 'package:ngiga/student_profile_editor.dart';
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
    await sessions.saveUser({'name': 'Student', 'account_id': 'STU-1'});
    expect(await sessions.restore(), 'remembered-token');
    expect((await sessions.restoreUser())['name'], 'Student');
    await sessions.save('temporary-token', remember: false);
    expect(await sessions.restore(), isEmpty);
    await sessions.save('remembered-again', remember: true);
    await sessions.clear();
    expect(await sessions.restore(), isEmpty);
    expect(await sessions.restoreUser(), isEmpty);
  });

  testWidgets('subpage slides in and slides back without painting through', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                appSlideRoute(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Destination'))),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(find.text('Destination')).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Destination')).dx,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2 -
            tester.getSize(find.text('Destination')).width / 2,
        2,
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Destination'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsNothing);
  });

  testWidgets('leaderboard shows skeletons until borrowers load', (
    tester,
  ) async {
    final response = Completer<dynamic>();
    await tester.pumpWidget(
      MaterialApp(home: LeaderboardPage(future: response.future)),
    );
    expect(find.byType(LeaderboardSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    response.complete([
      {
        'name': 'Student One',
        'program': 'Computer Science',
        'year_level': '1st Year',
        'section': 'A1',
        'borrow_count': 3,
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(LeaderboardSkeleton), findsNothing);
    expect(find.text('Student One'), findsOneWidget);
  });

  testWidgets('app messages appear in a dismissible popup', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppNotice(
                context,
                'Borrowing requires an active internet connection.',
                isError: true,
              ),
              child: const Text('Borrow'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Borrow'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.text('Borrowing requires an active internet connection.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('icon switch keeps the session until sign out', () async {
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionStore();
    await sessions.save('temporary-token', remember: false);
    await sessions.holdForIconChange('temporary-token');
    expect(await sessions.restore(), 'temporary-token');
    expect(await sessions.restore(), 'temporary-token');
    await sessions.clear();
    expect(await sessions.restore(), isEmpty);
  });

  testWidgets('forgot password opens the email reset request', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(onLogin: _noop)),
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    final loginField = find.widgetWithText(TextField, 'Enter Your Email');
    expect(tester.getSize(loginField).height, 43);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(TextField, 'Your email address'))
          .height,
      43,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('student ID and year level are visible but locked in profile', (
    tester,
  ) async {
    api.user = {
      'name': 'Student Example',
      'email': 'student@example.com',
      'phone': '09170000000',
      'account_id': '2026-12345',
      'year_level': '2nd Year',
      'program': 'Bachelor of Science in Computer Science',
      'section': 'TA01',
      'home_address': 'Manila',
    };
    await tester.pumpWidget(
      MaterialApp(home: StudentProfileEditor(onSaved: () {})),
    );
    expect(find.text('2026-12345'), findsOneWidget);
    expect(find.text('2nd Year'), findsOneWidget);
    expect(find.text('Program is fixed after sign up'), findsNothing);
    expect(find.text('Year level is fixed after sign up'), findsNothing);
    expect(find.text('Student ID is fixed'), findsNothing);
    expect(find.widgetWithText(TextField, 'Student ID'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification opens its complete message in a popup', (
    tester,
  ) async {
    const fullMessage = 'This is the complete item return notification.';
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationPage(
          initial: [
            {
              'id': 'return-test',
              'type': 'returned',
              'title': 'Item returned',
              'message': fullMessage,
              'created_at': '2026-11-20 12:00:00',
              'is_read': true,
            },
          ],
          onRead: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Item returned'));
    await tester.pumpAndSettle();
    expect(find.text(fullMessage), findsWidgets);
    expect(find.text('2026-11-20 12:00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop(bool _) {}

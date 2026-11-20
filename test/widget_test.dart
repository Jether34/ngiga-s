import 'package:flutter_test/flutter_test.dart';
import 'package:ngiga/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the sign in screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LabApp());
    await tester.pumpAndSettle();
    expect(find.text('Stockroom'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New student? Create an account'), findsOneWidget);
  });

  testWidgets('opens the student signup form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LabApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New student? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your student account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Student / user ID'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create student account'), findsOneWidget);
  });
}

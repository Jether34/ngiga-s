import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'main.dart' show api;
import 'header_haze.dart';

class StudentProfileEditor extends StatefulWidget {
  const StudentProfileEditor({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<StudentProfileEditor> createState() => _StudentProfileEditorState();
}

class _StudentProfileEditorState extends State<StudentProfileEditor> {
  late final name = TextEditingController(text: '${api.user['name'] ?? ''}');
  late final email = TextEditingController(text: '${api.user['email'] ?? ''}');
  late final phone = TextEditingController(text: '${api.user['phone'] ?? ''}');
  late final section = TextEditingController(
    text: '${api.user['section'] ?? ''}',
  );
  late final address = TextEditingController(
    text: '${api.user['home_address'] ?? ''}',
  );
  bool saving = false;
  String? error;
  String get termsAcceptedDate {
    final raw = '${api.user['terms_accepted_at'] ?? ''}';
    return raw.length >= 10 ? raw.substring(0, 10) : 'On sign up';
  }

  @override
  void dispose() {
    for (final controller in [name, email, phone, section, address]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await api.patch('/me', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'student_id': api.user['account_id'],
        'phone': phone.text.trim(),
        'year_level': api.user['year_level'],
        'section': section.text.trim(),
        'home_address': address.text.trim(),
      });
      api.user = Map<String, dynamic>.from(updated);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageGradientBackground(
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: pageWithHaze(
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your information',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppPalette.deep,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Details provided at sign up. Passwords are never shown here.',
              style: TextStyle(color: AppPalette.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Year level',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.lock_outline),
              ),
              child: Text('${api.user['year_level'] ?? ''}'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Program',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.lock_outline),
              ),
              child: Text('${api.user['program'] ?? ''}'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                    child: Text('${api.user['account_id'] ?? ''}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: section,
                    decoration: const InputDecoration(
                      labelText: 'Section / block',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: 'Home address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Terms and Privacy accepted: $termsAcceptedDate',
              style: const TextStyle(color: AppPalette.muted),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
      ),
    ),
  );
}

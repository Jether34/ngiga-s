import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'main.dart' show api;
import 'student_programs.dart';

class StudentProfileEditor extends StatefulWidget {
  const StudentProfileEditor({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<StudentProfileEditor> createState() => _StudentProfileEditorState();
}

class _StudentProfileEditorState extends State<StudentProfileEditor> {
  late final name = TextEditingController(text: '${api.user['name'] ?? ''}');
  late final email = TextEditingController(text: '${api.user['email'] ?? ''}');
  late final studentId = TextEditingController(
    text: '${api.user['account_id'] ?? ''}',
  );
  late final phone = TextEditingController(text: '${api.user['phone'] ?? ''}');
  late final program = TextEditingController(
    text: '${api.user['program'] ?? ''}',
  );
  String? year = '${api.user['year_level'] ?? ''}'.isEmpty
      ? null
      : '${api.user['year_level']}';
  late final section = TextEditingController(
    text: '${api.user['section'] ?? ''}',
  );
  late final address = TextEditingController(
    text: '${api.user['home_address'] ?? ''}',
  );
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      name,
      email,
      studentId,
      phone,
      program,
      section,
      address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (year == null || !feuPrograms.contains(program.text.trim())) {
      setState(() => error = 'Choose a year level and FEU Tech program.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await api.patch('/me', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'student_id': studentId.text.trim(),
        'phone': phone.text.trim(),
        'year_level': year,
        'program': program.text.trim(),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: ListView(
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
        DropdownButtonFormField<String>(
          initialValue: year,
          decoration: const InputDecoration(
            labelText: 'Year level',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final value in yearLevels)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) => setState(() => year = value),
        ),
        const SizedBox(height: 12),
        DropdownMenu<String>(
          controller: program,
          enableFilter: true,
          requestFocusOnTap: true,
          expandedInsets: EdgeInsets.zero,
          label: const Text('Program'),
          dropdownMenuEntries: [
            for (final value in feuPrograms)
              DropdownMenuEntry(value: value, label: value),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: studentId,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  border: OutlineInputBorder(),
                ),
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
          'Terms and Privacy accepted: ${api.user['terms_accepted_at'] ?? 'On sign up'}',
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
  );
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show api;
import 'app_palette.dart';
import 'auth_policy_sheet.dart';
import 'landing_art.dart';
import 'student_programs.dart';
import 'header_haze.dart';

const _ink = AppPalette.ink;
const _muted = AppPalette.muted;
const _accent = AppPalette.primary;
const _line = AppPalette.line;
const _years = yearLevels;
const _programs = feuPrograms;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onLogin});
  final ValueChanged<bool> onLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Page { welcome, login, signup, verify, resetRequest, resetSent }

class _AuthScreenState extends State<AuthScreen> {
  _Page page = _Page.welcome;
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final studentId = TextEditingController();
  final section = TextEditingController();
  final address = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final verificationCode = TextEditingController();
  final resetEmail = TextEditingController();
  final verificationFocus = FocusNode();
  String challengeId = '', verificationEmail = '';
  String? year, program, error;
  bool remember = false,
      terms = false,
      busy = false,
      showPassword = false,
      showConfirm = false,
      phoneTab = false;
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xffd7c7a1),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    for (final controller in [
      name,
      email,
      phone,
      studentId,
      section,
      address,
      password,
      confirm,
      verificationCode,
      resetEmail,
    ]) {
      controller.dispose();
    }
    verificationFocus.dispose();
    super.dispose();
  }

  void _open(_Page next) => setState(() {
    page = next;
    error = null;
    password.clear();
    confirm.clear();
  });

  void _startPasswordReset() {
    resetEmail.text = email.text.trim();
    verificationCode.clear();
    _open(_Page.resetRequest);
  }

  Future<void> _submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (page == _Page.signup) {
        if (name.text.trim().length < 2) {
          throw Exception('Enter your full name.');
        }
        if (!email.text.contains('@')) {
          throw Exception('Enter a valid email address.');
        }
        if (phone.text.trim().length < 7) {
          throw Exception('Enter your phone number.');
        }
        if (!RegExp(r'^[A-Za-z0-9-]{3,32}$').hasMatch(studentId.text.trim())) {
          throw Exception('Enter a valid student ID.');
        }
        if (section.text.trim().isEmpty || section.text.trim().length > 32) {
          throw Exception('Enter your section.');
        }
        if (address.text.trim().isEmpty) {
          throw Exception('Enter your home address.');
        }
        if (password.text.length < 12) {
          throw Exception('Use at least 12 characters for your password.');
        }
        if (password.text != confirm.text) {
          throw Exception('Passwords do not match.');
        }
        if (year == null || program == null) {
          throw Exception('Choose your year level and program.');
        }
        if (!terms) {
          throw Exception('Accept the terms and privacy policy to continue.');
        }
        final requestedId = studentId.text.trim();
        final result = await api.post('/auth/signup', {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'account_id': requestedId,
          'student_id': requestedId,
          'section': section.text.trim(),
          'password': password.text,
          'phone': phone.text.trim(),
          'year_level': year,
          'program': program,
          'home_address': address.text.trim(),
          'agree_terms': terms,
        });
        if (!mounted) return;
        challengeId = '${result['challenge_id']}';
        verificationEmail = '${result['email']}';
        _open(_Page.verify);
      } else if (page == _Page.verify) {
        if (!RegExp(r'^\d{6}$').hasMatch(verificationCode.text.trim())) {
          throw Exception('Enter the six-digit code from your email.');
        }
        final result = await api.post('/auth/verify', {
          'challenge_id': challengeId,
          'code': verificationCode.text.trim(),
        });
        api.token = result['token'];
        api.user = Map<String, dynamic>.from(result['user']);
        widget.onLogin(remember);
      } else if (page == _Page.resetRequest) {
        if (!resetEmail.text.trim().contains('@')) {
          throw Exception('Enter the email used for your account.');
        }
        await api.post('/auth/password-reset/request', {
          'email': resetEmail.text.trim(),
        });
        if (!mounted) return;
        _open(_Page.resetSent);
      } else {
        final result = await api.post('/auth/login', {
          'login_type': phoneTab ? 'phone' : 'email',
          if (phoneTab)
            'phone': phone.text.trim()
          else
            'email': email.text.trim(),
          'password': password.text,
        });
        if (result['verification_required'] == true) {
          challengeId = '${result['challenge_id']}';
          verificationEmail = '${result['email']}';
          _open(_Page.verify);
        } else {
          api.token = result['token'];
          api.user = Map<String, dynamic>.from(result['user']);
          widget.onLogin(remember);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        if (page == _Page.verify) {
          verificationCode.clear();
          verificationFocus.requestFocus();
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontSize: 12),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xff777777)),
        prefixIconConstraints: const BoxConstraints(minWidth: 39),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 11,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      );

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
  }) => SizedBox(
    height: 43,
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13, color: _ink),
      decoration: _decoration(hint, icon, suffix: suffix),
    ),
  );

  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool outline = false,
  }) => SizedBox(
    width: double.infinity,
    height: 43,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: outline ? Colors.white : AppPalette.primary,
        border: outline ? Border.all(color: AppPalette.pearl) : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: outline
            ? null
            : const [
                BoxShadow(
                  color: Color(0x27145a43),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: outline ? AppPalette.primary : Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 27,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, height: 1.35, color: _muted),
      ),
    ],
  );

  Widget _welcome() => LayoutBuilder(
    builder: (context, constraints) {
      final h = constraints.maxHeight;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: Column(
          children: [
            SizedBox(height: h * .12),
            SizedBox(
              height: h * .27,
              width: double.infinity,
              child: const LandingArt(),
            ),
            SizedBox(height: h * .085),
            _heading(
              'Your campus stockroom',
              'Borrow, track, and return equipment\nwith every item in one place.',
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 8, height: 3, color: const Color(0xff777777)),
                const SizedBox(width: 4),
                Container(width: 19, height: 3, color: _accent),
              ],
            ),
            const Spacer(),
            _button('Log In', () => _open(_Page.login)),
            const SizedBox(height: 8),
            _button('Sign Up', () => _open(_Page.signup), outline: true),
          ],
        ),
      );
    },
  );

  Future<void> _choose(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) async {
    var query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: (MediaQuery.sizeOf(sheetContext).height * .64).clamp(
            0.0,
            540.0,
          ),
          child: StatefulBuilder(
            builder: (context, update) {
              final filtered = options
                  .where(
                    (option) =>
                        option.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 43,
                      child: TextField(
                        autofocus: title == 'Program',
                        onChanged: (value) => update(() => query = value),
                        decoration: _decoration(
                          'Search ${title.toLowerCase()}',
                          Icons.search,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching programs',
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, color: _line),
                              itemBuilder: (context, index) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                title: Text(
                                  filtered[index],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _ink,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: _muted,
                                ),
                                onTap: () =>
                                    Navigator.of(sheetContext)
                                        .pop(filtered[index]),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null && mounted) onSelected(selected);
  }

  Widget _selector(
    String hint,
    String? value,
    List<String> choices,
    ValueChanged<String> onSelected,
  ) => Semantics(
    button: true,
    label: hint,
    value: value ?? 'Not selected',
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _choose(hint, choices, onSelected),
      child: Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: value == null ? _muted : _ink,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppPalette.primary,
            ),
          ],
        ),
      ),
    ),
  );

  void _policy(String name) =>
      showAuthPolicy(context, privacy: name == 'Privacy Policy');

  Widget _signup() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 150),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(
                'Sign Up',
                'Please provide the details below to\ncreate your account.',
              ),
              const SizedBox(height: 30),
              _input(name, 'Full Name', Icons.person_outline),
              const SizedBox(height: 9),
              _input(
                email,
                'Email Address',
                Icons.mail_outline,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 9),
              _input(
                phone,
                'Phone Number',
                Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _selector(
                      'Year Level',
                      year,
                      _years,
                      (v) => setState(() => year = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _selector(
                      'Program',
                      program,
                      _programs,
                      (v) => setState(() => program = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _input(
                      studentId,
                      'Student ID',
                      Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _input(section, 'Section', Icons.groups_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _input(address, 'Home Address', Icons.location_on_outlined),
              const SizedBox(height: 9),
              _input(
                password,
                'New Password',
                Icons.lock_outline,
                obscure: !showPassword,
                suffix: IconButton(
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
              const SizedBox(height: 9),
              _input(
                confirm,
                'Confirm Password',
                Icons.lock_outline,
                obscure: !showConfirm,
                suffix: IconButton(
                  icon: Icon(
                    showConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => showConfirm = !showConfirm),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 23,
                    height: 23,
                    child: Checkbox(
                      value: terms,
                      activeColor: _accent,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => terms = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: _muted,
                            height: 1.3,
                          ),
                          children: [
                            const TextSpan(text: 'I agree with the '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: const TextStyle(color: AppPalette.primary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _policy('Terms and Conditions'),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(color: AppPalette.primary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _policy('Privacy Policy'),
                            ),
                            const TextSpan(text: ' of Stockroom'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (error != null) _error(),
              const Spacer(),
              const SizedBox(height: 22),
              _button(busy ? 'Creating Account...' : 'Create Account', _submit),
              const SizedBox(height: 18),
              _footer('Have an account? ', 'Sign in', () => _open(_Page.login)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _error() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      error!,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xffbd293d), fontSize: 11),
    ),
  );

  Widget _footer(String lead, String link, VoidCallback onTap) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lead, style: const TextStyle(fontSize: 11, color: _muted)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            link,
            style: const TextStyle(fontSize: 11, color: AppPalette.primary),
          ),
        ),
      ],
    ),
  );

  Widget _login() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Login', 'Please provide the details below to log in.'),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 190,
            child: Row(
              children: [
                Expanded(
                  child: _tab(
                    'Email',
                    !phoneTab,
                    () => setState(() => phoneTab = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tab(
                    'Phone',
                    phoneTab,
                    () => setState(() => phoneTab = true),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 35),
        _input(
          phoneTab ? phone : email,
          phoneTab ? 'Enter Your Phone' : 'Enter Your Email',
          phoneTab ? Icons.phone_outlined : Icons.mail_outline,
          keyboard: phoneTab ? TextInputType.phone : TextInputType.emailAddress,
        ),
        const SizedBox(height: 9),
        _input(
          password,
          'Enter Your Password',
          Icons.lock_outline,
          obscure: !showPassword,
          suffix: IconButton(
            icon: Icon(
              showPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
            ),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 23,
              height: 23,
              child: Checkbox(
                value: remember,
                activeColor: _accent,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => remember = v ?? false),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Remember me',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _startPasswordReset,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 11, color: AppPalette.primary),
              ),
            ),
          ],
        ),
        if (error != null) _error(),
        const SizedBox(height: 8),
        _button(busy ? 'Logging In...' : 'Log In', _submit),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: _line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text(
                'Or Continue With',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
            const Expanded(child: Divider(color: _line)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _social(
                'Google',
                const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xff4285f4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _social(
                'Apple',
                const Icon(Icons.apple, size: 19, color: _ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 72),
        _footer(
          "Don't have an account? ",
          'Sign up',
          () => _open(_Page.signup),
        ),
      ],
    ),
  );

  Widget _tab(String label, bool active, VoidCallback onTap) => SizedBox(
    height: 40,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? _accent : Colors.transparent,
        foregroundColor: active ? Colors.white : _ink,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );

  Widget _codeBoxes() => SizedBox(
    height: 58,
    child: Stack(
      children: [
        Row(
          children: List.generate(
            6,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 5 ? 0 : 7),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: verificationCode.text.length == index
                          ? _accent
                          : _line,
                      width: verificationCode.text.length == index ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    index < verificationCode.text.length
                        ? verificationCode.text[index]
                        : '',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.01,
            child: TextField(
              focusNode: verificationFocus,
              controller: verificationCode,
              autofocus: true,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => error = null);
                if (value.length == 6 && !busy) _submit();
              },
            ),
          ),
        ),
      ],
    ),
  );

  Widget _verify() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 72, 24, 30),
    child: Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: _accent),
        const SizedBox(height: 24),
        _heading(
          'Check your email',
          'Enter the six-digit code sent to\n$verificationEmail',
        ),
        const SizedBox(height: 32),
        _codeBoxes(),
        const Text(
          'The code expires in 10 minutes. Five attempts are allowed.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        if (error != null) _error(),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => _open(_Page.login),
          child: const Text('Back to sign in'),
        ),
      ],
    ),
  );

  Widget _resetRequest() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 72, 24, 30),
    child: Column(
      children: [
        const Icon(Icons.lock_reset_outlined, size: 64, color: _accent),
        const SizedBox(height: 24),
        _heading(
          'Reset password',
          'Enter your account email to receive a secure password reset link.',
        ),
        const SizedBox(height: 30),
        _input(
          resetEmail,
          'Your email address',
          Icons.mail_outline,
          keyboard: TextInputType.emailAddress,
        ),
        if (error != null) _error(),
        const SizedBox(height: 20),
        _button(busy ? 'Sending...' : 'Send reset link', _submit),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => _open(_Page.login),
          child: const Text('Back to sign in'),
        ),
      ],
    ),
  );

  Widget _resetSent() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 72, 24, 30),
    child: Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 58, color: _accent),
        const SizedBox(height: 20),
        _heading(
          'Check your email',
          'If ${resetEmail.text.trim()} has an account, a password reset link is on its way. Check your inbox and spam folder. The link expires in 10 minutes.',
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: _startPasswordReset,
          child: const Text('Send another link'),
        ),
        TextButton(
          onPressed: () => _open(_Page.login),
          child: const Text('Back to sign in'),
        ),
      ],
    ),
  );

  Widget _social(String label, Widget icon) => SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label sign-in is not configured.')),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: icon,
      label: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Color(0xffd7c7a1),
      statusBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const HeaderHaze(height: 30),
            Expanded(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: SizedBox(
                        height: double.infinity,
                        child: switch (page) {
                          _Page.welcome => _welcome(),
                          _Page.login => _login(),
                          _Page.signup => _signup(),
                          _Page.verify => _verify(),
                          _Page.resetRequest => _resetRequest(),
                          _Page.resetSent => _resetSent(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

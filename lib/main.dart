import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const apiDefault = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
const navy = Color(0xff064b37),
    teal = Color(0xff14804a),
    canvas = Color(0xffffffff),
    neonCyan = Color(0xffffa91f),
    neonLime = Color(0xffffcf55),
    ink = Color(0xff1c1b19);
void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: canvas,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LabApp());
}

class LabApp extends StatelessWidget {
  const LabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Stockroom',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
      scaffoldBackgroundColor: canvas,
      useMaterial3: true,
    ),
    home: const Root(),
  );
}

class Api {
  String base = apiDefault, token = '';
  Map<String, dynamic> user = {};
  Map<String, String> get headers => {
    'content-type': 'application/json',
    if (token.isNotEmpty) 'authorization': 'Bearer $token',
  };
  Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$base$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception(_message(r));
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$base$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception(_message(r));
    return jsonDecode(r.body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http
        .patch(
          Uri.parse('$base$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception(_message(r));
    return jsonDecode(r.body);
  }

  Future<dynamic> delete(String path) async {
    final r = await http
        .delete(Uri.parse('$base$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception(_message(r));
    return jsonDecode(r.body);
  }

  String _message(http.Response r) {
    try {
      return jsonDecode(r.body)['detail'].toString();
    } catch (_) {
      return 'Server error (${r.statusCode})';
    }
  }
}

final api = Api();

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('token') ?? '';
    try {
      if (api.token.isNotEmpty)
        api.user = Map<String, dynamic>.from(await api.get('/me'));
    } catch (_) {
      api.token = '';
    }
    if (mounted) setState(() => ready = true);
  }

  void _signed(bool remember) async {
    final p = await SharedPreferences.getInstance();
    if (remember) {
      await p.setString('token', api.token);
    } else {
      await p.remove('token');
    }
    if (mounted) setState(() {});
  }

  void _logout() async {
    api.token = '';
    api.user = {};
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => !ready
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : api.token.isEmpty
      ? Login(onLogin: _signed)
      : Home(onLogout: _logout);
}

class Login extends StatefulWidget {
  const Login({super.key, required this.onLogin});
  final ValueChanged<bool> onLogin;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(),
      phone = TextEditingController(),
      pass = TextEditingController();
  final fullName = TextEditingController(),
      program = TextEditingController(),
      address = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false,
      signupMode = false,
      welcome = true,
      termsAccepted = false,
      phoneLogin = false,
      rememberMe = false,
      showPassword = false,
      showConfirmPassword = false;
  String? yearLevel, selectedProgram, error;

  @override
  void dispose() {
    email.dispose();
    phone.dispose();
    pass.dispose();
    fullName.dispose();
    program.dispose();
    address.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> go() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (signupMode) {
        if (pass.text != confirm.text)
          throw Exception('Passwords do not match');
        if (yearLevel == null) throw Exception('Select your year level');
        if (selectedProgram == null) throw Exception('Select your program');
        if (selectedProgram == 'Other' && program.text.trim().length < 2)
          throw Exception('Enter your program');
        if (!termsAccepted)
          throw Exception(
            'Accept the Terms and Conditions and Privacy Policy to continue',
          );
        final result = await api.post('/auth/signup', {
          'name': fullName.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'year_level': yearLevel,
          'program': selectedProgram == 'Other'
              ? program.text.trim()
              : selectedProgram,
          'home_address': address.text.trim(),
          'password': pass.text,
          'agree_terms': termsAccepted,
        });
        if (!mounted) return;
        setState(() {
          signupMode = false;
          pass.clear();
          confirm.clear();
        });
        final assignedId = result['account_id'] == null
            ? ''
            : ' Your user ID is ${result['account_id']}.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['message'] ?? 'Account created.'}$assignedId',
            ),
          ),
        );
      } else {
        final d = await api.post(
          '/auth/login',
          phoneLogin
              ? {
                  'login_type': 'phone',
                  'phone': phone.text.trim(),
                  'password': pass.text,
                }
              : {
                  'login_type': 'email',
                  'email': email.text.trim(),
                  'password': pass.text,
                },
        );
        api.token = d['token'];
        api.user = Map<String, dynamic>.from(d['user']);
        widget.onLogin(rememberMe);
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggleMode() {
    setState(() {
      welcome = false;
      signupMode = !signupMode;
      error = null;
      pass.clear();
      confirm.clear();
      if (signupMode) email.clear();
    });
  }

  void notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> showPolicy(bool privacy) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      final sections = privacy
          ? <Map<String, String>>[
              {
                'title': 'Information collected',
                'body': 'Stockroom stores the details you provide when creating an account: your name, email, phone number, year level, program, and home address. It also stores your generated student/user ID, login and account state, scanned item identifiers, loan and return dates, and receipt history.',
              },
              {
                'title': 'Camera and barcode scans',
                'body': 'The camera is used to read an equipment barcode or QR code. The decoded item code is sent to Stockroom to look up equipment and record a confirmed loan or return. Camera images and video are not uploaded as part of the scan request.',
              },
              {
                'title': 'How information is used',
                'body': 'Information is used to authenticate your account, manage equipment loans and returns, show receipts and loan history, and help authorized campus staff administer inventory and resolve account or equipment issues.',
              },
              {
                'title': 'Who can access it',
                'body': 'Authorized inventory administrators can see borrower identity and the account and transaction details needed to manage equipment. Information may also be processed by service providers that operate or maintain the app and its database.',
              },
              {
                'title': 'Storage and retention',
                'body': 'Account and transaction records are stored in the Stockroom database. Records are kept while needed to operate the account and meet the institution’s inventory and record-keeping requirements. Ask your campus administrator about the institution’s retention period.',
              },
              {
                'title': 'Your choices',
                'body': 'You may ask the campus administrator to review or correct your account details, or to explain the institution’s deletion and retention process. Some loan and inventory records may need to remain available for institutional records.',
              },
              {
                'title': 'Security and contact',
                'body': 'Stockroom uses password hashing and authenticated access controls. No online system can guarantee absolute security. For privacy questions, contact your laboratory or campus administrator through your institution’s usual support channel.',
              },
            ]
          : <Map<String, String>>[
              {
                'title': 'Your account',
                'body': 'Provide accurate account information and keep your password private. Public sign-up creates a student account. Stockroom assigns your student/user ID after registration.',
              },
              {
                'title': 'Borrowing equipment',
                'body': 'Choose a due date and time, scan the intended item, review the item and account details, then confirm the loan. A loan is created only after the server accepts the request. Borrowing and returning require an internet connection.',
              },
              {
                'title': 'Care and return',
                'body': 'Use borrowed equipment for its intended campus purpose, take reasonable care of it, and return the same physical item by the due date using the authorized return workflow. Report loss, damage, or a scan problem to the inventory administrator promptly.',
              },
              {
                'title': 'Accountability',
                'body': 'Stockroom records the borrower, physical item, barcode, due time, and return status so the borrower and authorized administrators can view the receipt and transaction history. Do not lend an issued item to another person or alter its barcode.',
              },
              {
                'title': 'Acceptable use',
                'body': 'Do not use Stockroom to access another person’s account, falsify inventory records, or bypass equipment controls. The institution may restrict borrowing access when required to protect equipment or resolve an overdue or disputed loan.',
              },
              {
                'title': 'Availability and changes',
                'body': 'Borrowing and returns need an active connection and depend on the campus service being available. The institution may update these terms and will publish the current version in the app.',
              },
              {
                'title': 'Questions',
                'body': 'For help with an account, loan, return, or these terms, contact your laboratory or campus inventory administrator through your institution’s usual support channel.',
              },
            ];
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xffdedede),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  privacy ? 'Privacy Policy' : 'Terms and Conditions',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Stockroom campus inventory',
                  style: TextStyle(color: Color(0xff77736d), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final section in sections) ...[
                        Text(
                          section['title']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          section['body']!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Color(0xff4f4d49),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  InputDecoration field(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17, color: const Color(0xff65615b)),
        suffixIcon: suffix,
        labelStyle: const TextStyle(color: Color(0xff77736d), fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffe3ded5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffe3ded5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neonCyan, width: 1.4),
        ),
      );

  Widget brand() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xffe8dfcf)),
        ),
        child: const Icon(Icons.inventory_2_rounded, color: navy, size: 20),
      ),
      const SizedBox(width: 9),
      const Text(
        'Stockroom',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
      ),
    ],
  );

  Widget hero() => Container(
    height: 254,
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 18,
          top: 26,
          child: Icon(
            Icons.auto_awesome,
            color: neonCyan.withValues(alpha: .8),
            size: 22,
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: Icon(
            Icons.qr_code_2_rounded,
            color: navy.withValues(alpha: .18),
            size: 36,
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 145,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 35,
                    top: 34,
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: navy.withValues(alpha: .56),
                    ),
                  ),
                  Positioned(
                    right: 35,
                    top: 32,
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 38,
                      color: neonCyan,
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 124,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xffcad7e3),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_balance_rounded,
                          color: Color(0xff7699c6),
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 46,
                          height: 4,
                          color: const Color(0xffd7e1ec),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 34,
                          height: 4,
                          color: const Color(0xffd7e1ec),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: neonCyan,
                          size: 27,
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 63,
                    bottom: 2,
                    child: Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: Color(0xff355984),
                    ),
                  ),
                  const Positioned(
                    right: 60,
                    bottom: 2,
                    child: Icon(
                      Icons.handyman_rounded,
                      size: 32,
                      color: Color(0xffd88342),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'SCAN  |  TRACK  |  RETURN',
              style: TextStyle(
                color: Color(0xff9a6200),
                fontSize: 9,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget action(String label, VoidCallback? onTap, {bool outline = false}) =>
      SizedBox(
        height: 44,
        width: double.infinity,
        child: outline
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff9a6200),
                  side: const BorderSide(color: neonCyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [neonLime, neonCyan]),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      );

  Widget authTab(String title, bool selected, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: selected ? neonCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xffd88a0c) : const Color(0xffe9e2d8),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 205,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xffffd79b),
                      Color(0xffffefd2),
                      Colors.white,
                    ],
                    stops: [0, .55, 1],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(25, 22, 25, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (welcome) ...[
                      const SizedBox(height: 2),
                      brand(),
                      const SizedBox(height: 12),
                      hero(),
                      const SizedBox(height: 5),
                      const Text(
                        'Track your campus equipment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Scan, borrow, and return equipment with every loan in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff5d5b56),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 3,
                            color: const Color(0xffaaa39a),
                          ),
                          const SizedBox(width: 4),
                          Container(width: 16, height: 3, color: neonCyan),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height > 760
                            ? MediaQuery.sizeOf(context).height * .30
                            : 28,
                      ),
                      action(
                        'Log in',
                        () => setState(() {
                          welcome = false;
                          signupMode = false;
                          error = null;
                        }),
                      ),
                      const SizedBox(height: 7),
                      action(
                        'Sign up',
                        () => setState(() {
                          welcome = false;
                          signupMode = true;
                          error = null;
                        }),
                        outline: true,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 30),
                      Text(
                        signupMode ? 'Sign Up' : 'Log In',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        signupMode
                            ? 'Enter your name, FEU Tech email, phone number, year level, program, and address. Your student/user ID is assigned after registration.'
                            : 'Sign in with your registered FEU Tech email or phone. Choose a return date and time before scanning equipment to borrow it.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff77736d),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 17),
                      if (signupMode) ...[
                        TextField(
                          controller: fullName,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field('Full Name', Icons.person_outline),
                        ),
                        SizedBox(height: signupMode ? 12 : 7),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field(
                            'Email Address',
                            Icons.mail_outline,
                          ),
                        ),
                        SizedBox(height: signupMode ? 12 : 7),
                        TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field(
                            'Phone Number',
                            Icons.phone_outlined,
                          ),
                        ),
                        SizedBox(height: signupMode ? 12 : 7),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: yearLevel,
                                isExpanded: true,
                                decoration: field(
                                  'Year Level',
                                  Icons.school_outlined,
                                ),
                                items:
                                    const [
                                          '1st Year',
                                          '2nd Year',
                                          '3rd Year',
                                          '4th Year',
                                          'Graduate',
                                        ]
                                        .map(
                                          (y) => DropdownMenuItem(
                                            value: y,
                                            child: Text(
                                              y,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(() => yearLevel = v),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedProgram,
                                isExpanded: true,
                                decoration: field(
                                  'Program',
                                  Icons.menu_book_outlined,
                                ),
                                items:
                                    const [
                                          'BS Computer Science',
                                          'BS Information Technology',
                                          'BS Information Systems',
                                          'BS Engineering',
                                          'Other',
                                        ]
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                              p,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(() {
                                  selectedProgram = v;
                                  if (v != 'Other') program.text = v ?? '';
                                }),
                              ),
                            ),
                          ],
                        ),
                        if (selectedProgram == 'Other') ...[
                          const SizedBox(height: 7),
                          TextField(
                            controller: program,
                            style: const TextStyle(color: ink, fontSize: 12),
                            decoration: field(
                              'Enter your program',
                              Icons.menu_book_outlined,
                            ),
                          ),
                        ],
                        SizedBox(height: signupMode ? 12 : 7),
                        TextField(
                          controller: address,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field(
                            'Home Address',
                            Icons.home_outlined,
                          ),
                        ),
                        SizedBox(height: signupMode ? 12 : 7),
                      ] else ...[
                        Row(
                          children: [
                            authTab(
                              'Email',
                              !phoneLogin,
                              () => setState(() {
                                phoneLogin = false;
                                error = null;
                              }),
                            ),
                            const SizedBox(width: 7),
                            authTab(
                              'Phone',
                              phoneLogin,
                              () => setState(() {
                                phoneLogin = true;
                                error = null;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneLogin ? phone : email,
                          keyboardType: phoneLogin
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field(
                            phoneLogin
                                ? 'Enter Your Phone'
                                : 'Enter Your Email',
                            phoneLogin
                                ? Icons.phone_outlined
                                : Icons.mail_outline,
                          ),
                        ),
                        SizedBox(height: signupMode ? 12 : 7),
                      ],
                      TextField(
                        controller: pass,
                        obscureText: !showPassword,
                        style: const TextStyle(color: ink, fontSize: 12),
                        decoration: field(
                          signupMode ? 'New Password' : 'Enter Your Password',
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 17,
                            ),
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                          ),
                        ),
                      ),
                      if (signupMode) ...[
                        SizedBox(height: signupMode ? 12 : 7),
                        TextField(
                          controller: confirm,
                          obscureText: !showConfirmPassword,
                          style: const TextStyle(color: ink, fontSize: 12),
                          decoration: field(
                            'Confirm Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              tooltip: showConfirmPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 17,
                              ),
                              onPressed: () => setState(
                                () =>
                                    showConfirmPassword = !showConfirmPassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 23,
                              child: Transform.scale(
                                scale: .72,
                                child: Checkbox(
                                  value: termsAccepted,
                                  onChanged: (v) => setState(
                                    () => termsAccepted = v ?? false,
                                  ),
                                  activeColor: const Color(0xffe99a12),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Wrap(
                                  children: [
                                    const Text(
                                      'I agree with the ',
                                      style: TextStyle(
                                        color: Color(0xff6b665f),
                                        fontSize: 9,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => showPolicy(false),
                                      child: const Text(
                                        'Terms and Conditions',
                                        style: TextStyle(
                                          color: Color(0xffa66a00),
                                          fontSize: 9,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' and ',
                                      style: TextStyle(
                                        color: Color(0xff6b665f),
                                        fontSize: 9,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => showPolicy(true),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: Color(0xffa66a00),
                                          fontSize: 9,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      '.',
                                      style: TextStyle(
                                        color: Color(0xff6b665f),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 23,
                              child: Transform.scale(
                                scale: .72,
                                child: Checkbox(
                                  value: rememberMe,
                                  onChanged: (v) =>
                                      setState(() => rememberMe = v ?? false),
                                  activeColor: const Color(0xffe99a12),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                color: Color(0xff55514c),
                                fontSize: 9,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => notice(
                                'Password recovery is not configured. Contact your administrator.',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xffb87600),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xffbd293d),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: signupMode
                            ? MediaQuery.sizeOf(context).height * .17
                            : 10,
                      ),
                      action(
                        busy
                            ? (signupMode
                                  ? 'Creating Account...'
                                  : 'Logging In...')
                            : (signupMode ? 'Create Account' : 'Log In'),
                        busy ? null : go,
                      ),
                      if (!signupMode) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xffddd6cc)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              child: Text(
                                'Or Continue With',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xffddd6cc)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    notice('Google sign-in is not configured.'),
                                icon: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xff4285f4),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                label: const Text(
                                  'Google',
                                  style: TextStyle(fontSize: 10, color: ink),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xffe3ded5),
                                  ),
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    notice('Apple sign-in is not configured.'),
                                icon: const Icon(
                                  Icons.apple,
                                  size: 15,
                                  color: ink,
                                ),
                                label: const Text(
                                  'Apple',
                                  style: TextStyle(fontSize: 10, color: ink),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xffe3ded5),
                                  ),
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 9),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              signupMode
                                  ? 'Have an account? '
                                  : "Don't have an account? ",
                              style: const TextStyle(
                                color: Color(0xff55514c),
                                fontSize: 9,
                              ),
                            ),
                            GestureDetector(
                              onTap: busy ? null : toggleMode,
                              child: Text(
                                signupMode ? 'Sign in' : 'Sign up',
                                style: const TextStyle(
                                  color: Color(0xffa66a00),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  List<dynamic> equipment = [], loans = [];
  List<dynamic> transactions = [];
  String historyType = 'ALL';
  String historyEquipment = 'ALL';
  bool loading = true;
  String? err;
  WebSocket? socket;
  bool get isAdmin => api.user['role'] == 'ADMIN';
  @override
  void initState() {
    super.initState();
    load();
    if (isAdmin) _connect();
  }

  Future<void> load() async {
    try {
      final requests = [api.get('/equipment'), api.get('/receipts')];
      if (isAdmin) requests.add(api.get('/transactions'));
      final values = await Future.wait(requests);
      if (!mounted) return;
      setState(() {
        equipment = values[0];
        loans = values[1];
        if (isAdmin) transactions = values[2];
        err = null;
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          err = e.toString();
          loading = false;
        });
    }
  }

  void _connect() {
    try {
      final u = Uri.parse(
        api.base.replaceFirst('http', 'ws') + '/events?token=${api.token}',
      );
      WebSocket.connect(u.toString())
          .then((s) {
            socket = s;
            s.listen(
              (raw) {
                final event = jsonDecode(raw as String);
                if (mounted) {
                  final record = event['data'];
                  final message = switch (event['type']) {
                    'loan' =>
                      'New loan: ${record['equipment_name']} / ${record['borrower_name']}',
                    'return' =>
                      'Return completed: ${record['equipment_name']} / ${record['borrower_name']}',
                    'transaction' =>
                      'Stock transaction recorded for ${record['equipment_id']}',
                    _ => 'Inventory status updated',
                  };
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                }
                load();
              },
              onDone: () {
                if (mounted)
                  Future.delayed(const Duration(seconds: 4), _connect);
              },
            );
          })
          .catchError((_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    socket?.close();
    super.dispose();
  }

  Future<void> scan({required bool returning}) async {
    try {
      if (!returning) {
        try {
          final fresh = await api.get('/equipment');
          if (!mounted) return;
          setState(() => equipment = fresh);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Borrowing requires an active internet connection. No loan was created.',
                ),
              ),
            );
          }
          return;
        }
      }
      DateTime? due;
      if (!returning) {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: DateTime.now().add(const Duration(days: 7)),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time == null) return;
        due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
      if (!mounted) return;
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      );
      if (code == null || code.trim().isEmpty) return;
      if (returning) {
        final r = await api.post(
          '/returns/${Uri.encodeComponent(code.trim())}',
          {},
        );
        _receiptDialog(r);
        await load();
        return;
      }
      final unit = Map<String, dynamic>.from(
        await api.get('/units/${Uri.encodeComponent(code.trim())}'),
      );
      if (unit['status'] != 'AVAILABLE')
        throw Exception('This unit is not available (${unit['status']}).');
      if (!mounted) return;
      final nl = String.fromCharCode(10);
      final content =
          '${unit['equipment_name']} (${unit['equipment_id']})' +
          nl +
          'Serial/barcode: ${unit['serial']}' +
          nl +
          'Borrower: ${api.user['name']} / ${api.user['account_id']} (${api.user['role']})' +
          nl +
          'Planned return: ${due!.toLocal()}' +
          nl +
          nl +
          'Confirm this loan?';
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm loan'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final r = await api.post('/loans', {
        'unit_id': unit['unit_id'],
        'due_at': due.toUtc().toIso8601String(),
        'idempotency_key': const Uuid().v4(),
      });
      _receiptDialog(r);
      await load();
    } catch (e) {
      if (mounted) {
        final detail = e.toString();
        final offline =
            detail.contains('SocketException') ||
            detail.contains('ClientException') ||
            detail.contains('TimeoutException');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              offline
                  ? 'Connection lost. Nothing was queued; retry when online.'
                  : 'Not completed: $e',
            ),
          ),
        );
      }
    }
  }

  void _receiptDialog(dynamic r) {
    final nl = String.fromCharCode(10);
    final text =
        'Borrower: ${r['borrower_name']}' +
        nl +
        'User ID: ${r['borrower_id']} (${r['account_type']})' +
        nl +
        'Equipment: ${r['equipment_name']} (${r['equipment_id']})' +
        nl +
        'Serial/barcode: ${r['barcode']}' +
        nl +
        'Database record: ${r['unit_record_id']}' +
        nl +
        'Borrowed: ${r['borrowed_at']}' +
        nl +
        'Due: ${r['due_at']}' +
        nl +
        'Status: ${r['loan_status']}';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Receipt ${r['receipt_number']}'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
          TextButton(onPressed: () => _share(text), child: const Text('Copy')),
          FilledButton.icon(
            onPressed: () => _exportReceipt(r),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReceipt(dynamic r) async {
    final document = pw.Document();
    final fields = <String, String>{
      'Receipt ID': '${r['receipt_number']}',
      'Borrower': '${r['borrower_name']}',
      'User ID': '${r['borrower_id']}',
      'Account type': '${r['account_type']}',
      'Equipment': '${r['equipment_name']} (${r['equipment_id']})',
      'Serial / barcode': '${r['barcode']}',
      'Database record ID': '${r['unit_record_id']}',
      'Borrowed': '${r['borrowed_at']}',
      'Due': '${r['due_at']}',
      if (r['returned_at'] != null) 'Returned': '${r['returned_at']}',
      'Status': '${r['loan_status']}',
    };
    document.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Stockroom loan receipt',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            for (final entry in fields.entries) ...[
              pw.Text(
                entry.key,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(entry.value),
              pw.SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'stockroom-${r['receipt_number']}.pdf',
    );
  }

  void _share(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt copied. You can paste or share it.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final names = isAdmin
        ? ['Home', 'Products', 'Scan', 'History', 'Settings']
        : ['Home', 'Inventory', 'My loans'];
    final pages = isAdmin
        ? [
            _dashboard(),
            _inventory(),
            _adminScanPage(),
            _history(),
            _settingsPage(),
          ]
        : [_dashboard(), _inventory(), _loans()];
    IconData iconFor(String name) => switch (name) {
      'Home' => Icons.home_outlined,
      'Products' || 'Inventory' => Icons.inventory_2_outlined,
      'Loans' || 'My loans' => Icons.history,
      'Scan' => Icons.qr_code_scanner,
      'History' => Icons.receipt_long_outlined,
      _ => Icons.settings_outlined,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isAdmin && wide ? Colors.white : navy,
            foregroundColor: isAdmin && wide ? navy : Colors.white,
            title: Text(
              isAdmin && wide
                  ? 'Stockroom - Campus Inventory'
                  : 'Stockroom / ${names[tab]}',
            ),
            actions: [
              if (err != null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.cloud_off),
                ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    if (isAdmin)
                      Container(
                        width: 232,
                        color: navy,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 24, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Stockroom',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'CAMPUS INVENTORY',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var i = 0; i < names.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                child: ListTile(
                                  selected: tab == i,
                                  selectedTileColor: const Color(0xff9ce6bc),
                                  selectedColor: navy,
                                  textColor: Colors.white,
                                  iconColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  leading: Icon(iconFor(names[i])),
                                  title: Text(names[i]),
                                  onTap: () => setState(() => tab = i),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      NavigationRail(
                        backgroundColor: Colors.white,
                        selectedIndex: tab,
                        onDestinationSelected: (i) => setState(() => tab = i),
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final n in names)
                            NavigationRailDestination(
                              icon: Icon(iconFor(n)),
                              label: Text(n),
                            ),
                        ],
                      ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[tab]),
                  ],
                )
              : pages[tab],
          bottomNavigationBar: wide
              ? null
              : NavigationBarTheme(
                  data: NavigationBarThemeData(
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => TextStyle(
                        color: isAdmin ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    backgroundColor: isAdmin ? navy : Colors.white,
                    indicatorColor: isAdmin
                        ? const Color(0xff9ce6bc)
                        : const Color(0xffcdece1),
                    selectedIndex: tab,
                    onDestinationSelected: (i) => setState(() => tab = i),
                    destinations: [
                      for (final n in names)
                        NavigationDestination(
                          icon: Icon(
                            iconFor(n),
                            color: isAdmin ? Colors.white : null,
                          ),
                          label: n,
                        ),
                    ],
                  ),
                ),
          floatingActionButton: tab == 0
              ? FloatingActionButton.extended(
                  onPressed: isAdmin
                      ? _editProduct
                      : () => scan(returning: false),
                  icon: Icon(isAdmin ? Icons.add : Icons.qr_code_scanner),
                  label: Text(isAdmin ? 'Add product' : 'Borrow item'),
                )
              : null,
        );
      },
    );
  }

  Widget _dashboard() {
    if (isAdmin) return _adminDashboard();
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Good ${DateTime.now().hour < 12 ? 'morning' : 'day'}, ${api.user['name']}',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: navy),
          ),
          const SizedBox(height: 6),
          Text('${api.user['role']} · ${api.user['account_id']}'),
          if (err != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Server unavailable. Borrowing and returns require an active connection. $err',
                ),
              ),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric(
                'Equipment types',
                '${equipment.length}',
                Icons.inventory_2,
              ),
              _metric(
                'Available units',
                '${equipment.fold<int>(0, (s, e) => s + (e['available'] as int))}',
                Icons.check_circle,
              ),
              _metric(
                isAdmin ? 'Active loans' : 'My active loans',
                '${loans.where((x) => x['loan_status'] == 'ACTIVE').length}',
                Icons.assignment,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent loans',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () {
                  if (isAdmin) {
                    _loansDialog();
                  } else {
                    setState(() => tab = 2);
                  }
                },
                child: const Text('View all'),
              ),
            ],
          ),
          ...loans.take(5).map(_loanCard),
        ],
      ),
    );
  }

  Widget _adminDashboard() {
    if (loading) return const Center(child: CircularProgressIndicator());
    final total = equipment.fold<int>(0, (n, e) => n + (e['total'] as int));
    final available = equipment.fold<int>(
      0,
      (n, e) => n + (e['available'] as int),
    );
    final issued = equipment.fold<int>(0, (n, e) => n + (e['issued'] as int));
    final low = equipment
        .where((e) => (e['available'] as int) <= (e['min_stock'] as int))
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${DateTime.now().hour < 12 ? 'morning' : 'day'}, ${api.user['name']}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: navy),
                    ),
                    Text(
                      'System Administrator  /  ${api.user['account_id']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (wide)
                FilledButton.icon(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add stock'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('Total items', '$total', Icons.inventory_2_outlined),
              _metric(
                'Available now',
                '$available',
                Icons.check_circle_outline,
              ),
              _metric('Currently issued', '$issued', Icons.outbox_outlined),
              _metric(
                'Low stock products',
                '${low.length}',
                Icons.warning_amber_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _stockOverview(low)),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _recentActivity()),
              ],
            )
          else ...[
            _stockOverview(low),
            const SizedBox(height: 12),
            _recentActivity(),
          ],
          if (err != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Backend connection issue: $err'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stockOverview(List<dynamic> low) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.layers_outlined, color: navy),
          title: const Text(
            'Inventory overview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('View all'),
          ),
        ),
        if (equipment.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'No products in inventory yet. Add stock to get started.',
            ),
          ),
        for (final e in equipment.take(6))
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.inventory_2_outlined),
            ),
            title: Text(e['name']),
            subtitle: Text('${e['category']}  /  ${e['id']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e['available']} available',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _stockChip(e),
              ],
            ),
          ),
        if (low.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '${low.length} product${low.length == 1 ? '' : 's'} at or below minimum stock',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _recentActivity() => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.schedule, color: navy),
          title: Text(
            'Recent activity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (loans.isEmpty && transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('No recent inventory activity.'),
          ),
        for (final r in loans.take(4))
          ListTile(
            leading: Icon(
              r['loan_status'] == 'RETURNED'
                  ? Icons.assignment_return
                  : Icons.outbox_outlined,
              color: teal,
            ),
            title: Text(
              '${r['equipment_name']} ${r['loan_status'] == 'RETURNED' ? 'returned' : 'issued'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('by ${r['borrower_name']}  /  ${r['borrower_id']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _receiptDialog(r),
          ),
      ],
    ),
  );

  Widget _stockChip(dynamic e) {
    final low = (e['available'] as int) <= (e['min_stock'] as int);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: low ? const Color(0xffffe2df) : const Color(0xffd9f2df),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        low ? 'LOW STOCK' : 'HEALTHY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: low ? Colors.red.shade800 : Colors.green.shade900,
        ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: teal),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    ),
  );
  Widget _inventory() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isAdmin)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _editProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search product ID or name',
            border: OutlineInputBorder(),
          ),
          onChanged: (q) => setState(() => _query = q.toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (equipment.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text('No products found.'),
          ),
        ...equipment
            .where(
              (e) => ('${e['id']} ${e['name']}').toLowerCase().contains(_query),
            )
            .map(
              (e) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(e['name']),
                  subtitle: Text(
                    '${e['id']} / ${e['category']} / Total ${e['total']} / Available ${e['available']} / Issued ${e['issued']}',
                  ),
                  isThreeLine: true,
                  trailing: isAdmin
                      ? PopupMenuButton<String>(
                          tooltip: 'Manage product',
                          onSelected: (v) {
                            if (v == 'units') _productUnits(e);
                            if (v == 'edit') _editProduct(e);
                            if (v == 'delete') _deleteProduct(e);
                            if (v == 'receive') _addUnits(e);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'receive',
                              child: Text('Scan / enter item serial'),
                            ),
                            PopupMenuItem(
                              value: 'units',
                              child: Text('View units / status'),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit product'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete product'),
                            ),
                          ],
                        )
                      : _stockChip(e),
                  onTap: isAdmin ? () => _productUnits(e) : null,
                ),
              ),
            ),
      ],
    ),
  );
  String _query = '';

  Future<void> _editProduct([dynamic product]) async {
    final editing = product != null;
    if (!editing) {
      final name = TextEditingController();
      final category = TextEditingController();
      final form = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('New product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: category,
                decoration: const InputDecoration(
                  labelText: 'Product category',
                ),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Next'),
            ),
          ],
        ),
      );
      try {
        if (form != true) return;
        if (name.text.trim().isEmpty || category.text.trim().isEmpty) {
          throw Exception('Enter a product name and category.');
        }
        final id = 'EQ-${const Uuid().v4().substring(0, 8).toUpperCase()}';
        final created = await api.post('/equipment', {
          'id': id,
          'name': name.text.trim(),
          'category': category.text.trim(),
          'min_stock': 0,
          'initial_quantity': 0,
          'serials': <String>[],
        });
        await load();
        if (mounted) await _addUnits(created, firstScan: true);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create product: $e')),
          );
      } finally {
        name.dispose();
        category.dispose();
      }
      return;
    }
    final id = TextEditingController(text: editing ? product['id'] : '');
    final name = TextEditingController(text: editing ? product['name'] : '');
    final category = TextEditingController(
      text: editing ? product['category'] : '',
    );
    final minimum = TextEditingController(
      text: editing ? '${product['min_stock']}' : '0',
    );
    final quantity = TextEditingController(text: '0');
    final barcodes = TextEditingController();
    final form = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit product'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: minimum,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum stock level',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, {
              'id': id.text.trim(),
              'name': name.text.trim(),
              'category': category.text.trim(),
              'min': minimum.text.trim(),
              'quantity': quantity.text.trim(),
              'barcodes': barcodes.text.trim(),
            }),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (form == null) return;
    try {
      final min = int.tryParse(form['min']!);
      if (form['name']!.isEmpty ||
          form['category']!.isEmpty ||
          min == null ||
          min < 0)
        throw Exception(
          'Enter a name, category, and nonnegative whole-number minimum stock.',
        );
      if (editing) {
        await api.patch('/equipment/${Uri.encodeComponent(form['id']!)}', {
          'name': form['name'],
          'category': form['category'],
          'min_stock': min,
        });
      }
      await load();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Product updated.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save product: $e')));
    } finally {
      id.dispose();
      name.dispose();
      category.dispose();
      minimum.dispose();
      quantity.dispose();
      barcodes.dispose();
    }
  }

  Future<void> _addUnits(dynamic product, {bool firstScan = false}) async {
    var scanNext = true;
    while (scanNext && mounted) {
      final serial = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanPage(title: 'Scan item barcode or QR code'),
        ),
      );
      if (serial == null || serial.trim().isEmpty) return;
      try {
        final unit = await api.post(
          '/equipment/${Uri.encodeComponent(product['id'])}/units',
          {'serial': serial.trim()},
        );
        await load();
        if (!mounted) return;
        scanNext =
            await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Item added'),
                content: Text(
                  '${product['name']} now has ${product['total'] == null ? 'more' : 'updated'} stock.\nSerial: ${unit['serial']}\nDatabase ID: ${unit['id']}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Done'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Scan next item'),
                  ),
                ],
              ),
            ) ??
            false;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Item not added: $e')));
        scanNext =
            await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Barcode not saved'),
                content: Text('$e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ) ??
            false;
      }
    }
  }

  Future<void> _deleteProduct(dynamic product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete ${product['name']} (${product['id']})? Products with transaction history are retained for audit purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/equipment/${Uri.encodeComponent(product['id'])}');
      await load();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete product: $e')));
    }
  }

  Future<void> _productUnits(dynamic product) async {
    try {
      final detail = Map<String, dynamic>.from(
        await api.get('/equipment/${Uri.encodeComponent(product['id'])}'),
      );
      if (!mounted) return;
      final units = List<Map<String, dynamic>>.from(
        (detail['units'] as List).map((x) => Map<String, dynamic>.from(x)),
      );
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${product['name']} units'),
          content: SizedBox(
            width: 420,
            child: units.isEmpty
                ? const Text('No physical units are registered.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (var i = 0; i < units.length; i++)
                        ListTile(
                          title: Text(units[i]['serial']),
                          subtitle: Text('Record ID: ${units[i]['id']}'),
                          trailing: DropdownButton<String>(
                            value: units[i]['status'],
                            items: [
                              for (final status in [
                                'AVAILABLE',
                                'ISSUED',
                                'MAINTENANCE',
                              ])
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                            ],
                            onChanged:
                                !isAdmin || units[i]['status'] == 'ISSUED'
                                ? null
                                : (status) async {
                                    if (status == null) return;
                                    try {
                                      await api.patch(
                                        '/units/${units[i]['id']}/status',
                                        {'status': status},
                                      );
                                      units[i]['status'] = status;
                                      await load();
                                    } catch (e) {
                                      if (mounted)
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Status update failed: $e',
                                                ),
                                              ),
                                            );
                                    }
                                  },
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _addUnits(product);
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Add item'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load product units: $e')),
        );
    }
  }

  Widget _adminScanPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Scan item',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: navy, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Scan a unit barcode to process its return. To receive new stock, choose a product and scan each unit from Products.',
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.keyboard_return)),
          title: const Text('Return equipment'),
          subtitle: const Text(
            'Scan or enter the serial number of an issued item.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => scan(returning: true),
        ),
      ),
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
          title: const Text('Current loans'),
          subtitle: Text(
            '${loans.where((l) => l['loan_status'] == 'ACTIVE').length} active loans',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _loansDialog,
        ),
      ),
    ],
  );

  Future<void> _loansDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Current loans'),
        content: SizedBox(
          width: 520,
          child: loans.isEmpty
              ? const Text('No loan records.')
              : ListView(
                  shrinkWrap: true,
                  children: loans
                      .map(
                        (r) => ListTile(
                          title: Text(
                            '${r['equipment_name']} · ${r['borrower_name']}',
                          ),
                          subtitle: Text(
                            '${r['barcode']} / ${r['borrower_id']} / due ${r['due_at']}',
                          ),
                          onTap: () {
                            Navigator.pop(c);
                            _receiptDialog(r);
                          },
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _settingsPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Settings',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: navy, fontWeight: FontWeight.bold),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(api.user['name'] ?? ''),
          subtitle: Text('${api.user['role']} · ${api.user['account_id']}'),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backend connection'),
          subtitle: Text(api.base),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: widget.onLogout,
        ),
      ),
    ],
  );

  Widget _history() {
    final rows = transactions
        .where(
          (t) =>
              (historyType == 'ALL' || t['type'] == historyType) &&
              (historyEquipment == 'ALL' ||
                  t['equipment_id'] == historyEquipment),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: historyEquipment,
                  decoration: const InputDecoration(labelText: 'Product ID'),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('All products'),
                    ),
                    ...equipment.map(
                      (e) => DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(e['id']),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => historyEquipment = v ?? 'ALL'),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: historyType,
                  decoration: const InputDecoration(
                    labelText: 'Transaction type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All types')),
                    DropdownMenuItem(value: 'ISSUE', child: Text('ISSUE')),
                    DropdownMenuItem(value: 'RECEIVE', child: Text('RECEIVE')),
                  ],
                  onChanged: (v) => setState(() => historyType = v ?? 'ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No transactions match these filters.'),
            ),
          for (final t in rows)
            Card(
              child: ListTile(
                leading: Icon(
                  t['type'] == 'ISSUE'
                      ? Icons.outbox_outlined
                      : Icons.move_to_inbox_outlined,
                  color: teal,
                ),
                title: Text(
                  '${t['type']}  /  ${t['equipment_name']} (${t['equipment_id']})',
                ),
                subtitle: Text(
                  'Qty ${t['quantity']}  /  Serial ${t['serial'] ?? 'multiple units'}  /  ${t['created_at']}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _loans() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isAdmin || loans.any((x) => x['loan_status'] == 'ACTIVE'))
          FilledButton.icon(
            onPressed: () => scan(returning: true),
            icon: const Icon(Icons.assignment_return),
            label: const Text('Return by QR/barcode'),
          ),
        const SizedBox(height: 8),
        if (loans.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No loans yet'),
            ),
          ),
        ...loans.map(_loanCard),
      ],
    ),
  );
  Widget _loanCard(dynamic r) => Card(
    child: ListTile(
      leading: Icon(
        r['loan_status'] == 'ACTIVE' ? Icons.schedule : Icons.check_circle,
        color: r['loan_status'] == 'ACTIVE' ? Colors.orange : teal,
      ),
      title: Text('${r['equipment_name']} · ${r['equipment_id']}'),
      subtitle: Text(
        '${r['borrower_name']} (${r['borrower_id']})\n${r['barcode']} · Due ${r['due_at']}',
      ),
      isThreeLine: true,
      trailing: Text(r['loan_status']),
      onTap: () => _receiptDialog(r),
    ),
  );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.title = 'Scan QR code or barcode'});
  final String title;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final manual = TextEditingController();
  final scanner = MobileScannerController();
  bool done = false;
  bool manualEntry = false;
  @override
  void dispose() {
    manual.dispose();
    scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: scanner,
            onDetect: (capture) {
              if (done || manualEntry) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null) {
                done = true;
                Navigator.pop(context, code);
              }
            },
            errorBuilder: (context, error) => Center(
              child: Text('Camera unavailable: ${error.errorCode.name}'),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Center the item QR code or barcode in the camera'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: manual,
                  onTap: () {
                    manualEntry = true;
                    scanner.stop();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Or enter barcode manually',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, manual.text),
                child: const Text('Use'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

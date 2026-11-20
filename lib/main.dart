import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'auth_screen.dart';
import 'app_palette.dart';
import 'student_profile_editor.dart';
import 'notification_page.dart';

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
const navy = AppPalette.deep,
    teal = AppPalette.primary,
    canvas = Color(0xffffffff);
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: canvas,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.line),
        ),
      ),
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
      ? AuthScreen(onLogin: _signed)
      : Home(onLogout: _logout);
}

class Home extends StatefulWidget {
  const Home({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  String iconVariant = 'violet';
  List<dynamic> equipment = [], loans = [];
  List<dynamic> transactions = [], notifications = [];
  String historyType = 'ALL';
  String historyEquipment = 'ALL';
  bool loading = true;
  int get unreadNotifications =>
      notifications.where((item) => item['is_read'] != true).length;
  String? err;
  WebSocket? socket;
  bool get isAdmin => api.user['role'] == 'ADMIN';
  @override
  void initState() {
    super.initState();
    load();
    if (isAdmin) _connect();
    if (!isAdmin && Platform.isAndroid) _loadIconVariant();
  }

  Future<void> _loadIconVariant() async {
    try {
      final result = await const MethodChannel('stockroom/app_icon')
          .invokeMethod<String>('getIcon');
      if (mounted) setState(() => iconVariant = result ?? 'violet');
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final requests = [
        api.get('/equipment'),
        api.get('/receipts'),
        api.get('/me'),
      ];
      if (isAdmin)
        requests.add(api.get('/transactions'));
      else
        requests.add(api.get('/notifications'));
      final values = await Future.wait(requests);
      if (!mounted) return;
      setState(() {
        equipment = values[0];
        loans = values[1];
        api.user = Map<String, dynamic>.from(values[2]);
        if (isAdmin) {
          transactions = values[3];
        } else {
          notifications = values[3];
        }
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
    final fields = _receiptFields(r);
    final text = fields.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppPalette.mist,
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan receipt',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.deep,
                          ),
                        ),
                        Text(
                          '${r['receipt_number']}',
                          style: const TextStyle(color: AppPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(c).height * .48,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final field in fields.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppPalette.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                field.value,
                                style: const TextStyle(color: AppPalette.ink),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () => _share(text),
                    child: const Text('Copy'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(c);
                      _exportReceipt(r);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text(
                      'Download receipt',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportReceipt(dynamic r) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Download receipt'),
                subtitle: Text('Choose a file format'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF document'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('PNG image'),
                onTap: () => Navigator.pop(context, 'png'),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null) return;
    try {
      final bytes = format == 'pdf'
          ? await _pdfReceiptBytes(r)
          : await _pngReceiptBytes(r);
      final fileName = 'stockroom-${r['receipt_number']}.$format';
      if (Platform.isAndroid) {
        final saved = await const MethodChannel('stockroom/files')
            .invokeMethod<bool>('saveFile', {
              'fileName': fileName,
              'mimeType': format == 'pdf' ? 'application/pdf' : 'image/png',
              'bytes': bytes,
            });
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Saved $fileName')));
        }
      } else if (format == 'pdf') {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        throw UnsupportedError('PNG download is available on Android.');
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save receipt: $error')),
        );
    }
  }

  Map<String, String> _receiptFields(dynamic r) => <String, String>{
    'Receipt ID': '${r['receipt_number']}',
    'Borrower': '${r['borrower_name']}',
    'User ID': '${r['borrower_id']}',
    'Account type': '${r['account_type']}',
    'Equipment': '${r['equipment_name']} (${r['equipment_id']})',
    'Serial / barcode': '${r['barcode']}',
    'Database record ID': '${r['unit_record_id']}',
    'Borrowed': _shortDate(r['borrowed_at']),
    'Due': _shortDate(r['due_at']),
    if (r['returned_at'] != null) 'Returned': _shortDate(r['returned_at']),
    'Status': '${r['loan_status']}',
  };

  String _shortDate(dynamic raw) {
    final date = DateTime.tryParse('$raw');
    if (date == null) return '$raw';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<Uint8List> _pdfReceiptBytes(dynamic r) async {
    final document = pw.Document();
    final fields = _receiptFields(r);
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
    return document.save();
  }

  Future<Uint8List> _pngReceiptBytes(dynamic r) async {
    const width = 1000.0;
    const height = 1420.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 180),
      Paint()..color = AppPalette.primary,
    );
    void line(
      String value,
      double x,
      double y,
      double size,
      Color color, {
      FontWeight weight = FontWeight.normal,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: width - x - 64);
      painter.paint(canvas, Offset(x, y));
    }

    line('STOCKROOM', 64, 52, 28, Colors.white, weight: FontWeight.bold);
    line('Loan receipt', 64, 96, 40, Colors.white, weight: FontWeight.bold);
    var y = 220.0;
    for (final entry in _receiptFields(r).entries) {
      line(
        entry.key.toUpperCase(),
        64,
        y,
        20,
        AppPalette.muted,
        weight: FontWeight.bold,
      );
      line(entry.value, 64, y + 34, 28, AppPalette.deep);
      y += 102;
    }
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not create PNG receipt');
    return data.buffer.asUint8List();
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
        : ['Home', 'Scan', 'Items', 'History', 'Settings'];
    final pages = isAdmin
        ? [
            _dashboard(),
            _inventory(),
            _adminScanPage(),
            _history(),
            _settingsPage(),
          ]
        : [
            _dashboard(),
            _studentScan(),
            _studentItems(),
            _studentHistory(),
            _studentSettings(),
          ];
    IconData iconFor(String name) => switch (name) {
      'Home' => Icons.home_outlined,
      'Products' || 'Inventory' || 'Items' => Icons.inventory_2_outlined,
      'Loans' || 'My loans' => Icons.history,
      'Scan' => Icons.qr_code_scanner,
      'History' => Icons.receipt_long_outlined,
      _ => Icons.settings_outlined,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        return Scaffold(
          appBar: isAdmin
              ? AppBar(
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
                )
              : null,
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
                                  selectedTileColor: AppPalette.pearl,
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
              : !isAdmin
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Material(
                      elevation: 14,
                      shadowColor: AppPalette.deep.withOpacity(.18),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: 72,
                        child: Row(
                          children: [
                            for (var i = 0; i < names.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Material(
                                    color: tab == i
                                        ? AppPalette.mist
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      overlayColor: WidgetStatePropertyAll(
                                        AppPalette.pearl.withOpacity(.5),
                                      ),
                                      onTap: () => setState(() => tab = i),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            iconFor(names[i]),
                                            size: 23,
                                            color: tab == i
                                                ? AppPalette.primary
                                                : AppPalette.muted,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            names[i],
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: tab == i
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: tab == i
                                                  ? AppPalette.primary
                                                  : AppPalette.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
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
                    indicatorColor: AppPalette.pearl,
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
          floatingActionButton: isAdmin && tab == 0
              ? FloatingActionButton.extended(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                )
              : null,
        );
      },
    );
  }

  Widget _dashboardHero({bool admin = false}) => Container(
    height: 185,
    decoration: BoxDecoration(
      gradient: AppPalette.metallic,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x286c4cce),
          blurRadius: 18,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -35,
          top: -56,
          child: Container(
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 19),
            ),
          ),
        ),
        const Positioned(
          right: 24,
          bottom: 21,
          child: Icon(
            Icons.qr_code_2_rounded,
            size: 64,
            color: Color(0x99ffffff),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 22, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STOCKROOM  /  FEU TECH',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                admin ? 'Inventory in focus' : 'Your equipment,\nat a glance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                admin
                    ? 'Manage stock, loans, and returns in one place.'
                    : 'Borrow, track, and return with confidence.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dashboard() {
    if (isAdmin) return _adminDashboard();
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 20,
                color: AppPalette.mist.withOpacity(.72),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good day, ${'${api.user['name'] ?? ''}'.trim().split(' ').first}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold, color: navy),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${api.user['account_id']}\n${api.user['email']}',
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Leaderboard',
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: _openLeaderboard,
              ),
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history),
                onPressed: () => setState(() => tab = 3),
              ),
              IconButton(
                tooltip: 'Notifications',
                icon: unreadNotifications == 0
                    ? const Icon(Icons.notifications_none)
                    : Badge.count(
                        count: unreadNotifications,
                        child: const Icon(Icons.notifications_none),
                      ),
                onPressed: _openNotifications,
              ),
            ],
          ),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => scan(returning: false),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Borrow item'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _studentMetric(
                  'Types',
                  '${equipment.length}',
                  Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _studentMetric(
                  'Available',
                  '${equipment.fold<int>(0, (s, e) => s + (e['available'] as int))}',
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _studentMetric(
                  'My loans',
                  '${loans.where((x) => x['loan_status'] == 'ACTIVE').length}',
                  Icons.assignment_outlined,
                ),
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
                    setState(() => tab = 3);
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
          _dashboardHero(admin: true),
          const SizedBox(height: 22),
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
        color: low ? const Color(0xffffe2df) : AppPalette.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        low ? 'LOW STOCK' : 'HEALTHY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: low ? Colors.red.shade800 : AppPalette.deep,
        ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600
        ? (MediaQuery.sizeOf(context).width - 52) / 2
        : 180,
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

  Widget _studentMetric(String title, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppPalette.primary, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppPalette.deep,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
        ],
      ),
    ),
  );
  void _openLeaderboard() {
    final future = api.get('/leaderboard');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Leaderboard')),
          body: FutureBuilder<dynamic>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError)
                return Center(
                  child: Text('Could not load leaderboard: ${snapshot.error}'),
                );
              final people = List<dynamic>.from(snapshot.data as List);
              if (people.isEmpty)
                return const Center(child: Text('No student loans yet.'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: people.length,
                itemBuilder: (context, index) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppPalette.mist,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: navy),
                      ),
                    ),
                    title: Text('${people[index]['name']}'),
                    subtitle: Text(
                      '${people[index]['program']}\n${people[index]['year_level']} • ${people[index]['section']}\n${people[index]['borrow_count']} items borrowed',
                    ),
                    isThreeLine: true,
                    trailing: index < 3
                        ? Icon(
                            Icons.emoji_events,
                            color: index == 0
                                ? const Color(0xffd39a2e)
                                : AppPalette.primary,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationPage(
          initial: notifications,
          onRead: (id) => setState(() {
            for (final notice in notifications) {
              if (notice['id'] == id) notice['is_read'] = true;
            }
          }),
        ),
      ),
    );
  }

  Widget _studentScan() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Scan an item',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: navy, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Use the item barcode or QR code to borrow or return equipment.',
        style: TextStyle(color: AppPalette.muted),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 74,
                color: AppPalette.primary,
              ),
              const SizedBox(height: 13),
              const Text(
                'Borrow equipment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a due date, scan the item, and confirm the loan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.muted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => scan(returning: false),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan to borrow'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          leading: const Icon(
            Icons.assignment_return_outlined,
            color: AppPalette.primary,
          ),
          title: const Text('Return an item'),
          subtitle: const Text(
            'Scan an item you borrowed to complete its return.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => scan(returning: true),
        ),
      ),
    ],
  );

  Widget _studentItems() {
    final items =
        equipment.where((item) => (item['available'] as num) > 0).toList()
          ..sort(
            (a, b) => '${a['name']}'.toLowerCase().compareTo(
              '${b['name']}'.toLowerCase(),
            ),
          );
    final hotCount = items.fold<int>(
      0,
      (best, item) => (item['borrow_count'] as num? ?? 0).toInt() > best
          ? (item['borrow_count'] as num).toInt()
          : best,
    );
    final matches = items
        .where(
          (item) => '${item['name']} ${item['id']} ${item['category']}'
              .toLowerCase()
              .contains(_query),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Items',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: navy, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Available equipment, sorted by name.',
            style: TextStyle(color: AppPalette.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search items',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) =>
                setState(() => _query = value.toLowerCase().trim()),
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No available items match your search.'),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 180,
            ),
            itemBuilder: (context, index) {
              final item = matches[index];
              return Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppPalette.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  overlayColor: WidgetStatePropertyAll(
                    AppPalette.pearl.withOpacity(.35),
                  ),
                  onTap: () => _studentItemDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppPalette.mist,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: AppPalette.primary,
                              ),
                            ),
                            if (hotCount > 0 &&
                                (item['borrow_count'] as num? ?? 0).toInt() ==
                                    hotCount)
                              const Tooltip(
                                message: 'Most borrowed',
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: Color(0xffe9784d),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${item['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${item['category']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['available']} in stock',
                          style: const TextStyle(
                            color: AppPalette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _studentItemDetail(dynamic item) async {
    try {
      final detail = await api.get(
        '/equipment/${Uri.encodeComponent('${item['id']}')}',
      );
      if (!mounted) return;
      final units = List<dynamic>.from(detail['units'] as List);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .68,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['name']}',
                    style: const TextStyle(
                      fontSize: 21,
                      color: navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item['available']} available • ${item['total']} total',
                    style: const TextStyle(color: AppPalette.muted),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Physical items',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final unit in units)
                          ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text('${unit['serial']}'),
                            trailing: Text(
                              '${unit['status']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (item['available'] as num) > 0
                          ? () {
                              Navigator.pop(sheetContext);
                              scan(returning: false);
                            }
                          : null,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Borrow item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load item: $e')));
    }
  }

  Widget _studentHistory() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'History',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: navy, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your loans and receipts.',
          style: TextStyle(color: AppPalette.muted),
        ),
        const SizedBox(height: 16),
        if (loans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No borrowed items yet.'),
          ),
        for (final loan in loans)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.receipt_long_outlined,
                color: AppPalette.primary,
              ),
              title: Text('${loan['equipment_name']}'),
              subtitle: Text(
                '${loan['loan_status']} • ${_shortDate(loan['borrowed_at'])}',
              ),
              trailing: IconButton(
                tooltip: 'Download receipt',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _exportReceipt(loan),
              ),
              onTap: () => _receiptDialog(loan),
            ),
          ),
      ],
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

  Widget _studentSettings() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Settings',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: navy, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 14),
      _settingsTile(
        leading: const CircleAvatar(
          backgroundColor: AppPalette.mist,
          child: Icon(Icons.person_outline, color: AppPalette.primary),
        ),
        title: Text('${api.user['name']}'),
        subtitle: Text(
          'Student ID ${api.user['account_id']} • ${api.user['section'] ?? ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                StudentProfileEditor(onSaved: () => setState(() {})),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'App preferences',
        style: TextStyle(fontWeight: FontWeight.bold, color: AppPalette.deep),
      ),
      const SizedBox(height: 8),
      _settingsTile(
        leading: const Icon(Icons.apps_outlined),
        title: const Text('App icon'),
        subtitle: Text(
          Platform.isAndroid ? 'Current: $iconVariant' : 'Available on Android',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: Platform.isAndroid ? _chooseAppIcon : null,
      ),
      _settingsTile(
        leading: const Icon(Icons.notifications_none),
        title: const Text('Notifications'),
        subtitle: const Text('Loan and return activity'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openNotifications,
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backend connection'),
          subtitle: Text(api.base),
        ),
      ),
      const SizedBox(height: 18),
      _settingsTile(
        leading: const Icon(Icons.logout),
        title: const Text('Log out'),
        onTap: _confirmLogout,
      ),
    ],
  );

  Widget _settingsTile({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppPalette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(AppPalette.pearl.withOpacity(.35)),
        child: ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
      ),
    ),
  );

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to borrow items and view your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  void _chooseAppIcon() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose app icon',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppPalette.deep,
              ),
            ),
            for (final (value, label, color) in [
              ('violet', 'Violet', AppPalette.primary),
              ('silver', 'Silver', const Color(0xffa7a9bd)),
              ('midnight', 'Midnight', AppPalette.deep),
            ])
              _settingsTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(label),
                trailing: iconVariant == value
                    ? const Icon(Icons.check, color: AppPalette.primary)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setAppIcon(value);
                },
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _setAppIcon(String choice) async {
    try {
      await const MethodChannel('stockroom/app_icon')
          .invokeMethod<void>('setIcon', {'icon': choice});
      if (mounted) setState(() => iconVariant = choice);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change app icon: $e')),
        );
    }
  }

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

  Widget _loanCard(dynamic r) => Card(
    child: ListTile(
      leading: Icon(
        r['loan_status'] == 'ACTIVE' ? Icons.schedule : Icons.check_circle,
        color: r['loan_status'] == 'ACTIVE' ? AppPalette.primary : teal,
      ),
      title: Text('${r['equipment_name']} · ${r['equipment_id']}'),
      subtitle: Text(
        '${r['borrower_name']} (${r['borrower_id']})\n${r['barcode']} · Due ${_shortDate(r['due_at'])}',
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

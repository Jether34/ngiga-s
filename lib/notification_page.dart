import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'header_haze.dart';
import 'main.dart' show api;

class NotificationPage extends StatefulWidget {
  const NotificationPage({
    super.key,
    required this.initial,
    required this.onRead,
  });
  final List<dynamic> initial;
  final ValueChanged<String> onRead;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late List<dynamic> notices = widget.initial
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  String? error;

  Future<void> refresh() async {
    try {
      final result = await api.get('/notifications');
      if (mounted)
        setState(() {
          notices = List<dynamic>.from(result);
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> read(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    try {
      await api.post(
        '/notifications/${Uri.encodeComponent('${item['id']}')}/read',
        {},
      );
      if (!mounted) return;
      setState(() {
        for (final notice in notices) {
          if (notice['id'] == item['id']) notice['is_read'] = true;
        }
      });
      widget.onRead('${item['id']}');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark notification read: $e')),
        );
    }
  }

  IconData _iconFor(String type) => switch (type) {
    'overdue' => Icons.warning_amber_rounded,
    'returned' => Icons.assignment_return_outlined,
    _ => Icons.inventory_2_outlined,
  };

  Future<void> _openNotice(Map<String, dynamic> item) async {
    await read(item);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppPalette.mist,
                child: Icon(
                  _iconFor('${item['type']}'),
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${item['title'] ?? 'Notification'}',
                style: const TextStyle(
                  color: AppPalette.deep,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${item['message'] ?? ''}',
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${item['created_at'] ?? ''}',
                style: const TextStyle(color: AppPalette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: pageWithHaze(
      RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            if (notices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications yet.'),
              ),
            for (final notice in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppPalette.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    overlayColor: WidgetStatePropertyAll(
                      AppPalette.pearl.withValues(alpha: .48),
                    ),
                    onTap: () => _openNotice(Map<String, dynamic>.from(notice)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        _iconFor('${notice['type']}'),
                        color: AppPalette.primary,
                      ),
                      title: Text(
                        '${notice['title']}',
                        style: TextStyle(
                          fontWeight: notice['is_read'] == true
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${notice['message']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: notice['is_read'] == true
                          ? const Icon(
                              Icons.done,
                              color: AppPalette.muted,
                              size: 20,
                            )
                          : const CircleAvatar(
                              radius: 5,
                              backgroundColor: AppPalette.primary,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

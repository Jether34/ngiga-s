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
              Card(
                color: notice['is_read'] == true
                    ? Colors.white
                    : AppPalette.mist,
                child: ListTile(
                  leading: Icon(
                    notice['type'] == 'overdue'
                        ? Icons.warning_amber_rounded
                        : notice['type'] == 'returned'
                        ? Icons.assignment_return_outlined
                        : Icons.inventory_2_outlined,
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
                    '${notice['message']}\n${notice['created_at']}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
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
                  onTap: () => read(Map<String, dynamic>.from(notice)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

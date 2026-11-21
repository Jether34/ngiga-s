import 'package:flutter/material.dart';

import 'app_palette.dart';

Future<void> showAppNotice(
  BuildContext context,
  String message, {
  bool isError = false,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    icon: Icon(
      isError
          ? Icons.error_outline_rounded
          : Icons.check_circle_outline_rounded,
      color: isError ? const Color(0xffa04435) : AppPalette.primary,
    ),
    title: Text(isError ? 'Something went wrong' : 'Notice'),
    content: Text(message),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('OK'),
      ),
    ],
  ),
);

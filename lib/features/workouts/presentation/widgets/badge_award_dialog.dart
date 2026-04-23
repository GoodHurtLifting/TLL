import 'package:flutter/material.dart';

Future<void> showBadgeAwardDialog({
  required BuildContext context,
  required String title,
  required IconData icon,
  required String message,
  String? detail,
  String buttonLabel = 'Nice',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                icon,
                size: 48,
              ),
            ),
            const SizedBox(height: 12),
            Text(message),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonLabel),
          ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';

Future<void> showBadgeAwardDialog({
  required BuildContext context,
  required String title,
  required IconData icon,
  required String message,
  String? detail,
  String? assetPath,
  String buttonLabel = 'Nice',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final screenWidth = MediaQuery.of(dialogContext).size.width;
      final imageWidth = screenWidth * 0.75;

      return AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath,
                width: imageWidth,
                fit: BoxFit.contain,
              )
            else
              Icon(
                icon,
                size: 64,
                color: Colors.white,
              ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
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
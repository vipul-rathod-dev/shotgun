import 'package:flutter/material.dart';

Future<void> showDeleteConfirmationDialog(
  BuildContext context, {
  required String productName,
  required VoidCallback onConfirm,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Product'),
      content: Text('Are you sure you want to delete "$productName"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    ),
  );
}

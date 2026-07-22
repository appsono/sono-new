import 'package:flutter/material.dart';

extension ToastExtension on BuildContext {
  void toast(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
      ),
    );
  }
}

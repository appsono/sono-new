import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermission();
  runApp(const MaterialApp(home: TestPage()));
}

Future<void> requestPermission() async {
  if (Platform.isAndroid || Platform.isIOS) {
    await Permission.audio.request();
  }
}
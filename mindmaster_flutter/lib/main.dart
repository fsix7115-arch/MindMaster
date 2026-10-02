// MindMaster — app entry point.
import 'package:flutter/material.dart';

import 'theme.dart';
import 'store.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.init();
  runApp(const MindMasterApp());
}

class MindMasterApp extends StatelessWidget {
  const MindMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindMaster',
      debugShowCheckedModeBanner: false,
      theme: MindTheme.theme(),
      home: const HomeScreen(),
    );
  }
}
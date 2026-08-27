import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/screens/home_screen.dart';

class KaibitzerApp extends StatelessWidget {
  const KaibitzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaibitzer',
      debugShowCheckedModeBanner: false,
      theme: buildKaibitzerTheme(),
      home: const HomeScreen(),
    );
  }
}

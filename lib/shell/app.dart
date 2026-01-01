import 'package:flutter/material.dart';

import '../experiences/auth/login_screen.dart';
import '../ui-system/theme.dart';

class PravaApp extends StatelessWidget {
  const PravaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prava',
      debugShowCheckedModeBanner: false,

      // 🌞 Light mode (PRIMARY)
      theme: PravaTheme.light,

      // 🌙 Dark mode (ready)
      darkTheme: PravaTheme.dark,
      themeMode: ThemeMode.system,

      // 🚪 Entry screen
      home: const LoginScreen(),
    );
  }
}

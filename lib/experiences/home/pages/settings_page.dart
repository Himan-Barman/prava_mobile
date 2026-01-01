import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text("Settings"),
      ),
      body: const Center(
        child: Text("Privacy • Security • Account"),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class BroadcastPage extends StatelessWidget {
  const BroadcastPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text("New Broadcast"),
      ),
      body: const Center(
        child: Text("Create broadcast list"),
      ),
    );
  }
}

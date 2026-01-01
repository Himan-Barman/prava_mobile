import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class StarredMessagesPage extends StatelessWidget {
  const StarredMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text("Starred Messages"),
      ),
      body: const Center(
        child: Text("Your starred messages"),
      ),
    );
  }
}

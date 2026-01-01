import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class NewGroupPage extends StatelessWidget {
  const NewGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text("New Group"),
      ),
      body: const Center(
        child: Text("Create a new group"),
      ),
    );
  }
}

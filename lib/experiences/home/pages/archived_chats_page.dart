import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ArchivedChatsPage extends StatelessWidget {
  const ArchivedChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text("Archived Chats"),
      ),
      body: const Center(
        child: Text("Archived conversations"),
      ),
    );
  }
}

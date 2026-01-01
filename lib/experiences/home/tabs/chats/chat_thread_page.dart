import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '/../ui-system/colors.dart';
import '/../ui-system/typography.dart';
import 'chats_page.dart';

class ChatThreadPage extends StatefulWidget {
  final ChatPreview chat;

  const ChatThreadPage({super.key, required this.chat});

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? PravaColors.darkSurface : PravaColors.lightSurface,
      appBar: CupertinoNavigationBar(
        middle: Column(
          children: [
            Text(widget.chat.name,
                style: PravaTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 2),
            Text(
              "End-to-end encrypted",
              style: PravaTypography.caption,
            ),
          ],
        ),
      ),

      /// 🔐 Chat Body
      body: Column(
        children: [
          /// Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: demoMessages.length,
              itemBuilder: (_, index) {
                final msg = demoMessages[index];
                return _Bubble(
                  text: msg.text,
                  isMe: msg.isMe,
                );
              },
            ),
          ),

          /// Input Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Message",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: PravaColors.accentPrimary,
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// CHAT BUBBLE — WhatsApp geometry
////////////////////////////////////////////////////////////

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _Bubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe
              ? PravaColors.accentPrimary
              : Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: PravaTypography.body.copyWith(
            color: isMe ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// MESSAGE MODEL (E2EE-READY)
////////////////////////////////////////////////////////////

class Message {
  final String id;
  final String text; // decrypted in memory only
  final bool isMe;

  const Message({
    required this.id,
    required this.text,
    required this.isMe,
  });
}

/// Demo messages (replace with encrypted stream)
const demoMessages = [
  Message(id: "1", text: "Hey 👋", isMe: false),
  Message(id: "2", text: "Hi!", isMe: true),
  Message(id: "3", text: "How are you?", isMe: false),
  Message(id: "4", text: "All good 😊", isMe: true),
];

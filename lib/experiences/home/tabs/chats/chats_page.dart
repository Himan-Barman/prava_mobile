import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '/../ui-system/colors.dart';
import '/../ui-system/typography.dart';
import 'chat_thread_page.dart';
import '/../ui-system/skeleton/chat_list_skeleton.dart'; 

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true; // 🔥 skeleton trigger

  @override
  void initState() {
    super.initState();

    // ⏳ Simulate backend fetch (replace with real stream / API)
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 🔍 Premium Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: "Search chats",
            backgroundColor:
                isDark ? Colors.white10 : Colors.black12,
          ),
        ),

        // 💬 Chats List OR Skeleton
        Expanded(
          child: _loading
              ? const ChatListSkeleton()
              : ListView.separated(
                  itemCount: demoChats.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final chat = demoChats[index];
                    return _ChatTile(chat: chat);
                  },
                ),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// CHAT TILE (WhatsApp-grade)
////////////////////////////////////////////////////////////

class _ChatTile extends StatelessWidget {
  final ChatPreview chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ChatThreadPage(chat: chat),
          ),
        );
      },

      leading: CircleAvatar(
        radius: 26,
        backgroundColor:
            PravaColors.accentPrimary.withOpacity(0.15),
        child: Text(
          chat.name[0],
          style: PravaTypography.h2.copyWith(
            color: PravaColors.accentPrimary,
          ),
        ),
      ),

      title: Text(
        chat.name,
        style: PravaTypography.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PravaTypography.caption,
      ),

      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            chat.time,
            style: PravaTypography.caption,
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor:
                  PravaColors.accentPrimary,
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// DATA MODEL (Backend-ready)
////////////////////////////////////////////////////////////

class ChatPreview {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;

  const ChatPreview({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
  });
}

/// TEMP demo data (replace with backend stream)
const demoChats = [
  ChatPreview(
    id: "1",
    name: "Ushri",
    lastMessage: "See you tomorrow 🌙",
    time: "10:12 PM",
    unreadCount: 2,
    isGroup: false,
  ),
  ChatPreview(
    id: "2",
    name: "Prava Team",
    lastMessage: "Deployment completed successfully",
    time: "9:45 PM",
    unreadCount: 0,
    isGroup: true,
  ),
  ChatPreview(
    id: "3",
    name: "Friends",
    lastMessage: "Movie plan confirmed 🎬",
    time: "Yesterday",
    unreadCount: 5,
    isGroup: true,
  ),
];

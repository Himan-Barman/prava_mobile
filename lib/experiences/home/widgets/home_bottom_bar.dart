import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/../ui-system/colors.dart';

class HomeBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const HomeBottomBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background =
        isDark ? const Color(0xFF0E0E10) : Colors.white;

    final inactiveColor =
        isDark ? Colors.white54 : Colors.black54;

    return CupertinoTabBar(
      currentIndex: index,
      onTap: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      backgroundColor: background,
      activeColor: PravaColors.accentPrimary,
      inactiveColor: inactiveColor,
      iconSize: 24,
      items: const [
        /// 📰 FEED
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.news),
          activeIcon: Icon(CupertinoIcons.news_solid),
          label: "Feed",
        ),

        /// 💬 CHATS
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chat_bubble_2),
          activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
          label: "Chats",
        ),

        /// 👥 FRIENDS
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person_2),
          activeIcon: Icon(CupertinoIcons.person_2_fill),
          label: "Friends",
        ),

        /// 👤 PROFILE
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person),
          activeIcon: Icon(CupertinoIcons.person_fill),
          label: "Profile",
        ),
      ],
    );
  }
}

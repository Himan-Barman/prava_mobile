import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '/../ui-system/colors.dart';
import '/../ui-system/typography.dart';

import '../pages/new_group_page.dart';
import '../pages/broadcast_page.dart';
import '../pages/starred_messages_page.dart';
import '../pages/archived_chats_page.dart';
import '../pages/settings_page.dart';

class HomeOverflowMenu {
  static void show(BuildContext context) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width - 220,
        kToolbarHeight + 12,
        16,
        0,
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? PravaColors.darkSurface
          : PravaColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      items: <PopupMenuEntry<void>>[
        _menuItem(
          context,
          icon: CupertinoIcons.group,
          label: "New group",
          page: const NewGroupPage(),
        ),
        _menuItem(
          context,
          icon: CupertinoIcons.speaker_2,
          label: "New broadcast",
          page: const BroadcastPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.star,
          label: "Starred messages",
          page: const StarredMessagesPage(),
        ),
        _menuItem(
          context,
          icon: CupertinoIcons.archivebox,
          label: "Archived chats",
          page: const ArchivedChatsPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.settings,
          label: "Settings",
          page: const SettingsPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.square_arrow_right,
          label: "Log out",
          destructive: true,
          onTap: () {
            Navigator.of(context)
                .pushNamedAndRemoveUntil("/login", (_) => false);
          },
        ),
      ],
    );
  }

  static PopupMenuItem<void> _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? page,
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    return PopupMenuItem<void>(
      height: 46,
      onTap: () {
        HapticFeedback.selectionClick();
        Future.microtask(() {
          if (onTap != null) {
            onTap();
          } else if (page != null) {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => page),
            );
          }
        });
      },
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                destructive ? PravaColors.error : PravaColors.accentPrimary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: PravaTypography.body.copyWith(
              color: destructive ? PravaColors.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

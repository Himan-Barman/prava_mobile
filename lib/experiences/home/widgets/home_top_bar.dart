import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '/../ui-system/typography.dart';
import '/../ui-system/colors.dart';
import '../pages/search_page.dart';
import 'home_overflow_menu.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryText = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          /// 🏷 Brand
          Text(
            "Prava",
            style: PravaTypography.h2.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: primaryText,
            ),
          ),

          const Spacer(),

          /// 🔍 Search
          IconButton(
            icon: const Icon(CupertinoIcons.search),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const SearchPage(),
                ),
              );
            },
          ),

          /// ⋯ Overflow Menu
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_vertical),
            onPressed: () {
              HomeOverflowMenu.show(context);
            },
          ),
        ],
      ),
    );
  }
}

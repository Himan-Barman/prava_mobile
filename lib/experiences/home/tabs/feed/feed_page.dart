import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '/../ui-system/colors.dart';
import '/../ui-system/typography.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: demoFeed.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final post = demoFeed[index];
        return _FeedPostTile(post: post);
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// FEED POST TILE (Twitter-like)
////////////////////////////////////////////////////////////

class _FeedPostTile extends StatelessWidget {
  final FeedPost post;

  const _FeedPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: PravaColors.accentPrimary.withOpacity(0.15),
            child: Text(
              post.authorName[0],
              style: PravaTypography.h2.copyWith(
                color: PravaColors.accentPrimary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header
                Row(
                  children: [
                    Text(
                      post.authorName,
                      style: PravaTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "@${post.authorHandle}",
                      style: PravaTypography.caption,
                    ),
                    const SizedBox(width: 6),
                    const Text("·"),
                    const SizedBox(width: 6),
                    Text(
                      post.time,
                      style: PravaTypography.caption,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                /// Post text
                Text(
                  post.content,
                  style: PravaTypography.body.copyWith(
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 10),

                /// Actions
                _FeedActions(post: post),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ACTION BAR
////////////////////////////////////////////////////////////

class _FeedActions extends StatelessWidget {
  final FeedPost post;

  const _FeedActions({required this.post});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _action(
          icon: CupertinoIcons.chat_bubble,
          label: post.comments.toString(),
          color: iconColor,
        ),
        _action(
          icon: CupertinoIcons.arrow_2_squarepath,
          label: post.reposts.toString(),
          color: iconColor,
        ),
        _action(
          icon: CupertinoIcons.heart,
          label: post.likes.toString(),
          color: iconColor,
        ),
        Icon(
          CupertinoIcons.share,
          size: 18,
          color: iconColor,
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: PravaTypography.caption,
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// DATA MODEL (BACKEND-READY)
////////////////////////////////////////////////////////////

class FeedPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final String content;
  final String time;
  final int likes;
  final int comments;
  final int reposts;

  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.time,
    required this.likes,
    required this.comments,
    required this.reposts,
  });
}

////////////////////////////////////////////////////////////
/// TEMP DEMO DATA
////////////////////////////////////////////////////////////

const demoFeed = [
  FeedPost(
    id: "p1",
    authorId: "u1",
    authorName: "Ushri",
    authorHandle: "ushri",
    content:
        "Some conversations don’t need noise. They just need honesty.",
    time: "2h",
    likes: 124,
    comments: 18,
    reposts: 9,
  ),
  FeedPost(
    id: "p2",
    authorId: "u2",
    authorName: "Prava",
    authorHandle: "prava_app",
    content:
        "Privacy is not a feature. It’s a foundation. 🔐",
    time: "5h",
    likes: 982,
    comments: 76,
    reposts: 201,
  ),
  FeedPost(
    id: "p3",
    authorId: "u3",
    authorName: "Animesh",
    authorHandle: "animesh",
    content:
        "Building something meaningful takes time. Silence helps.",
    time: "1d",
    likes: 342,
    comments: 41,
    reposts: 22,
  ),
];

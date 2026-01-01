import 'package:flutter/material.dart';
import '/../ui-system/typography.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Friends',
        style: PravaTypography.h2,
      ),
    );
  }
}

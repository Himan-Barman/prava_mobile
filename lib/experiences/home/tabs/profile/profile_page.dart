import 'package:flutter/material.dart';
import '/../ui-system/typography.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Profile',
        style: PravaTypography.h2,
      ),
    );
  }
}

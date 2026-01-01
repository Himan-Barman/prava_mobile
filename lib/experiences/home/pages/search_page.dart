// lib/experiences/home/pages/search_page.dart

import 'package:flutter/material.dart';
import '../../../ui-system/typography.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Center(
        child: Text(
          "Search coming soon",
          style: PravaTypography.body,
        ),
      ),
    );
  }
}

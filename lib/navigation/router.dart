import 'package:flutter/material.dart';
import '../experiences/feed/feed_screen.dart';

class PravaRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const FeedScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404')),
          ),
        );
    }
  }
}

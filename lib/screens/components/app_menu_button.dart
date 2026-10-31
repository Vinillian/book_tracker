import 'package:flutter/material.dart';

/// The menu button of an AppBar: opens the end drawer of the nearest Scaffold
/// (put an `AppDrawerMenu` there as `endDrawer`). An AppBar that has its own
/// `actions` does not get Flutter's default button, so it adds this one (#166).
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Меню',
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}

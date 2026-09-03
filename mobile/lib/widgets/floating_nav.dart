import 'package:flutter/material.dart';
import 'bottom_nav.dart';

// Alias widget for backward compatibility
class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNav(currentIndex: currentIndex, onTap: onTap);
  }
}

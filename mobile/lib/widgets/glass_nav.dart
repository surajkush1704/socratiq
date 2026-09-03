import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class GlassNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool visible;

  const GlassNav({
    required this.currentIndex,
    required this.onTap,
    this.visible = true,
    super.key,
  });

  static const _items = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.menu_book_rounded, 'label': 'Library'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Progress'},
    {'icon': Icons.person_rounded, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: AppTheme.cyanAccent.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final isActive = index == currentIndex;
              return GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    color: isActive ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: isActive ? AppTheme.buttonShadow : null,
                  ),
                  child: Icon(
                    _items[index]['icon'] as IconData,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                    size: 22,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

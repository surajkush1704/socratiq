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
    {'icon': Icons.auto_awesome_rounded, 'label': 'Ask AI'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Progress'},
    {'icon': Icons.person_rounded, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F19).withOpacity(0.96),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: const Color(0xFF2355F5).withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.20),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final isActive = index == currentIndex;
              final isAskAi = index == 2;
              return GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isAskAi ? 14 : 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? (isAskAi ? AppTheme.cyanGradient : AppTheme.primaryGradient)
                        : null,
                    color: isActive
                        ? null
                        : (isAskAi ? AppTheme.cyanAccent.withOpacity(0.12) : Colors.transparent),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: isActive ? AppTheme.buttonShadow : null,
                  ),
                  child: Icon(
                    _items[index]['icon'] as IconData,
                    color: isActive
                        ? Colors.white
                        : (isAskAi
                            ? AppTheme.cyanAccent
                            : Colors.white.withOpacity(0.45)),
                    size: isAskAi ? 24 : 22,
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

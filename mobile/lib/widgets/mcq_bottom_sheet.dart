import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/mcq_model.dart';

class MCQBottomSheet extends StatefulWidget {
  final MCQModel mcq;
  final VoidCallback onContinue;

  const MCQBottomSheet({
    required this.mcq,
    required this.onContinue,
    super.key,
  });

  @override
  State<MCQBottomSheet> createState() => _MCQBottomSheetState();
}

class _MCQBottomSheetState extends State<MCQBottomSheet> {
  int? _selected;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Question
              Text(
                widget.mcq.question,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.navyText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Options
              ...List.generate(widget.mcq.options.length, (i) {
                final isSelected = _selected == i;
                final isCorrect = _submitted && i == widget.mcq.correctIndex;
                final isWrong = _submitted && isSelected && i != widget.mcq.correctIndex;
                Color borderColor = AppTheme.divider;
                Color bgColor = Colors.white;
                if (isSelected && !_submitted) borderColor = AppTheme.primaryBlue;
                if (isSelected && !_submitted) bgColor = const Color(0xFFEEF2FF);
                if (isCorrect) { borderColor = AppTheme.success; bgColor = const Color(0xFFECFDF5); }
                if (isWrong) { borderColor = AppTheme.error; bgColor = const Color(0xFFFEF2F2); }

                return GestureDetector(
                  onTap: _submitted ? null : () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.backgroundAlt,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppTheme.secondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.mcq.options[i],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.navyText,
                            ),
                          ),
                        ),
                        if (isCorrect) const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                        if (isWrong) const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              // Explanation after submit
              if (_submitted && widget.mcq.explanation.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    widget.mcq.explanation,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                      height: 1.5,
                    ),
                  ),
                ),
              // Submit or Continue
              const SizedBox(height: 8),
              if (!_submitted)
                AppTheme.gradientButton(
                  label: 'Submit Answer',
                  width: double.infinity,
                  onTap: _selected == null ? () {} : () => setState(() => _submitted = true),
                )
              else
                AppTheme.gradientButton(
                  label: 'Continue Learning',
                  width: double.infinity,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onContinue();
                  },
                ),
            ],
          ),
        );
  }
}

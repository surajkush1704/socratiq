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
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColorDef = AppTheme.dynamicDivider(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(
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
                    color: borderColorDef,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Question
              Text(
                widget.mcq.question,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textCol,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Options
              ...List.generate(widget.mcq.options.length, (i) {
                final isSelected = _selected == i;
                final isCorrect = _submitted && i == widget.mcq.correctIndex;
                final isWrong = _submitted && isSelected && i != widget.mcq.correctIndex;
                Color borderColor = borderColorDef;
                Color bgColor = cardBg;
                if (isSelected && !_submitted) {
                  borderColor = AppTheme.primaryBlue;
                  bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
                }
                if (isCorrect) {
                  borderColor = AppTheme.success;
                  bgColor = isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5);
                }
                if (isWrong) {
                  borderColor = AppTheme.error;
                  bgColor = isDark ? const Color(0xFF7F1D1D).withOpacity(0.4) : const Color(0xFFFEF2F2);
                }

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
                      boxShadow: isDark ? [] : AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : (isDark ? AppTheme.darkBackgroundAlt : AppTheme.backgroundAlt),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isSelected ? Colors.white : secCol,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.mcq.options[i],
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: textCol,
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
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: borderColorDef),
                  ),
                  child: Text(
                    widget.mcq.explanation,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: secCol,
                      height: 1.6,
                    ),
                  ),
                ),
              // Submit or Continue
              const SizedBox(height: 8),
              if (!_submitted)
                AppTheme.gradientButton(
                  label: 'Submit answer',
                  width: double.infinity,
                  onTap: _selected == null ? () {} : () => setState(() => _submitted = true),
                )
              else
                AppTheme.gradientButton(
                  label: 'Continue learning',
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

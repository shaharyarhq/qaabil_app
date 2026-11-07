import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// Real attachments at a course, section or chapter, opened with member auth.
class CurriculumNotes extends StatefulWidget {
  const CurriculumNotes({
    super.key,
    required this.kind,
    required this.resourceId,
    required this.notes,
    required this.accent,
    required this.tint,
  });
  final String kind;
  final int resourceId;
  final List<LessonNote> notes;
  final Color accent, tint;

  @override
  State<CurriculumNotes> createState() => _CurriculumNotesState();
}

class _CurriculumNotesState extends State<CurriculumNotes> {
  int? _opening;

  Future<void> _open(LessonNote note) async {
    setState(() => _opening = note.id);
    try {
      await SessionScope.of(context)
          .openCurriculumNote(widget.kind, widget.resourceId, note);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Could not open these notes. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty || SessionScope.of(context).member == null) {
      return const SizedBox.shrink();
    }
    final title = switch (widget.kind) {
      'course' => 'Course notes',
      'section' => 'Section notes',
      _ => 'Chapter notes',
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          for (final note in widget.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: widget.tint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: widget.accent.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  leading: Icon(
                    note.mime == 'application/pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.description_rounded,
                    color: widget.accent,
                    size: 28,
                  ),
                  title: Text(note.name, style: AppTextStyles.label),
                  subtitle: Text(
                    _opening == note.id
                        ? 'Opening…'
                        : '${note.name.split('.').last.toUpperCase()} · ${(note.size / 1024).ceil()} KB · Tap to open',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: _opening == note.id
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.accent,
                          ),
                        )
                      : Icon(
                          Icons.open_in_new_rounded,
                          color: widget.accent,
                          size: 22,
                        ),
                  onTap: _opening != null ? null : () => _open(note),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

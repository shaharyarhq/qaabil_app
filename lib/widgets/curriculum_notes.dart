import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Real attachments at a course, section, chapter or objective, opened with member auth.
class CurriculumNotes extends StatefulWidget {
  const CurriculumNotes({
    super.key,
    required this.kind,
    required this.resourceId,
    required this.notes,
    required this.accent,
    required this.tint,
    this.stacked = false,
  });
  final String kind;
  final int resourceId;
  final List<LessonNote> notes;
  final Color accent, tint;
  final bool stacked;

  @override
  State<CurriculumNotes> createState() => _CurriculumNotesState();
}

class _CurriculumNotesState extends State<CurriculumNotes> {
  int? _opening;

  Future<void> _open(LessonNote note) async {
    setState(() => _opening = note.id);
    try {
      final session = SessionScope.of(context);
      if (widget.kind == 'objective') {
        await session.openNote(widget.resourceId, note);
      } else {
        await session.openCurriculumNote(widget.kind, widget.resourceId, note);
      }
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
    final inHero = widget.kind == 'course';
    final title = inHero ? 'Course notes' : 'Download ${widget.kind} notes';
    final buttons = [
      for (final note in widget.notes)
        Tooltip(
          message: note.name,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: inHero
                  ? Colors.white
                  : AppPalette.of(context).accent,
              backgroundColor: widget.tint,
              side: BorderSide(
                color: inHero
                    ? const Color(0x20FFFFFF)
                    : const Color(0x241B3A6B),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 38),
              tapTargetSize: inHero ? MaterialTapTargetSize.shrinkWrap : null,
              textStyle: AppTextStyles.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: _opening == null ? () => _open(note) : null,
            icon: Icon(Icons.download_rounded, size: 14, color: widget.accent),
            label: Text(_opening == note.id ? 'Opening…' : title),
          ),
        ),
    ];
    if (inHero || widget.stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: buttons,
      );
    }
    if (buttons.length == 1) return buttons.single;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: buttons,
    );
  }
}

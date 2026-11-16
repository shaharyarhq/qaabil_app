import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/video_submission.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/qaabil_app_bar.dart';

import 'submit_video_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  final _items = <VideoSubmission>[];
  MemberSession? _session;
  int? _memberId;
  int _request = 0, _page = 0, _lastPage = 1;
  bool _loading = false, _retryRefresh = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final id = session.member?.id;
    if (_session == session && _memberId == id) return;
    _session = session;
    _memberId = id;
    _request++;
    _items.clear();
    _page = 0;
    _lastPage = 1;
    _error = null;
    _loading = false;
    if (id != null) _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_memberId == null || (_loading && !refresh)) return;
    final session = _session!;
    final id = _memberId;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await session.submissions(page: refresh ? 1 : _page + 1);
      if (!mounted || request != _request || session.member?.id != id) return;
      setState(() {
        if (refresh) _items.clear();
        final loadedIds = _items.map((item) => item.id).toSet();
        _items.addAll(result.items.where((item) => loadedIds.add(item.id)));
        _page = result.page;
        _lastPage = result.lastPage;
      });
    } on ApiException catch (error) {
      if (mounted && request == _request && session.member?.id == id) {
        setState(() {
          _error = error.message;
          _retryRefresh = refresh;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _openSubmissionForm([int? submissionId]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubmitVideoScreen(submissionId: submissionId),
      ),
    );
    if (!mounted || result == null || _memberId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submissionId != null
              ? 'Changes saved.'
              : result
              ? 'Video submitted for review.'
              : 'You already submitted this video for this objective.',
        ),
      ),
    );
    await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = SessionScope.of(context).member != null;
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: const QaabilAppBar(showAppearance: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 960 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          return RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'My Video Submissions',
                    style: AppTextStyles.heading.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (signedIn) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _openSubmissionForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Submit video'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Material(
                  color: palette.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!signedIn)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Log in to see your submissions.'),
                        )
                      else ...[
                        if (wide && _items.isNotEmpty) const _TableHeader(),
                        for (final (index, item) in _items.indexed) ...[
                          if (wide || index > 0)
                            Divider(height: 1, color: palette.border),
                          _SubmissionRow(
                            item: item,
                            wide: wide,
                            onEdit: () => _openSubmissionForm(item.id),
                          ),
                        ],
                        if (_error case final error?)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(error),
                                TextButton(
                                  onPressed: () =>
                                      _load(refresh: _retryRefresh),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        if (!_loading && _items.isEmpty && _error == null)
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              spacing: 12,
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  color: palette.textSecondary,
                                  size: 32,
                                ),
                                const Text(
                                  'No videos',
                                  style: AppTextStyles.title,
                                ),
                              ],
                            ),
                          ),
                        if (_loading)
                          const LinearProgressIndicator()
                        else if (_error == null && _page < _lastPage) ...[
                          Divider(height: 1, color: palette.border),
                          Center(
                            child: TextButton(
                              onPressed: _load,
                              child: const Text('Load more submissions'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _columns = [
  (label: 'Video Thumbnail', flex: 1),
  (label: 'Title', flex: 2),
  (label: 'Course', flex: 2),
  (label: 'Section', flex: 2),
  (label: 'Chapter', flex: 2),
  (label: 'Objective', flex: 2),
  (label: 'Status', flex: 2),
  (label: 'Approved By', flex: 1),
  (label: 'Actions', flex: 1),
];

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: palette.elevated,
      child: _TableRow(
        cells: [
          for (final column in _columns)
            Semantics(
              header: true,
              child: Text(
                column.label,
                style: AppTextStyles.label.copyWith(color: palette.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      spacing: 12,
      children: [
        for (final (index, cell) in cells.indexed)
          Expanded(flex: _columns[index].flex, child: cell),
      ],
    ),
  );
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({
    required this.item,
    required this.wide,
    required this.onEdit,
  });

  final VideoSubmission item;
  final bool wide;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final date = item.submittedAt?.toLocal();
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          item.title,
          style: AppTextStyles.title.copyWith(color: palette.textPrimary),
        ),
        if (date != null)
          Text(
            'Submitted ${MaterialLocalizations.of(context).formatMediumDate(date)}',
            style: AppTextStyles.caption.copyWith(color: palette.textSecondary),
          ),
      ],
    );
    final status = _StatusBadge(status: item.status);
    final thumbnail = _Thumbnail(url: item.thumbnail);
    final details = [
      (label: 'Course', value: item.course),
      (label: 'Section', value: item.section),
      (label: 'Chapter', value: item.chapter),
      (label: 'Objective', value: item.objective),
    ];
    final body = AppTextStyles.body.copyWith(color: palette.textPrimary);
    final edit = TextButton(onPressed: onEdit, child: const Text('Edit'));
    if (wide) {
      return _TableRow(
        cells: [
          Align(alignment: Alignment.centerLeft, child: thumbnail),
          title,
          for (final detail in details) Text(detail.value ?? '—', style: body),
          Align(alignment: Alignment.centerLeft, child: status),
          Text(item.approvedBy ?? '—', style: body),
          edit,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              thumbnail,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [title, status],
                ),
              ),
            ],
          ),
          for (final detail in [
            ...details,
            (label: 'Approved By', value: item.approvedBy),
          ])
            if (detail.value case final value? when value.trim().isNotEmpty)
              Text.rich(
                TextSpan(
                  text: '${detail.label}  ',
                  style: body.copyWith(color: palette.textSecondary),
                  children: [TextSpan(text: value, style: body)],
                ),
              ),
          Align(alignment: Alignment.centerRight, child: edit),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final placeholder = ColoredBox(
      color: palette.elevated,
      child: Icon(Icons.videocam_outlined, color: palette.textSecondary),
    );
    return SizedBox.square(
      dimension: 52,
      child: ClipOval(
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (label, color, tint) = switch (status) {
      'approved' => ('Approved', palette.teal, palette.tealTint),
      'pending' => ('Pending', palette.amberText, palette.amberTint),
      'rejected' => ('Rejected', palette.error, palette.coralTint),
      _ => ('Status unavailable', palette.textSecondary, palette.elevated),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: AppTextStyles.label.copyWith(color: color)),
      ),
    );
  }
}

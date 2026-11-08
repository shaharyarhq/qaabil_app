import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/video_submission.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/section_header.dart';

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

  @override
  Widget build(BuildContext context) {
    final signedIn = SessionScope.of(context).member != null;
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const SectionHeader(
                  eyebrow: 'YOUR CONTRIBUTIONS',
                  title: 'My Video Submissions',
                  accent: '',
                  subtitle:
                      'See what you’ve shared and follow its review status.',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!signedIn)
                  const AppCard(child: Text('Log in to see your submissions.'))
                else ...[
                  if (_error != null)
                    AppCard(
                      child: Column(
                        children: [
                          Text(_error!, style: AppTextStyles.body),
                          TextButton(
                            onPressed: () => _load(refresh: _retryRefresh),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (_items.isEmpty && !_loading && _error == null)
                    const AppCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            color: AppColors.violet,
                            size: 46,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'No video submissions yet',
                            style: AppTextStyles.title,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Videos you submit to Qaabil will appear here.',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _SubmissionCard(item: item),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error == null && _page < _lastPage)
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Load more submissions'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.item});
  final VideoSubmission item;

  @override
  Widget build(BuildContext context) {
    final (label, color, tint, icon) = switch (item.status) {
      'approved' => (
        'Approved',
        AppColors.teal,
        AppColors.tealTint,
        Icons.check_circle_outline,
      ),
      'pending' => (
        'Pending review',
        AppColors.amberText,
        AppColors.amberTint,
        Icons.schedule_rounded,
      ),
      'rejected' => (
        'Rejected',
        AppColors.coral,
        AppColors.coralTint,
        Icons.cancel_outlined,
      ),
      _ => (
        'Status unavailable',
        AppColors.navy,
        AppColors.navyTint,
        Icons.info_outline,
      ),
    };
    final date = item.submittedAt?.toLocal();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            backgroundColor: tint,
            avatar: Icon(icon, color: color, size: 18),
            label: Text(
              label,
              style: AppTextStyles.label.copyWith(color: color),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: AppTextStyles.cardTitle),
          if (item.contextLabels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(item.contextLabels.join(' › '), style: AppTextStyles.body),
          ],
          if (date != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Submitted ${MaterialLocalizations.of(context).formatMediumDate(date)}',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

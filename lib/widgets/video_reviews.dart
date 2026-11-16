import 'package:flutter/material.dart';

import 'content_report_button.dart';
import 'content_rules.dart';

import 'package:qaabil_mobile/widgets/primary_button.dart';

import '../auth/member_session.dart';
import '../models/video_details.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_text_styles.dart';
import 'video_information.dart';

/// Reviews use the website's records and the signed-in member's ownership.
class VideoReviews extends StatefulWidget {
  const VideoReviews({super.key, required this.videoId});
  final int videoId;
  @override
  State<VideoReviews> createState() => _VideoReviewsState();
}

class _VideoReviewsState extends State<VideoReviews> {
  final _text = TextEditingController();
  final List<VideoReview> _reviews = [];
  VideoReviewPage? _summary;
  int? _memberId;
  int? _visibilityVersion;
  int _version = 0, _rating = 0;
  bool _loading = false, _saving = false;
  String? _error, _actionError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final id = session.member?.id;
    if (_memberId != id ||
        _visibilityVersion != session.contentVisibilityVersion) {
      _memberId = id;
      _visibilityVersion = session.contentVisibilityVersion;
      _version++;
      _reviews.clear();
      _summary = null;
      _text.clear();
      _rating = 0;
      if (id != null) _load(reset: true);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final session = SessionScope.of(context);
    if (session.member == null || (_loading && !reset)) return;
    final page = reset ? 1 : (_summary?.page ?? 0) + 1;
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _reviews.clear();
        _summary = null;
      }
    });
    try {
      final result = await session.videoReviews(widget.videoId, page: page);
      if (!mounted || version != _version) return;
      setState(() {
        final ids = _reviews.map((r) => r.id).toSet();
        _reviews.addAll(result.reviews.where((r) => ids.add(r.id)));
        _summary = result;
      });
    } catch (e) {
      if (mounted && version == _version) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not load reviews.',
        );
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving || _rating < 1) return;
    final session = SessionScope.of(context);
    if (!await confirmContentRules(context) ||
        !mounted ||
        session.member == null) {
      return;
    }
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      await session.submitVideoReview(widget.videoId, _rating, _text.text);
      if (!mounted) return;
      _text.clear();
      _rating = 0;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review submitted.')));
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _actionError = e is ApiException
              ? e.message
              : 'Could not submit your review.',
        );
        if (e is ApiException && e.status == 422) await _load(reset: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(VideoReview review) async {
    if (_saving) return;
    final session = SessionScope.of(context);
    final owner = session.member?.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text(
          'This removes your rating and comment from this video.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete review'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || owner != session.member?.id) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      await session.deleteVideoReview(widget.videoId, review.id);
      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _actionError = e is ApiException
              ? e.message
              : 'Could not delete your review.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card(VideoReview review) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: VideoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${review.author}${review.isMine ? ' · You' : ''}',
            style: AppTextStyles.label,
          ),
          _reviewStars(context, review.rating),
          if (review.createdAt != null)
            Text(
              review.createdAt!.toLocal().toIso8601String().split('T').first,
              style: AppTextStyles.caption,
            ),
          if (review.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(review.text),
            ),
          if (review.isMine)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _saving ? null : () => _delete(review),
                child: const Text('Delete my review'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: ContentReportButton(
                videoId: widget.videoId,
                reviewId: review.id,
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 16, height: 3, color: AppColors.amberDark),
            const SizedBox(width: 8),
            const Text('Reviews', style: AppTextStyles.title),
            if (summary != null && summary.total > 0)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${summary.total} ${summary.total == 1 ? 'review' : 'reviews'}',
                    style: AppTextStyles.caption,
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh reviews',
              onPressed: _loading || _saving ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _loading ? null : () => _load(reset: _summary == null),
            child: const Text('Retry reviews'),
          ),
        ],
        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              _actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (summary != null) ...[
          if (summary.total > 0) _RatingSummary(summary: summary),
          const SizedBox(height: AppSpacing.md),
          if (summary.ownReview == null)
            VideoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'LEAVE A REVIEW',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: AppPalette.of(context).textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        IconButton(
                          tooltip: n == 1 ? '1 star' : '$n stars',
                          isSelected: _rating == n,
                          onPressed: _saving
                              ? null
                              : () => setState(() => _rating = n),
                          icon: Icon(
                            n <= _rating ? Icons.star : Icons.star_border,
                          ),
                          color: AppPalette.of(context).amberText,
                        ),
                    ],
                  ),
                  TextField(
                    controller: _text,
                    enabled: !_saving,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your review (optional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    onPressed: _saving || _rating == 0 ? null : _submit,
                    child: Text(_saving ? 'Saving…' : 'Submit review'),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'You have already reviewed this video.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            _card(summary.ownReview!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (summary.total == 0 && summary.ownReview == null)
            const Text('No reviews yet. Be the first to share your thoughts.'),
          for (final review in _reviews.where((r) => !r.isMine)) _card(review),
          if (summary.page < summary.lastPage)
            TextButton(
              onPressed: _loading || _saving ? null : () => _load(),
              child: const Text('Load more reviews'),
            ),
        ],
      ],
    );
  }
}

Widget _reviewStars(BuildContext context, int rating) => Semantics(
  label: '$rating out of 5 stars',
  child: Wrap(
    spacing: 2,
    children: [
      for (var star = 1; star <= 5; star++)
        Icon(
          Icons.star_rounded,
          size: 15,
          color: star <= rating
              ? AppColors.amberDark
              : AppPalette.of(context).border,
        ),
    ],
  ),
);

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.summary});

  final VideoReviewPage summary;

  @override
  Widget build(BuildContext context) => VideoPanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final average = Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              summary.average.toStringAsFixed(1),
              style: const TextStyle(
                fontFamily: AppTextStyles.serif,
                fontSize: 52,
                height: 1,
              ),
            ),
            _reviewStars(context, summary.average.round()),
            const Text('out of 5', style: AppTextStyles.caption),
          ],
        );
        final bars = Column(
          spacing: 6,
          children: [
            for (var star = 5; star >= 1; star--)
              Row(
                spacing: 8,
                children: [
                  Text('$star', style: AppTextStyles.caption),
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.amberDark,
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: summary.counts[star - 1] / summary.total,
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.amberDark,
                      backgroundColor: AppPalette.of(context).navyTint,
                    ),
                  ),
                  Text(
                    '${summary.counts[star - 1]}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
          ],
        );
        return constraints.maxWidth < 460
            ? Column(spacing: 16, children: [average, bars])
            : Row(
                spacing: 24,
                children: [
                  average,
                  Expanded(child: bars),
                ],
              );
      },
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:qaabil_mobile/widgets/primary_button.dart';

import '../auth/member_session.dart';
import '../models/video_details.dart';
import '../services/member_api.dart';
import '../theme/app_tokens.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

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
  int _version = 0, _rating = 0;
  bool _loading = false, _saving = false;
  String? _error, _actionError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = SessionScope.of(context).member?.id;
    if (_memberId != id) {
      _memberId = id;
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
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${review.author}${review.isMine ? ' · You' : ''}',
            style: AppTextStyles.label,
          ),
          Text('${review.rating}/5 stars', style: AppTextStyles.body),
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
            const Expanded(child: Text('Reviews', style: AppTextStyles.title)),
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
          if (summary.total > 0)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${summary.average.toStringAsFixed(1)} / 5 · ${summary.total} reviews',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 35, child: Text('$star ★')),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: summary.counts[star - 1] / summary.total,
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${summary.counts[star - 1]}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (summary.ownReview == null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Leave a review', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Choose a rating from 1 to 5 stars.'),
                  Wrap(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        IconButton(
                          tooltip: '$n stars',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _rating = n),
                          icon: Icon(
                            n <= _rating ? Icons.star : Icons.star_border,
                          ),
                          color: Theme.of(context).colorScheme.primary,
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

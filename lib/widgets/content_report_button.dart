import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../services/member_api.dart';

class ContentReportButton extends StatelessWidget {
  const ContentReportButton({super.key, required this.videoId, this.reviewId});

  final int videoId;
  final int? reviewId;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.flag_outlined),
    label: Text(reviewId == null ? 'Report video' : 'Report review'),
    onPressed: () async {
      final session = SessionScope.of(context);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final route = ModalRoute.of(context);
      final result = await showDialog<String>(
        context: context,
        builder: (_) => _ReportDialog(
          session: session,
          videoId: videoId,
          reviewId: reviewId,
        ),
      );
      if (result == null) return;
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result == 'blocked'
                  ? 'Author blocked.'
                  : 'Report sent to Qaabil.',
            ),
          ),
        );
      }
      if (result == 'blocked' &&
          reviewId == null &&
          navigator.mounted &&
          route?.isCurrent == true) {
        navigator.maybePop();
      }
    },
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.session,
    required this.videoId,
    required this.reviewId,
  });

  final MemberSession session;
  final int videoId;
  final int? reviewId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _sending = false, _reportAuthor = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.reportVideoContent(
        widget.videoId,
        reviewId: widget.reviewId,
        reportAuthor: _reportAuthor,
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.of(context).pop('reported');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this author?'),
        content: const Text(
          'Their videos and reviews will be hidden from you in the app. You can unblock them in Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block author'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.blockVideoAuthor(
        widget.videoId,
        reviewId: widget.reviewId,
      );
      if (mounted) Navigator.of(context).pop('blocked');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.reviewId == null ? 'Report video' : 'Report review'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _reason,
            enabled: !_sending,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason for reporting',
            ),
            validator: (value) => (value ?? '').trim().runes.length < 4
                ? 'Describe what you’re reporting.'
                : null,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Also report the author'),
            value: _reportAuthor,
            onChanged: _sending
                ? null
                : (value) => setState(() => _reportAuthor = value ?? false),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _sending ? null : _block,
              child: const Text('Block author'),
            ),
          ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _sending ? null : _send,
        child: Text(_sending ? 'Sending…' : 'Send report'),
      ),
    ],
  );
}

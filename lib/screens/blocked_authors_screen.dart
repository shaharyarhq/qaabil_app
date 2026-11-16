import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../services/member_api.dart';
import '../theme/app_tokens.dart';

class BlockedAuthorsScreen extends StatefulWidget {
  const BlockedAuthorsScreen({super.key});

  @override
  State<BlockedAuthorsScreen> createState() => _BlockedAuthorsScreenState();
}

class _BlockedAuthorsScreenState extends State<BlockedAuthorsScreen> {
  Future<List<({int id, String name})>>? _authors;
  int? _unblocking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authors ??= SessionScope.of(context).blockedAuthors();
  }

  void _reload() {
    setState(() => _authors = SessionScope.of(context).blockedAuthors());
  }

  Future<void> _unblock(int id) async {
    setState(() => _unblocking = id);
    try {
      await SessionScope.of(context).unblockAuthor(id);
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _unblocking = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked authors')),
    body: FutureBuilder(
      future: _authors,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (snapshot.hasError) ...[
              const Text('Could not load blocked authors.'),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ] else if (snapshot.data?.isEmpty ?? true)
              const Text('You haven’t blocked any authors.')
            else
              for (final author in snapshot.data!)
                ListTile(
                  title: Text(author.name),
                  trailing: TextButton(
                    onPressed: _unblocking == null
                        ? () => _unblock(author.id)
                        : null,
                    child: Text(
                      _unblocking == author.id ? 'Unblocking…' : 'Unblock',
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

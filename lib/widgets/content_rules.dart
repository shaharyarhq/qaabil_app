import 'package:flutter/material.dart';

import 'website_links.dart';

Future<bool> confirmContentRules(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Qaabil content rules'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By continuing, you agree to the terms of use. Share only material '
              'you have permission to post. Harassment, hate, sexually explicit '
              'content, threats, and sharing private information are prohibited.',
            ),
            TextButton(
              onPressed: () => WebsiteLinks.open(context, WebsiteLinks.terms),
              child: const Text('Read terms of use'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree and continue'),
          ),
        ],
      ),
    ) ??
    false;

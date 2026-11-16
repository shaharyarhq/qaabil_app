import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebsiteLinks extends StatelessWidget {
  const WebsiteLinks({super.key});

  static final privacy = Uri.https('qaabil.io', '/privacy-policy');
  static final terms = Uri.https('qaabil.io', '/terms-and-conditions');
  static final support = Uri.https('qaabil.io', '/contact');
  static final accountDeletion = support.replace(
    queryParameters: {'topic': 'account-deletion'},
  );

  static Future<void> open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Show the same feedback when the device has no browser.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => open(context, privacy),
        child: const Text('Privacy policy'),
      ),
      TextButton(
        onPressed: () => open(context, terms),
        child: const Text('Terms of use'),
      ),
      TextButton(
        onPressed: () => open(context, support),
        child: const Text('Contact support'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BunnyVideo extends StatefulWidget {
  const BunnyVideo({super.key, required this.url});

  final Uri url;

  @override
  State<BunnyVideo> createState() => _BunnyVideoState();
}

class _BunnyVideoState extends State<BunnyVideo> {
  late final WebViewController _controller;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'https' &&
                    uri?.host == widget.url.host &&
                    uri?.path == widget.url.path
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
        ),
      );
      await _controller.loadRequest(widget.url);
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _failed
          ? Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _failed = false;
                    _loading = true;
                  });
                  _load();
                },
                child: const Text('Could not load the video. Retry'),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    ),
  );
}

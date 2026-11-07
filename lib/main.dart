import 'package:flutter/material.dart';

import 'auth/member_session.dart';
import 'screens/main_screen.dart';
import 'services/member_api.dart';
import 'theme/app_theme.dart';
import 'services/note_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NoteFiles.clearPreviousFiles();
  } catch (_) {
    /* OS can also clear temporary cache. */
  }
  runApp(const QaabilApp());
}

class QaabilApp extends StatefulWidget {
  const QaabilApp({super.key, this.session});
  final MemberSession? session;

  @override
  State<QaabilApp> createState() => _QaabilAppState();
}

class _QaabilAppState extends State<QaabilApp> {
  late final MemberSession _session;
  @override
  void initState() {
    super.initState();
    _session = widget.session ?? MemberSession(api: MemberApi());
    _session.restore();
  }

  @override
  void dispose() {
    if (widget.session == null) {
      _session.api.close();
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        title: 'Qaabil',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const MainScreen(),
      ),
    );
  }
}

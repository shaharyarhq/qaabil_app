import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth/member_session.dart';
import 'screens/main_screen.dart';
import 'services/member_api.dart';
import 'theme/app_theme.dart';
import 'theme/app_appearance.dart';
import 'services/note_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NoteFiles.clearPreviousFiles();
  } catch (_) {
    /* OS can also clear temporary cache. */
  }
  const storage = FlutterSecureStorage();
  const appearanceKey = 'qaabil_appearance';
  var mode = ThemeMode.system;
  try {
    final saved = await storage.read(key: appearanceKey);
    mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  } catch (_) {
    // Use the system setting when local preferences are unavailable.
  }
  runApp(
    QaabilApp(
      initialThemeMode: mode,
      saveThemeMode: (mode) =>
          storage.write(key: appearanceKey, value: mode.name),
    ),
  );
}

class QaabilApp extends StatefulWidget {
  const QaabilApp({
    super.key,
    this.session,
    this.initialThemeMode = ThemeMode.system,
    this.saveThemeMode,
  });
  final MemberSession? session;
  final ThemeMode initialThemeMode;
  final Future<void> Function(ThemeMode)? saveThemeMode;

  @override
  State<QaabilApp> createState() => _QaabilAppState();
}

class _QaabilAppState extends State<QaabilApp> {
  late final MemberSession _session;
  late ThemeMode _themeMode = widget.initialThemeMode;
  Future<void> _themeSave = Future.value();

  void _changeTheme(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    final save = widget.saveThemeMode;
    if (save != null) {
      _themeSave = _themeSave.then((_) async {
        try {
          await save(mode);
        } catch (_) {
          // The selection still applies for the current app session.
        }
      });
    }
  }

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
      child: AppAppearance(
        mode: _themeMode,
        onChanged: _changeTheme,
        child: MaterialApp(
          title: 'Qaabil',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          home: const MainScreen(),
        ),
      ),
    );
  }
}

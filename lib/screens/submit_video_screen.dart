import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/member_session.dart';
import '../models/catalogue_course.dart';
import '../models/member_course.dart';
import '../models/objective_resources.dart';
import '../models/video_submission.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/bunny_video.dart';
import '../widgets/local_video_preview.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/searchable_select.dart';
import '../widgets/youtube_video.dart';

class SubmitVideoScreen extends StatefulWidget {
  const SubmitVideoScreen({super.key, this.submissionId});

  final int? submissionId;

  @override
  State<SubmitVideoScreen> createState() => _SubmitVideoScreenState();
}

class _SubmitVideoScreenState extends State<SubmitVideoScreen> {
  final _form = GlobalKey<FormState>();
  final _previewAnchor = GlobalKey();
  bool _showPreview = false;
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _description = TextEditingController();
  final _courses = <int, CatalogueCourse>{};
  Map<String, String> _languages = {}, _focuses = {};
  int _page = 0, _lastPage = 1;
  int? _courseId, _objectiveId;
  MemberCourse? _course;
  VideoSubmission? _draft;
  ({XFile file, String name})? _file;
  int? _uploadMaxMb;
  int _fileSize = 0;
  double _uploadProgress = 0;
  bool _uploadingFile = false, _pickingFile = false;
  String? _language, _focus, _catalogueError, _courseError, _submitError;
  bool _loadingCourses = false, _loadingCourse = false, _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 0 && !_loadingCourses && _catalogueError == null) {
      _loadCourses();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _description.dispose();
    _discardAndroidFile(_file?.file);
    super.dispose();
  }

  Future<void> _loadCourses() async {
    final session = SessionScope.of(context);
    if (session.member == null || _loadingCourses) return;
    setState(() {
      _catalogueError = null;
      _loadingCourses = true;
    });
    try {
      final submissionId = widget.submissionId;
      final initial = _page == 0;
      if (initial) {
        final options = await session.submissionOptions();
        if (!mounted) return;
        _languages = options.languages;
        _focuses = options.focuses;
        _uploadMaxMb = options.uploadMaxMb;
        if (submissionId != null && _draft == null) {
          final draft = await session.submission(submissionId);
          if (!mounted) return;
          setState(() {
            _draft = draft;
            _title.text = draft.title;
            _url.text = draft.videoUrl ?? '';
            _description.text = draft.description ?? '';
            _language = draft.language;
            _focus = draft.focus;
            _courseId = draft.courseId;
            _objectiveId = draft.objectiveId;
          });
        } else if (submissionId == null && _languages.containsKey('en')) {
          _language = 'en';
        }
      }
      do {
        final page = await session.api.catalogue(page: _page + 1);
        if (!mounted) return;
        _courses.addEntries(
          page.courses.map((course) => MapEntry(course.id, course)),
        );
        _page = page.page;
        _lastPage = page.lastPage;
      } while (_page < _lastPage);
      if (_courseId case final courseId? when _course == null) {
        await _selectCourse(courseId, preserveObjective: true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _catalogueError = error.message);
    } finally {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  Future<void> _selectCourse(int id, {bool preserveObjective = false}) async {
    final api = SessionScope.of(context).api;
    setState(() {
      _courseId = id;
      _course = null;
      if (!preserveObjective) _objectiveId = null;
      _courseError = null;
      _loadingCourse = true;
    });
    try {
      final course = await api.publicCourse(id);
      if (mounted) setState(() => _course = course);
    } on ApiException catch (error) {
      if (mounted) setState(() => _courseError = error.message);
    } finally {
      if (mounted) setState(() => _loadingCourse = false);
    }
  }

  Future<({XFile file, String name})?> _pickAndroidVideo() async {
    const channel = MethodChannel('qaabil/video_picker');
    final result = await channel.invokeMapMethod<String, String>('pickVideo', {
      'maxBytes': _uploadMaxMb! * 1024 * 1024,
    });
    if (result == null) return null;
    return (file: XFile(result['path']!), name: result['name']!);
  }

  Future<void> _discardAndroidFile(XFile? file) async {
    if (!Platform.isAndroid || file == null) return;
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // Android can remove a cached upload before this screen closes.
    }
  }

  Future<void> _pickVideo() async {
    if (_pickingFile) return;
    setState(() => _pickingFile = true);
    try {
      final selection = Platform.isAndroid
          ? await _pickAndroidVideo()
          : await _pickOtherVideo();
      if (selection == null) return;
      final file = selection.file;
      if (!mounted) {
        _discardAndroidFile(file);
        return;
      }
      final size = await file.length();
      if (!mounted) {
        _discardAndroidFile(file);
        return;
      }
      setState(() {
        if (size <= 0 || size > _uploadMaxMb! * 1024 * 1024) {
          _discardAndroidFile(file);
          _submitError = 'Choose a video up to $_uploadMaxMb MB.';
          return;
        }
        _discardAndroidFile(_file?.file);
        _file = selection;
        _showPreview = false;
        _fileSize = size;
        _submitError = null;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _submitError = switch (error.code) {
            'file_unreadable' =>
              'Android couldn’t open this video. Try another file or device.',
            'file_too_large' => 'Choose a video up to $_uploadMaxMb MB.',
            _ => 'Could not open the file picker.',
          },
        );
      }
    } on FileSystemException {
      if (mounted) {
        setState(() => _submitError = 'Could not read this video file.');
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  Future<({XFile file, String name})?> _pickOtherVideo() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Videos',
          extensions: ['mp4', 'mov'],
          mimeTypes: ['video/mp4', 'video/quicktime'],
          uniformTypeIdentifiers: [
            'public.mpeg-4',
            'com.apple.quicktime-movie',
          ],
        ),
      ],
    );
    return file == null ? null : (file: file, name: file.name);
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    final session = SessionScope.of(context);
    final objectiveId = _objectiveId;
    if (objectiveId == null) return;
    final file = _file;
    if (_uploadingFile && file == null) {
      setState(() => _submitError = 'Choose a video file first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _showPreview = false;
      _uploadProgress = 0;
      _submitError = null;
    });
    try {
      final fields = {
        'title': _title.text.trim(),
        if (!_uploadingFile) 'video_url': _url.text.trim(),
        'objective_id': '$objectiveId',
        'language': _language ?? '',
        'focus_of_the_video': _focus ?? '',
        'description': _description.text.trim(),
      };
      final submissionId = widget.submissionId;
      if (submissionId == null) {
        final created = _uploadingFile
            ? await session.uploadVideo(
                fields,
                filename: file!.name,
                size: _fileSize,
                stream: file.file.openRead(),
                onProgress: (progress) {
                  if (mounted) setState(() => _uploadProgress = progress);
                },
              )
            : await session.submitVideo(fields);
        if (mounted) Navigator.of(context).pop(created);
      } else {
        await session.updateSubmission(submissionId, fields);
        if (mounted) Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } on FileSystemException {
      if (mounted) {
        setState(() => _submitError = 'Could not read this video file.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _select<T>({
    Key? key,
    required String label,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
    bool enabled = true,
    bool requiredValue = true,
  }) => SearchableSelectField<T>(
    key: key,
    label: label,
    value: value,
    options: options,
    decoration: InputDecoration(labelText: label),
    onChanged: _saving || !enabled || options.isEmpty
        ? null
        : (value) {
            if (value != null) onChanged(value);
          },
    validator: (value) =>
        requiredValue && value == null ? 'Choose a value.' : null,
  );

  String? get _youtubeId {
    final url = Uri.tryParse(_url.text.trim());
    if (url == null ||
        url.scheme != 'https' ||
        url.hasPort ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    if (url.path == '/watch' &&
        const {
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
        }.contains(url.host)) {
      try {
        final id = url.queryParameters['v'];
        return id != null && _youtubeIdPattern.hasMatch(id) ? id : null;
      } on FormatException {
        return null;
      }
    }
    final id = switch (url.host) {
      'youtu.be' => url.path.replaceFirst(RegExp(r'^/+'), ''),
      'youtube.com' || 'www.youtube.com' || 'm.youtube.com' => RegExp(
        r'^/(?:embed|shorts)/([^/]+)$',
      ).firstMatch(url.path)?.group(1),
      _ => null,
    };
    return id != null && _youtubeIdPattern.hasMatch(id) ? id : null;
  }

  static final _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  void _togglePreview() {
    FocusScope.of(context).unfocus();
    setState(() => _showPreview = !_showPreview);
    if (!_showPreview) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final previewContext = _previewAnchor.currentContext;
      if (previewContext != null) {
        Scrollable.ensureVisible(
          previewContext,
          duration: const Duration(milliseconds: 220),
        );
      }
    });
  }

  Widget _sourceChoice(String label, {required bool upload}) {
    final selected = _uploadingFile == upload;
    final palette = AppPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : palette.textPrimary;
    return ChoiceChip(
      label: Text(label),
      labelStyle: AppTextStyles.label.copyWith(color: foreground),
      selected: selected,
      selectedColor: colors.primary,
      backgroundColor: palette.surface,
      checkmarkColor: foreground,
      side: BorderSide(color: selected ? colors.primary : palette.border),
      onSelected: _saving || _pickingFile
          ? null
          : (_) {
              setState(() {
                if (_uploadingFile != upload) _showPreview = false;
                _uploadingFile = upload;
                _submitError = null;
              });
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = SessionScope.of(context).member != null;
    final draft = _draft;
    final editing = widget.submissionId != null;
    final bunnyUrl = VideoPlayback.parseBunnyEmbedUrl(draft?.videoUrl);
    final bunnyVideo = bunnyUrl != null;
    final youtubeId = bunnyVideo || _uploadingFile ? null : _youtubeId;
    final localPath = _uploadingFile ? _file?.file.path : null;
    final canPreview = bunnyVideo || youtubeId != null || localPath != null;
    final courseOptions = {
      ?draft?.courseId: draft?.course ?? 'Current course',
      for (final course in _courses.values) course.id: course.name,
    };
    final objectives = <int, String>{
      if (draft != null && _courseId == draft.courseId)
        ?draft.objectiveId: draft.objective ?? 'Current objective',
      for (final section in _course?.sections ?? <OutlineSection>[])
        for (final chapter in section.chapters)
          for (final objective in chapter.objectives)
            objective.id:
                '${objective.name} (${section.name} › ${chapter.name})',
    };
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: const QaabilAppBar(showAppearance: true),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              editing ? 'Edit video' : 'Submit a video',
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!signedIn)
              const Text('Sign in to submit a video.')
            else if (editing && draft == null)
              if (_catalogueError case final error?)
                TextButton(onPressed: _loadCourses, child: Text('$error Retry'))
              else
                const Center(child: CircularProgressIndicator())
            else
              AppCard(
                child: Form(
                  key: _form,
                  child: Column(
                    spacing: AppSpacing.lg,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (draft?.status == 'approved')
                        const Text(
                          'Changing this approved video will send it back for review.',
                        ),
                      TextFormField(
                        controller: _title,
                        enabled: !_saving,
                        decoration: const InputDecoration(labelText: 'Title'),
                        maxLength: 255,
                        validator: (value) =>
                            value!.trim().isEmpty ? 'Enter a title.' : null,
                      ),
                      _select(
                        key: ValueKey(('course', draft?.id)),
                        label: 'Course',
                        value: _courseId,
                        options: courseOptions,
                        enabled: !_loadingCourse && !_loadingCourses,
                        onChanged: _selectCourse,
                      ),
                      if (_loadingCourses || _loadingCourse)
                        const LinearProgressIndicator(),
                      if (_catalogueError case final error?)
                        TextButton(
                          onPressed: _loadCourses,
                          child: Text('$error Retry'),
                        ),
                      if (_courseError case final error?)
                        TextButton(
                          onPressed: () => _selectCourse(
                            _courseId!,
                            preserveObjective: true,
                          ),
                          child: Text('$error Retry'),
                        ),
                      _select(
                        key: ValueKey(('objective', _courseId, draft?.id)),
                        label: 'Objective',
                        value: _objectiveId,
                        options: objectives,
                        onChanged: (value) =>
                            setState(() => _objectiveId = value),
                      ),
                      if (_course != null && objectives.isEmpty)
                        const Text('This course has no learning objectives.'),
                      _select(
                        key: ValueKey(('focus', draft?.id)),
                        label: 'Focus',
                        value: _focus,
                        options: {
                          ?draft?.focus: draft?.focus ?? '',
                          ..._focuses,
                        },
                        requiredValue: !editing || draft?.focus != null,
                        onChanged: (value) => setState(() => _focus = value),
                      ),
                      _select(
                        key: ValueKey((
                          'language',
                          _languages.isEmpty,
                          draft?.id,
                        )),
                        label: 'Language',
                        value: _language,
                        options: {
                          ?draft?.language: draft?.language ?? '',
                          ..._languages,
                        },
                        requiredValue: !editing || draft?.language != null,
                        onChanged: (value) => setState(() => _language = value),
                      ),
                      if (!editing && _uploadMaxMb != null)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _sourceChoice('YouTube link', upload: false),
                            _sourceChoice('Upload a video', upload: true),
                          ],
                        ),
                      if (_uploadingFile) ...[
                        OutlinedButton.icon(
                          onPressed: _saving || _pickingFile
                              ? null
                              : _pickVideo,
                          icon: const Icon(Icons.video_file_outlined),
                          label: Text(_file?.name ?? 'Choose video file'),
                        ),
                        Text('MP4 or MOV up to $_uploadMaxMb MB'),
                        if (_saving) ...[
                          LinearProgressIndicator(
                            value: _uploadProgress < 1 ? _uploadProgress : null,
                          ),
                          Text(
                            _uploadProgress < 1
                                ? 'Uploading ${(_uploadProgress * 100).floor()}%'
                                : 'Sending to Bunny Stream…',
                          ),
                        ],
                      ] else
                        TextFormField(
                          controller: _url,
                          enabled: !_saving && !bunnyVideo,
                          decoration: InputDecoration(
                            labelText: bunnyVideo
                                ? 'Uploaded video'
                                : 'YouTube link',
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (_) =>
                              setState(() => _showPreview = false),
                          validator: (value) =>
                              (editing &&
                                      value!.trim() ==
                                          (draft?.videoUrl ?? '')) ||
                                  Uri.tryParse(value!.trim())?.scheme == 'https'
                              ? null
                              : 'Enter an HTTPS YouTube link.',
                        ),
                      if (canPreview) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving || _pickingFile
                                ? null
                                : _togglePreview,
                            icon: Icon(
                              _showPreview
                                  ? Icons.expand_less
                                  : Icons.play_circle_outline,
                            ),
                            label: Text(
                              _showPreview ? 'Hide preview' : 'Preview video',
                            ),
                          ),
                        ),
                        if (_showPreview)
                          Align(
                            key: _previewAnchor,
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: switch ((localPath, bunnyUrl, youtubeId)) {
                                (final path?, _, _) => LocalVideoPreview(
                                  path: path,
                                ),
                                (_, final url?, _) => BunnyVideo(url: url),
                                (_, _, final id?) => YoutubeVideo(videoId: id),
                                _ => const SizedBox.shrink(),
                              },
                            ),
                          ),
                      ],
                      TextFormField(
                        controller: _description,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                        maxLength: 5000,
                        minLines: 2,
                        maxLines: 5,
                      ),
                      if (_submitError case final error?)
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed:
                              _saving ||
                                  _pickingFile ||
                                  _loadingCourse ||
                                  _page == 0
                              ? null
                              : _submit,
                          child: Text(
                            _saving
                                ? (editing ? 'Saving…' : 'Submitting…')
                                : (editing
                                      ? 'Save changes'
                                      : 'Submit for review'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

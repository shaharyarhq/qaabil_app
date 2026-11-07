import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/objective_resources.dart';
import 'member_api.dart';

/// Temporary private copies for the OS document viewer; no token in any URL.
class NoteFiles {
  NoteFiles({
    Future<Directory> Function()? directory,
    Future<OpenResult> Function(String path, String mime)? openFile,
  }) : _getDirectory = directory ?? _folder,
       _openFile = openFile ?? _defaultOpen;
  final Future<Directory> Function() _getDirectory;
  final Future<OpenResult> Function(String, String) _openFile;
  static Future<OpenResult> _defaultOpen(String path, String mime) =>
      OpenFilex.open(path, type: mime);
  Directory? _directory;

  static Future<Directory> _folder() async =>
      Directory('${(await getTemporaryDirectory()).path}/qaabil_notes');

  static Future<void> clearPreviousFiles() async {
    final directory = await _folder();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> clear() async {
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _directory = null;
  }

  Future<void> open(
    LessonNote note,
    Uint8List bytes,
    bool Function() stillSignedIn,
  ) async {
    final extension = note.name.split('.').last.toLowerCase();
    if (!{
      'pdf',
      'ppt',
      'pptx',
      'doc',
      'docx',
      'txt',
      'png',
      'jpg',
      'jpeg',
      'webp',
    }.contains(extension)) {
      throw const ApiException('This document format is not supported yet.');
    }
    if (!stillSignedIn()) {
      throw const ApiException('Please log in again to open notes.');
    }
    _directory = await _getDirectory();
    await _directory!.create(recursive: true);
    final file = File(
      '${_directory!.path}/${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}.$extension',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      if (!stillSignedIn()) {
        await file.delete();
        throw const ApiException('Please log in again to open notes.');
      }
      final result = await _openFile(file.path, note.mime);
      if (result.type != ResultType.done) {
        throw const ApiException(
          'No compatible document app could open these notes. Install a viewer for this file type and try again.',
        );
      }
    } on FileSystemException {
      throw const ApiException(
        'Could not save the document temporarily. Check available storage.',
      );
    }
  }
}

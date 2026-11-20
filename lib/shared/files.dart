import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/api_client.dart';
import '../core/models.dart';

Future<List<PlatformFile>> pickOneFile({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) async {
  final file = await FilePicker.pickFile(
    type: type,
    allowedExtensions: allowedExtensions,
  );
  return file == null ? [] : [file];
}

String fileMime(String name) => switch (name.split('.').last.toLowerCase()) {
  'pdf' => 'application/pdf',
  'png' => 'image/png',
  'jpg' || 'jpeg' => 'image/jpeg',
  'mp4' => 'video/mp4',
  _ => 'application/octet-stream',
};

Future<Json> inlineDocument(PlatformFile file) async {
  final size = await file.length();
  if (file.path == null ||
      size == null ||
      size <= 0 ||
      size > 5 * 1024 * 1024) {
    throw const ApiFailure('Choose a PDF/JPEG/PNG file of at most 5 MB.');
  }
  final mime = fileMime(file.name);
  if (!['application/pdf', 'image/jpeg', 'image/png'].contains(mime)) {
    throw const ApiFailure('Choose a PDF, JPEG or PNG file.');
  }
  final data = await File(file.path!).readAsBytes();
  return {
    'id': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
    'fileName': file.name,
    'contentType': mime,
    'sizeBytes': data.length,
    'dataUrl': 'data:$mime;base64,${base64Encode(data)}',
  };
}

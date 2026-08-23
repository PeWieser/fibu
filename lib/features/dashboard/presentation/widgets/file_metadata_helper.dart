import '../../../../core/localization/app_strings.dart';

/// Categorization of file formats for specialized inspector and preview views.
enum FileCategory {
  image,
  video,
  audio,
  textCode,
  document,
  archive,
  binary,
}

/// Helper class providing detailed, realistic file metadata tailored to each file type.
class FileMetadataHelper {
  /// Zweisprachige Labels via AppStrings.current (Service-Schicht ohne Ref).
  static bool get _de => AppStrings.current.isGerman;

  static String getExtension(String fileName) {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }

  static FileCategory getCategory(String fileName) {
    final ext = getExtension(fileName);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
      case 'heic':
      case 'raw':
      case 'ico':
        return FileCategory.image;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
      case 'webm':
      case 'flv':
      case 'm4v':
        return FileCategory.video;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
      case 'aac':
      case 'ogg':
      case 'wma':
        return FileCategory.audio;
      case 'txt':
      case 'md':
      case 'json':
      case 'csv':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'log':
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'html':
      case 'css':
      case 'sh':
      case 'bat':
        return FileCategory.textCode;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return FileCategory.document;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return FileCategory.archive;
      default:
        return FileCategory.binary;
    }
  }

  static String getFormatLabel(String fileName) {
    final ext = getExtension(fileName).toUpperCase();
    final cat = getCategory(fileName);
    switch (cat) {
      case FileCategory.image:
        return _de ? '$ext Bilddatei' : '$ext image file';
      case FileCategory.video:
        return _de ? '$ext Videodatei' : '$ext video file';
      case FileCategory.audio:
        return _de ? '$ext Audiodatei' : '$ext audio file';
      case FileCategory.textCode:
        return _de ? '$ext Text-/Quellcode' : '$ext text/source code';
      case FileCategory.document:
        return _de ? '$ext Dokument' : '$ext document';
      case FileCategory.archive:
        return _de ? '$ext Archiv' : '$ext archive';
      case FileCategory.binary:
        return _de ? '$ext Datei' : '$ext file';
    }
  }

  static String getMimeType(String fileName) {
    final ext = getExtension(fileName);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'm4a':
        return 'audio/mp4';
      case 'json':
        return 'application/json';
      case 'txt':
      case 'log':
        return 'text/plain; charset=utf-8';
      case 'md':
        return 'text/markdown; charset=utf-8';
      case 'csv':
        return 'text/csv';
      case 'dart':
        return 'text/x-dart';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  static String formatExactBytes(int bytes) {
    final str = bytes.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '$buffer Bytes';
  }

  /// Returns a map of key-value metadata pairs tailored for the specific file type.
  static Map<String, String> getSpecificMetadata({
    required String fileName,
    required int fileSize,
    String? modTime,
  }) {
    final Map<String, String> data = {};

    data[_de ? 'Dateiname' : 'File name'] = fileName;
    data[_de ? 'Dateigröße' : 'File size'] = formatExactBytes(fileSize);
    data[_de ? 'Erweiterung' : 'Extension'] = getExtension(fileName).toUpperCase();
    data[_de ? 'Kategorie' : 'Category'] = getFormatLabel(fileName);
    data[_de ? 'MIME-Typ' : 'MIME type'] = getMimeType(fileName);
    if (modTime != null) {
      data[_de ? 'Änderungsdatum' : 'Modified'] = modTime;
    }

    return data;
  }
}

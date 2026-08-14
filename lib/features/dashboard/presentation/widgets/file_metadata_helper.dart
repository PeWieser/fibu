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
        return '$ext Bilddatei';
      case FileCategory.video:
        return '$ext Videodatei';
      case FileCategory.audio:
        return '$ext Audiodatei';
      case FileCategory.textCode:
        return '$ext Text-/Quellcode';
      case FileCategory.document:
        return '$ext Dokument';
      case FileCategory.archive:
        return '$ext Archiv';
      case FileCategory.binary:
        return '$ext Datei';
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
  }) {
    final cat = getCategory(fileName);
    final ext = getExtension(fileName);
    final Map<String, String> data = {};

    switch (cat) {
      case FileCategory.image:
        if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'heic') {
          data['Abmessungen'] = '4032 × 3024 Pixel';
          data['Auflösung'] = '12.2 Megapixel';
          data['Farbraum'] = 'sRGB IEC61966-2.1 (24-Bit)';
          data['Kamera-Modell'] = 'Sony Alpha 7 IV / iPhone 15 Pro';
          data['Objektiv'] = '24-70mm F2.8 G Master';
          data['Belichtung'] = '1/250 Sek. bei f/2.8';
          data['ISO-Wert'] = 'ISO 100';
          data['Brennweite'] = '35 mm (Kleinbild-Äquivalent)';
        } else if (ext == 'svg') {
          data['Vektortyp'] = 'Scalable Vector Graphics (SVG)';
          data['Farbraum'] = 'Vektor (RGB)';
          data['Rendering'] = 'Auflösungsunabhängig';
        } else {
          data['Abmessungen'] = '1920 × 1080 Pixel';
          data['Auflösung'] = '2.1 Megapixel';
          data['Farbraum'] = 'sRGB (24-Bit)';
        }
        break;

      case FileCategory.video:
        data['Video-Codec'] = ext == 'mov' ? 'Apple ProRes / HEVC' : 'H.264 / MPEG-4 AVC';
        data['Auflösung'] = '3840 × 2160 (4K UHD)';
        data['Bildrate'] = '59.94 Bilder/Sek. (60 FPS)';
        data['Audio-Format'] = 'AAC Stereo (48.000 kHz, 2 Kanäle)';
        data['Bitrate'] = '45.2 Mbit/s';
        data['Dauer'] = fileSize > 50000000 ? '03:45 Min.' : '00:58 Min.';
        break;

      case FileCategory.audio:
        data['Audio-Codec'] = ext == 'flac' ? 'FLAC (Lossless 24-Bit)' : 'MPEG Audio Layer 3 (MP3)';
        data['Abtastrate'] = '48.000 Hz (48.0 kHz)';
        data['Bitrate'] = ext == 'flac' ? '1.411 kbit/s' : '320 kbit/s (CBR)';
        data['Kanäle'] = '2 Kanäle (Stereo)';
        data['Dauer'] = '03:42 Min.';
        break;

      case FileCategory.textCode:
        data['Zeichenkodierung'] = 'Unicode (UTF-8)';
        data['Zeilenumbrüche'] = 'LF (UNIX) / CRLF (Windows)';
        data['Geschätzte Zeilen'] = (fileSize ~/ 40).clamp(1, 10000).toString();
        data['Geschätzte Zeichen'] = fileSize.toString();
        data['Programmiersprache'] = ext.toUpperCase();
        break;

      case FileCategory.document:
        data['Dokumententyp'] = ext == 'pdf' ? 'Portable Document Format (PDF 1.7)' : 'Office Open XML Dokument';
        data['Seiten'] = (fileSize ~/ 50000).clamp(1, 150).toString();
        data['Sicherheit'] = 'Kein Passwortschutz';
        break;

      case FileCategory.archive:
        data['Archivformat'] = '$ext-Archiv';
        data['Komprimierungs-Methode'] = 'Deflate / LZMA2';
        data['Verschlüsselung'] = 'Standard';
        break;

      case FileCategory.binary:
        data['Binärformat'] = 'Ausführbare Datei / Binärdaten';
        data['Architektur'] = 'x86_64 / Universal';
        break;
    }

    return data;
  }
}

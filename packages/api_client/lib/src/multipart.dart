import 'package:dio/dio.dart';

/// Maps a filename extension to the image MIME type the BarberHero
/// backend accepts (mirrors the server allow-list:
/// jpeg/png/webp/heic/heif). Returns null for unknown extensions — dio
/// then falls back to `application/octet-stream` and the server's
/// magic-byte sniffing takes over.
DioMediaType? imageMediaTypeFor(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot == -1 ? '' : filename.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return DioMediaType('image', 'jpeg');
    case 'png':
      return DioMediaType('image', 'png');
    case 'webp':
      return DioMediaType('image', 'webp');
    case 'heic':
      return DioMediaType('image', 'heic');
    case 'heif':
      return DioMediaType('image', 'heif');
    default:
      return null;
  }
}

/// Builds a [MultipartFile] for an image upload with the `Content-Type`
/// set from [filename]. Without this, dio defaults the part to
/// `application/octet-stream`, which every BarberHero upload route
/// rejects with HTTP 400 ("Unsupported content type"). Use this for all
/// photo uploads instead of `MultipartFile.fromBytes` directly.
MultipartFile imageMultipartFromBytes(
  List<int> bytes, {
  required String filename,
}) {
  return MultipartFile.fromBytes(
    bytes,
    filename: filename,
    contentType: imageMediaTypeFor(filename),
  );
}

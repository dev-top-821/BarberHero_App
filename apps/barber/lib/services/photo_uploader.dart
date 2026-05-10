import 'dart:io';

import 'package:api_client/api_client.dart';

/// Max upload size in bytes — mirrored on the server.
const int kMaxUploadBytes = 5 * 1024 * 1024;

/// Single-step multipart uploads for barber photos. Server saves the
/// bytes to the photos disk and creates/updates the right DB rows in one
/// round-trip.
class PhotoUploader {
  final ApiClient _api;
  PhotoUploader(this._api);

  Future<String> uploadProfilePhoto(File file) async {
    final mf = await _toMultipart(file);
    return _api.uploadBarberProfilePhoto(mf);
  }

  /// Uploads a portfolio photo and returns the server's photo record
  /// (`{ id, url, order, ... }`) so the caller can update local state.
  Future<Map<String, dynamic>> uploadPortfolioPhoto(File file) async {
    final mf = await _toMultipart(file);
    return _api.uploadBarberPortfolio(mf);
  }

  Future<MultipartFile> _toMultipart(File file) async {
    final bytes = await file.readAsBytes();
    _guardSize(bytes.lengthInBytes);
    return MultipartFile.fromBytes(
      bytes,
      filename: _filename(file.path),
    );
  }

  void _guardSize(int bytes) {
    if (bytes > kMaxUploadBytes) {
      throw Exception('Image is too large. Maximum 5 MB.');
    }
  }

  String _filename(String path) {
    final segs = path.split(RegExp(r'[\\/]'));
    return segs.isEmpty ? 'upload' : segs.last;
  }
}

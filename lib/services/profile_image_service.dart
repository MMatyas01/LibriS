import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ProfileImageService {
  static const String _cloudName = 'vulosqas';

  static const String _uploadPreset =
      'libris_profile_images';

  static const int _maximumFileSize =
      5 * 1024 * 1024;

  Future<String> uploadProfileImage(
    XFile image,
  ) async {
    final List<int> imageBytes =
        await image.readAsBytes();

    if (imageBytes.isEmpty) {
      throw StateError(
        'The selected image is empty.',
      );
    }

    if (imageBytes.length > _maximumFileSize) {
      throw StateError(
        'The selected image must be smaller than 5 MB.',
      );
    }

    final Uri uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uploadUri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: _normalizedFilename(
          image.name,
        ),
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String responseBody =
        await response.stream.bytesToString();

    final Object? decodedResponse =
        jsonDecode(responseBody);

    if (decodedResponse
        is! Map<String, dynamic>) {
      throw StateError(
        'Cloudinary returned an invalid response.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final Object? errorObject =
          decodedResponse['error'];

      if (errorObject
              is Map<String, dynamic> &&
          errorObject['message'] is String) {
        throw StateError(
          errorObject['message'] as String,
        );
      }

      throw StateError(
        'Unable to upload the profile image.',
      );
    }

    final String secureUrl =
        (decodedResponse['secure_url']
                    as String? ??
                '')
            .trim();

    if (secureUrl.isEmpty) {
      throw StateError(
        'Cloudinary did not return an image URL.',
      );
    }

    return secureUrl;
  }

  String _normalizedFilename(
    String originalName,
  ) {
    final String trimmed =
        originalName.trim();

    if (trimmed.isEmpty) {
      return 'profile_image.jpg';
    }

    final String lowerName =
        trimmed.toLowerCase();

    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp')) {
      return trimmed;
    }

    return '$trimmed.jpg';
  }
}
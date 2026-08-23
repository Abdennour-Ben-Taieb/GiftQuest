import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// Uploads a picked image to Cloudinary. Matches the Kotlin app's behavior:
/// returns null (never throws) on any failure so callers can save the
/// profile without a photo instead of blocking sign up.
class CloudinaryService {
  Future<String?> uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloud}/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = AppConfig.cloudinaryPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'pfp.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } catch (e) {
      developer.log('Cloudinary upload failed: $e', name: 'GiftQuest');
      return null;
    }
  }
}

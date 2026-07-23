import 'dart:io';

import 'package:callvault/model/recording_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadService {
  static Future<bool> uploadRecording(
    File file, {
    required RecordingMetadata metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final webhookUrl =
          prefs.getString('server_url') ??
          'https://n8n-642200590.kloudbeansite.com/webhook/call-upload';

      final request = http.MultipartRequest('POST', Uri.parse(webhookUrl));

      String mime = 'audio/mpeg';

      switch (file.path.split('.').last.toLowerCase()) {
        case 'm4a':
          mime = 'audio/mp4';
          break;
        case 'mp3':
          mime = 'audio/mpeg';
          break;
        case 'wav':
          mime = 'audio/wav';
          break;
        case 'aac':
          mime = 'audio/aac';
          break;
        case 'amr':
          mime = 'audio/amr';
          break;
        case '3gp':
          mime = 'audio/3gpp';
          break;
        case 'ogg':
          mime = 'audio/ogg';
          break;
      }

      request.fields.addAll({
        'filename': metadata.filename,
        'phone_number': metadata.phoneNumber,
        'contact_name': metadata.contactName,
        'call_date': metadata.callDate,
        'call_time': metadata.callTime,
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: metadata.filename,
          contentType: MediaType.parse(mime),
        ),
      );

      final response = await request.send().timeout(const Duration(minutes: 3));

      final body = await response.stream.bytesToString();

      debugPrint('Uploading to: $webhookUrl');
      debugPrint('Filename: ${metadata.filename}');
      debugPrint('Phone: ${metadata.phoneNumber}');
      debugPrint('Contact: ${metadata.contactName}');
      debugPrint('Date: ${metadata.callDate}');
      debugPrint('Time: ${metadata.callTime}');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: $body');

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e, stackTrace) {
      debugPrint('UploadService error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}

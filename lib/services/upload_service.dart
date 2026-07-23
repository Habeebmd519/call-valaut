import 'dart:io';

import 'package:callvault/model/recording_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadService {
  static String _safeValue(String? value, {required String placeholder}) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'unknown') {
      return placeholder;
    }

    return cleaned;
  }

  static Future<bool> uploadRecording(
    File file, {

    required RecordingMetadata metadata,

    required String clientName,
  }) async {
    try {
      debugPrint('UploadService received metadata:');

      debugPrint('filename: ${metadata.filename}');

      debugPrint('phoneNumber: ${metadata.phoneNumber}');

      debugPrint('contactName: ${metadata.contactName}');
      debugPrint('clientName: $clientName');

      debugPrint('callDate: ${metadata.callDate}');

      debugPrint('callTime: ${metadata.callTime}');
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

      final filename = _safeValue(
        metadata.filename,
        placeholder: file.uri.pathSegments.last,
      );

      final fields = <String, String>{
        'filename': filename,
        'phone_number': _safeValue(
          metadata.phoneNumber,
          placeholder: 'Not available',
        ),
        'contact_name': _safeValue(
          metadata.contactName,
          placeholder: 'Unknown contact',
        ),
        'client_name': _safeValue(clientName, placeholder: 'Unknown client'),
        'call_date': _safeValue(
          metadata.callDate,
          placeholder: 'Not available',
        ),
        'call_time': _safeValue(
          metadata.callTime,
          placeholder: 'Not available',
        ),
      };
      request.fields.addAll(fields);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
          contentType: MediaType.parse(mime),
        ),
      );

      debugPrint('Uploading to: $webhookUrl');
      debugPrint('Fields being sent: $fields');
      debugPrint('File field: file');
      debugPrint('File path: ${file.path}');
      debugPrint('MIME type: $mime');
      debugPrint('Fields being sent:');
      fields.forEach((key, value) {
        debugPrint('$key = $value');
      });

      final response = await request.send().timeout(const Duration(minutes: 3));

      final body = await response.stream.bytesToString();

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

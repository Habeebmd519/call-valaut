import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadService {
  static Future<bool> uploadRecording(File file) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final webhookUrl =
          prefs.getString("server_url") ??
          "https://n8n-642200590.kloudbeansite.com/webhook/call-upload";

      final request = http.MultipartRequest("POST", Uri.parse(webhookUrl));

      String mime = "audio/mpeg";

      switch (file.path.split('.').last.toLowerCase()) {
        case "m4a":
          mime = "audio/mp4";
          break;
        case "mp3":
          mime = "audio/mpeg";
          break;
        case "wav":
          mime = "audio/wav";
          break;
        case "aac":
          mime = "audio/aac";
          break;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          file.path,
          filename: file.uri.pathSegments.last,
          contentType: MediaType.parse(mime),
        ),
      );

      request.fields["filename"] = file.uri.pathSegments.last;

      final response = await request.send();

      final body = await response.stream.bytesToString();

      print("Uploading to: $webhookUrl");
      print("Status: ${response.statusCode}");
      print(body);

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print(e);
      return false;
    }
  }
}

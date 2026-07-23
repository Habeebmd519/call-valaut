import 'dart:io';

import 'package:callvault/model/recording_metadata.dart';
import 'package:flutter/foundation.dart';

class MetadataService {
  static Future<RecordingMetadata> fromFile(File file) async {
    final originalFilename = file.uri.pathSegments.last;
    final nameWithoutExtension = _removeExtension(originalFilename);

    debugPrint('Parsing original filename: $originalFilename');

    final pattern = RegExp(r'^(.*?)\(([^)]+)\)_(\d{8})(\d{6})$');

    final match = pattern.firstMatch(nameWithoutExtension);

    if (match == null) {
      debugPrint('Metadata pattern did not match: $nameWithoutExtension');

      return RecordingMetadata(
        filename: originalFilename,
        phoneNumber: '',
        contactName: '',
        callDate: '',
        callTime: '',
      );
    }

    final rawContactName = match.group(1)?.trim() ?? '';
    final phoneNumber = match.group(2)?.trim() ?? '';
    final rawDate = match.group(3) ?? '';
    final rawTime = match.group(4) ?? '';

    final contactName = rawContactName.replaceFirst(RegExp(r'^#+'), '').trim();

    final callDate = _formatDate(rawDate);
    final callTime = _formatTime(rawTime);

    debugPrint('Parsed phone number: $phoneNumber');
    debugPrint('Parsed contact name: $contactName');
    debugPrint('Parsed call date: $callDate');
    debugPrint('Parsed call time: $callTime');

    return RecordingMetadata(
      filename: originalFilename,
      phoneNumber: phoneNumber,
      contactName: contactName,
      callDate: callDate,
      callTime: callTime,
    );
  }

  static String _removeExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');

    if (dotIndex <= 0) {
      return filename;
    }

    return filename.substring(0, dotIndex);
  }

  static String _formatDate(String value) {
    if (value.length != 8) {
      return '';
    }

    final year = value.substring(0, 4);
    final month = value.substring(4, 6);
    final day = value.substring(6, 8);

    return '$year-$month-$day';
  }

  static String _formatTime(String value) {
    if (value.length != 6) {
      return '';
    }

    final hour = value.substring(0, 2);
    final minute = value.substring(2, 4);
    final second = value.substring(4, 6);

    return '$hour:$minute:$second';
  }
}

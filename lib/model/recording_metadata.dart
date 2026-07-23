import 'dart:io';

class RecordingMetadata {
  final String filename;
  final String phoneNumber;
  final String contactName;
  final String callDate;
  final String callTime;

  const RecordingMetadata({
    required this.filename,
    required this.phoneNumber,
    required this.contactName,
    required this.callDate,
    required this.callTime,
  });

  RecordingMetadata copyWith({
    String? filename,
    String? phoneNumber,
    String? contactName,
    String? callDate,
    String? callTime,
  }) {
    return RecordingMetadata(
      filename: filename ?? this.filename,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      callDate: callDate ?? this.callDate,
      callTime: callTime ?? this.callTime,
    );
  }
}

class MetadataService {
  static Future<RecordingMetadata> fromFile(File file) async {
    final filename = file.uri.pathSegments.last;

    String phoneNumber = 'Unknown';
    String callDate = 'Unknown';
    String callTime = 'Unknown';

    // Example supported filename:
    // Call recording(9876543210)_20260721143025.m4a

    final phoneMatch = RegExp(r'\(([^)]+)\)').firstMatch(filename);

    if (phoneMatch != null) {
      final value = phoneMatch.group(1)?.trim();

      if (value != null && value.isNotEmpty) {
        phoneNumber = value;
      }
    }

    final dateTimeMatch = RegExp(r'_(\d{14})').firstMatch(filename);

    if (dateTimeMatch != null) {
      final value = dateTimeMatch.group(1)!;

      callDate =
          '${value.substring(0, 4)}-'
          '${value.substring(4, 6)}-'
          '${value.substring(6, 8)}';

      callTime =
          '${value.substring(8, 10)}:'
          '${value.substring(10, 12)}:'
          '${value.substring(12, 14)}';
    } else {
      try {
        final modified = await file.lastModified();

        callDate =
            '${modified.year.toString().padLeft(4, '0')}-'
            '${modified.month.toString().padLeft(2, '0')}-'
            '${modified.day.toString().padLeft(2, '0')}';

        callTime =
            '${modified.hour.toString().padLeft(2, '0')}:'
            '${modified.minute.toString().padLeft(2, '0')}:'
            '${modified.second.toString().padLeft(2, '0')}';
      } catch (_) {
        // Keep Unknown when file metadata cannot be read.
      }
    }

    return RecordingMetadata(
      filename: filename,
      phoneNumber: phoneNumber,
      contactName: 'Unknown',
      callDate: callDate,
      callTime: callTime,
    );
  }
}

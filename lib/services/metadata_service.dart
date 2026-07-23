import 'dart:io';

import 'package:callvault/model/recording_metadata.dart';

class MetadataService {
  static Future<RecordingMetadata> fromFile(File file) async {
    // TODO:
    // extract filename
    // extract phone number
    // extract date
    // extract time

    return RecordingMetadata(
      filename: file.uri.pathSegments.last,
      phoneNumber: '',
      contactName: '',
      callDate: '',
      callTime: '',
    );
  }
}

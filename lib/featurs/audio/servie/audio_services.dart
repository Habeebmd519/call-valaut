import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class AudioConverter {
  static Future<File> convertToMp3(File input) async {
    if (input.path.toLowerCase().endsWith(".mp3")) {
      return input;
    }

    final dir = await getTemporaryDirectory();

    final output = File(
      "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp3",
    );

    final command =
        '-y -i "${input.path}" -codec:a libmp3lame -qscale:a 2 "${output.path}"';

    final session = await FFmpegKit.execute(command);

    final rc = await session.getReturnCode();

    if (rc?.isValueSuccess() != true) {
      throw Exception("MP3 conversion failed");
    }

    return output;
  }
}

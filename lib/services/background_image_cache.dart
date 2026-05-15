import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundImageCache {
  const BackgroundImageCache();

  Future<String> createDisplayCopy({
    required String sourcePath,
    required Size logicalScreenSize,
    required double devicePixelRatio,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final physicalWidth = logicalScreenSize.width * devicePixelRatio;
    final targetWidth = physicalWidth.clamp(720, 1440).round();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      return sourcePath;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/nyacourse_background_display_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return path;
  }

  Future<void> deleteIfOwned(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final normalizedDirectory = directory.path.replaceAll('\\', '/');
    final normalizedPath = file.path.replaceAll('\\', '/');
    if (!normalizedPath.startsWith('$normalizedDirectory/')) {
      return;
    }
    final name = normalizedPath.split('/').last;
    if (!name.startsWith('nyacourse_background')) {
      return;
    }
    await file.delete();
  }

  int estimateDecodeBytes({
    required Size logicalScreenSize,
    required double devicePixelRatio,
  }) {
    final width = (logicalScreenSize.width * devicePixelRatio)
        .clamp(720, 1440)
        .round();
    final scale = width / math.max(logicalScreenSize.width, 1);
    final height = (logicalScreenSize.height * scale).round();
    return width * height * 4;
  }
}

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
// import 'simple_audio_trimmer_platform_interface.dart';

class SimpleAudioTrimmer {
  static const MethodChannel _channel = MethodChannel('simple_audio_trimmer');

  Future<String> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version ?? 'Unknown platform version';
  }

  /// Converts a relative path to an absolute path if needed
  static String _ensureAbsolutePath(String filePath) {
    if (path.isAbsolute(filePath)) {
      return filePath;
    }
    
    // Convert relative path to absolute
    return path.join(Directory.current.path, filePath);
  }

  /// Trims an audio file between the given start and end times
  /// 
  /// [inputPath] can be absolute or relative
  /// [outputPath] can be absolute or relative
  /// [start] is the start time in seconds
  /// [end] is the end time in seconds
  /// 
  /// Returns the absolute path of the trimmed audio file
  /// 
  /// Throws [PlatformException] if trimming fails
  static Future<String> trim({
    required String inputPath,
    required String outputPath,
    required double start,
    required double end,
  }) async {
    // Convert paths to absolute if they are relative
    final String absoluteInputPath = _ensureAbsolutePath(inputPath);
    final String absoluteOutputPath = _ensureAbsolutePath(outputPath);
    
    try {
      final result = await _channel.invokeMethod('trim', {
        'inputPath': absoluteInputPath,
        'outputPath': absoluteOutputPath,
        'start': start,
        'end': end,
      });

      return result as String;
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Audio trimming failed: ${e.message}',
        details: e.details,
      );
    } catch (e) {
      throw Exception('Unknown error occurred during audio trimming: $e');
    }
  }
}

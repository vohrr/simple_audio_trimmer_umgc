import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'simple_audio_trimmer_platform_interface.dart';

/// An implementation of [SimpleAudioTrimmerPlatform] that uses method channels.
class MethodChannelSimpleAudioTrimmer extends SimpleAudioTrimmerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('simple_audio_trimmer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'simple_audio_trimmer_method_channel.dart';

abstract class SimpleAudioTrimmerPlatform extends PlatformInterface {
  /// Constructs a SimpleAudioTrimmerPlatform.
  SimpleAudioTrimmerPlatform() : super(token: _token);

  static final Object _token = Object();

  static SimpleAudioTrimmerPlatform _instance = MethodChannelSimpleAudioTrimmer();

  /// The default instance of [SimpleAudioTrimmerPlatform] to use.
  ///
  /// Defaults to [MethodChannelSimpleAudioTrimmer].
  static SimpleAudioTrimmerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SimpleAudioTrimmerPlatform] when
  /// they register themselves.
  static set instance(SimpleAudioTrimmerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

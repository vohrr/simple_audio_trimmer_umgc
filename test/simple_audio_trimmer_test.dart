import 'package:flutter_test/flutter_test.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer_platform_interface.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSimpleAudioTrimmerPlatform
    with MockPlatformInterfaceMixin
    implements SimpleAudioTrimmerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SimpleAudioTrimmerPlatform initialPlatform = SimpleAudioTrimmerPlatform.instance;

  test('$MethodChannelSimpleAudioTrimmer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSimpleAudioTrimmer>());
  });

  test('getPlatformVersion', () async {
    SimpleAudioTrimmer simpleAudioTrimmerPlugin = SimpleAudioTrimmer();
    MockSimpleAudioTrimmerPlatform fakePlatform = MockSimpleAudioTrimmerPlatform();
    SimpleAudioTrimmerPlatform.instance = fakePlatform;

    expect(await simpleAudioTrimmerPlugin.getPlatformVersion(), '42');
  });
}

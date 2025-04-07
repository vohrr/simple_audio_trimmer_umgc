import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer_method_channel.dart';

void main() {
  MethodChannelSimpleAudioTrimmer platform = MethodChannelSimpleAudioTrimmer();
  const MethodChannel channel = MethodChannel('simple_audio_trimmer');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}

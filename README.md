# simple_audio_trimmer

A Flutter plugin for audio trimming functionality.

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  simple_audio_trimmer: ^0.1.4
```

## Usage

### Basic Usage

```dart
import 'package:simple_audio_trimmer/simple_audio_trimmer.dart';

// Trim audio file
Future<void> trimAudio() async {
  String inputPath = "path/to/input/audio/file";
  String outputPath = "path/to/output/audio/file";
  
  try {
    String result = await SimpleAudioTrimmer.trim(
      inputPath: inputPath,
      outputPath: outputPath,
      start: 10.0,  // Start time in seconds
      end: 30.0,    // End time in seconds
    );
    
    print("Audio file trimmed successfully: $result");
  } catch (e) {
    print("Failed to trim audio file: $e");
  }
}
```

### Path Resolution

The plugin supports both absolute and relative paths:

```dart
// Using absolute paths
await SimpleAudioTrimmer.trim(
  inputPath: "/absolute/path/to/input.m4a",
  outputPath: "/absolute/path/to/output.m4a",
  start: 10.0,
  end: 30.0,
);

// Using relative paths (will be resolved to absolute)
await SimpleAudioTrimmer.trim(
  inputPath: "assets/audio/input.m4a",
  outputPath: "trimmed_output.m4a",
  start: 10.0,
  end: 30.0,
);
```

### Example Code

For more detailed usage examples, please refer to the example folder.

## Supported Formats

Supported audio file formats:
- M4A
- WAV

The output format is determined by the extension of the output file. For example:

```dart
// Output as m4a
await SimpleAudioTrimmer.trim(
  inputPath: "input.m4a",
  outputPath: "output.m4a",
  start: 10.0,
  end: 30.0,
);

// Output as WAV
await SimpleAudioTrimmer.trim(
  inputPath: "input.m4a",
  outputPath: "output.wav",
  start: 10.0,
  end: 30.0,
);
```

### Platform-specific format support notes:

#### iOS
iOS fully supports M4A and WAV formats for both input and output using native AVFoundation.

#### Android
- **WAV**: Supported with direct PCM conversion (pure native implementation, no external dependencies)

## Platform-specific Notes

### Android
- The output directory must exist and have write permissions.
- No external dependencies are used for audio encoding, ensuring no license conflicts.

### iOS
- Appropriate permissions are required to access files outside the sandbox.

## Getting Started

For more information on developing Flutter plugins, see:
[Developing packages and plugins](https://flutter.dev/to/develop-plugins)

For help getting started with Flutter, view the online documentation:
[Flutter documentation](https://docs.flutter.dev)


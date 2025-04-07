import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Ready';
  String? _trimmedFilePath;
  String? _originalFilePath;
  
  final AudioPlayer _originalPlayer = AudioPlayer();
  final AudioPlayer _trimmedPlayer = AudioPlayer();
  
  double _startTime = 5.0;
  double _endTime = 10.0;
  double _maxDuration = 15.0;
  bool _isOriginalPlaying = false;
  bool _isTrimmedPlaying = false;
  
  // Variables for displaying progress time
  StreamSubscription<Duration>? _originalPositionSubscription;
  StreamSubscription<Duration>? _trimmedPositionSubscription;
  Duration _originalPosition = Duration.zero;
  Duration _trimmedPosition = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _setupAudio();
    _setupPositionListeners();
  }
  
  @override
  void dispose() {
    _originalPositionSubscription?.cancel();
    _trimmedPositionSubscription?.cancel();
    _originalPlayer.dispose();
    _trimmedPlayer.dispose();
    super.dispose();
  }
  
  void _setupPositionListeners() {
    // Original audio progress time listener
    _originalPositionSubscription = _originalPlayer.positionStream.listen((position) {
      setState(() {
        _originalPosition = position;
      });
    });
    
    // Trimmed audio progress time listener
    _trimmedPositionSubscription = _trimmedPlayer.positionStream.listen((position) {
      setState(() {
        _trimmedPosition = position;
      });
    });
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  Future<void> _setupAudio() async {
    try {
      setState(() => _status = 'Copying audio from assets...');
      final dir = await getApplicationDocumentsDirectory();
      final inputFile = File('${dir.path}/sample.m4a');
      final byteData = await rootBundle.load('assets/audio/sample.m4a');
      await inputFile.writeAsBytes(byteData.buffer.asUint8List());
      
      _originalFilePath = inputFile.path;
      await _originalPlayer.setFilePath(inputFile.path);
      
      // Get total length of audio file - 안전하게 계산
      await Future.delayed(Duration(milliseconds: 500)); // 오디오 로딩 시간 확보
      _maxDuration = _originalPlayer.duration?.inSeconds.toDouble() ?? 15.0;

      // 샘플 길이가 너무 길면 UI 표시 목적으로 표시 범위 제한
      if (_maxDuration > 15.0) {
        _maxDuration = 15.0;
      }
      
      setState(() {
        _status = 'Ready';
        // Set initial start/end times based on audio max length
        _startTime = 0;
        _endTime = _maxDuration;
      });
      
      // Monitor playback state
      _originalPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isOriginalPlaying = false;
          });
          _originalPlayer.seek(Duration.zero);
        }
      });
      
      _trimmedPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isTrimmedPlaying = false;
          });
          _trimmedPlayer.seek(Duration.zero);
        }
      });
      
    } catch (e) {
      setState(() {
        _status = 'Error during audio setup: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Trimmer Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 16),
              
              // Original audio playback section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      
                      // Playback progress indicator
                      if (_originalPlayer.duration != null)
                        Column(
                          children: [
                            Stack(
                              children: [
                                // Base progress bar in container with fixed size
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  width: double.infinity,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          LinearProgressIndicator(
                                            value: _originalPlayer.duration!.inMilliseconds > 0
                                              ? _originalPosition.inMilliseconds / _originalPlayer.duration!.inMilliseconds
                                              : 0.0,
                                            backgroundColor: Colors.grey[300],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                          ),
                                          // Trim start indicator - UI 위치 계산 부분 수정
                                          Positioned(
                                            left: (_startTime / _maxDuration) * constraints.maxWidth,
                                            child: Container(
                                              height: 15,
                                              width: 2,
                                              color: Colors.red,
                                            ),
                                          ),
                                          // Trim end indicator - UI 위치 계산 부분 수정
                                          Positioned(
                                            left: (_endTime / _maxDuration) * constraints.maxWidth,
                                            child: Container(
                                              height: 15,
                                              width: 2,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(_originalPosition)} / ${_formatDuration(_originalPlayer.duration ?? Duration.zero)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _originalFilePath == null ? null : _playOriginalAudio,
                            icon: Icon(_isOriginalPlaying ? Icons.pause : Icons.play_arrow),
                            iconSize: 40,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Trimming settings section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trimming Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      Text('Start Time: ${_startTime.toStringAsFixed(1)} sec'),
                      Slider(
                        value: _startTime,
                        min: 0,
                        max: _endTime - 0.5,
                        divisions: (_maxDuration * 2).toInt(),
                        label: _startTime.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _startTime = value;
                          });
                        },
                      ),
                      
                      Text('End Time: ${_endTime.toStringAsFixed(1)} sec'),
                      Slider(
                        value: _endTime,
                        min: _startTime + 0.5,
                        max: _maxDuration,
                        divisions: (_maxDuration * 2).toInt(),
                        label: _endTime.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _endTime = value;
                          });
                        },
                      ),
                      
                      Center(
                        child: ElevatedButton(
                          onPressed: _trimAudio,
                          child: const Text('Trim Audio'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Trimmed audio section
              if (_trimmedFilePath != null) 
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trimmed Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        // Playback progress indicator
                        if (_trimmedPlayer.duration != null)
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: LinearProgressIndicator(
                                  value: _trimmedPlayer.duration!.inMilliseconds > 0
                                      ? _trimmedPosition.inMilliseconds / _trimmedPlayer.duration!.inMilliseconds
                                      : 0.0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDuration(_trimmedPosition)} / ${_formatDuration(_trimmedPlayer.duration ?? Duration.zero)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _playTrimmedAudio,
                              icon: Icon(_isTrimmedPlaying ? Icons.pause : Icons.play_arrow),
                              iconSize: 40,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('File Path:'),
                        SelectableText(_trimmedFilePath!),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _playOriginalAudio() async {
    if (_isOriginalPlaying) {
      await _originalPlayer.pause();
      setState(() {
        _isOriginalPlaying = false;
      });
    } else {
      // Reset position if in completed state
      if (_originalPlayer.processingState == ProcessingState.completed) {
        await _originalPlayer.seek(Duration.zero);
      }
      
      await _originalPlayer.play();
      setState(() {
        _isOriginalPlaying = true;
      });
    }
  }
  
  Future<void> _playTrimmedAudio() async {
    if (_isTrimmedPlaying) {
      await _trimmedPlayer.pause();
      setState(() {
        _isTrimmedPlaying = false;
      });
    } else {
      // Reset position to beginning before playing
      if (_trimmedPlayer.processingState == ProcessingState.completed) {
        await _trimmedPlayer.seek(Duration.zero);
      }
      await _trimmedPlayer.play();
      setState(() {
        _isTrimmedPlaying = true;
      });
    }
  }

  Future<void> _trimAudio() async {
    try {
      setState(() => _status = 'Trimming...');
      
      if (_originalFilePath == null) {
        throw Exception('Original audio file is not ready.');
      }
      
      // Stop playing audio
      if (_isOriginalPlaying) {
        await _originalPlayer.pause();
        setState(() {
          _isOriginalPlaying = false;
        });
      }
      
      if (_isTrimmedPlaying) {
        await _trimmedPlayer.pause();
        setState(() {
          _isTrimmedPlaying = false;
        });
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final outputFile = File('${dir.path}/trimmed_${const Uuid().v4()}.m4a');

      final trimmedPath = await SimpleAudioTrimmer.trim(
        inputPath: _originalFilePath!,
        outputPath: outputFile.path,
        start: _startTime,
        end: _endTime,
      );
      
      // Load new trimmed audio
      await _trimmedPlayer.setFilePath(trimmedPath);

      setState(() {
        _status = 'Completed!';
        _trimmedFilePath = trimmedPath;
      });
      
      // Auto-play trimmed audio
      await _trimmedPlayer.play();
      setState(() {
        _isTrimmedPlaying = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Error occurred: $e';
      });
    }
  }
}
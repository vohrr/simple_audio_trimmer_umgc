import Flutter
import UIKit
import AVFoundation

public class AudioTrimmerPlugin: NSObject, FlutterPlugin {
  public func getPlatformVersion() -> String {
    return "iOS " + UIDevice.current.systemVersion
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "simple_audio_trimmer", binaryMessenger: registrar.messenger())
    let instance = AudioTrimmerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "trim" {
      guard let args = call.arguments as? [String: Any],
            let inputPath = args["inputPath"] as? String,
            let outputPath = args["outputPath"] as? String,
            let start = args["start"] as? Double,
            let end = args["end"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
      }

      trimAudio(inputPath: inputPath, outputPath: outputPath, start: start, end: end, result: result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func trimAudio(inputPath: String, outputPath: String, start: Double, end: Double, result: @escaping FlutterResult) {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)

    let asset = AVAsset(url: inputURL)
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      result(FlutterError(code: "EXPORT_SESSION_ERROR", message: "Could not create export session", details: nil))
      return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a

    let startTime = CMTime(seconds: start, preferredTimescale: 600)
    let duration = CMTime(seconds: end - start, preferredTimescale: 600)
    exportSession.timeRange = CMTimeRange(start: startTime, duration: duration)

    exportSession.exportAsynchronously {
      if exportSession.status == .completed {
        result(outputPath)
      } else {
        let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
        result(FlutterError(code: "EXPORT_FAILED", message: errorMessage, details: nil))
      }
    }
  }
}
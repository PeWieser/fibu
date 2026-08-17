import Flutter
import Foundation

// The `Rclone` module is produced by `ios/scripts/build_librclone.sh`
// (gomobile build of rclone's `librclone/gomobile` package) and dropped in as
// `ios/Frameworks/Rclone.xcframework`. It exposes:
//   RcloneInitialize(), RcloneFinalize()
//   RcloneRPC(_ method: String, _ input: String) -> RcloneRPCResult { output, status }
//
// The import is wrapped in `canImport` so the Dart/Flutter project still
// compiles before the framework has been built, surfacing a clear runtime error
// instead of failing the whole build.
#if canImport(Rclone)
import Rclone
#endif

/// Bridges Flutter's `fibu/rclone` MethodChannel to the embedded librclone engine.
public class RcloneBridge: NSObject {
  private static var didInitialize = false

  public static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fibu/rclone", binaryMessenger: messenger)
    let instance = RcloneBridge()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initializeEngine(result: result)
    case "rpc":
      guard let args = call.arguments as? [String: Any],
            let method = args["method"] as? String else {
        result(FlutterError(code: "bad_args", message: "method missing", details: nil))
        return
      }
      let input = args["input"] as? String ?? "{}"
      performRPC(method: method, input: input, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeEngine(result: @escaping FlutterResult) {
    #if canImport(Rclone)
    if !RcloneBridge.didInitialize {
      RcloneInitialize()
      RcloneBridge.didInitialize = true
    }
    result(nil)
    #else
    result(FlutterError(
      code: "librclone_missing",
      message: "Rclone.xcframework ist nicht eingebunden. Bitte ios/scripts/build_librclone.sh ausführen.",
      details: nil))
    #endif
  }

  private func performRPC(method: String, input: String, result: @escaping FlutterResult) {
    #if canImport(Rclone)
    if !RcloneBridge.didInitialize {
      RcloneInitialize()
      RcloneBridge.didInitialize = true
    }
    // Run off the platform thread; large syncs would otherwise block the UI.
    DispatchQueue.global(qos: .userInitiated).async {
      let rpcResult = RcloneRPC(method, input)
      let status = rpcResult.status
      let output = rpcResult.output
      DispatchQueue.main.async {
        if status >= 200 && status < 300 {
          result(output)
        } else {
          result(FlutterError(
            code: "rclone_error_\(status)",
            message: "rclone \(method) fehlgeschlagen (Status \(status))",
            details: output))
        }
      }
    }
    #else
    result(FlutterError(
      code: "librclone_missing",
      message: "Rclone.xcframework ist nicht eingebunden. Bitte ios/scripts/build_librclone.sh ausführen.",
      details: nil))
    #endif
  }
}

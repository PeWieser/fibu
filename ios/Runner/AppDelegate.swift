import Flutter
import UIKit
#if canImport(workmanager)
import workmanager
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// The `Rclone` module is produced by `ios/scripts/build_librclone.sh`
// (gomobile build of rclone's `librclone/gomobile` package) and dropped in as
// `ios/Frameworks/Rclone.xcframework`.
//
// Symbol naming: gobind prefixes every exported name with
// `<-prefix><Title(go package name)>`. The script passes `-prefix Rclone` and the
// bound Go package is `gomobile`, so the prefix is `Rclone` + `Gomobile`:
//   RcloneGomobileRcloneInitialize(), RcloneGomobileRcloneFinalize()
//   RcloneGomobileRcloneRPC(_ method: String, _ input: String)
//       -> RcloneGomobileRcloneRPCResult? { output, status }
// (The module/umbrella header stays `Rclone`, because that is the .xcframework name.)
//
// The import is wrapped in `canImport` so the project still compiles before the
// framework has been built, surfacing a clear runtime error instead of a build failure.
#if canImport(Rclone)
import Rclone
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(workmanager)
    // Erlaubt Workmanager, Plugins in den Hintergrund-Isolates zu registrieren.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Hintergrund-Task für geplante Syncs (Identifier siehe Info.plist).
    // Hinweis: registerBGProcessingTask ist in workmanager >=0.5 nicht mehr nötig
    // bzw. wurde entfernt; die Registrierung erfolgt automatisch.
    // WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "workmanager.background.task")
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RcloneBridge") {
      RcloneBridge.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WidgetStatusChannel") {
      WidgetStatusChannel.register(with: registrar.messenger())
    }
  }
}

/// Channel `fibu/widget`: Die Flutter-App schiebt den Sync-Zustand in die
/// App-Group; die Widget-Extension liest ihn beim nächsten Timeline-Reload.
final class WidgetStatusChannel: NSObject {
  static let appGroup = "group.com.example.fibu"
  static let statusKey = "fibu_widget_status"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fibu/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "setStatus",
         let dict = call.arguments as? [String: Any] {
        do {
          let data = try JSONSerialization.data(withJSONObject: dict)
          if let json = String(data: data, encoding: .utf8),
             let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(json, forKey: statusKey)
            defaults.synchronize()
            #if canImport(WidgetKit) && !targetEnvironment(macCatalyst)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
          }
          result(nil)
        } catch {
          result(FlutterError(code: "widget_write_failed", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Bridges Flutter's `fibu/rclone` MethodChannel to the embedded librclone engine.
///
/// This lives inside AppDelegate.swift on purpose: AppDelegate.swift is already
/// part of the Runner target's Compile Sources, so no `project.pbxproj` edit is
/// required for the bridge to be built.
final class RcloneBridge: NSObject {
  private static var didInitialize = false

  static func register(with messenger: FlutterBinaryMessenger) {
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
      RcloneGomobileRcloneInitialize()
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
      RcloneGomobileRcloneInitialize()
      RcloneBridge.didInitialize = true
    }
    // Run off the platform thread; large syncs would otherwise block the UI.
    DispatchQueue.global(qos: .userInitiated).async {
      guard let rpcResult = RcloneGomobileRcloneRPC(method, input) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "rclone_error_nil",
            message: "rclone \(method) lieferte keine Antwort",
            details: nil))
        }
        return
      }
      let status = Int(rpcResult.status)
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

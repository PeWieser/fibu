import Flutter
import UIKit
import Security
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
    // WICHTIG: Auch die Fibu-eigenen Channels (rclone-Engine, Widget-Status,
    // Schlüsselbund) registrieren — sonst kann der Hintergrund-Sync weder
    // rclone aufrufen noch den Widget-Status in die App-Group pushen.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      if let registrar = registry.registrar(forPlugin: "RcloneBridge") {
        RcloneBridge.register(with: registrar.messenger())
      }
      if let registrar = registry.registrar(forPlugin: "WidgetStatusChannel") {
        WidgetStatusChannel.register(with: registrar.messenger())
      }
      if let registrar = registry.registrar(forPlugin: "KeychainChannel") {
        KeychainChannel.register(with: registrar.messenger())
      }
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KeychainChannel") {
      KeychainChannel.register(with: registrar.messenger())
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

/// Channel `fibu/keychain`: direkter Apple-Schlüsselbund-Zugriff
/// (Security.framework, kSecClassGenericPassword) — ersetzt das zuvor
/// verwendete flutter_secure_storage-Plugin komplett.
///
/// Methoden: read {key} → String?, write {key,value}, delete {key}.
/// Ablage: service = "fibu.secure", account = key. Bar­werte werden nie
/// geloggt; Zugriffsklasse AfterFirstUnlockThisDeviceOnly, damit
/// Hintergrund-Syncs lesen können, aber nichts das Gerät per Backup verlässt.
final class KeychainChannel: NSObject {
  private static let service = "fibu.secure"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fibu/keychain", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String, !key.isEmpty else {
        result(FlutterError(code: "bad_args", message: "key missing", details: nil))
        return
      }
      switch call.method {
      case "read":
        result(readValue(account: key))
      case "write":
        guard let value = args["value"] as? String else {
          result(FlutterError(code: "bad_args", message: "value missing", details: nil))
          return
        }
        writeValue(account: key, value: value)
        result(nil)
      case "delete":
        deleteValue(account: key)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  private static func readValue(account: String) -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func writeValue(account: String, value: String) {
    // Erst löschen, dann neu anlegen — so bleibt write idempotent.
    deleteValue(account: account)
    var attrs = baseQuery(account: account)
    attrs[kSecValueData as String] = Data(value.utf8)
    attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(attrs as CFDictionary, nil)
  }

  private static func deleteValue(account: String) {
    SecItemDelete(baseQuery(account: account) as CFDictionary)
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

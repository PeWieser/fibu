import Flutter
import UIKit

// MARK: - Liquid Glass (iOS 26+)
//
// Echtes natives Liquid Glass via UIGlassEffect. Der Typ wird zur Laufzeit
// über NSClassFromString geladen — so kompiliert der Code auch mit älteren
// Xcode/SDKs (CI), und auf iOS < 26 bleibt alles unverändert (nil → kein Effekt).
//
// Deployment Target bleibt 15.0. Kein Hard-Link auf UIGlassEffect-Symbole.
// OS-Version per ProcessInfo (nicht #available(iOS 26)), damit ältere SDKs
// ohne „unknown version“-Warnung durchlaufen.

enum LiquidGlassSupport {
  /// true ab iOS 26.0 (Runtime-Check, SDK-unabhängig).
  static var isIOS26OrNewer: Bool {
    ProcessInfo.processInfo.isOperatingSystemAtLeast(
      OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
    )
  }

  /// true, wenn das OS UIGlassEffect anbietet (iOS 26+ und Klasse vorhanden).
  static var isAvailable: Bool {
    guard isIOS26OrNewer else { return false }
    return NSClassFromString("UIGlassEffect") != nil
  }

  /// Erzeugt einen UIVisualEffect für Liquid Glass, oder nil unter iOS 26.
  static func makeEffect() -> UIVisualEffect? {
    guard isAvailable,
          let cls = NSClassFromString("UIGlassEffect") as? NSObject.Type else {
      return nil
    }
    // UIGlassEffect() — Default-Variante .regular
    let instance = cls.init()
    return instance as? UIVisualEffect
  }

  /// Baut eine UIVisualEffectView mit Liquid Glass (oder nil).
  static func makeEffectView(cornerRadius: CGFloat = 12) -> UIVisualEffectView? {
    guard let effect = makeEffect() else { return nil }
    let view = UIVisualEffectView(effect: effect)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isUserInteractionEnabled = false
    view.layer.cornerRadius = cornerRadius
    view.clipsToBounds = true
    return view
  }
}

// MARK: - Flutter Platform-View: Glass-Fläche für Karten / Tab-Bar / Chrome

/// viewType für UiKitView in Flutter.
let kLiquidGlassViewType = "fibu/liquid_glass_view"

final class LiquidGlassPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    LiquidGlassPlatformView(frame: frame, args: args as? [String: Any])
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, args: [String: Any]?) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    container.isOpaque = false
    container.clipsToBounds = true

    let radius = CGFloat((args?["cornerRadius"] as? NSNumber)?.doubleValue ?? 12)
    // 0 = volle Breite ohne Rundung (z. B. Tab-Bar-Streifen)
    container.layer.cornerRadius = radius

    super.init()

    if let glass = LiquidGlassSupport.makeEffectView(cornerRadius: radius) {
      glass.frame = container.bounds
      glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      container.addSubview(glass)
    } else {
      // Defensiv: sollte Flutter nur anfragen, wenn available.
      container.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.88)
    }
  }

  func view() -> UIView { container }
}

// MARK: - MethodChannel + Platform-View-Registrierung

final class LiquidGlassChannel: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: "fibu/liquid_glass", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(LiquidGlassSupport.isAvailable)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let factory = LiquidGlassPlatformViewFactory()
    registrar.register(factory, withId: kLiquidGlassViewType)
  }
}

import ExpoModulesCore

/**
 * iOS registration for the rclone bridge.
 *
 * The previous implementation attempted to launch a macOS command-line binary
 * with Foundation.Process. Process is unavailable on iOS and therefore made
 * every iOS native build fail. The production implementation must link
 * rclone's gomobile XCFramework and call librclone in-process. Until that
 * artifact is available, reject explicitly instead of shipping a silent no-op.
 */
public final class RcloneModule: Module {
  public func definition() -> ModuleDefinition {
    Name("Rclone")

    AsyncFunction("initialize") { (promise: Promise) in
      promise.reject(
        "RCLONE_NOT_IMPLEMENTED",
        "NotImplemented: RcloneModule.initialize requires an iOS librclone XCFramework"
      )
    }

    AsyncFunction("rpcCall") { (_: String, _: String, promise: Promise) in
      promise.reject(
        "RCLONE_NOT_IMPLEMENTED",
        "NotImplemented: RcloneModule.rpcCall requires an iOS librclone XCFramework"
      )
    }

    AsyncFunction("startOAuthFlow") { (_: String, promise: Promise) in
      promise.reject(
        "RCLONE_NOT_IMPLEMENTED",
        "NotImplemented: RcloneModule.startOAuthFlow requires an iOS librclone XCFramework"
      )
    }

    AsyncFunction("exchangeOAuthCode") { (_: String, _: String, promise: Promise) in
      promise.reject(
        "RCLONE_NOT_IMPLEMENTED",
        "NotImplemented: RcloneModule.exchangeOAuthCode requires an iOS librclone XCFramework"
      )
    }
  }
}

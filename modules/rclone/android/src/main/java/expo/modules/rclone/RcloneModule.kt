package expo.modules.rclone

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * Android registration for the rclone bridge.
 *
 * Executing a binary copied into writable app storage is blocked on modern
 * Android versions. The production implementation must link rclone's gomobile
 * AAR and call librclone in-process. Until that artifact is available, reject
 * explicitly instead of shipping a silent no-op or a broken process launcher.
 */
class RcloneModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("Rclone")

    AsyncFunction("initialize") {
      throw IllegalStateException(
        "NotImplemented: RcloneModule.initialize requires an Android librclone AAR"
      )
    }

    AsyncFunction("rpcCall") { _: String, _: String ->
      throw IllegalStateException(
        "NotImplemented: RcloneModule.rpcCall requires an Android librclone AAR"
      )
    }

    AsyncFunction("startOAuthFlow") { _: String ->
      throw IllegalStateException(
        "NotImplemented: RcloneModule.startOAuthFlow requires an Android librclone AAR"
      )
    }

    AsyncFunction("exchangeOAuthCode") { _: String, _: String ->
      throw IllegalStateException(
        "NotImplemented: RcloneModule.exchangeOAuthCode requires an Android librclone AAR"
      )
    }
  }
}

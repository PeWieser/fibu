package expo.modules.rclone

import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Expo Module that wraps the rclone binary bundled in assets/rclone/.
 *
 * Lifecycle:
 *   1. initialize() extracts rclone from assets to internal storage and starts
 *      `rclone rcd --rc-no-auth` on localhost:5572.
 *   2. rpcCall(method, paramsJson) forwards calls to the rcd HTTP API.
 *   3. OnDestroy terminates the rclone process.
 *
 * Pre-build setup (run once):
 *   chmod +x scripts/download-rclone.sh && ./scripts/download-rclone.sh
 */
class RcloneModule : Module() {
  private val tag = "RcloneModule"
  private val rcdPort = 5572
  private val scope = CoroutineScope(Dispatchers.IO)
  private var rcloneProcess: Process? = null
  private val initialized = AtomicBoolean(false)

  override fun definition() = ModuleDefinition {
    Name("Rclone")

    AsyncFunction("initialize") { promise: Promise ->
      scope.launch {
        try {
          if (initialized.compareAndSet(false, true)) {
            val binary = extractBinary()
            startRcd(binary)
          }
          promise.resolve(null)
        } catch (e: Exception) {
          initialized.set(false)
          Log.e(tag, "initialize failed", e)
          promise.reject("RCLONE_INIT", e.message ?: "init error", e)
        }
      }
    }

    AsyncFunction("rpcCall") { method: String, paramsJson: String, promise: Promise ->
      scope.launch {
        try {
          promise.resolve(httpPost(method, paramsJson))
        } catch (e: Exception) {
          Log.e(tag, "rpcCall [$method] failed", e)
          promise.reject("RCLONE_RPC", e.message ?: "rpc error", e)
        }
      }
    }

    AsyncFunction("startOAuthFlow") { provider: String, promise: Promise ->
      scope.launch {
        try {
          val res = httpPost("config/providers", "{}")
          val url = JSONObject(res).optString("oauthUrl", "https://rclone.org/")
          promise.resolve(url)
        } catch (e: Exception) {
          promise.reject("RCLONE_OAUTH", e.message ?: "oauth error", e)
        }
      }
    }

    AsyncFunction("exchangeOAuthCode") { provider: String, code: String, promise: Promise ->
      scope.launch {
        try {
          val params = JSONObject()
            .put("name", "oauth_tmp")
            .put("type", provider)
            .put("parameters", JSONObject().put("token", code))
          promise.resolve(httpPost("config/create", params.toString()))
        } catch (e: Exception) {
          promise.reject("RCLONE_OAUTH_EXCHANGE", e.message ?: "exchange error", e)
        }
      }
    }

    OnDestroy {
      rcloneProcess?.destroy()
      rcloneProcess = null
      initialized.set(false)
    }
  }

  private fun extractBinary(): File {
    val ctx = appContext.reactContext ?: error("No ReactContext")
    val dir = File(ctx.filesDir, "rclone").also { it.mkdirs() }
    File(dir, "config").mkdirs()
    val binary = File(dir, "rclone")
    val versionFile = File(dir, ".version")
    val assetVer = runCatching {
      ctx.assets.open("rclone/version.txt").bufferedReader().readText().trim()
    }.getOrDefault("unknown")
    val curVer = runCatching { versionFile.readText().trim() }.getOrDefault("")
    if (!binary.exists() || curVer != assetVer) {
      ctx.assets.open("rclone/rclone").use { src ->
        FileOutputStream(binary).use { dst -> src.copyTo(dst) }
      }
      binary.setExecutable(true, true)
      versionFile.writeText(assetVer)
      Log.i(tag, "rclone binary extracted v$assetVer")
    }
    val conf = File(dir, "config/rclone.conf")
    if (!conf.exists()) conf.createNewFile()
    return binary
  }

  private fun startRcd(binary: File) {
    val ctx = appContext.reactContext ?: error("No ReactContext")
    val conf = File(ctx.filesDir, "rclone/config/rclone.conf")
    rcloneProcess = ProcessBuilder(
      binary.absolutePath, "rcd",
      "--rc-addr", "127.0.0.1:$rcdPort",
      "--rc-no-auth",
      "--config", conf.absolutePath,
      "--log-level", "ERROR",
    ).redirectErrorStream(true).apply {
      environment()["HOME"] = binary.parentFile?.absolutePath ?: "/data/local/tmp"
      environment()["TMPDIR"] = ctx.cacheDir.absolutePath
    }.start()
    Thread.sleep(800)
    Log.i(tag, "rclone rcd started on :$rcdPort")
  }

  private fun httpPost(method: String, body: String): String {
    val conn = URL("http://127.0.0.1:$rcdPort/$method").openConnection() as HttpURLConnection
    return try {
      conn.requestMethod = "POST"
      conn.setRequestProperty("Content-Type", "application/json")
      conn.doOutput = true
      conn.connectTimeout = 10_000
      conn.readTimeout = 60_000
      conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
      val code = conn.responseCode
      val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
        .bufferedReader(Charsets.UTF_8).readText()
      if (code !in 200..299) throw RuntimeException("rcd $code: $text")
      text
    } finally {
      conn.disconnect()
    }
  }
}

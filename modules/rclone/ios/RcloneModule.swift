import ExpoModulesCore
import Foundation

/**
 * Expo Module that wraps the rclone binary bundled in the iOS app bundle.
 *
 * Lifecycle:
 *   1. initialize() extracts rclone from the bundle to the app's Documents directory,
 *      then starts `rclone rcd --rc-no-auth` on localhost:5572.
 *   2. rpcCall(method, paramsJson) proxies calls to the rcd HTTP API.
 *   3. OnDestroy terminates the rclone process.
 *
 * Pre-build setup (run once):
 *   chmod +x scripts/download-rclone.sh && ./scripts/download-rclone.sh
 */
public class RcloneModule: Module {
  private let rcdPort = 5572
  private var rcloneProcess: Process?
  private var initialized = false

  public func definition() -> ModuleDefinition {
    Name("Rclone")

    AsyncFunction("initialize") { (promise: Promise) in
      guard !self.initialized else {
        promise.resolve(nil)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let binary = try self.extractBinary()
          try self.startRcd(binary: binary)
          self.initialized = true
          promise.resolve(nil)
        } catch {
          promise.reject("RCLONE_INIT", error.localizedDescription)
        }
      }
    }

    AsyncFunction("rpcCall") { (method: String, paramsJson: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try self.httpPost(method: method, body: paramsJson)
          promise.resolve(result)
        } catch {
          promise.reject("RCLONE_RPC", error.localizedDescription)
        }
      }
    }

    AsyncFunction("startOAuthFlow") { (provider: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try self.httpPost(method: "config/providers", body: "{}")
          if let data = result.data(using: .utf8),
             let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let url = json["oauthUrl"] as? String {
            promise.resolve(url)
          } else {
            promise.resolve("https://rclone.org/")
          }
        } catch {
          promise.reject("RCLONE_OAUTH", error.localizedDescription)
        }
      }
    }

    AsyncFunction("exchangeOAuthCode") { (provider: String, code: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let params: [String: Any] = [
            "name": "oauth_tmp",
            "type": provider,
            "parameters": ["token": code],
          ]
          let body = try JSONSerialization.data(withJSONObject: params)
          let result = try self.httpPost(method: "config/create", body: String(data: body, encoding: .utf8) ?? "{}")
          promise.resolve(result)
        } catch {
          promise.reject("RCLONE_OAUTH_EXCHANGE", error.localizedDescription)
        }
      }
    }

    OnDestroy {
      self.rcloneProcess?.terminate()
      self.rcloneProcess = nil
      self.initialized = false
    }
  }

  // MARK: - Private helpers

  private func extractBinary() throws -> URL {
    let fm = FileManager.default
    let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let dir = docs.appendingPathComponent("rclone", isDirectory: true)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let confDir = dir.appendingPathComponent("config", isDirectory: true)
    try fm.createDirectory(at: confDir, withIntermediateDirectories: true)

    let binary = dir.appendingPathComponent("rclone")
    let versionDst = dir.appendingPathComponent(".version")

    guard let bundleBinary = Bundle.main.url(forResource: "rclone", withExtension: nil, subdirectory: "rclone"),
          let bundleVersion = Bundle.main.url(forResource: "version", withExtension: "txt", subdirectory: "rclone")
    else {
      throw NSError(domain: "RcloneModule", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "rclone binary not found in bundle. Run scripts/download-rclone.sh first."])
    }

    let assetVer = (try? String(contentsOf: bundleVersion, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    let curVer = (try? String(contentsOf: versionDst, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if !fm.fileExists(atPath: binary.path) || curVer != assetVer {
      if fm.fileExists(atPath: binary.path) { try fm.removeItem(at: binary) }
      try fm.copyItem(at: bundleBinary, to: binary)
      try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
      try assetVer.write(to: versionDst, atomically: true, encoding: .utf8)
    }

    let conf = confDir.appendingPathComponent("rclone.conf")
    if !fm.fileExists(atPath: conf.path) {
      fm.createFile(atPath: conf.path, contents: nil)
    }

    return binary
  }

  private func startRcd(binary: URL) throws {
    let fm = FileManager.default
    let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let conf = docs.appendingPathComponent("rclone/config/rclone.conf")
    let tmp = fm.temporaryDirectory

    let process = Process()
    process.executableURL = binary
    process.arguments = [
      "rcd",
      "--rc-addr", "127.0.0.1:\(rcdPort)",
      "--rc-no-auth",
      "--config", conf.path,
      "--log-level", "ERROR",
    ]
    process.environment = [
      "HOME": docs.path,
      "TMPDIR": tmp.path,
    ]
    try process.run()
    Thread.sleep(forTimeInterval: 0.8)
    rcloneProcess = process
  }

  private func httpPost(method: String, body: String) throws -> String {
    guard let url = URL(string: "http://127.0.0.1:\(rcdPort)/\(method)") else {
      throw NSError(domain: "RcloneModule", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }
    var request = URLRequest(url: url, timeoutInterval: 60)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body.data(using: .utf8)

    var responseData: Data?
    var responseError: Error?
    var statusCode = 0

    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, error in
      responseData = data
      responseError = error
      statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      semaphore.signal()
    }.resume()
    semaphore.wait()

    if let error = responseError { throw error }
    guard let data = responseData, let text = String(data: data, encoding: .utf8) else {
      throw NSError(domain: "RcloneModule", code: 3, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
    }
    guard (200...299).contains(statusCode) else {
      throw NSError(domain: "RcloneModule", code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "rcd \(statusCode): \(text)"])
    }
    return text
  }
}

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Geteilte Daten (App Group ↔ App ↔ Widget)
//
// Die Haupt-App pusht den Sync-Zustand nach jedem Run via MethodChannel
// „fibu/widget" in UserDefaults(suiteName: <App-Group>) als JSON.
// Das Widget liest ihn einfach aus — synchron, billig, ohne App-Start.
//
// WICHTIG: Die App-Group-ID wird zur Laufzeit aus dem Signierprofil
// (embedded.mobileprovision) gelesen — Sideload-Tools (iLoader, AltStore,
// Sideloadly …) benennen App-Groups beim Signieren häufig um. Die Haupt-App
// löst die ID identisch auf (siehe AppDelegate.swift).

private let fallbackAppGroupID = "group.com.example.fibu"
private let statusKey = "fibu_widget_status"

private func resolveAppGroupID() -> String {
  guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
        let data = FileManager.default.contents(atPath: path),
        let content = String(data: data, encoding: .isoLatin1),
        let start = content.range(of: "<?xml"),
        let end = content.range(of: "</plist>") else { return fallbackAppGroupID }
  let plistString = String(content[start.lowerBound..<end.upperBound])
  guard let plistData = plistString.data(using: .isoLatin1),
        let plist = try? PropertyListSerialization.propertyList(
          from: plistData, options: [], format: nil) as? [String: Any],
        let entitlements = plist["Entitlements"] as? [String: Any],
        let groups = entitlements["com.apple.security.application-groups"] as? [String],
        let first = groups.first, !first.isEmpty else { return fallbackAppGroupID }
  return first
}

private let appGroupID: String = resolveAppGroupID()

struct SharedTask: Codable {
  let name: String
  let status: String          // ok | pending | never | error
  let lastSyncIso: String
}

struct SharedStatus: Codable {
  let lastSyncIso: String
  let needsSync: Bool
  let lastError: String
  let activeTaskCount: Int
  let tasks: [SharedTask]
}

// MARK: - Timeline Entry

struct FibuEntry: TimelineEntry {
  let date: Date
  let status: SharedStatus?
}

// MARK: - Provider

final class FibuProvider: TimelineProvider {
  func placeholder(in context: Context) -> FibuEntry {
    FibuEntry(date: Date(), status: nil)
  }

  func getSnapshot(in context: Context,
                   completion: @escaping (FibuEntry) -> Void) {
    completion(FibuEntry(date: Date(), status: Self.loadStatus()))
  }

  func getTimeline(in context: Context,
                   completion: @escaping (Timeline<FibuEntry>) -> Void) {
    let entry = FibuEntry(date: Date(), status: Self.loadStatus())
    // Widget aktualisiert sich spätestens alle 30 Minuten selbst; jede App-
    // Änderung stößt zusätzlich reloadAllTimelines() an.
    let next = Date().addingTimeInterval(30 * 60)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }

  static func loadStatus() -> SharedStatus? {
    guard let defaults = UserDefaults(suiteName: appGroupID),
          let json = defaults.string(forKey: statusKey),
          let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(SharedStatus.self, from: data)
  }

  static func formatSyncTime(_ iso: String) -> String {
    guard !iso.isEmpty else { return "—" }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let parsed = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    guard let date = parsed else { return "—" }
    return date.formatted(.dateTime.day().month().hour().minute())
  }
}

// MARK: - Liquid Glass (Runtime, SDK-unabhängig)
//
// UIGlassEffect wird per NSClassFromString geladen — kompiliert auf jedem
// Xcode, aktiv nur ab iOS 26. Unter iOS 26: systemBackground wie bisher.

private var isIOS26OrNewer: Bool {
  ProcessInfo.processInfo.isOperatingSystemAtLeast(
    OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
  )
}

/// UIView mit echtem UIGlassEffect (iOS 26+) oder systemBackground.
private final class FibuGlassUIView: UIView {
  private let effectView: UIVisualEffectView?

  override init(frame: CGRect) {
    if isIOS26OrNewer,
       let cls = NSClassFromString("UIGlassEffect") as? NSObject.Type,
       let effect = cls.init() as? UIVisualEffect {
      let ev = UIVisualEffectView(effect: effect)
      ev.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      effectView = ev
    } else {
      effectView = nil
    }
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    if let effectView {
      effectView.frame = bounds
      addSubview(effectView)
    } else {
      backgroundColor = .systemBackground
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// SwiftUI-Bridge zum nativen Glass-UIView.
private struct FibuNativeGlassView: UIViewRepresentable {
  func makeUIView(context: Context) -> FibuGlassUIView {
    FibuGlassUIView(frame: .zero)
  }

  func updateUIView(_ uiView: FibuGlassUIView, context: Context) {}
}

// MARK: - Hintergrund
//
// iOS 17+: containerBackground (Pflicht, sonst Platzhalter).
// iOS 26+: darin natives Liquid Glass.
// iOS 15–16: background.

extension View {
  @ViewBuilder
  func fibuWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) {
        FibuWidgetBackdrop()
      }
    } else {
      self.background(FibuWidgetBackdrop())
    }
  }
}

struct FibuWidgetBackdrop: View {
  var body: some View {
    if isIOS26OrNewer {
      FibuNativeGlassView()
    } else {
      Color(.systemBackground)
    }
  }
}

// MARK: - Darstellung

private let accent = Color(red: 0.0, green: 0.478, blue: 1.0)      // App-Akzent
private let okColor = Color(red: 0.18, green: 0.80, blue: 0.44)    // Grün
private let pendingColor = Color(red: 1.0, green: 0.62, blue: 0.04)// Orange
private let errorColor = Color(red: 1.0, green: 0.27, blue: 0.23)  // Rot
private let calmColor = Color(white: 0.55)                         // Grau

private func taskColor(_ status: String) -> Color {
  switch status {
  case "ok": return okColor
  case "pending": return pendingColor
  case "error": return errorColor
  default: return calmColor
  }
}

private enum FibuText {
  static var isGerman: Bool {
    (Locale.preferredLanguages.first ?? "de").hasPrefix("de")
  }
  static var upToDate: String { isGerman ? "Aktuell" : "Up to date" }
  static var needsSync: String { isGerman ? "Sync fällig" : "Sync needed" }
  static var neverSynced: String { isGerman ? "Noch nie gesynct" : "Never synced" }
  static var noTasks: String { isGerman ? "Noch keine Backup-Aufgaben" : "No backup tasks yet" }
  static var lastSync: String { isGerman ? "Zuletzt" : "Last sync" }
  static var tasksLabel: String { isGerman ? "Aufgaben" : "Tasks" }
}

struct FibuWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: FibuEntry

  var body: some View {
    Group {
      switch family {
      case .systemLarge:
        _FibuLarge(entry: entry)
      case .systemMedium:
        _FibuMedium(entry: entry)
      default:
        _FibuSmall(entry: entry)
      }
    }
    .fibuWidgetBackground()
    .widgetURL(URL(string: "fibu://open"))
  }
}

// MARK: - Klein (Home-screen, rundes Icon)

private struct _FibuSmall: View {
  let entry: FibuEntry

  var body: some View {
    let state = entry.status
    let color: Color = {
      guard let s = state, s.activeTaskCount > 0 else { return calmColor }
      if !s.lastError.isEmpty { return errorColor }
      return s.needsSync ? pendingColor : okColor
    }()
    let title: String = {
      // Keine Aufgaben = kein „Aktuell“-Versprechen — ehrlicher Leerzustand.
      guard let s = state, s.activeTaskCount > 0 else { return FibuText.noTasks }
      if !s.lastError.isEmpty { return s.lastError }
      return s.needsSync ? FibuText.needsSync : FibuText.upToDate
    }()

    VStack(spacing: 12) {
      _StatusGlyph(color: color, size: 62, iconSize: 25)
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(color)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
      Text("\(FibuText.lastSync): \(state.map { FibuProvider.formatSyncTime($0.lastSyncIso) } ?? "—")")
        .font(.system(size: 12))
        .foregroundColor(Color.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Status-Icon: ab iOS 26 Glass-Kreis (UIKit), davor getönter Kreis.
private struct _StatusGlyph: View {
  let color: Color
  let size: CGFloat
  let iconSize: CGFloat

  var body: some View {
    ZStack {
      if isIOS26OrNewer {
        // Nativer Glass-Kreis hinter dem Icon.
        FibuNativeGlassView()
          .frame(width: size, height: size)
          .clipShape(Circle())
          .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 1))
      } else {
        Circle().fill(color.opacity(0.16)).frame(width: size, height: size)
      }
      Image(systemName: "arrow.triangle.2.circlepath")
        .font(.system(size: iconSize, weight: .semibold))
        .foregroundColor(color)
    }
  }
}

// MARK: - Mittel

private struct _FibuMedium: View {
  let entry: FibuEntry

  var body: some View {
    let state = entry.status
    let tasks = Array((state?.tasks ?? []).prefix(3))

    HStack(spacing: 14) {
      _FibuSmall(entry: entry)
        .frame(width: 108)

      VStack(alignment: .leading, spacing: 9) {
        if tasks.isEmpty {
          Text(FibuText.noTasks)
            .font(.system(size: 14))
            .foregroundColor(Color.secondary)
        } else {
          ForEach(tasks, id: \.name) { t in
            HStack(spacing: 8) {
              Circle()
                .fill(taskColor(t.status))
                .frame(width: 8, height: 8)
              Text(t.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.primary)
                .lineLimit(1)
              Spacer()
              Text(FibuProvider.formatSyncTime(t.lastSyncIso))
                .font(.system(size: 12))
                .foregroundColor(Color.secondary)
                .lineLimit(1)
            }
          }
        }
        Spacer()
        Text("\(state?.activeTaskCount ?? 0) \(FibuText.tasksLabel)")
          .font(.system(size: 12))
          .foregroundColor(Color.secondary)
      }
    }
    .padding(6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Groß

private struct _FibuLarge: View {
  let entry: FibuEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      __FibuLargeHeader(entry: entry)
      Divider().padding(.vertical, 2)
      if (entry.status?.tasks.isEmpty ?? true) {
        Text(FibuText.noTasks)
          .font(.system(size: 15))
          .foregroundColor(Color.secondary)
      } else {
        ForEach(Array((entry.status?.tasks ?? []).prefix(6)), id: \.name) { t in
          HStack(spacing: 10) {
            Circle().fill(taskColor(t.status)).frame(width: 9, height: 9)
            Text(t.name)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(Color.primary)
              .lineLimit(1)
            Spacer()
            Text(FibuProvider.formatSyncTime(t.lastSyncIso))
              .font(.system(size: 12))
              .foregroundColor(Color.secondary)
              .lineLimit(1)
          }
        }
      }
      Spacer()
    }
    .padding(8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct __FibuLargeHeader: View {
  let entry: FibuEntry

  var body: some View {
    let s = entry.status
    let color: Color = {
      guard let s = s, s.activeTaskCount > 0 else { return calmColor }
      if !s.lastError.isEmpty { return errorColor }
      return s.needsSync ? pendingColor : okColor
    }()
    let title: String = {
      guard let s = s, s.activeTaskCount > 0 else { return FibuText.noTasks }
      if !s.lastError.isEmpty { return s.lastError }
      return s.needsSync ? FibuText.needsSync : FibuText.upToDate
    }()

    HStack(spacing: 12) {
      _StatusGlyph(color: color, size: 52, iconSize: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(color)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        Text("\(FibuText.lastSync): \(s.map { FibuProvider.formatSyncTime($0.lastSyncIso) } ?? "—")")
          .font(.system(size: 12))
          .foregroundColor(Color.secondary)
          .lineLimit(1)
      }
      Spacer()
    }
  }
}

// MARK: - Widget

@main
struct FibuWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
        kind: "com.example.fibu.widget",
        provider: FibuProvider()
    ) { entry in
      FibuWidgetEntryView(entry: entry)
        .widgetURL(URL(string: "fibu://open"))
    }
    .configurationDisplayName("Fibu Backup")
    .description(FibuText.isGerman
        ? "Zeigt den aktuellen Stand deiner Backup-Aufgaben – vom Homescreen aus."
        : "Shows the status of your backup jobs – right from your home screen.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

import WidgetKit
import SwiftUI

// MARK: - Geteilte Daten (App Group ↔ App ↔ Widget)
//
// Die Haupt-App pusht den Sync-Zustand nach jedem Run via MethodChannel
// „fibu/widget" in UserDefaults(suiteName: group.com.example.fibu) als JSON.
// Das Widget liest ihn einfach aus — synchron, billig, ohne App-Start.

private let appGroupID = "group.com.example.fibu"
private let statusKey = "fibu_widget_status"

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
    .widgetURL(URL(string: "fibu://open"))
  }
}

// MARK: - Klein (Home-screen, rundes Icon)

private struct _FibuSmall: View {
  let entry: FibuEntry

  var body: some View {
    let state = entry.status
    let color: Color = {
      guard let s = state else { return calmColor }
      if !s.lastError.isEmpty { return errorColor }
      return s.needsSync ? pendingColor : okColor
    }()
    let title: String = {
      guard let s = state else { return FibuText.noTasks }
      if !s.lastError.isEmpty { return s.lastError }
      return s.needsSync ? FibuText.needsSync : FibuText.upToDate
    }()

    VStack(spacing: 10) {
      ZStack {
        Circle().fill(color.opacity(0.16)).frame(width: 56, height: 56)
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 22, weight: .semibold))
          .foregroundColor(color)
      }
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(color)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
      Text("\(FibuText.lastSync): \(state.map { FibuProvider.formatSyncTime($0.lastSyncIso) } ?? "—")")
        .font(.system(size: 11))
        .foregroundColor(Color.secondary)
        .lineLimit(1)
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
  }
}

// MARK: - Mittel

private struct _FibuMedium: View {
  let entry: FibuEntry

  var body: some View {
    let state = entry.status
    let tasks = Array((state?.tasks ?? []).prefix(3))

    HStack(spacing: 16) {
      _FibuSmall(entry: entry)
        .frame(width: 95)

      VStack(alignment: .leading, spacing: 6) {
        if tasks.isEmpty {
          Text(FibuText.noTasks)
            .font(.system(size: 12))
            .foregroundColor(Color.secondary)
        } else {
          ForEach(tasks, id: \.name) { t in
            HStack(spacing: 6) {
              Circle()
                .fill(taskColor(t.status))
                .frame(width: 7, height: 7)
              Text(t.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.primary)
                .lineLimit(1)
              Spacer()
              Text(FibuProvider.formatSyncTime(t.lastSyncIso))
                .font(.system(size: 11))
                .foregroundColor(Color.secondary)
            }
          }
        }
        Spacer()
        Text("\(state?.activeTaskCount ?? 0) \(FibuText.tasksLabel)")
          .font(.system(size: 11))
          .foregroundColor(Color.secondary)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
  }
}

// MARK: - Groß

private struct _FibuLarge: View {
  let entry: FibuEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      __FibuLargeHeader(entry: entry)
      Divider().padding(.vertical, 2)
      if (entry.status?.tasks.isEmpty ?? true) {
        Text(FibuText.noTasks)
          .font(.system(size: 13))
          .foregroundColor(Color.secondary)
      } else {
        ForEach(Array((entry.status?.tasks ?? []).prefix(6)), id: \.name) { t in
          HStack {
            Circle().fill(taskColor(t.status)).frame(width: 8, height: 8)
            Text(t.name)
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(Color.primary)
              .lineLimit(1)
            Spacer()
            Text(FibuProvider.formatSyncTime(t.lastSyncIso))
              .font(.system(size: 11))
              .foregroundColor(Color.secondary)
          }
        }
      }
      Spacer()
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
  }
}

private struct __FibuLargeHeader: View {
  let entry: FibuEntry

  var body: some View {
    let s = entry.status
    let color: Color = {
      guard let s = s else { return calmColor }
      if !s.lastError.isEmpty { return errorColor }
      return s.needsSync ? pendingColor : okColor
    }()
    let title: String = {
      guard let s = s else { return FibuText.noTasks }
      if !s.lastError.isEmpty { return s.lastError }
      return s.needsSync ? FibuText.needsSync : FibuText.upToDate
    }()

    HStack(spacing: 12) {
      ZStack {
        Circle().fill(color.opacity(0.16)).frame(width: 46, height: 46)
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(color)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
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

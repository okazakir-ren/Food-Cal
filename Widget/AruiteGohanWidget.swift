import SwiftUI
import WidgetKit

struct GohanEntry: TimelineEntry {
    let date: Date
    /// nil なら初回設定が終わっていない。
    let snapshot: DaySnapshot?
}

struct GohanProvider: TimelineProvider {
    private static let sample = DaySnapshot(dayStart: .now, steps: 7150, weightKg: 60, lastReadAt: .now)
    private static let reloadInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> GohanEntry {
        GohanEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GohanEntry) -> Void) {
        let store = SharedStore()
        let snapshot = context.isPreview ? Self.sample : (store.snapshot ?? Self.sample)
        completion(GohanEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GohanEntry>) -> Void) {
        Task {
            let now = Date.now
            let store = SharedStore()
            var entries: [GohanEntry]
            if store.isSetupComplete,
               let snapshot = await TodayRefresher.refresh(source: .widget, action: "timeline", now: now) {
                entries = [GohanEntry(date: now, snapshot: snapshot)]
                // 読み直しが間に合わなくても、0時には0歩に戻す。
                if let nextDay = SnapshotPolicy.startOfNextDay(from: snapshot) {
                    entries.append(GohanEntry(date: nextDay.dayStart, snapshot: nextDay))
                }
            } else {
                entries = [GohanEntry(date: now, snapshot: nil)]
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.reloadInterval))))
        }
    }
}

struct GohanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GohanEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium:
                    MediumGohanView(display: snapshot.display)
                default:
                    SmallGohanView(display: snapshot.display)
                }
            } else {
                SetupNeededView()
            }
        }
        .containerBackground(for: .widget) { Theme.background }
    }
}

struct AruiteGohanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AruiteGohanWidget", provider: GohanProvider()) { entry in
            GohanWidgetView(entry: entry)
        }
        .configurationDisplayName("あるいてごはん")
        .description("歩いた分のカロリーを、食べもので見せます。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct AruiteGohanWidgetBundle: WidgetBundle {
    var body: some Widget {
        AruiteGohanWidget()
    }
}

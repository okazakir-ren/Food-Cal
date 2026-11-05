import SwiftUI
import WidgetKit

struct WatchGohanEntry: TimelineEntry {
    let date: Date
    /// nil ならまだiPhoneから体重を受け取っていない。
    let snapshot: DaySnapshot?
}

struct WatchGohanProvider: TimelineProvider {
    private static let sample = DaySnapshot(dayStart: .now, steps: 7150, weightKg: 60, lastReadAt: .now)
    /// 実際の更新間隔はwatchOSが決める。
    private static let reloadInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> WatchGohanEntry {
        WatchGohanEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchGohanEntry) -> Void) {
        let snapshot = context.isPreview ? Self.sample : (SharedStore().snapshot ?? Self.sample)
        completion(WatchGohanEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchGohanEntry>) -> Void) {
        Task {
            let now = Date.now
            var entries = [WatchGohanEntry(date: now, snapshot: nil)]
            if let snapshot = await TodayRefresher.refresh(source: .widget, action: "watchTimeline", now: now) {
                entries = [WatchGohanEntry(date: now, snapshot: snapshot)]
                // 読み直しが間に合わなくても、0時には0歩に戻す。
                if let nextDay = SnapshotPolicy.startOfNextDay(from: snapshot) {
                    entries.append(WatchGohanEntry(date: nextDay.dayStart, snapshot: nextDay))
                }
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.reloadInterval))))
        }
    }
}

struct WatchGohanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchGohanEntry

    /// 体重を受け取るまでは0kcalと分かるお茶を出す。
    private var display: GohanDisplay {
        entry.snapshot?.display ?? GohanDisplay(steps: 0, kcal: 0)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                if entry.snapshot == nil {
                    Text("iPhoneでアプリを開いてください").font(.caption2)
                } else {
                    GohanRectangularComplication(display: display)
                }
            case .accessoryInline:
                if entry.snapshot == nil {
                    Text("iPhoneで設定")
                } else {
                    GohanInlineComplication(display: display)
                }
            case .accessoryCorner:
                GohanCornerComplication(display: display)
            default:
                GohanCircularComplication(display: display)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct AruiteGohanWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AruiteGohanWatchWidget", provider: WatchGohanProvider()) { entry in
            WatchGohanWidgetView(entry: entry)
        }
        .configurationDisplayName("あるいてごはん")
        .description("歩いた分のカロリーを、食べもので見せます。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct AruiteGohanWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        AruiteGohanWatchWidget()
    }
}

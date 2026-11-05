import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class WatchModel {
    private(set) var snapshot: DaySnapshot?
    private(set) var needsHealthAuthorization = false

    private let store = SharedStore()
    private let reader = HealthReader()

    init() {
        snapshot = store.snapshot
        WatchSnapshotReceiver.shared.onChange = { [weak self] in
            Task { @MainActor in self?.snapshot = SharedStore().snapshot }
        }
    }

    /// iPhoneに問い合わせ、Watch自身の歩数も読む。多いほうが残る。
    func refresh() async {
        WatchSnapshotReceiver.shared.request()
        needsHealthAuthorization = await reader.needsAuthorizationRequest()
        snapshot = await TodayRefresher.refresh(source: .app, action: "watchForeground") ?? store.snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    func requestHealthAuthorization() async {
        try? await reader.requestAuthorization()
        await refresh()
    }
}

struct WatchRootView: View {
    @Bindable var model: WatchModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// 開きっぱなしでも古くならないよう、画面が点いている間は取り直す。
    private static let refreshInterval: Duration = .seconds(180)

    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if WatchDebugBootstrap.showsComplications {
            WatchComplicationGallery()
        } else {
            main
        }
        #else
        main
        #endif
    }

    private var main: some View {
        ScrollView {
            if let snapshot = model.snapshot {
                content(snapshot)
            } else {
                setupNeeded
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    private func content(_ snapshot: DaySnapshot) -> some View {
        let display = snapshot.display
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10)
                .fill(WatchTheme.paper)
                .frame(width: 64, height: 64)
                .overlay { WatchPixelFood(tier: display.tier, size: 56) }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(display.kcalText)
                    .font(WatchTheme.dot(30))
                    .foregroundStyle(WatchTheme.accent)
                Text("kcal")
                    .font(WatchTheme.dot(12))
                    .foregroundStyle(WatchTheme.sub)
            }

            WatchSegmentGauge(filled: display.filledSegments, height: 6)

            Text("\(display.stepsText)歩・\(display.tier.name)")
                .font(WatchTheme.dot(13))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(display.nextText)
                .font(WatchTheme.dot(12))
                .foregroundStyle(WatchTheme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if isLuminanceReduced || snapshot.lastReadAt != nil {
                Text(updatedText(snapshot))
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.sub)
            }

            if model.needsHealthAuthorization {
                Button("Watchの歩数も使う") {
                    Task { await model.requestHealthAuthorization() }
                }
                .font(.caption2)
            }
        }
        .padding(.horizontal, 4)
    }

    private var setupNeeded: some View {
        VStack(spacing: 8) {
            WatchPixelFood(tier: GohanTier.all[0], size: 48)
            Text("iPhoneでアプリを開いてください")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }

    private func updatedText(_ snapshot: DaySnapshot) -> String {
        guard let lastReadAt = snapshot.lastReadAt else { return "まだ読めていません" }
        return "\(lastReadAt.formatted(date: .omitted, time: .shortened))時点"
    }
}

#if DEBUG && targetEnvironment(simulator)
/// シミュレータ専用。例: -fakeSteps 7150 -fakeWeight 60 -complications
enum WatchDebugBootstrap {
    static var showsComplications: Bool { UserDefaults.standard.bool(forKey: "complications") }

    static func apply() {
        let store = SharedStore()
        if UserDefaults.standard.object(forKey: "fakeSteps") != nil {
            store.debugFakeSteps = UserDefaults.standard.integer(forKey: "fakeSteps")
        }
        if UserDefaults.standard.object(forKey: "fakeWeight") != nil {
            store.weightKg = UserDefaults.standard.double(forKey: "fakeWeight")
        }
    }
}

struct WatchComplicationGallery: View {
    private let display = GohanDisplay(steps: 7150, kcal: 286)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    GohanCircularComplication(display: display).frame(width: 50, height: 50)
                    GohanCornerComplication(display: display).frame(width: 40, height: 40)
                }
                GohanRectangularComplication(display: display).frame(width: 160, height: 50)
                GohanInlineComplication(display: display).font(.footnote)
            }
        }
    }
}
#endif

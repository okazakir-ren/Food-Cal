import HealthKit
import SwiftUI
import WidgetKit

@main
struct AruiteGohanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        DebugBootstrap.apply()
        #endif
        DiagnosticLog.trim()
        WatchSnapshotSender.shared.activate()
        // バックグラウンドで起こされたときも受け取れるよう、起動の最初に登録する。
        BackgroundDelivery.shared.startIfAuthorized()
        return true
    }
}

/// 歩数が増えたら本体を起こしてもらい、値を保存してウィジェットの更新を頼む。
@MainActor
final class BackgroundDelivery {
    static let shared = BackgroundDelivery()

    private let store = HKHealthStore()
    private var isStarted = false

    /// 起動時と、初回の許可の直後に呼ぶ。許可の直後にも呼ばないと、次の起動まで監視が始まらない。
    func startIfAuthorized() {
        guard !isStarted, HKHealthStore.isHealthDataAvailable(), SharedStore().isAuthorizationRequested else { return }
        isStarted = true
        Self.register(store: store)
    }

    /// HealthKitのコールバックは別のキューで呼ばれるので、メインアクターの外で組み立てる。
    private nonisolated static func register(store: HKHealthStore) {
        let type = HKQuantityType(.stepCount)

        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            if let error {
                let nsError = error as NSError
                DiagnosticLog.append(.init(
                    at: .now, source: .background, action: "observer",
                    steps: nil, error: "\(nsError.domain)/\(nsError.code)"
                ))
                completion()
                return
            }
            Task {
                if let snapshot = await TodayRefresher.refresh(source: .background, action: "observer") {
                    WatchSnapshotSender.shared.send(snapshot)
                }
                WidgetCenter.shared.reloadAllTimelines()
                completion()
            }
        }
        store.execute(query)

        store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, error in
            guard let error else { return }
            let nsError = error as NSError
            DiagnosticLog.append(.init(
                at: .now, source: .background, action: "enableBackgroundDelivery",
                steps: nil, error: "\(nsError.domain)/\(nsError.code)"
            ))
        }
    }
}

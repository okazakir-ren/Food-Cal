import SwiftUI
import WatchConnectivity

@main
struct AruiteGohanWatchApp: App {
    @State private var model = WatchModel()

    init() {
        #if DEBUG && targetEnvironment(simulator)
        WatchDebugBootstrap.apply()
        #endif
        // 裏で起こされたときも受け取れるよう、起動の最初に有効にする。
        WatchSnapshotReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: model)
                .preferredColorScheme(.dark)
        }
        .backgroundTask(.watchConnectivity) {
            // 届いている内容を受け取り終えるまで待つ（最大5秒）。
            for _ in 0..<10 where WCSession.default.hasContentPending {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

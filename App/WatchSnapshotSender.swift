import Foundation
import WatchConnectivity

/// 今日の値をWatchへ渡す。Watchが開いたときの問い合わせには、値を読み直して答える。
final class WatchSnapshotSender: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSnapshotSender()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 値を読み直すたびに呼ぶ。Watchが眠っていても、起きたときに最新の値が届く。
    func send(_ snapshot: DaySnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        let payload = WatchSyncPayload.encode(snapshot)
        do {
            try session.updateApplicationContext(payload)
            // 文字盤に置かれていれば、Watch側のコンプリケーションを更新してもらう（回数に上限がある）。
            if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
                session.transferCurrentComplicationUserInfo(payload)
            }
        } catch {
            let nsError = error as NSError
            DiagnosticLog.append(.init(
                at: .now, source: .app, action: "watchSend",
                steps: snapshot.steps, error: "\(nsError.domain)/\(nsError.code)"
            ))
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task {
            let snapshot = await TodayRefresher.refresh(source: .background, action: "watchRequest")
            replyHandler(snapshot.map(WatchSyncPayload.encode) ?? [:])
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let snapshot = SharedStore().snapshot { send(snapshot) }
    }

    /// Watchアプリを入れた直後にも値を渡す。
    func sessionWatchStateDidChange(_ session: WCSession) {
        if let snapshot = SharedStore().snapshot { send(snapshot) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Watchを切り替えたときは、新しいWatch用に有効にし直す。
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

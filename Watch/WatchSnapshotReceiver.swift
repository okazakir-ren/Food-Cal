import Foundation
import WatchConnectivity
import WidgetKit

/// iPhoneから今日の値を受け取り、Watchの保存先に合わせて入れる。
final class WatchSnapshotReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSnapshotReceiver()

    /// 保存した内容が変わったときに呼ばれる。
    var onChange: (@Sendable () -> Void)?

    func activate() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// iPhoneに今の値を問い合わせる。届かないときは手元の値を使い続ける。
    func request() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchSyncPayload.requestKey: true], replyHandler: { [weak self] reply in
            self?.apply(reply)
        }, errorHandler: { _ in })
    }

    private func apply(_ message: [String: Any]) {
        guard let remote = WatchSyncPayload.decode(message) else { return }
        let store = SharedStore()
        store.weightKg = remote.weightKg
        store.snapshot = SnapshotPolicy.merge(local: store.snapshot, remote: remote)
        WidgetCenter.shared.reloadAllTimelines()
        onChange?()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
        request()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        request()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    /// `transferCurrentComplicationUserInfo` はここに届く。
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }
}

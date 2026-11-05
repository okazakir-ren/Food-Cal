import Foundation

/// iPhoneとWatchの間で受け渡す内容。WatchConnectivityの辞書に入れられる形にする。
enum WatchSyncPayload {
    private static let snapshotKey = "snapshot"
    static let requestKey = "requestSnapshot"

    static func encode(_ snapshot: DaySnapshot) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(snapshot) else { return [:] }
        return [snapshotKey: data]
    }

    static func decode(_ message: [String: Any]) -> DaySnapshot? {
        guard let data = message[snapshotKey] as? Data else { return nil }
        return try? JSONDecoder().decode(DaySnapshot.self, from: data)
    }
}

extension SnapshotPolicy {
    /// Watchの値とiPhoneから届いた値を合わせる。
    /// - 同じ日なら歩数の多いほう（iPhoneの値は複数の端末を合算済みで、Watchは自分の分だけのことがある）
    /// - 届いた値が古い日なら捨てる
    /// - 体重はiPhoneの値を使う
    static func merge(local: DaySnapshot?, remote: DaySnapshot) -> DaySnapshot {
        guard let local else { return remote }
        if remote.dayStart < local.dayStart { return local }
        if remote.dayStart > local.dayStart { return remote }
        return DaySnapshot(
            dayStart: local.dayStart,
            steps: max(local.steps, remote.steps),
            weightKg: remote.weightKg,
            lastReadAt: [local.lastReadAt, remote.lastReadAt].compactMap { $0 }.max()
        )
    }
}

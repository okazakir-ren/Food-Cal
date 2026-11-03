import Foundation

/// App Group で共有する、その日の表示用の値。
struct DaySnapshot: Codable, Equatable, Sendable {
    var dayStart: Date
    var steps: Int
    var weightKg: Double
    /// 最後に歩数を読めた時刻。一度も読めていなければ nil。
    var lastReadAt: Date?

    var kcal: Int { CalorieCalculator.kcal(steps: steps, weightKg: weightKg) }
    var display: GohanDisplay { GohanDisplay(steps: steps, kcal: kcal) }
}

enum SnapshotPolicy {
    /// 読み取り結果と前回値から、表示する値を決める。
    /// - 同じ日の表示は下げない（0や読み取り失敗で前回値を消さない）
    /// - 日付が変わっていたら0から始める
    static func resolve(
        cached: DaySnapshot?,
        readSteps: Int?,
        weightKg: Double,
        now: Date,
        calendar: Calendar = .current
    ) -> DaySnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let sameDay = cached?.dayStart == dayStart
        let baseSteps = sameDay ? (cached?.steps ?? 0) : 0
        return DaySnapshot(
            dayStart: dayStart,
            steps: max(baseSteps, readSteps ?? 0),
            weightKg: weightKg,
            lastReadAt: readSteps != nil ? now : (sameDay ? cached?.lastReadAt : nil)
        )
    }

    /// その日の0時以降に表示する、0歩の値。
    static func startOfNextDay(from snapshot: DaySnapshot, calendar: Calendar = .current) -> DaySnapshot? {
        guard let next = calendar.date(byAdding: .day, value: 1, to: snapshot.dayStart) else { return nil }
        return DaySnapshot(dayStart: next, steps: 0, weightKg: snapshot.weightKg, lastReadAt: nil)
    }
}

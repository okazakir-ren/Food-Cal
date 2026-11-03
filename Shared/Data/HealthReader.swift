import Foundation
import HealthKit

/// HealthKitの読み取り。歩数は統計クエリで読み、iPhoneとWatchの重複処理を任せる。
struct HealthReader: Sendable {
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static var stepType: HKQuantityType { HKQuantityType(.stepCount) }
    private static var bodyMassType: HKQuantityType { HKQuantityType(.bodyMass) }
    private static var readTypes: Set<HKObjectType> { [stepType, bodyMassType] }

    /// 読み取りの拒否は判別できないので、分かるのは「許可画面をまだ出す必要があるか」だけ。
    func needsAuthorizationRequest() async -> Bool {
        guard Self.isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        return status != .unnecessary
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    /// 今日の歩数。データなしは0を返す。読めないときはエラーを投げる（0と区別するため）。
    func todaySteps(now: Date = .now, calendar: Calendar = .current) async throws -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.stepType, predicate: predicate),
            options: .cumulativeSum
        )
        do {
            let statistics = try await descriptor.result(for: store)
            return Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        } catch let error as HKError where error.code == .errorNoData {
            return 0
        }
    }

    func latestWeightKg() async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: Self.bodyMassType)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: store)
        return samples.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }
}

enum TodayRefresher {
    /// 歩数を読み、前回値と合わせて保存する。体重がなければ計算できないので nil を返す。
    @discardableResult
    static func refresh(
        source: DiagnosticEvent.Source,
        action: String,
        reader: HealthReader = HealthReader(),
        store: SharedStore = SharedStore(),
        now: Date = .now
    ) async -> DaySnapshot? {
        guard let weightKg = store.weightKg else {
            DiagnosticLog.append(.init(at: now, source: source, action: action, steps: nil, error: "体重なし"))
            return nil
        }

        var readSteps: Int?
        var errorText: String?
        do {
            readSteps = try await readTodaySteps(reader: reader, store: store, now: now)
        } catch {
            let nsError = error as NSError
            errorText = "\(nsError.domain)/\(nsError.code)"
        }
        DiagnosticLog.append(.init(at: now, source: source, action: action, steps: readSteps, error: errorText))

        let snapshot = SnapshotPolicy.resolve(
            cached: store.snapshot,
            readSteps: readSteps,
            weightKg: weightKg,
            now: now
        )
        store.snapshot = snapshot
        return snapshot
    }

    private static func readTodaySteps(reader: HealthReader, store: SharedStore, now: Date) async throws -> Int {
        #if DEBUG && targetEnvironment(simulator)
        if let fake = store.debugFakeSteps { return fake }
        #endif
        return try await reader.todaySteps(now: now)
    }
}

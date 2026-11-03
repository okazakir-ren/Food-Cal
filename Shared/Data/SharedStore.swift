import Foundation

enum AppGroup {
    static let identifier = "group.jp.renokazaki.aruitegohan"
}

/// 本体とウィジェットで共有する値。DB全体は共有せず、表示に要る値だけを置く。
struct SharedStore: Sendable {
    private enum Key {
        static let snapshot = "today.snapshot"
        static let weightKg = "weight.kg"
        static let weightFromHealth = "weight.fromHealth"
        static let authorizationRequested = "health.authorizationRequested"
        static let debugFakeSteps = "debug.fakeSteps"
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
    }

    var snapshot: DaySnapshot? {
        get {
            guard let data = defaults?.data(forKey: Key.snapshot) else { return nil }
            return try? JSONDecoder().decode(DaySnapshot.self, from: data)
        }
        nonmutating set {
            defaults?.set(try? JSONEncoder().encode(newValue), forKey: Key.snapshot)
        }
    }

    var weightKg: Double? {
        get {
            let value = defaults?.double(forKey: Key.weightKg) ?? 0
            return value > 0 ? value : nil
        }
        nonmutating set { defaults?.set(newValue ?? 0, forKey: Key.weightKg) }
    }

    var isWeightFromHealth: Bool {
        get { defaults?.bool(forKey: Key.weightFromHealth) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Key.weightFromHealth) }
    }

    var isAuthorizationRequested: Bool {
        get { defaults?.bool(forKey: Key.authorizationRequested) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Key.authorizationRequested) }
    }

    /// 初回設定が終わっていなければ、ウィジェットは「タップして設定」を出す。
    var isSetupComplete: Bool { isAuthorizationRequested && weightKg != nil }

    #if DEBUG && targetEnvironment(simulator)
    /// シミュレータにはHealthKitのデータが無いので、表示確認用の疑似歩数を使う。
    var debugFakeSteps: Int? {
        get { defaults?.object(forKey: Key.debugFakeSteps) as? Int }
        nonmutating set { defaults?.set(newValue, forKey: Key.debugFakeSteps) }
    }
    #endif
}

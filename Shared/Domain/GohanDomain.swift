import Foundation

enum CalorieCalculator {
    /// 仕様書 2章: kcal = round(歩数 × 体重kg × 0.04 ÷ 60)
    static func kcal(steps: Int, weightKg: Double) -> Int {
        Int((Double(max(steps, 0)) * weightKg * 0.04 / 60).rounded())
    }
}

struct GohanTier: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let label: String
    let minKcal: Int

    /// 画像名はアセットカタログの imageset 名と同じ。
    var imageName: String { id }

    static let all: [GohanTier] = [
        .init(id: "tea", name: "お茶", label: "まだお茶でひといき", minKcal: 0),
        .init(id: "mikan", name: "みかん", label: "みかん 1こぶん", minKcal: 50),
        .init(id: "banana", name: "バナナ", label: "バナナ 1本ぶん", minKcal: 90),
        .init(id: "onigiri", name: "おにぎり", label: "おにぎり 1こぶん", minKcal: 170),
        .init(id: "burger", name: "ハンバーガー", label: "ハンバーガー 1こぶん", minKcal: 260),
        .init(id: "cake", name: "ショートケーキ", label: "ショートケーキ 1こぶん", minKcal: 340),
        .init(id: "ramen", name: "ラーメン", label: "ラーメン 1杯ぶん 完食!", minKcal: 500)
    ]

    static func tier(forKcal kcal: Int) -> GohanTier {
        all.last { kcal >= $0.minKcal } ?? all[0]
    }

    static func next(after tier: GohanTier) -> GohanTier? {
        guard let index = all.firstIndex(of: tier), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

/// ウィジェットと本体で共通の表示値。
struct GohanDisplay: Equatable, Sendable {
    static let capKcal = 500
    static let segmentCount = 10

    let steps: Int
    let kcal: Int

    var tier: GohanTier { GohanTier.tier(forKcal: kcal) }
    var isCapped: Bool { kcal >= Self.capKcal }
    var kcalText: String { isCapped ? "\(Self.capKcal)+" : "\(kcal)" }
    var stepsText: String { steps.formatted(.number.locale(Locale(identifier: "ja_JP"))) }

    var filledSegments: Int {
        min(Self.segmentCount, min(kcal, Self.capKcal) / (Self.capKcal / Self.segmentCount))
    }

    var nextText: String {
        guard let next = GohanTier.next(after: tier) else {
            return "MAX!上限 \(Self.capKcal)kcal 到達"
        }
        return "あと\(next.minKcal - kcal)kcalで\(next.name)"
    }
}

/// 16pxのドット絵を整数倍で表示するための倍率を決める。
enum PixelScale {
    static let artSize: CGFloat = 16

    /// 小: 文字とゲージの高さを引いた残りに収まる最大の整数倍（4〜6倍）。
    static func small(contentHeight: CGFloat) -> CGFloat {
        clamp(floor((contentHeight - 41) / artSize), min: 4, max: 6)
    }

    /// 中: タイルの余白を引いた残りに収まる最大の整数倍（4〜7倍）。
    static func medium(tileHeight: CGFloat) -> CGFloat {
        clamp(floor((tileHeight - 24) / artSize), min: 4, max: 7)
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), upper)
    }
}

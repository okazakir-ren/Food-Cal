#if os(watchOS)
import SwiftUI
import WidgetKit

enum WatchTheme {
    static let paper = Color(red: 0xF6 / 255, green: 0xF2 / 255, blue: 0xE7 / 255)
    static let accent = Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x5C / 255)
    static let sub = Color(red: 0xA9 / 255, green: 0xA2 / 255, blue: 0xB5 / 255)
    static let empty = Color(red: 0x3A / 255, green: 0x35 / 255, blue: 0x46 / 255)

    static func dot(_ size: CGFloat) -> Font { .custom("DotGothic16-Regular", fixedSize: size) }
}

struct WatchPixelFood: View {
    let tier: GohanTier
    /// 16pxのドット絵を崩さない大きさにする。Watchは2倍の画面なので、8pt刻みなら画素が揃う。
    let size: CGFloat

    var body: some View {
        Image(tier.imageName)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
            .accessibilityLabel(tier.name)
    }
}

struct WatchSegmentGauge: View {
    let filled: Int
    let height: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<GohanDisplay.segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? WatchTheme.accent : WatchTheme.empty)
                    .frame(height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - コンプリケーション

/// 文字盤の円形。周りのリングがゲージで、中がごはん。
struct GohanCircularComplication: View {
    let display: GohanDisplay

    var body: some View {
        Gauge(value: Double(display.filledSegments), in: 0...Double(GohanDisplay.segmentCount)) {
            WatchPixelFood(tier: display.tier, size: 24)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

/// 文字盤の長方形。
struct GohanRectangularComplication: View {
    let display: GohanDisplay

    var body: some View {
        HStack(spacing: 6) {
            WatchPixelFood(tier: display.tier, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(display.kcalText).font(WatchTheme.dot(20))
                    Text("kcal").font(WatchTheme.dot(10))
                }
                .widgetAccentable()
                Text("\(display.stepsText)歩").font(WatchTheme.dot(11))
                HStack(spacing: 1) {
                    ForEach(0..<GohanDisplay.segmentCount, id: \.self) { index in
                        Rectangle()
                            .opacity(index < display.filledSegments ? 1 : 0.25)
                            .frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 文字盤の時計の上。文字だけを出せる。
struct GohanInlineComplication: View {
    let display: GohanDisplay

    var body: some View {
        Text("\(display.kcalText)kcal・\(display.tier.name)")
    }
}

/// 文字盤の四隅。
struct GohanCornerComplication: View {
    let display: GohanDisplay

    var body: some View {
        WatchPixelFood(tier: display.tier, size: 24)
            .widgetLabel {
                Gauge(value: Double(display.filledSegments), in: 0...Double(GohanDisplay.segmentCount)) {
                    Text(display.kcalText)
                } currentValueLabel: {
                    Text(display.kcalText)
                }
            }
    }
}
#endif

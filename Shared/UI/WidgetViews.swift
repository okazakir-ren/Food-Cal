#if os(iOS)
import SwiftUI
import UIKit

enum Theme {
    static let background = dynamic(light: 0xF6F2E7, dark: 0x1F1C27)
    static let ink = dynamic(light: 0x23202B, dark: 0xF4EFE4)
    static let sub = dynamic(light: 0x5E5868, dark: 0xA9A2B5)
    static let accent = dynamic(light: 0xC23A26, dark: 0xFF7A5C)
    static let empty = dynamic(light: 0xE3DCCB, dark: 0x3A3546)
    static let tile = dynamic(light: 0xECE5D3, dark: 0x2A2634)

    static func dot(_ size: CGFloat) -> Font { .custom("DotGothic16-Regular", fixedSize: size) }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PixelFood: View {
    let tier: GohanTier
    let scale: CGFloat

    var body: some View {
        Image(tier.imageName)
            .resizable()
            .interpolation(.none)
            .frame(width: PixelScale.artSize * scale, height: PixelScale.artSize * scale)
            .accessibilityLabel(tier.name)
    }
}

struct SegmentGauge: View {
    let filled: Int
    let height: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<GohanDisplay.segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? Theme.accent : Theme.empty)
                    .frame(height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 小・ごはん主役
struct SmallGohanView: View {
    let display: GohanDisplay

    var body: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 12
            let scale = PixelScale.small(contentHeight: proxy.size.height - padding * 2)
            VStack(spacing: 2) {
                HStack {
                    Text("\(display.stepsText)歩")
                        .foregroundStyle(Theme.sub)
                    Spacer(minLength: 4)
                    Text("\(display.kcalText)kcal")
                        .foregroundStyle(Theme.accent)
                }
                .font(Theme.dot(11))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                PixelFood(tier: display.tier, scale: scale)

                Text(display.tier.name)
                    .font(Theme.dot(12))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                SegmentGauge(filled: display.filledSegments, height: 6)
            }
            .padding(padding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// 中
struct MediumGohanView: View {
    let display: GohanDisplay

    var body: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 14
            let tileSize = proxy.size.height - padding * 2
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.tile)
                    .frame(width: tileSize, height: tileSize)
                    .overlay {
                        PixelFood(tier: display.tier, scale: PixelScale.medium(tileHeight: tileSize))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("きょうの消費")
                        Spacer(minLength: 4)
                        Text("\(display.stepsText)歩")
                    }
                    .font(Theme.dot(12))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(display.kcalText)
                            .font(Theme.dot(tileSize < 130 ? 34 : 40))
                            .foregroundStyle(Theme.accent)
                        Text("kcal")
                            .font(Theme.dot(13))
                            .foregroundStyle(Theme.sub)
                    }

                    Text(display.tier.label)
                        .font(Theme.dot(13))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    SegmentGauge(filled: display.filledSegments, height: 8)

                    Text(display.nextText)
                        .font(Theme.dot(11))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(padding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct SetupNeededView: View {
    var body: some View {
        VStack(spacing: 8) {
            PixelFood(tier: GohanTier.all[0], scale: 3)
            Text("タップして設定")
                .font(Theme.dot(14))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

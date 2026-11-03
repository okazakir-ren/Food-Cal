#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// シミュレータ専用。起動引数で疑似データを入れて表示を確かめる。
/// 例: -fakeSteps 7150 -fakeWeight 60 -gallery small
enum DebugBootstrap {
    private static let defaults = UserDefaults.standard

    static var opensGallery: Bool { defaults.string(forKey: "gallery") != nil }
    static var galleryPage: String { defaults.string(forKey: "gallery") ?? "small" }

    static func apply() {
        let store = SharedStore()
        if defaults.object(forKey: "fakeSteps") != nil {
            store.debugFakeSteps = defaults.integer(forKey: "fakeSteps")
            store.isAuthorizationRequested = true
        }
        if defaults.object(forKey: "fakeWeight") != nil {
            store.weightKg = defaults.double(forKey: "fakeWeight")
        }
    }
}

struct WidgetGalleryView: View {
    private static let tierSteps = GohanTier.all.map { Int((Double($0.minKcal) / 0.04).rounded(.up)) }

    private func display(_ steps: Int) -> GohanDisplay {
        GohanDisplay(steps: steps, kcal: CalorieCalculator.kcal(steps: steps, weightKg: 60))
    }

    private func card<Content: View>(_ width: CGFloat, _ height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, height: height)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch DebugBootstrap.galleryPage {
                case "medium":
                    ForEach(Self.tierSteps.suffix(4), id: \.self) { steps in
                        card(364, 170) { MediumGohanView(display: display(steps)) }
                    }
                case "narrow":
                    Text("小 148 / 158pt").font(.caption)
                    HStack {
                        card(148, 148) { SmallGohanView(display: display(7150)) }
                        card(158, 158) { SmallGohanView(display: display(21250)) }
                    }
                    Text("中 321×148 / 338×158pt").font(.caption)
                    card(321, 148) { MediumGohanView(display: display(8500)) }
                    card(338, 158) { MediumGohanView(display: display(21250)) }
                default:
                    LazyVGrid(columns: [GridItem(.fixed(170)), GridItem(.fixed(170))], spacing: 12) {
                        ForEach(Self.tierSteps, id: \.self) { steps in
                            card(170, 170) { SmallGohanView(display: display(steps)) }
                        }
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.725, green: 0.796, blue: 0.753))
        .navigationTitle("表示確認")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif

import SwiftUI

/// Every colour in the app is a shade of green.
enum Theme {
    static let forest = Color(hex: 0x173D2F)   // deepest — run screens, big numbers
    static let pine = Color(hex: 0x2E5E4E)     // primary buttons, selected states
    static let fern = Color(hex: 0x4F8A6B)     // secondary accents
    static let moss = Color(hex: 0x86B596)     // walk accents
    static let sage = Color(hex: 0xB9D6C3)     // tracks, dividers on tint
    static let mint = Color(hex: 0xE2EFE6)     // soft fills
    static let mist = Color(hex: 0xF3F7F4)     // page background
    static let ink = Color(hex: 0x14241C)      // body text
    static let muted = Color(hex: 0x6F857A)    // secondary text

    static func color(for kind: Segment.Kind) -> Color {
        switch kind {
        case .run: forest
        case .walk: moss
        case .warmup, .cooldown: sage
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// The misty page background: a deep green glow at the top that fades into
/// pale green, like light through leaves.
struct GlowBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Theme.mist
            LinearGradient(colors: [Theme.pine, Theme.fern.opacity(0.75), Theme.mist],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.mint.opacity(0.35))
                        .frame(width: 320)
                        .blur(radius: 70)
                        .offset(x: 120, y: -40)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Theme.forest.opacity(0.5))
                        .frame(width: 260)
                        .blur(radius: 60)
                        .offset(x: -90, y: -60)
                }
        }
        .ignoresSafeArea()
    }
}

/// A white, softly shadowed card.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.forest.opacity(0.06), radius: 18, y: 8)
    }
}

/// Full-width pill button, deep green.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Theme.pine
    var text: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Pins a button to the bottom, over a backdrop that fades the content
    /// scrolling beneath it.
    func bottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            bar()
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 4)
                .background(
                    LinearGradient(stops: [.init(color: Theme.mist.opacity(0), location: 0),
                                           .init(color: Theme.mist, location: 0.4)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
        }
    }

    /// Fades content as it scrolls up under the status bar.
    func statusBarScrim(_ color: Color = Theme.pine) -> some View {
        overlay(alignment: .top) {
            GeometryReader { geo in
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.safeAreaInsets.top + 16)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
        }
    }
}

/// A ring that fills clockwise from the top.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var track: Color = Theme.mint
    var fill: Color = Theme.pine

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // A round cap on an empty ring would draw a stray dot.
                .opacity(progress > 0 ? 1 : 0)
        }
    }
}

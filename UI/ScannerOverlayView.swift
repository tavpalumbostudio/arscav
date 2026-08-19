import SwiftUI

/// Dimmed camera atmosphere with a subtle sci‑fi scanner HUD.
struct ScannerOverlayView: View {
    var isVisible = true
    /// Full HUD when scanning; softens while a card or modal is on screen.
    var focused = true

    private var strength: Double { focused ? 1 : 0.55 }

    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.32 * strength)
                    .ignoresSafeArea()

                vignette

                ScannerGridPattern()
                    .opacity(0.06 * strength)

                ScannerReticle(focused: focused)

                ScanLineEffect(active: focused)

                cornerStatusDots
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.35), value: focused)
        }
    }

    private var vignette: some View {
        RadialGradient(
            colors: [
                .clear,
                Color.black.opacity(0.05 * strength),
                Color.black.opacity(0.38 * strength)
            ],
            center: .center,
            startRadius: 80,
            endRadius: 520
        )
        .ignoresSafeArea()
    }

    private var cornerStatusDots: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let pulse = 0.35 + 0.35 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.0)
            GeometryReader { geo in
                let inset: CGFloat = 28
                let positions: [CGPoint] = [
                    CGPoint(x: inset, y: inset + 40),
                    CGPoint(x: geo.size.width - inset, y: inset + 40),
                    CGPoint(x: inset, y: geo.size.height - inset - 88),
                    CGPoint(x: geo.size.width - inset, y: geo.size.height - inset - 88)
                ]
                ZStack {
                    ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(ScannerPalette.accent.opacity(pulse * 0.45 * strength))
                            .frame(width: 5, height: 5)
                            .shadow(color: ScannerPalette.glow.opacity(0.35), radius: 3)
                            .position(point)
                            .opacity(index.isMultiple(of: 2) ? 1 : pulse)
                    }
                }
            }
        }
    }
}

private enum ScannerPalette {
    static let accent = Color(red: 0.28, green: 0.96, blue: 0.86)
    static let glow = Color(red: 0.18, green: 0.78, blue: 0.92)
    static let bracket = Color(red: 0.55, green: 1.0, blue: 0.92)
}

private struct ScannerReticle: View {
    var focused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.45 + 0.35 * sin(t * 1.5)
            GeometryReader { geo in
                let inset: CGFloat = 34
                let length: CGFloat = min(geo.size.width, geo.size.height) * 0.11
                let rect = CGRect(
                    x: inset,
                    y: inset + 36,
                    width: geo.size.width - inset * 2,
                    height: geo.size.height - inset * 2 - 120
                )

                ZStack {
                    CornerBrackets(rect: rect, length: length)
                        .stroke(
                            ScannerPalette.bracket.opacity((focused ? 0.38 : 0.22) * pulse),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .shadow(color: ScannerPalette.glow.opacity(0.18 * pulse), radius: 4)

                    CenterCrosshair()
                        .stroke(
                            ScannerPalette.accent.opacity((focused ? 0.18 : 0.10) * pulse),
                            lineWidth: 1
                        )
                        .frame(width: 44, height: 44)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}

private struct CornerBrackets: Shape {
    let rect: CGRect
    let length: CGFloat

    func path(in _: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)
        ]

        for (origin, dx, dy) in corners {
            path.move(to: CGPoint(x: origin.x, y: origin.y + length * dy))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x + length * dx, y: origin.y))
        }
        return path
    }
}

private struct CenterCrosshair: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        let arm: CGFloat = 10
        let gap: CGFloat = 4
        path.move(to: CGPoint(x: mid.x - arm, y: mid.y))
        path.addLine(to: CGPoint(x: mid.x - gap, y: mid.y))
        path.move(to: CGPoint(x: mid.x + gap, y: mid.y))
        path.addLine(to: CGPoint(x: mid.x + arm, y: mid.y))
        path.move(to: CGPoint(x: mid.x, y: mid.y - arm))
        path.addLine(to: CGPoint(x: mid.x, y: mid.y - gap))
        path.move(to: CGPoint(x: mid.x, y: mid.y + gap))
        path.addLine(to: CGPoint(x: mid.x, y: mid.y + arm))
        return path
    }
}

private struct ScanLineEffect: View {
    var active: Bool

    private let sweepDuration = 8.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let progress = time.truncatingRemainder(dividingBy: sweepDuration) / sweepDuration
            let pulse = 0.42 + 0.58 * sin(time * 2.2)
            let lineOpacity = (active ? 0.14 : 0.07) * pulse
            let bandOpacity = (active ? 0.10 : 0.05) * pulse

            GeometryReader { geo in
                let y = geo.size.height * progress
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    ScannerPalette.glow.opacity(bandOpacity * 0.35),
                                    ScannerPalette.accent.opacity(bandOpacity),
                                    ScannerPalette.glow.opacity(bandOpacity * 0.35),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: active ? 72 : 48)
                        .blur(radius: 1)
                        .position(x: geo.size.width / 2, y: y)

                    Rectangle()
                        .fill(ScannerPalette.accent.opacity(lineOpacity))
                        .frame(width: geo.size.width * 0.68, height: 1)
                        .blur(radius: 0.4)
                        .shadow(color: ScannerPalette.glow.opacity(lineOpacity * 0.8), radius: 3, y: 0)
                        .position(x: geo.size.width / 2, y: y)
                }
            }
        }
    }
}

private struct ScannerGridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 44
            var path = Path()
            stride(from: 0 as CGFloat, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            stride(from: 0 as CGFloat, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(ScannerPalette.accent.opacity(0.18)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }
}

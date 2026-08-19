import SwiftUI

#if targetEnvironment(simulator)
/// Stand-in camera feed for Simulator so scanner dimming and HUD can be previewed.
struct SimulatorCameraFeedView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.52, green: 0.58, blue: 0.64),
                        Color(red: 0.38, green: 0.42, blue: 0.48),
                        Color(red: 0.24, green: 0.26, blue: 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Back wall
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.74, blue: 0.68),
                                Color(red: 0.62, green: 0.58, blue: 0.52)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geo.size.height * 0.52)
                    .frame(maxHeight: .infinity, alignment: .top)

                // Table surface
                Path { path in
                    let topY = geo.size.height * 0.48
                    path.move(to: CGPoint(x: 0, y: topY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: topY * 0.92))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.56, green: 0.42, blue: 0.30),
                            Color(red: 0.34, green: 0.24, blue: 0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Soft window light
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.04),
                        .clear
                    ],
                    center: UnitPoint(x: 0.78, y: 0.18),
                    startRadius: 12,
                    endRadius: geo.size.width * 0.55
                )

                // Marker cards on table
                markerSheet(
                    title: "07",
                    colors: [Color(red: 0.18, green: 0.42, blue: 0.78), Color(red: 0.08, green: 0.18, blue: 0.42)],
                    size: CGSize(width: 74, height: 98),
                    rotation: -8
                )
                .position(x: geo.size.width * 0.28, y: geo.size.height * 0.62)

                markerSheet(
                    title: "03",
                    colors: [Color(red: 0.16, green: 0.58, blue: 0.40), Color(red: 0.05, green: 0.28, blue: 0.18)],
                    size: CGSize(width: 68, height: 90),
                    rotation: 12
                )
                .position(x: geo.size.width * 0.56, y: geo.size.height * 0.68)

                markerSheet(
                    title: "11",
                    colors: [Color(red: 0.52, green: 0.28, blue: 0.72), Color(red: 0.24, green: 0.10, blue: 0.38)],
                    size: CGSize(width: 62, height: 82),
                    rotation: -3
                )
                .position(x: geo.size.width * 0.78, y: geo.size.height * 0.58)

                // Mug / prop for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.92, green: 0.90, blue: 0.86), Color(red: 0.58, green: 0.54, blue: 0.48)],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 34
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
                    .position(x: geo.size.width * 0.14, y: geo.size.height * 0.74)

                // Simulator badge
                VStack {
                    HStack {
                        Spacer()
                        Text("SIM CAMERA PREVIEW")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.35), in: Capsule())
                            .padding(.top, 56)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func markerSheet(title: String, colors: [Color], size: CGSize, rotation: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            Text(title)
                .font(.system(size: size.width * 0.34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        .rotationEffect(.degrees(rotation))
    }
}
#endif

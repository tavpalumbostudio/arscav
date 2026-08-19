import SwiftUI
import UIKit

struct HuntPickerView: View {
    @ObservedObject var engine: HuntEngine
    var onOpenDevMenu: () -> Void

    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 12

    private var groupedRounds: [(group: String, rounds: [(index: Int, round: HuntRound)])] {
        var buckets: [String: [(Int, HuntRound)]] = [:]
        var order: [String] = []
        for (index, round) in engine.manifest.rounds.enumerated() {
            let group = round.categoryGroup ?? "Hunts"
            if buckets[group] == nil {
                order.append(group)
            }
            buckets[group, default: []].append((index, round))
        }
        return order.map { (group: $0, rounds: buckets[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.14),
                    Color(red: 0.10, green: 0.12, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    ForEach(groupedRounds, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.group.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.horizontal, 2)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: columnSpacing),
                                    GridItem(.flexible(), spacing: columnSpacing)
                                ],
                                spacing: rowSpacing
                            ) {
                                ForEach(section.rounds, id: \.index) { item in
                                    HuntPickerTile(
                                        round: item.round,
                                        roundIndex: item.index,
                                        thumbnail: engine.pickerThumbnails[item.round.id]
                                    ) {
                                        Task { await engine.startNewGame(categoryIndex: item.index) }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ARScav")
                    .font(.largeTitle.weight(.heavy))
                Text("Pick a hunt to start. Print markers, lay them face-down, then scan to play.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if engine.pickerThumbnailsTotal > 0,
                   engine.pickerThumbnailsLoaded < engine.pickerThumbnailsTotal {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Loading hunt photos \(engine.pickerThumbnailsLoaded)/\(engine.pickerThumbnailsTotal)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            Spacer(minLength: 12)

            Button(action: onOpenDevMenu) {
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dev menu")
        }
        .padding(.top, 52)
    }
}

private struct HuntPickerTile: View {
    let round: HuntRound
    let roundIndex: Int
    let thumbnail: UIImage?
    let action: () -> Void

    private static let cornerRadius: CGFloat = 14

    private var theme: CardTextureFactory.HuntCardTheme {
        CardTextureFactory.HuntCardTheme.forRound(index: roundIndex, round: round)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                tileArtwork

                if thumbnail == nil {
                    placeholderSymbol
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55), .black.opacity(0.82)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                captionOverlay
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: theme.deep))
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color(uiColor: theme.accent).opacity(0.45),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(HuntPickerTileButtonStyle())
        .accessibilityLabel("\(round.title). \(round.pickerSubtitle)")
    }

    private var captionOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(round.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(round.pickerSubtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 28)
    }

    @ViewBuilder
    private var tileArtwork: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(uiColor: theme.base), Color(uiColor: theme.deep)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var placeholderSymbol: some View {
        ZStack {
            Text(round.pickerEmoji)
                .font(.system(size: 44))
                .opacity(0.35)
            ProgressView()
                .scaleEffect(0.85)
                .tint(.white.opacity(0.85))
        }
    }
}

private struct HuntPickerTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

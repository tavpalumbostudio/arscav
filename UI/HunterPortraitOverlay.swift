import SwiftUI
import UIKit

struct HunterPortraitOverlay: View {
    @ObservedObject var engine: HuntEngine

    var body: some View {
        if engine.phase == .playing,
           engine.currentRound.isPredatorHunt,
           engine.markerCard == nil,
           !engine.isDevMenuOpen,
           !engine.showRoundSuccess {
            VStack {
                Spacer()
                HStack {
                    portraitCard
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 96)
            }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .move(edge: .leading)))
            .animation(.easeInOut(duration: 0.25), value: engine.roundToken)
        }
    }

    @ViewBuilder
    private var portraitCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You are")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            if let portrait = engine.hunterPortrait {
                Image(uiImage: portrait)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            } else {
                placeholder
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .frame(width: 96, height: 124)
            Text(engine.currentRound.predatorEmoji ?? "🐾")
                .font(.system(size: 52))
            ProgressView()
                .scaleEffect(0.8)
                .tint(.gray)
        }
    }
}

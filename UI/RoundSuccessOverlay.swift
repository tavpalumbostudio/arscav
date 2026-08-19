import SwiftUI

struct RoundSuccessOverlay: View {
    @ObservedObject var engine: HuntEngine

    var body: some View {
        if engine.showRoundSuccess {
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Text("🎉")
                        .font(.system(size: 56))

                    Text("Round complete!")
                        .font(.title2.weight(.bold))

                    Text(engine.lastCompletedRoundTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    foundSummary

                    Button {
                        Task { await engine.continueToNextRound() }
                    } label: {
                        Text(engine.hasNextRound ? "Next hunt" : "All done!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .foregroundStyle(.white)
                .padding(24)
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeInOut(duration: 0.28), value: engine.showRoundSuccess)
        }
    }

    @ViewBuilder
    private var foundSummary: some View {
        let objects = engine.lastCompletedRoundTargets
        if !objects.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("You found:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                ForEach(objects, id: \.id) { object in
                    Label(object.name.capitalized, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

import SwiftUI
import UIKit

struct OverlayControls: View {
    @ObservedObject var engine: HuntEngine

    var body: some View {
        VStack {
            if engine.showContentPanel {
                ContentLoadBanner(engine: engine)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 52)
            }
            Spacer()
            HStack {
                Button {
                    engine.repeatPrompt()
                } label: {
                    Label("Repeat prompt", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityIdentifier("repeat-prompt")
            }
            .disabled(engine.markerCard != nil || engine.showRoundSuccess)
            .opacity(engine.markerCard == nil && !engine.showRoundSuccess ? 1 : 0.45)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.25), value: engine.showContentPanel)
        .animation(.easeInOut(duration: 0.2), value: engine.imagesLoaded)
    }
}

struct HuntStatusBar: View {
    @ObservedObject var engine: HuntEngine
    var onOpenDevMenu: () -> Void

    var body: some View {
        Button(action: onOpenDevMenu) {
            Text(status)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .padding(.top, 12)
        .foregroundStyle(.white)
        .accessibilityIdentifier("hunt-status")
    }

    private var status: String {
        if engine.phase == .complete {
            return "Hunt complete"
        }
        let found = engine.sessionTargetIDs.filter { engine.foundIDs.contains($0) }.count
        let progress = "\(found)/\(max(engine.sessionTargetIDs.count, engine.currentRound.targets.count))"
        if let target = engine.currentTarget {
            let cue = engine.currentRound.isPredatorHunt ? "Track" : "Find"
            return "\(cue) \(target.name) · \(progress)"
        }
        if engine.currentRound.isPredatorHunt {
            let emoji = engine.currentRound.predatorEmoji ?? "🐾"
            let name = engine.currentRound.predatorName ?? "Hunter"
            return "\(emoji) \(name) · \(progress)"
        }
        return "\(engine.currentRound.title) · \(progress)"
    }
}

private struct ContentLoadBanner: View {
    @ObservedObject var engine: HuntEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            loadRow(
                title: "Photos",
                loaded: engine.imagesLoaded,
                total: engine.imagesTotal,
                doneLabel: "Photos ready"
            )
            if engine.nextImagesTotal > 0, engine.nextImagesLoaded < engine.nextImagesTotal {
                loadRow(
                    title: "Next round",
                    loaded: engine.nextImagesLoaded,
                    total: engine.nextImagesTotal,
                    doneLabel: "Next round ready"
                )
            }
            modelRow
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var modelRow: some View {
        HStack(spacing: 8) {
            switch engine.modelStatus {
            case .idle, .loading:
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(.white)
                if engine.modelDownloadProgress > 0, engine.modelDownloadProgress < 1 {
                    Text("Voice model \(Int(engine.modelDownloadProgress * 100))%")
                } else {
                    Text("Voice model…")
                }
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                Text("Voice model ready")
            case .unavailable:
                Image(systemName: "minus.circle.fill")
                Text("Voice model skipped")
            }
            Spacer(minLength: 0)
            if engine.modelStatus == .loading, engine.modelDownloadProgress > 0, engine.modelDownloadProgress < 1 {
                ProgressView(value: engine.modelDownloadProgress)
                    .frame(width: 72)
                    .tint(.white)
            }
        }
    }

    private func loadRow(title: String, loaded: Int, total: Int, doneLabel: String) -> some View {
        let finished = total > 0 && loaded >= total
        return HStack(spacing: 8) {
            if finished {
                Image(systemName: "checkmark.circle.fill")
                Text(doneLabel)
            } else {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(.white)
                Text("\(title) \(loaded)/\(max(total, 1))")
            }
            Spacer(minLength: 0)
            if total > 0, !finished {
                ProgressView(value: Double(loaded), total: Double(total))
                    .frame(width: 72)
                    .tint(.white)
            }
        }
    }
}

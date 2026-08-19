import SwiftUI
import UIKit

struct MarkerCardOverlay: View {
    @ObservedObject var engine: HuntEngine

    var body: some View {
        if let card = engine.markerCard,
           let object = engine.currentRound.object(id: card.objectId) {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if card.isPreview {
                            engine.dismissMarkerCard()
                        }
                    }

                ZStack(alignment: .topTrailing) {
                    FlippableCardView(
                        isFlipped: card.isFlipped,
                        backImage: engine.backImage(for: card.markerId),
                        faceImage: engine.faceImage(for: object),
                        objectName: object.capsName,
                        autoFlip: engine.autoFlipCards
                    ) {
                        engine.flipMarkerCard()
                    }
                    .id(card.markerId)

                    HStack(spacing: 8) {
                        if card.isPreview {
                            previewBadge
                        }
                        if card.isFlipped {
                            refreshPhotoButton(for: object)
                        }
                        if card.isPreview {
                            Button {
                                engine.dismissMarkerCard()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close preview")
                        }
                    }
                    .padding(10)
                }
                .padding(.horizontal, 28)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: card.markerId)
        }
    }

    private var previewBadge: some View {
        Text("PREVIEW")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityHidden(true)
    }

    private func refreshPhotoButton(for object: HuntObject) -> some View {
        Button {
            Task { await engine.refreshCardImage(for: object.id) }
        } label: {
            Group {
                if engine.isRefreshingCardImage(object.id) {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                } else {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.caption.weight(.bold))
                }
            }
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(engine.isRefreshingCardImage(object.id))
        .accessibilityLabel("Try another photo")
    }
}

private struct FlippableCardView: View {
    let isFlipped: Bool
    let backImage: UIImage
    let faceImage: UIImage
    let objectName: String
    let autoFlip: Bool
    let onTap: () -> Void

    @State private var rotation: Double = 0
    @State private var entranceScale: CGFloat = 0.74
    @State private var autoFlipTask: Task<Void, Never>?

    private enum Motion {
        static let autoFlipDelayNanoseconds: UInt64 = 850_000_000
    }

    var body: some View {
        Button {
            autoFlipTask?.cancel()
            onTap()
        } label: {
            ZStack {
                cardSide(image: backImage)
                    .opacity(rotation <= 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.55)

                cardSide(image: faceImage)
                    .opacity(rotation > 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(rotation - 180), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            }
            .frame(maxWidth: 300)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .scaleEffect(entranceScale)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFlipped ? objectName : "Face-down card, tap to flip")
        .onAppear {
            runEntranceAnimation()
            scheduleAutoFlipIfNeeded()
        }
        .onDisappear {
            autoFlipTask?.cancel()
            autoFlipTask = nil
        }
        .onChange(of: isFlipped) { _, flipped in
            if flipped {
                autoFlipTask?.cancel()
            }
            withAnimation(.easeInOut(duration: 0.42)) {
                rotation = flipped ? 180 : 0
            }
        }
    }

    private func runEntranceAnimation() {
        rotation = isFlipped ? 180 : 0
        entranceScale = 0.74
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            entranceScale = 1
        }
    }

    private func scheduleAutoFlipIfNeeded() {
        autoFlipTask?.cancel()
        guard autoFlip, !isFlipped else { return }
        autoFlipTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Motion.autoFlipDelayNanoseconds)
            guard !Task.isCancelled, !isFlipped else { return }
            onTap()
        }
    }

    private func cardSide(image: UIImage) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
    }
}

import SwiftUI
import UIKit

@main
struct ARScavApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

private enum HuntOverlaySheet: Identifiable {
    case collection

    var id: Self { self }
}

struct RootView: View {
    @StateObject private var engine: HuntEngine
    @State private var loadError: String?
    @State private var activeSheet: HuntOverlaySheet?
    @State private var showDevMenu = false

    init() {
        let manifest = (try? ContentLoader.loadBundled()) ?? HuntManifest(physicalMarkerWidthMeters: 0.1, markerCount: 12, rounds: [])
        _engine = StateObject(wrappedValue: HuntEngine(manifest: manifest))
    }

    var body: some View {
        ZStack {
            if engine.manifest.rounds.isEmpty {
                Text(loadError ?? "Missing hunt manifest.")
                    .padding()
            } else if engine.phase == .selecting || engine.phase == .loading {
                HuntPickerView(engine: engine, onOpenDevMenu: openDevMenu)

                if showDevMenu {
                    DevMenuOverlay(engine: engine, onClose: closeDevMenu)
                }
            } else {
                #if targetEnvironment(simulator)
                SimulatorCameraFeedView()
                #else
                HuntARView(engine: engine)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                #endif
                ScannerOverlayView(
                    isVisible: !engine.isDevMenuOpen,
                    focused: engine.markerCard == nil && !engine.showRoundSuccess
                )
                OverlayControls(engine: engine)
                MarkerCardOverlay(engine: engine)
                HunterPortraitOverlay(engine: engine)

                RoundSuccessOverlay(engine: engine)

                if showDevMenu {
                    DevMenuOverlay(engine: engine, onClose: closeDevMenu)
                }
            }
        }
        .overlay(alignment: .top) {
            if !engine.manifest.rounds.isEmpty, engine.phase != .selecting {
                HuntStatusBar(engine: engine, onOpenDevMenu: openDevMenu)
            }
        }
        .sheet(item: $activeSheet) { _ in
            CollectionGridView(engine: engine)
        }
        .onChange(of: engine.showCollection) { _, requested in
            guard requested else { return }
            activeSheet = .collection
            engine.showCollection = false
        }
        .task {
            HuntAudioSession.activate()
            HuntSoundFX.shared.prepare()
            if engine.manifest.rounds.isEmpty {
                loadError = "Could not load hunt manifest.json from the app bundle."
                return
            }
            await engine.prepare()
            let remote = await ContentLoader.loadMergedManifest()
            await engine.applyMergedManifest(remote.manifest, status: remote.status)
        }
    }

    private func openDevMenu() {
        engine.dismissMarkerCard()
        engine.notifyDevMenuOpened()
        engine.isDevMenuOpen = true
        showDevMenu = true
    }

    private func closeDevMenu() {
        engine.isDevMenuOpen = false
        engine.notifyDevMenuClosed()
        showDevMenu = false
    }
}

private struct DevMenuOverlay: View {
    @ObservedObject var engine: HuntEngine
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            DevMenuView(engine: engine, onClose: onClose)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 28)
        }
    }
}

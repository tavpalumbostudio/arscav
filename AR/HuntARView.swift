import ARKit
import RealityKit
import SwiftUI
import UIKit

/// Camera + marker tracking only. Cards render in SwiftUI (`MarkerCardOverlay`).
struct HuntARView: UIViewRepresentable {
    let engine: HuntEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.renderOptions.insert(.disableMotionBlur)
        view.environment.background = .cameraFeed()
        view.scene.anchors.removeAll()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.engine = engine
        context.coordinator.syncRoundIfNeeded()
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        var engine: HuntEngine
        weak var arView: ARView?
        private var loadedRoundToken = -1
        private var loadedMarkerLimit = -1
        private var referenceImages: Set<ARReferenceImage> = []

        init(engine: HuntEngine) {
            self.engine = engine
        }

        func attach(to view: ARView) {
            arView = view
            view.session.delegate = self
            HuntAudioSession.activate()
            referenceImages = Self.loadReferenceImages(
                width: CGFloat(engine.physicalWidth),
                count: engine.resolvedMarkerLimit
            )
            loadedRoundToken = engine.roundToken
            loadedMarkerLimit = engine.resolvedMarkerLimit
            runTracking()
        }

        func syncRoundIfNeeded() {
            let markerLimit = engine.resolvedMarkerLimit
            guard loadedRoundToken != engine.roundToken || loadedMarkerLimit != markerLimit else { return }
            loadedRoundToken = engine.roundToken
            loadedMarkerLimit = markerLimit
            referenceImages = Self.loadReferenceImages(
                width: CGFloat(engine.physicalWidth),
                count: markerLimit
            )
            engine.resetMarkerCardForNewRound()
            runTracking()
        }

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            Task { @MainActor in self.process(anchors) }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            Task { @MainActor in self.process(anchors) }
        }

        nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            Task { @MainActor in
                for anchor in anchors {
                    guard let imageAnchor = anchor as? ARImageAnchor,
                          let name = imageAnchor.referenceImage.name else { continue }
                    self.engine.markerDidLoseTrack(name)
                }
            }
        }

        private func process(_ anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let imageAnchor = anchor as? ARImageAnchor,
                      let name = imageAnchor.referenceImage.name else { continue }
                if imageAnchor.isTracked {
                    engine.markerDidTrack(name)
                } else {
                    engine.markerDidLoseTrack(name)
                }
            }
        }

        private func runTracking() {
            guard let view = arView else { return }
            let config = ARImageTrackingConfiguration()
            config.trackingImages = referenceImages
            config.maximumNumberOfTrackedImages = 4
            view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            HuntAudioSession.activate()
        }

        private static func loadReferenceImages(width: CGFloat, count: Int) -> Set<ARReferenceImage> {
            var images = Set<ARReferenceImage>()
            for index in 1...count {
                let name = String(format: "marker-%02d", index)
                guard let ui = loadPNG(named: name), let cg = ui.cgImage else { continue }
                let reference = ARReferenceImage(cg, orientation: .up, physicalWidth: width)
                reference.name = name
                images.insert(reference)
            }
            return images
        }

        private static func loadPNG(named name: String) -> UIImage? {
            if let img = UIImage(named: name) { return img }
            let bundle = Bundle.main
            let locations: [(String?, String)] = [
                (nil, name),
                ("Markers", name),
                ("Resources", name),
                ("Resources/Markers", name)
            ]
            for (subdirectory, fileName) in locations {
                if let url = bundle.url(forResource: fileName, withExtension: "png", subdirectory: subdirectory),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    return image
                }
            }
            return nil
        }
    }
}

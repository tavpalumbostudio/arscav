import RealityKit
import UIKit
import simd

struct HuntCardComponent: Component {
    var objectId: String
}

@MainActor
final class HuntCardEntity {
    let objectId: String
    let root = Entity()
    private let flipRoot = Entity()
    private let front: ModelEntity
    private let back: ModelEntity
    private(set) var isRevealed = false
    private var spinning = false
    private var storedFaceMaterial: UnlitMaterial?

    init(objectId: String, markerWidth: Float, backTexture: TextureResource, faceTexture: TextureResource) {
        Self.registerIfNeeded()
        self.objectId = objectId

        // Portrait card sized to fit inside the square marker.
        let maxSide = markerWidth * 0.92
        var width = maxSide * 0.72
        var height = width * (4.0 / 3.0)
        if height > maxSide {
            height = maxSide
            width = height * 0.75
        }
        let halfThick: Float = 0.0006

        let mesh = MeshResource.generatePlane(width: width, height: height)
        let backMaterial = Self.unlit(backTexture)
        let faceMaterial = Self.unlit(faceTexture)
        storedFaceMaterial = faceMaterial

        front = ModelEntity(mesh: mesh, materials: [backMaterial])
        back = ModelEntity(mesh: mesh, materials: [backMaterial])
        back.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        front.position.z = halfThick
        back.position.z = -halfThick
        front.generateCollisionShapes(recursive: false)
        back.generateCollisionShapes(recursive: false)

        root.name = "card-\(objectId)"
        root.components.set(HuntCardComponent(objectId: objectId))
        // Slightly above the paper to avoid z-fighting, but visually flush.
        root.position.z = 0.0004

        if #available(iOS 18.0, *) {
            front.components.set(InputTargetComponent())
            back.components.set(InputTargetComponent())
        }

        flipRoot.name = "flip"
        flipRoot.addChild(front)
        flipRoot.addChild(back)
        root.addChild(flipRoot)
    }

    func updateFaceTexture(_ texture: TextureResource) {
        storedFaceMaterial = Self.unlit(texture)
        if isRevealed {
            applyFaceMaterials()
        }
    }

    func revealIfNeeded() -> Bool {
        guard !isRevealed else { return false }
        isRevealed = true
        root.stopAllAnimations()
        flipRoot.stopAllAnimations()

        let flipped = flipRoot.orientation * simd_quatf(angle: .pi, axis: [1, 0, 0])
        var target = flipRoot.transform
        target.rotation = flipped
        flipRoot.move(to: target, relativeTo: flipRoot.parent, duration: 0.42, timingFunction: .easeInOut)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard self.isRevealed else { return }
            self.applyFaceMaterials()
            self.startSpin()
        }
        return true
    }

    private func applyFaceMaterials() {
        guard let face = storedFaceMaterial else { return }
        front.model?.materials = [face]
        back.model?.materials = [face]
    }

    private func startSpin() {
        guard !spinning else { return }
        spinning = true
        let start = flipRoot.transform
        let end = Transform(
            scale: start.scale,
            rotation: flipRoot.orientation * simd_quatf(angle: .pi * 2, axis: [0, 0, 1]),
            translation: start.translation
        )
        let spin = FromToByAnimation<Transform>(
            name: "spin",
            from: start,
            to: end,
            duration: 10,
            timing: .linear,
            isAdditive: false,
            bindTarget: .transform,
            repeatMode: .repeat,
            fillMode: .forwards
        )
        if let resource = try? AnimationResource.generate(with: spin) {
            flipRoot.playAnimation(resource)
        }
    }

    func teardown() {
        root.stopAllAnimations()
        flipRoot.stopAllAnimations()
    }

    private static var didRegisterComponent = false

    private static func registerIfNeeded() {
        guard !didRegisterComponent else { return }
        HuntCardComponent.registerComponent()
        didRegisterComponent = true
    }

    private static func unlit(_ texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }
}

enum ObjectEntityFactory {
    @MainActor
    static func makeCard(
        object: HuntObject,
        markerWidth: Float,
        faceImage: UIImage,
        backTexture: TextureResource
    ) -> HuntCardEntity? {
        guard let faceTexture = texture(from: faceImage) else { return nil }
        return HuntCardEntity(
            objectId: object.id,
            markerWidth: markerWidth,
            backTexture: backTexture,
            faceTexture: faceTexture
        )
    }

    @MainActor
    static func texture(from image: UIImage) -> TextureResource? {
        guard let cg = rgbaCGImage(from: image) else { return nil }
        return try? TextureResource.generate(from: cg, options: .init(semantic: .color))
    }

    static func rgbaCGImage(from image: UIImage) -> CGImage? {
        let width = max(1, image.size.width * image.scale)
        let height = max(1, image.size.height * image.scale)
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let flattened = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return flattened.cgImage
    }
}

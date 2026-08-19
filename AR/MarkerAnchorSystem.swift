import ARKit
import RealityKit

/// Places hunt cards on tracked image anchors.
enum MarkerAnchorSystem {
    static func makeAnchor(for imageAnchor: ARImageAnchor, card: HuntCardEntity) -> AnchorEntity {
        let anchor = AnchorEntity(anchor: imageAnchor)
        anchor.addChild(card.root)
        return anchor
    }
}

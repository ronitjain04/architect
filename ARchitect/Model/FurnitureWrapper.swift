import UIKit
import RealityKit

enum MovementMode {
    case horizontal
    case vertical
}

class FurnitureWrapper {
    let instanceID = UUID().uuidString
    let model: RoomFurnitureModel?
    let entity: ModelEntity
    let originalScale: SIMD3<Float>
    let originalPosition: SIMD3<Float>
    var isLocked: Bool = false
    var gestureRecognizers: [UIGestureRecognizer] = []
    var movementMode: MovementMode = .horizontal
    var isSelected = false

    init(entity: ModelEntity, model: RoomFurnitureModel? = nil) {
        self.model = model
        self.entity = entity
        self.originalScale = entity.scale
        self.originalPosition = entity.position
    }
}

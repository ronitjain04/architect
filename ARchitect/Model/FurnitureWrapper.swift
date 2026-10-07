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
    var isLocked: Bool = false
    var gestureRecognizers: [UIGestureRecognizer] = []
    var movementMode: MovementMode = .horizontal
    var isSelected = false

    init(entity: ModelEntity, model: RoomFurnitureModel? = nil) {
        self.model = model
        self.entity = entity
    }
}

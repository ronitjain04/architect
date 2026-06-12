import UIKit
import RealityKit

enum MovementMode {
    case horizontal
    case vertical
}

class FurnitureWrapper {
    let entity: ModelEntity
    var isLocked: Bool = false
    var gestureRecognizers: [UIGestureRecognizer] = []
    var movementMode: MovementMode = .horizontal
    var isSelected = false

    init(entity: ModelEntity) {
        self.entity = entity
    }
}

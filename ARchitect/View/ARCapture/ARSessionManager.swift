//
//  ARSessionManager.swift
//  ARchitect
//
//  Owns the AR capture session: world tracking, furniture placement via
//  raycast, selection/locking, drag + rotate/scale gestures, and snapshots.
//  Logic ported from the retired UIKit ARViewController; the SwiftUI capture
//  screen renders its chrome and talks to this object.
//

import Foundation
import ARKit
import RealityKit
import UIKit
import RoomPlan

enum FurnitureDragMath {
    static func verticalMetersPerPoint(depth: Float, viewportHeight: Float) -> Float {
        guard viewportHeight > 0 else { return 0 }
        // Approximate the camera's vertical field of view (60 degrees).
        return 2 * min(max(depth, 0.1), 3) * tan(.pi / 6) / viewportHeight
    }

    static func screenAlignedTarget(anchorAtStart: SIMD3<Float>, fingerDelta: CGPoint,
                                    cameraTransform: simd_float4x4,
                                    metersPerPoint: Float) -> SIMD3<Float> {
        let cameraRight = cameraTransform.columns.0
        let cameraForward = cameraTransform.columns.2
        let cameraUp = cameraTransform.columns.1
        let right = simd_normalize(SIMD3<Float>(cameraRight.x, 0, cameraRight.z))
        var forward = SIMD3<Float>(-cameraForward.x, 0, -cameraForward.z)
        if simd_length_squared(forward) < 0.01 {
            forward = SIMD3<Float>(cameraUp.x, 0, cameraUp.z)
        }
        forward = simd_normalize(forward)
        let movement = right * Float(fingerDelta.x) * metersPerPoint
            - forward * Float(fingerDelta.y) * metersPerPoint
        // A near-horizontal camera can make projected depth feel exaggerated.
        // Keep one continuous drag within reach; the next drag can continue.
        let limited = simd_length(movement) > 0.6
            ? simd_normalize(movement) * 0.6 : movement
        return anchorAtStart
            + limited
    }

    static func verticalTarget(startHeight: Float, fingerDeltaY: Float,
                               metersPerPoint: Float) -> Float {
        startHeight - fingerDeltaY * metersPerPoint
    }
}

enum FurnitureScaleMath {
    static func resizedScale(originalScale: SIMD3<Float>, scaleAtStart: SIMD3<Float>,
                             gestureScale: Float) -> SIMD3<Float> {
        guard originalScale.x > 0, scaleAtStart.x > 0,
              gestureScale.isFinite, gestureScale > 0 else { return scaleAtStart }
        let factor = min(max(scaleAtStart.x / originalScale.x * gestureScale, 0.5), 2.5)
        return originalScale * SIMD3<Float>(repeating: factor)
    }
}

final class ARSessionManager: NSObject, ObservableObject {
    let arView = ARView(frame: .zero)
    var capturedRoom: CapturedRoom?
    @Published var errorMessage: String?

    /// World tracking isn't available in the simulator.
    let isARSupported = ARWorldTrackingConfiguration.isSupported

    @Published var placementFailed = false
    /// Movement mode of the currently selected piece; nil when none selected.
    @Published private(set) var selectedMovementMode: MovementMode?

    private(set) var usedFurnitureModels: [String] = []
    private var furnitureWrappers: [FurnitureWrapper] = []
    private var gesturesAttached = false
    private struct PanContext {
        let wrapper: FurnitureWrapper
        let worldAtStart: SIMD3<Float>
        let localAtStart: SIMD3<Float>
        let fingerAtStart: CGPoint
        let cameraTransform: simd_float4x4
        let metersPerPoint: Float
    }
    private var panContext: PanContext?
    private struct PinchContext {
        let wrapper: FurnitureWrapper
        let scaleAtStart: SIMD3<Float>
        let bottomAtStart: Float
    }
    private var pinchContext: PinchContext?

    // MARK: - Session lifecycle

    func start() {
        guard isARSupported else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.automaticallyConfigureSession = false
        arView.renderOptions.insert(.disableMotionBlur)
        arView.session.run(configuration)
    }

    func stop() {
        arView.session.pause()
    }

    func attachGesturesIfNeeded() {
        guard !gesturesAttached else { return }
        gesturesAttached = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        arView.addGestureRecognizer(pinchGesture)
    }

    // MARK: - Placement

    func loadAndPlace(named modelName: String) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
            errorMessage = "This furniture model is unavailable. Please choose another."
            return
        }

        do {
            let modelEntity = try ModelEntity.loadModel(contentsOf: modelURL)
            let width = modelEntity.visualBounds(relativeTo: nil).extents.x
            let target = RoomFurnitureModel.allCases.first { $0.resourceName == modelName }?.previewWidth ?? 1
            if width > 0 { modelEntity.scale *= SIMD3<Float>(repeating: target / width) }
            modelEntity.generateCollisionShapes(recursive: true)
            placeFurnitureInScene(modelEntity: modelEntity, modelName: modelName)


        } catch {
            errorMessage = "Could not load this furniture: \(error.localizedDescription)"
        }
    }

    private func placeFurnitureInScene(modelEntity: ModelEntity, modelName: String) {
        guard furnitureWrappers.count < 50 else {
            errorMessage = "Use at most 50 furniture pieces per room in the beta."
            return
        }
        // Raycast from screen center onto a horizontal plane.
        let raycastResults = arView.raycast(
            from: CGPoint(x: arView.bounds.midX, y: arView.bounds.midY),
            allowing: .estimatedPlane,
            alignment: .horizontal
        )

        guard let raycastResult = raycastResults.first else {
            placementFailed = true
            return
        }

        let worldPosition = SIMD3<Float>(
            raycastResult.worldTransform.columns.3.x,
            raycastResult.worldTransform.columns.3.y,
            raycastResult.worldTransform.columns.3.z
        )
        modelEntity.position = SIMD3(0, -modelEntity.visualBounds(relativeTo: nil).min.y, 0)

        let anchor = AnchorEntity(world: worldPosition)
        anchor.addChild(modelEntity)
        arView.scene.anchors.append(anchor)

        // Select the new piece; deselect everything else.
        let gestures = arView.installGestures([.rotation], for: modelEntity)
        let furnitureWrapper = FurnitureWrapper(entity: modelEntity, model: RoomFurnitureModel.allCases.first { $0.resourceName == modelName })
        for wrapper in furnitureWrappers {
            wrapper.isSelected = false
        }
        furnitureWrapper.isSelected = true
        furnitureWrapper.movementMode = .horizontal
        furnitureWrapper.gestureRecognizers = gestures
        furnitureWrappers.append(furnitureWrapper)

        usedFurnitureModels = furnitureWrappers.compactMap { $0.model?.resourceName }
        refreshSelectionState()
    }

    private func createInfoBox(for modelEntity: ModelEntity, modelName: String) -> Entity {
        let textMesh = MeshResource.generateText(
            "Furniture Info\nName: \(modelName)\nSize: \(modelEntity.scale)",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.03),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let textMaterial = SimpleMaterial(color: .black, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.scale = SIMD3<Float>(0.5, 0.5, 0.5)

        let textBounds = textMesh.bounds
        let textWidth = textBounds.max.x - textBounds.min.x
        let textHeight = textBounds.max.y - textBounds.min.y

        let boxMesh = MeshResource.generateBox(size: [textWidth * 0.6, textHeight * 0.6, 0.01])
        let boxMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [boxMaterial])
        boxEntity.position = [0, 0, -0.005]

        let textOffsetX = -textBounds.center.x * 0.5
        let textOffsetY = -textBounds.center.y * 0.5
        textEntity.position = [textOffsetX, textOffsetY, 0.005]

        let infoBoxEntity = Entity()
        infoBoxEntity.addChild(boxEntity)
        infoBoxEntity.addChild(textEntity)

        return infoBoxEntity
    }

    // MARK: - Selection & movement

    /// Double-tap locks/unlocks a piece (locking removes rotation and blocks drag/resize).
    @objc private func handleTapGesture(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        guard let tappedEntity = arView.entity(at: tapLocation),
              let tappedWrapper = furnitureWrappers.first(where: { $0.entity === tappedEntity }) else { return }

        for wrapper in furnitureWrappers {
            wrapper.isSelected = false
        }
        tappedWrapper.isSelected = true

        if !tappedWrapper.isLocked {
            tappedWrapper.isLocked = true
            for gesture in tappedWrapper.gestureRecognizers {
                arView.removeGestureRecognizer(gesture)
            }
            tappedWrapper.gestureRecognizers.removeAll()
        } else {
            tappedWrapper.isLocked = false
            tappedWrapper.gestureRecognizers = arView.installGestures([.rotation], for: tappedWrapper.entity)
        }

        refreshSelectionState()
    }

    /// Move in camera-aligned ground directions at the furniture's depth.
    /// A floor-plane intersection becomes unstable near the horizon, making
    /// a small finger motion send furniture far away or fail entirely.
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        let finger = sender.location(in: arView)
        switch sender.state {
        case .began:
            guard let wrapper = furnitureWrappers.first(where: { $0.isSelected && !$0.isLocked }) else { return }
            let start = wrapper.entity.position(relativeTo: nil)
            let distance = simd_distance(arView.cameraTransform.translation, start)
            panContext = PanContext(wrapper: wrapper,
                                    worldAtStart: start,
                                    localAtStart: wrapper.entity.position,
                                    fingerAtStart: finger,
                                    cameraTransform: arView.cameraTransform.matrix,
                                    metersPerPoint: FurnitureDragMath.verticalMetersPerPoint(
                                        depth: distance, viewportHeight: Float(arView.bounds.height)))
        case .changed:
            guard let context = panContext, !context.wrapper.isLocked else { return }
            if context.wrapper.movementMode == .vertical {
                var position = context.localAtStart
                position.y = FurnitureDragMath.verticalTarget(
                    startHeight: position.y,
                    fingerDeltaY: Float(finger.y - context.fingerAtStart.y),
                    metersPerPoint: context.metersPerPoint)
                context.wrapper.entity.position = position
            } else {
                let target = FurnitureDragMath.screenAlignedTarget(
                    anchorAtStart: context.worldAtStart,
                    fingerDelta: CGPoint(x: finger.x - context.fingerAtStart.x,
                                         y: finger.y - context.fingerAtStart.y),
                    cameraTransform: context.cameraTransform,
                    metersPerPoint: context.metersPerPoint)
                context.wrapper.entity.position = context.localAtStart + target - context.worldAtStart
            }
        case .ended, .cancelled, .failed:
            panContext = nil
        default:
            break
        }
    }

    /// Resize the selected piece relative to its size when this pinch began.
    /// Compensating its lowest point keeps the piece on the same floor plane.
    @objc private func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
        switch sender.state {
        case .began:
            let location = sender.location(in: arView)
            let hit = arView.entity(at: location)
            let wrapper = furnitureWrappers.first { candidate in
                var entity = hit
                while let current = entity {
                    if current === candidate.entity { return true }
                    entity = current.parent
                }
                return false
            } ?? furnitureWrappers.first(where: { $0.isSelected })
            guard let wrapper, !wrapper.isLocked else { return }
            furnitureWrappers.forEach { $0.isSelected = ($0 === wrapper) }
            refreshSelectionState()
            pinchContext = PinchContext(
                wrapper: wrapper,
                scaleAtStart: wrapper.entity.scale,
                bottomAtStart: wrapper.entity.visualBounds(relativeTo: wrapper.entity.parent).min.y)
        case .changed:
            guard let context = pinchContext, !context.wrapper.isLocked else { return }
            let entity = context.wrapper.entity
            entity.scale = FurnitureScaleMath.resizedScale(
                originalScale: context.wrapper.originalScale,
                scaleAtStart: context.scaleAtStart,
                gestureScale: Float(sender.scale))
            let bottom = entity.visualBounds(relativeTo: entity.parent).min.y
            entity.position.y += context.bottomAtStart - bottom
        case .ended, .cancelled, .failed:
            pinchContext = nil
        default:
            break
        }
    }

    func toggleMovementMode() {
        guard let selectedWrapper = furnitureWrappers.first(where: { $0.isSelected }) else { return }
        selectedWrapper.movementMode = (selectedWrapper.movementMode == .horizontal) ? .vertical : .horizontal
        refreshSelectionState()
    }

    private func refreshSelectionState() {
        selectedMovementMode = furnitureWrappers.first(where: { $0.isSelected })?.movementMode
    }

    func removeSelected() {
        guard let index = furnitureWrappers.firstIndex(where: { $0.isSelected }) else { return }
        let wrapper = furnitureWrappers.remove(at: index)
        wrapper.gestureRecognizers.forEach { arView.removeGestureRecognizer($0) }
        wrapper.entity.anchor?.removeFromParent()
        usedFurnitureModels = furnitureWrappers.compactMap { $0.model?.resourceName }
        refreshSelectionState()
    }

    func recenterSelected() {
        guard let wrapper = furnitureWrappers.first(where: { $0.isSelected }),
              let anchor = wrapper.entity.anchor as? AnchorEntity else { return }
        let point = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard let result = arView.raycast(from: point, allowing: .estimatedPlane,
                                          alignment: .horizontal).first else {
            placementFailed = true
            return
        }
        let position = result.worldTransform.columns.3
        let anchorWorld = anchor.position(relativeTo: nil)
        wrapper.entity.position = wrapper.originalPosition
            + SIMD3(position.x - anchorWorld.x,
                    position.y - anchorWorld.y,
                    position.z - anchorWorld.z)
        let floorHeightInAnchor = position.y - anchorWorld.y
        let bottomInAnchor = wrapper.entity.visualBounds(relativeTo: anchor).min.y
        wrapper.entity.position.y += floorHeightInAnchor - bottomInAnchor
    }

    func experience() throws -> RoomExperience {
        guard let capturedRoom else { throw RoomExperience.ValidationError.invalidScene }
        let pieces = furnitureWrappers.compactMap { wrapper -> PlacedFurniture? in
            guard let model = wrapper.model else { return nil }
            return PlacedFurniture(id: wrapper.instanceID, model: model,
                                   matrix: wrapper.entity.transformMatrix(relativeTo: nil))
        }
        return try RoomExperience(room: capturedRoom, furniture: pieces)
    }

    // MARK: - Capture

    func snapshot(completion: @escaping (UIImage?) -> Void) {
        arView.snapshot(saveToHDR: false) { image in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}

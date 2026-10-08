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
    static func horizontalTarget(anchorAtStart: SIMD3<Float>, hitAtStart: SIMD3<Float>,
                                 currentHit: SIMD3<Float>) -> SIMD3<Float> {
        anchorAtStart + currentHit - hitAtStart
    }

    static func verticalMetersPerPoint(depth: Float, viewportHeight: Float) -> Float {
        guard viewportHeight > 0 else { return 0 }
        // Approximate the camera's vertical field of view (60 degrees).
        return 2 * max(depth, 0.1) * tan(.pi / 6) / viewportHeight
    }

    static func verticalTarget(startHeight: Float, fingerDeltaY: Float,
                               metersPerPoint: Float) -> Float {
        startHeight - fingerDeltaY * metersPerPoint
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
        let anchor: AnchorEntity
        let anchorAtStart: SIMD3<Float>
        let fingerAtStart: CGPoint
        let hitAtStart: SIMD3<Float>?
        let metersPerPoint: Float
    }
    private var panContext: PanContext?

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
        arView.addGestureRecognizer(panGesture)
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
        let gestures = arView.installGestures([.rotation, .scale], for: modelEntity)
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

    /// Double-tap locks/unlocks a piece (locking removes rotate/scale gestures).
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
            tappedWrapper.gestureRecognizers = arView.installGestures([.rotation, .scale], for: tappedWrapper.entity)
        }

        refreshSelectionState()
    }

    /// Keep the grabbed point beneath the finger on the furniture's floor
    /// plane. A world-space ray/plane intersection avoids camera-relative
    /// reversals and arbitrary pixel-to-meter multipliers.
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        let finger = sender.location(in: arView)
        switch sender.state {
        case .began:
            guard let wrapper = furnitureWrappers.first(where: { $0.isSelected && !$0.isLocked }),
                  let anchor = wrapper.entity.anchor as? AnchorEntity else { return }
            let start = anchor.position(relativeTo: nil)
            let distance = simd_distance(arView.cameraTransform.translation, start)
            panContext = PanContext(wrapper: wrapper, anchor: anchor,
                                    anchorAtStart: start, fingerAtStart: finger,
                                    hitAtStart: floorHit(at: finger, height: start.y),
                                    metersPerPoint: FurnitureDragMath.verticalMetersPerPoint(
                                        depth: distance, viewportHeight: Float(arView.bounds.height)))
        case .changed:
            guard let context = panContext, !context.wrapper.isLocked else { return }
            if context.wrapper.movementMode == .vertical {
                var position = context.anchorAtStart
                position.y = FurnitureDragMath.verticalTarget(
                    startHeight: position.y,
                    fingerDeltaY: Float(finger.y - context.fingerAtStart.y),
                    metersPerPoint: context.metersPerPoint)
                context.anchor.setPosition(position, relativeTo: nil)
            } else if let initialHit = context.hitAtStart,
                      let currentHit = floorHit(at: finger, height: context.anchorAtStart.y) {
                let target = FurnitureDragMath.horizontalTarget(
                    anchorAtStart: context.anchorAtStart,
                    hitAtStart: initialHit, currentHit: currentHit)
                context.anchor.setPosition(target, relativeTo: nil)
            }
        case .ended, .cancelled, .failed:
            panContext = nil
        default:
            break
        }
    }

    private func floorHit(at point: CGPoint, height: Float) -> SIMD3<Float>? {
        var plane = matrix_identity_float4x4
        plane.columns.3.y = height
        return arView.unproject(point, ontoPlane: plane)
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

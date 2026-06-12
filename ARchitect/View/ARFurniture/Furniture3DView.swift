import UIKit
import ARKit
import RealityKit

class Furniture3DView: UIViewController {
    var modelName: String = ""
    var furnitureWrappers: [FurnitureWrapper] = []
    var toggleMovementButton: UIButton!
    var arView: ARView!
    var selectedFurniture: ModelEntity?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupUI()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        arView.addGestureRecognizer(panGesture)



    }

    func setupARView() {
        arView = ARView(frame: self.view.bounds)
        self.view.addSubview(arView)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal] // Enable horizontal plane detection
        configuration.environmentTexturing = .automatic // Enable environment texturing for better rendering
        arView.session.run(configuration)

        // Ensure RealityKit rendering is properly configured
        arView.automaticallyConfigureSession = false // Prevent ARView from overriding the session configuration
        arView.renderOptions.insert(.disableMotionBlur) // Optional: Disable motion blur for better performance
    }

    func setupUI() {
        let backArrowButton = UIButton(frame: CGRect(x: 10, y: 30, width: 50, height: 50))
        backArrowButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
        backArrowButton.tintColor = .systemGray
        backArrowButton.addTarget(self, action: #selector(goBackToEntryView), for: .touchUpInside)
        self.view.addSubview(backArrowButton)
        
        toggleMovementButton = UIButton(type: .system)
        toggleMovementButton.frame = CGRect(x: 20, y: 150, width: 44, height: 44)
        toggleMovementButton.tintColor = .white
        toggleMovementButton.backgroundColor = UIColor.systemOrange
        toggleMovementButton.layer.cornerRadius = 22
        toggleMovementButton.addTarget(self, action: #selector(toggleMovementMode), for: .touchUpInside)
        self.view.addSubview(toggleMovementButton)
        updateToggleButtonIcon() // Set the initial icon


    }

    @objc func goBackToEntryView() {
        self.dismiss(animated: true, completion: nil)
    }


    func placeFurnitureInScene(modelEntity: ModelEntity, modelName: String) {
        guard let currentFrame = arView.session.currentFrame else {
            print("Error: Unable to get the current AR frame.")
            return
        }

        // Perform a raycast to check for a horizontal plane
        let raycastResults = arView.raycast(from: CGPoint(x: arView.bounds.midX, y: arView.bounds.midY), allowing: .estimatedPlane, alignment: .horizontal)

        if let raycastResult = raycastResults.first {
            // Place the furniture at the raycast result's position
            let worldPosition = SIMD3<Float>(
                raycastResult.worldTransform.columns.3.x,
                raycastResult.worldTransform.columns.3.y,
                raycastResult.worldTransform.columns.3.z
            )
            modelEntity.position = worldPosition

            let anchor = AnchorEntity(world: worldPosition)
            anchor.addChild(modelEntity)
            arView.scene.anchors.append(anchor)
            selectedFurniture = modelEntity // Set the selected furniture for manipulation

            // Add gestures for translation, rotation, and scaling
            let gestures = arView.installGestures([.rotation, .scale], for: modelEntity)
            let furnitureWrapper = FurnitureWrapper(entity: modelEntity)
            for wrapper in furnitureWrappers {
                wrapper.isSelected = false
            }
            furnitureWrapper.isSelected = true
            furnitureWrapper.movementMode = .horizontal
            furnitureWrapper.gestureRecognizers = gestures

            furnitureWrappers.append(furnitureWrapper)
            updateToggleButtonIcon()

            print("Furniture placed in the scene at position: \(worldPosition).")
        } else {
            // Show an alert if no valid plane is detected
            showAlertForInsufficientSpace()
        }
    }

    func showAlertForInsufficientSpace() {
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: true) { [weak self] in
                self?.presentInsufficientSpaceAlert()
            }
        } else {
            presentInsufficientSpaceAlert()
        }
    }

    private func presentInsufficientSpaceAlert() {
        let alert = UIAlertController(
            title: "Insufficient Space",
            message: "It seems there isn't enough space in front of you to place the furniture. Please move to a more open area and try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }


    @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        if let tappedEntity = arView.entity(at: tapLocation),
           let tappedWrapper = furnitureWrappers.first(where: { $0.entity === tappedEntity }) {

            // 🔁 Mark all as unselected first
            for wrapper in furnitureWrappers {
                wrapper.isSelected = false
            }

            // ✅ Select the one tapped
            tappedWrapper.isSelected = true

            if !tappedWrapper.isLocked {
                tappedWrapper.isLocked = true
                for gesture in tappedWrapper.gestureRecognizers {
                    arView.removeGestureRecognizer(gesture)
                }
                tappedWrapper.gestureRecognizers.removeAll()
                print("\(tappedWrapper.entity.name) locked")
            } else {
                tappedWrapper.isLocked = false
                let newGestures = arView.installGestures([.rotation, .scale], for: tappedWrapper.entity)
                tappedWrapper.gestureRecognizers = newGestures
                print("\(tappedWrapper.entity.name) unlocked")
            }
        }
    }


    
    @objc func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        guard let wrapper = furnitureWrappers.first(where: { $0.isSelected && !$0.isLocked }) else { return }

        let location = sender.location(in: arView)
        let translation = sender.translation(in: arView)
        sender.setTranslation(.zero, in: arView) // Reset each cycle

        var position = wrapper.entity.position

        if wrapper.movementMode == .vertical {
            // Freeform vertical dragging
            let deltaY = Float(translation.y) * -0.004
            position.y += deltaY
        } else {
            // Try raycast first
            let results = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)

//            if let result = results.first {
//                position.x = result.worldTransform.columns.3.x
//                position.z = result.worldTransform.columns.3.z
//            } else {
//                // Fallback: freeform dragging
//                let deltaX = Float(translation.x) * 0.004
//                let deltaZ = Float(translation.y) * 0.004
//                position.x += deltaX
//                position.z += deltaZ
//            }
            // Fallback: freeform dragging
            let deltaX = Float(translation.x) * 0.004
            let deltaZ = Float(translation.y) * 0.004
            position.x += deltaX
            position.z += deltaZ
        }

        wrapper.entity.position = position
    }




    @objc func toggleMovementMode() {
        if let selectedWrapper = furnitureWrappers.first(where: { $0.isSelected }) {
            selectedWrapper.movementMode = (selectedWrapper.movementMode == .horizontal) ? .vertical : .horizontal
            print("🔄 \(selectedWrapper.entity.name) movement mode: \(selectedWrapper.movementMode == .horizontal ? "HORIZONTAL" : "VERTICAL")")
        } else {
            print("No selected object to toggle movement mode.")
        }
        updateToggleButtonIcon()
    }

    func updateToggleButtonIcon() {
        if let selectedWrapper = furnitureWrappers.first(where: { $0.isSelected }) {
            let imageName = selectedWrapper.movementMode == .horizontal
                ? "arrow.up.and.down.circle.fill"  // clicking will switch to vertical
                : "arrow.left.and.right.circle.fill" // clicking will switch to horizontal
            toggleMovementButton.setImage(UIImage(systemName: imageName), for: .normal)
        } else {
            toggleMovementButton.setImage(nil, for: .normal)
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Delaying to let ARKit detect the scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.loadAndPlaceFurniture()
        }
    }

    func loadAndPlaceFurniture() {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
            print("Error: Model \(modelName) not found.")
            return
        }

        do {
            let modelEntity = try ModelEntity.loadModel(contentsOf: modelURL)
            modelEntity.generateCollisionShapes(recursive: true)
            placeFurnitureInScene(modelEntity: modelEntity, modelName: modelName)
        } catch {
            print("Error loading model \(modelName): \(error)")
        }
    }




}


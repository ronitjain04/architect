import SwiftUI
import RealityKit
import ARKit


class EntityWrapper: Identifiable {
    let id = UUID()
    let entity: ModelEntity
    let config: VREnvironmentConfig.VRObjectConfig
    
    init(entity: ModelEntity, config: VREnvironmentConfig.VRObjectConfig) {
        self.entity = entity
        self.config = config
    }
}

struct ARSessionView2: View {
    @State private var arView = ARView(frame: .zero)
    let config: VREnvironmentConfig
    @State private var showInfoPanel: Bool = false
    @State private var selectedEntity: ModelEntity? = nil
    @State private var selectedObjectInfo: VREnvironmentConfig.VRObjectConfig? = nil
    
    var body: some View {
        ZStack {
            ARViewContainer2(
                config: config,
                arView: $arView,
                showInfoPanel: $showInfoPanel,
                selectedEntity: $selectedEntity,
                selectedObjectInfo: $selectedObjectInfo
            )
            
            if showInfoPanel, let objectInfo = selectedObjectInfo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(objectInfo.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                // Animate entity back down before closing panel
                                if let entity = selectedEntity {
                                    entity.position.y -= 0.25
                                }
                                showInfoPanel = false
                                selectedEntity = nil
                                selectedObjectInfo = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(objectInfo.description)
                        .font(.body)
                        .padding(.vertical, 4)
                    
                    if !objectInfo.properties.isEmpty {
                        Divider()
                        
                        ForEach(Array(objectInfo.properties.keys.sorted()), id: \.self) { key in
                            if let value = objectInfo.properties[key] {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(key)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    
                                    Text(value)
                                        .font(.footnote)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 300, height: 400)
                .background(Color.white)
                .foregroundColor(Color.black)
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding()
                .offset(x: 80, y: 100)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct ARViewContainer2: UIViewRepresentable {
    let config: VREnvironmentConfig
    @Binding var arView: ARView
    
    @Binding var showInfoPanel: Bool
    @Binding var selectedEntity: ModelEntity?
    @Binding var selectedObjectInfo: VREnvironmentConfig.VRObjectConfig?
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update logic if needed
    }
    
    func makeUIView(context: Context) -> ARView {
        // Configure AR view
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical] // Enable both horizontal and vertical plane detection
        configuration.environmentTexturing = .automatic // Better realism
        configuration.isLightEstimationEnabled = true // Better lighting
        
        arView.session.run(configuration)
        
        let anchor = AnchorEntity(world: .zero) // Use world origin for precise positioning
        arView.scene.anchors.append(anchor)
        
        // Set up coordinator with proper references
        context.coordinator.arView = arView
        context.coordinator.anchor = anchor
        
        // Load models - objects first, then environment
        loadObjects(context: context)
        loadEnvironment(context: context)
        
        // Set up tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(tapGesture)

        // Add debug visualization for tap location
        context.coordinator.setupDebugVisualization()
        
        return arView
    }
    
    private func loadEnvironment(context: Context) {
        // Load environment model last
        if let environmentModel = config.environmentModel {
            Task {
                do {
                    let environmentEntity = try await ModelEntity.loadModel(named: environmentModel)
                    environmentEntity.name = "environment"
                    environmentEntity.transform.scale = config.environmentScale
                    environmentEntity.position = config.environmentPosition
                    environmentEntity.generateCollisionShapes(recursive: true)
                    
                    context.coordinator.environmentEntity = environmentEntity
                    context.coordinator.anchor?.addChild(environmentEntity)
                } catch {
                    print("Failed to import environment model: \(error)")
                }
            }
        }
    }
    
    private func loadObjects(context: Context) {
        // Load object models first
        for objectConfig in config.objects {
            Task {
                do {
                    let objectEntity = try await ModelEntity.loadModel(named: objectConfig.modelName)
                    objectEntity.name = objectConfig.displayName
                    objectEntity.transform.scale = objectConfig.scale
                    objectEntity.position = objectConfig.position
                    
                    // Create a larger collision shape for better hit detection
                    let boundingBox = objectEntity.visualBounds(relativeTo: nil)
                    let size = boundingBox.extents
                    let expanded = size * 1.2 // 20% larger for easier selection
                    
                    // Create a collision shape slightly larger than the actual model
                    objectEntity.collision = CollisionComponent(
                        shapes: [.generateBox(size: expanded)],
                        mode: .trigger,
                        filter: CollisionFilter(group: .all, mask: .all)
                    )
                    
                    context.coordinator.anchor?.addChild(objectEntity)
                    
                    // Store object entity for interaction
                    let entityWrapper = EntityWrapper(entity: objectEntity, config: objectConfig)
                    context.coordinator.entities.append(entityWrapper)
                    
                    print("Loaded object: \(objectConfig.displayName) at position: \(objectConfig.position)")
                } catch {
                    print("Failed to import model \(objectConfig.modelName): \(error)")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARViewContainer2
        weak var arView: ARView?
        var anchor: AnchorEntity?
        var entities: [EntityWrapper] = []
        var environmentEntity: ModelEntity?
        var tapIndicator: ModelEntity?
        
        init(_ parent: ARViewContainer2) {
            self.parent = parent
        }
        
        func setupDebugVisualization() {
            // Create a small sphere to show tap location
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.02),
                                    materials: [SimpleMaterial(color: .red, isMetallic: false)])
            sphere.name = "tapIndicator"
            self.tapIndicator = sphere
            
            // Add to scene but initially hide it
            anchor?.addChild(sphere)
            sphere.isEnabled = false
        }
        
        func showTapIndicator(at position: SIMD3<Float>) {
            guard let tapIndicator = tapIndicator else { return }
            
            // Show the tap indicator at the position
            tapIndicator.position = position
            tapIndicator.isEnabled = true
        }
        
        @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            // If a panel is already open, close it
            if parent.showInfoPanel {
                // Animate entity back down before closing panel
                if let entity = parent.selectedEntity {
                    entity.position.y -= 0.25
                }
                tapIndicator!.isEnabled = false
                
                // Update parent state
                DispatchQueue.main.async {
                    self.parent.showInfoPanel = false
                    self.parent.selectedEntity = nil
                    self.parent.selectedObjectInfo = nil
                }
                return
            }
            
            // Handle opening a panel for a tapped entity
            let tapLocation = sender.location(in: arView)
            
            // Method 1: Direct entity hit testing
            if let tappedEntity = arView.entity(at: tapLocation) {
                print("Tapped entity: \(tappedEntity.name)")
                
                // Skip if it's the environment entity or tap indicator
                if tappedEntity === environmentEntity ||
                   tappedEntity === tapIndicator ||
                   tappedEntity.name == "tapIndicator" ||
                   tappedEntity.name == "environment" ||
                   environmentEntity?.children.contains(where: { $0 === tappedEntity }) == true {
                    print("Skipping environment entity or tap indicator")

                    // Try raycast as fallback
                    performRaycast(from: tapLocation)
                    return
                }
                
                // Find the matching entity wrapper
                if let entityWrapper = entities.first(where: {
                    $0.entity === tappedEntity ||
                    $0.entity.children.contains(where: { $0 === tappedEntity })
                }) {
                    print("Selected object: \(entityWrapper.config.displayName)")
                    
                    // Animate the entity up
                    entityWrapper.entity.position.y += 0.25
                    
                    // Update UI state
                    DispatchQueue.main.async {
                        self.parent.selectedObjectInfo = entityWrapper.config
                        self.parent.selectedEntity = entityWrapper.entity
                        self.parent.showInfoPanel = true
                    }
                    return
                }
            }
            
            // Method 2: Raycast-based entity selection as fallback
            performRaycast(from: tapLocation)
        }
        
        func performRaycast(from tapLocation: CGPoint) {
            guard let arView = arView else { return }
            
            // Convert tap location to ray
            let hitTestResults = arView.hitTest(tapLocation, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            
            guard let hitResult = hitTestResults.first else {
                // Fallback to standard raycast if ARKit hit test fails
                let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any)
                guard let firstResult = results.first else { return }
                
                // Convert the raycast hit to a position in world space
                let worldPosition = firstResult.worldTransform.columns.3
                let hitPosition = SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z)
                
                // Show debug indicator
                showTapIndicator(at: hitPosition)
                
                // Find the closest entity to the hit point
                findClosestEntity(to: hitPosition)
                return
            }
            
            // Convert hit result to world coordinates
            let hitPosition = SIMD3<Float>(
                hitResult.worldTransform.columns.3.x,
                hitResult.worldTransform.columns.3.y,
                hitResult.worldTransform.columns.3.z
            )
            
            // Show debug indicator
            showTapIndicator(at: hitPosition)
            
            // Find closest entity
            findClosestEntity(to: hitPosition)
        }
        
        func findClosestEntity(to position: SIMD3<Float>) {
            // Find the closest object to the hit point
            var closestEntity: EntityWrapper? = nil
            var closestDistance: Float = 10 // Maximum distance threshold - reduced for better precision
            
            for entityWrapper in entities {
                let distance = simd_distance(entityWrapper.entity.position, position)
                print("Distance to \(entityWrapper.config.displayName): \(distance)")
                if distance < closestDistance {
                    closestEntity = entityWrapper
                    closestDistance = distance
                }
            }
            
            if let entityWrapper = closestEntity {
                print("Selected closest object: \(entityWrapper.config.displayName) at distance: \(closestDistance)")
                
                // Animate the entity up
                entityWrapper.entity.position.y += 0.25
                
                // Update UI state
                DispatchQueue.main.async {
                    self.parent.selectedObjectInfo = entityWrapper.config
                    self.parent.selectedEntity = entityWrapper.entity
                    self.parent.showInfoPanel = true
                }
            }
        }
    }
}

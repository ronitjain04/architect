import SwiftUI
import RealityKit
import ARKit

class CubeWrapper: Identifiable {
    let id = UUID()
    let entity: ModelEntity
    var isLocked: Bool = false
    var gestureRecognizers: [UIGestureRecognizer] = []
    
    init(entity: ModelEntity) {
        self.entity = entity
    }
}

struct ARSessionView: View {
    @State private var arView = ARView(frame: .zero)
    @State private var selectedColor: UIColor? = nil
    @State private var showMenu = false

    let colors: [(name: String, color: UIColor)] = [
        ("Gray", .gray),
        ("Red", .red),
        ("Green", .green),
        ("Blue", .blue),
        ("Yellow", .yellow)
    ]
    
    var body: some View {
        ZStack {
            ARViewContainer(arView: $arView, selectedColor: $selectedColor)
                .edgesIgnoringSafeArea(.all)
            if showMenu {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Cube Color:")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    
                    ForEach(colors, id: \.name) { color in
                        Button(action: {
                            selectedColor = color.color
                        }) {
                            HStack {
                                Rectangle()
                                    .fill(Color(color.color))
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                                Text(color.name)
                                    .foregroundColor(.white)
                                    .font(.body)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                    Spacer()
                }
                .frame(width: 200)
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
                .padding()
                .transition(.move(edge: .leading))
            }
            
            Button(action: {
                withAnimation {
                    showMenu.toggle()
                }
            }) {
                Image(systemName: "line.horizontal.3")
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
            }
            .position(x: 30, y: 50)
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var arView: ARView
    @Binding var selectedColor: UIColor?
    
    func makeUIView(context: Context) -> ARView {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        
        let anchor = AnchorEntity(plane: .horizontal)
        arView.scene.anchors.append(anchor)
        context.coordinator.arView = arView
        context.coordinator.anchor = anchor
        context.coordinator.addCube(with: .gray)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(tapGesture)


        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if let color = selectedColor {
            context.coordinator.addCube(with: color)
            DispatchQueue.main.async {
                self.selectedColor = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARViewContainer
        weak var arView: ARView?
        var anchor: AnchorEntity?
        var cubes: [CubeWrapper] = []
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        func addCube(with color: UIColor) {
            guard let anchor = anchor, let arView = arView else { return }
            
            let offset: Float = Float(cubes.count) * 0.15
            let modelEntity = ModelEntity(
                mesh: .generateBox(size: 0.1),
                materials: [SimpleMaterial(color: color, isMetallic: false)]
            )
            modelEntity.name = "Cube \(cubes.count + 1)"
            modelEntity.position = [offset, 0.05, 0]
            modelEntity.generateCollisionShapes(recursive: true)
            
            let infoBox = ARViewContainer.createInfoBox(color: color)
            infoBox.position = SIMD3<Float>(0, 0.1, 0)
            modelEntity.addChild(infoBox)
            
            anchor.addChild(modelEntity)
            
            let gestures = arView.installGestures([.translation, .rotation, .scale], for: modelEntity)
            let cubeWrapper = CubeWrapper(entity: modelEntity)
            cubeWrapper.gestureRecognizers = gestures
            cubes.append(cubeWrapper)
        }
        
        @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            if let tappedEntity = arView.entity(at: tapLocation) {
                if let cubeWrapper = cubes.first(where: { $0.entity === tappedEntity || $0.entity.children.contains(where: { $0 === tappedEntity }) }) {
                    if !cubeWrapper.isLocked {
                        cubeWrapper.isLocked = true
                        for gesture in cubeWrapper.gestureRecognizers {
                            arView.removeGestureRecognizer(gesture)
                        }
                        cubeWrapper.gestureRecognizers.removeAll()
                        print("\(cubeWrapper.entity.name) locked")
                    } else {
                        cubeWrapper.isLocked = false
                        let newGestures = arView.installGestures([.translation, .rotation, .scale], for: cubeWrapper.entity)
                        cubeWrapper.gestureRecognizers = newGestures
                        print("\(cubeWrapper.entity.name) unlocked")
                    }
                }
            }

        }
    }
    
    static func createInfoBox(color: UIColor) -> Entity {
        let textMesh = MeshResource.generateText(
            "Cube Info\nColor: \(color.accessibilityName)\nSize: 0.10m",
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
}

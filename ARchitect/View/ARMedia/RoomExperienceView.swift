import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import FirebaseFirestore

struct RoomExperienceView: View {
    let data: Data?
    var postID: String? = nil
    @State private var furniture: [PlacedFurniture] = []
    @State private var scene: SCNScene?
    @State private var errorMessage: String?
    @State private var showAR = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if let scene {
                VStack(spacing: 12) {
                    SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                    if !furniture.isEmpty {
                        Text(furniture.map { $0.model.title }.joined(separator: " · "))
                            .font(.caption).lineLimit(2).padding(.horizontal)
                    }
                    Text("Drag to orbit · Pinch to zoom")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Place room in AR", systemImage: "arkit") { showAR = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!ARWorldTrackingConfiguration.isSupported)
                        .padding()
                }
            } else if let errorMessage {
                ContentUnavailableView("Unable to open this room", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView("Rebuilding the room…")
            }
        }
        .navigationTitle("Shared room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            guard scene == nil else { return }
            do {
                let payload: Data
                if let data { payload = data }
                else if let postID {
                    let snapshot = try await Firestore.firestore().collection("posts").document(postID)
                        .collection("experience").document("scene").getDocument()
                    guard let value = snapshot.data()?["sceneData"] as? Data else {
                        throw RoomExperience.ValidationError.invalidScene
                    }
                    payload = value
                } else { throw RoomExperience.ValidationError.invalidScene }
                let experience = try RoomExperience.decode(payload)
                furniture = experience.furniture
                scene = try experience.makeScene()
            } catch { errorMessage = error.localizedDescription }
        }
        .fullScreenCover(isPresented: $showAR) {
            if let scene { RoomARPreview(scene: scene) }
        }
    }
}

private struct RoomARPreview: View {
    let scene: SCNScene
    @Environment(\.dismiss) private var dismiss
    @State private var fullSize = false
    @State private var cameraAllowed = false
    @State private var checkedCamera = false

    var body: some View {
        ZStack(alignment: .top) {
            if cameraAllowed {
                RoomARContainer(source: scene, fullSize: fullSize).ignoresSafeArea()
            } else if checkedCamera {
                ContentUnavailableView("Camera access needed", systemImage: "camera", description: Text("Enable camera access for ARchitect in Settings."))
            } else { ProgressView() }
            VStack {
                HStack {
                    Button("Close") { dismiss() }
                    Spacer()
                    Toggle("Full size", isOn: $fullSize).fixedSize()
                }.padding().background(.regularMaterial)
                Spacer()
                Text("Tap a detected floor to place the room. \(fullSize ? "Life-size" : "Tabletop (1:10)") reconstruction.")
                    .multilineTextAlignment(.center).padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
            }
        }
        .task {
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            checkedCamera = true
        }
    }
}

private struct RoomARContainer: UIViewRepresentable {
    let source: SCNScene
    let fullSize: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        let placement = SCNNode()
        let content = source.rootNode.clone()
        // Put the model's bottom center at the tapped floor, independent of scan origin.
        let bounds = content.boundingBox
        content.position = SCNVector3(-(bounds.min.x + bounds.max.x)/2, -bounds.min.y, -(bounds.min.z + bounds.max.z)/2)
        placement.addChildNode(content)
        placement.isHidden = true
        placement.scale = SCNVector3(0.1, 0.1, 0.1)
        view.scene.rootNode.addChildNode(placement)
        context.coordinator.placement = placement
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.place(_:)))
        view.addGestureRecognizer(tap)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration)
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        let scale: Float = fullSize ? 1 : 0.1
        context.coordinator.placement?.scale = SCNVector3(scale, scale, scale)
    }
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) { uiView.session.pause() }
    final class Coordinator: NSObject {
        var placement: SCNNode?
        @objc func place(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? ARSCNView,
                  let query = view.raycastQuery(from: gesture.location(in: view), allowing: .estimatedPlane, alignment: .horizontal),
                  let result = view.session.raycast(query).first else { return }
            let p = result.worldTransform.columns.3
            placement?.simdPosition = SIMD3(p.x, p.y, p.z)
            placement?.isHidden = false
        }
    }
}

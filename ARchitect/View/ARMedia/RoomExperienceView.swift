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
                VStack(spacing: 0) {
                    SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Explore the room")
                            .font(AppFont.title3)
                            .foregroundStyle(Color.appText)
                        Text("Drag to turn the room · Pinch to zoom")
                            .font(AppFont.callout)
                            .foregroundStyle(Color.appTextSecondary)
                        if !furniture.isEmpty {
                            Text(furniture.map { $0.model.title }.joined(separator: " · "))
                                .font(AppFont.caption)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(2)
                        }
                        Button("View in your space", systemImage: "arkit") { showAR = true }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!ARWorldTrackingConfiguration.isSupported)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appBackground)
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
            Color.appBackground.ignoresSafeArea()
            if cameraAllowed {
                RoomARContainer(source: scene, fullSize: fullSize).ignoresSafeArea()
            } else if checkedCamera {
                ContentUnavailableView("Camera access needed", systemImage: "camera", description: Text("Enable camera access for ARchitect in Settings."))
            } else { ProgressView() }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.appSurfaceAlt, in: Circle())
                    }
                    .accessibilityLabel("Close AR preview")
                    Spacer()
                    Text("View in your space")
                        .font(AppFont.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .foregroundStyle(Color.appText)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)
                .background(Color.appBackground.opacity(0.97))
                Spacer()
                VStack(spacing: AppSpacing.md) {
                    Text("Tap a detected floor to place the room.")
                        .font(AppFont.callout)
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                    Picker("Room size", selection: $fullSize) {
                        Text("Tabletop").tag(false)
                        Text("Full size").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(AppSpacing.lg)
                .background(Color.appBackground.opacity(0.97), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(AppSpacing.md)
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

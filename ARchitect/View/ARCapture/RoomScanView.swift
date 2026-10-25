import SwiftUI
import RoomPlan
import ARKit
import AVFoundation
import SceneKit

struct RoomScanView: View {
    @Environment(\.scenePhase) private var scenePhase
    let session: ARSession
    let onScanned: (CapturedRoom) -> Void
    let onCancel: () -> Void
    @State private var cameraAllowed = false
    @State private var cameraChecked = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var captureView: RoomCaptureView?
    @State private var scanID = UUID()
    @State private var detectedWalls = 0
    @State private var guidance = "Point at a well-lit wall and move slowly."
    @State private var scannedRoom: CapturedRoom?
    @State private var previewScene: SCNScene?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if let previewScene {
                SceneView(scene: previewScene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                    .ignoresSafeArea()
            } else if RoomCaptureSession.isSupported && cameraAllowed {
                Scanner(session: session, view: $captureView,
                        onProgress: { detectedWalls = $0 },
                        onGuidance: { guidance = $0 }) { result in
                    isProcessing = false
                    switch result {
                    case .success(let room):
                        do {
                            let experience = try RoomExperience(room: room, furniture: [])
                            previewScene = try experience.makeScene()
                            scannedRoom = room
                        } catch { errorMessage = error.localizedDescription }
                    case .failure(let error): errorMessage = error.localizedDescription
                    }
                }
                .id(scanID)
                .ignoresSafeArea()
            }
            VStack(spacing: 16) {
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Text("Scan your room").font(.headline)
                    Spacer()
                    if let scannedRoom {
                        Button("Use room") { onScanned(scannedRoom) }
                    } else {
                        Button("Done") {
                            isProcessing = true
                            captureView?.captureSession.stop(pauseARSession: false)
                        }
                        .disabled(captureView == nil || detectedWalls == 0 || isProcessing || errorMessage != nil)
                    }
                }
                .padding().background(.regularMaterial)
                Spacer()
                if !RoomCaptureSession.isSupported {
                    ContentUnavailableView("Room scanning needs LiDAR", systemImage: "viewfinder", description: Text("Use a compatible iPhone Pro to create a room. You can still explore shared rooms on this device."))
                } else if cameraChecked && !cameraAllowed {
                    ContentUnavailableView("Camera access needed", systemImage: "camera", description: Text("Allow camera access in Settings to scan your room."))
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } else if scannedRoom != nil {
                    VStack(spacing: 10) {
                        Text("Your room is ready")
                            .font(.headline)
                        Text("Drag to inspect the scan. Pinch to zoom, then tap Use room to add furniture.")
                            .multilineTextAlignment(.center)
                        Button("Scan again") { resetScan() }
                            .buttonStyle(.bordered)
                    }
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if isProcessing {
                    ProgressView("Building your room…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if let errorMessage {
                    Text(errorMessage).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Button("Scan again") { resetScan() }.buttonStyle(.borderedProminent)
                } else {
                    Text(detectedWalls == 0
                         ? "\(guidance) No walls detected yet."
                         : "\(detectedWalls) wall\(detectedWalls == 1 ? "" : "s") detected. \(guidance) Tap Done when the room is complete.")
                        .multilineTextAlignment(.center).padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                Spacer().frame(height: 30)
            }.padding(.horizontal)
        }
        .task { await refreshCameraAccess() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshCameraAccess() } }
        }
    }

    private func refreshCameraAccess() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
        cameraChecked = true
    }

    private func resetScan() {
        errorMessage = nil
        scannedRoom = nil
        previewScene = nil
        captureView = nil
        detectedWalls = 0
        guidance = "Point at a well-lit wall and move slowly."
        scanID = UUID()
    }
}

private struct Scanner: UIViewRepresentable {
    let session: ARSession
    @Binding var view: RoomCaptureView?
    let onProgress: (Int) -> Void
    let onGuidance: (String) -> Void
    let completion: (Result<CapturedRoom, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress, onGuidance: onGuidance, completion: completion)
    }
    func makeUIView(context: Context) -> RoomCaptureView {
        // RoomPlan requires a supplied ARSession to already be running with
        // ARWorldTrackingConfiguration before creating RoomCaptureView.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration)
        let capture = RoomCaptureView(frame: .zero, arSession: session)
        capture.delegate = context.coordinator
        capture.captureSession.delegate = context.coordinator
        capture.captureSession.run(configuration: .init())
        DispatchQueue.main.async { view = capture }
        return capture
    }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop(pauseARSession: false)
        uiView.captureSession.delegate = nil
        uiView.delegate = nil
    }

    @objc(ARchitectRoomScanCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        let onProgress: (Int) -> Void
        let onGuidance: (String) -> Void
        let completion: (Result<CapturedRoom, Error>) -> Void
        private var delivered = false
        init(onProgress: @escaping (Int) -> Void, onGuidance: @escaping (String) -> Void,
             completion: @escaping (Result<CapturedRoom, Error>) -> Void) {
            self.onProgress = onProgress
            self.onGuidance = onGuidance
            self.completion = completion
        }
        required init?(coder: NSCoder) { nil }
        func encode(with coder: NSCoder) {}
        func finish(_ result: Result<CapturedRoom, Error>) {
            guard !delivered else { return }
            delivered = true
            DispatchQueue.main.async { self.completion(result) }
        }
        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            if let error { finish(.failure(error)); return false }
            return true
        }
        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error { finish(.failure(error)) }
            else {
                do {
                    _ = try RoomExperience(room: processedResult, furniture: [])
                    finish(.success(processedResult))
                } catch { finish(.failure(error)) }
            }
        }
        func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
            DispatchQueue.main.async { self.onProgress(room.walls.count) }
        }
        func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
            let message: String
            switch instruction {
            case .moveCloseToWall: message = "Move closer to a wall."
            case .moveAwayFromWall: message = "Move farther from the wall."
            case .slowDown: message = "Move your phone more slowly."
            case .turnOnLight: message = "Turn on more lights."
            case .lowTexture: message = "Aim at a corner or textured surface."
            case .normal: message = "Keep scanning the walls and floor."
            @unknown default: message = "Move slowly around the room."
            }
            DispatchQueue.main.async { self.onGuidance(message) }
        }
        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
            if let error { finish(.failure(error)) }
        }
    }
}

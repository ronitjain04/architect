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
                        onProgress: { detectedWalls = $0 }) { result in
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
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.appSurfaceAlt, in: Circle())
                    }
                    .accessibilityLabel("Close room scan")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scannedRoom == nil ? "STEP 1 OF 3" : "STEP 2 OF 3")
                            .font(AppFont.inter(11, .semibold))
                            .foregroundStyle(Color.appTextSecondary)
                        Text(scannedRoom == nil ? "Scan your room" : "Preview your room")
                            .font(AppFont.title3)
                            .foregroundStyle(Color.appText)
                    }
                    Spacer()
                    if scannedRoom == nil && detectedWalls > 0 {
                        Text("\(detectedWalls) wall\(detectedWalls == 1 ? "" : "s")")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.appPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.appSurfaceAlt, in: Capsule())
                    }
                }
                .foregroundStyle(Color.appPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)
                .background(Color.appBackground.opacity(0.97))

                Spacer()

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if !RoomCaptureSession.isSupported {
                        statusMessage("Room scanning needs LiDAR", detail: "Use a compatible iPhone Pro to create a room.", icon: "viewfinder")
                    } else if cameraChecked && !cameraAllowed {
                        statusMessage("Camera access needed", detail: "Allow camera access in Settings to scan your room.", icon: "camera")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.buttonStyle(PrimaryButtonStyle())
                    } else if let scannedRoom {
                        statusMessage("Your room is ready", detail: "Drag to look around. Pinch to zoom, then continue to add furniture.", icon: "checkmark.circle.fill")
                        Button("Continue to furniture") { onScanned(scannedRoom) }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Scan again") { resetScan() }
                            .buttonStyle(SecondaryButtonStyle())
                    } else if isProcessing {
                        HStack(spacing: AppSpacing.md) {
                            ProgressView().tint(.appPrimary)
                            Text("Building your room preview…")
                                .font(AppFont.body)
                                .foregroundStyle(Color.appText)
                        }
                    } else if let errorMessage {
                        statusMessage("Couldn't build the room", detail: errorMessage, icon: "exclamationmark.triangle")
                        Button("Scan again") { resetScan() }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        statusMessage(detectedWalls == 0 ? "Find your first wall" : "Keep going around the room",
                                      detail: "Move slowly and scan each wall, corner, and the floor.", icon: "viewfinder")
                        Button {
                            isProcessing = true
                            captureView?.captureSession.stop(pauseARSession: false)
                        } label: {
                            Text("Preview scan")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(captureView == nil || detectedWalls == 0)
                        .opacity(detectedWalls == 0 ? 0.5 : 1)
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: AppRadius.lg, topTrailingRadius: AppRadius.lg)
                        .fill(Color.appBackground.opacity(0.97))
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .task { await refreshCameraAccess() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshCameraAccess() } }
        }
    }

    private func statusMessage(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(AppFont.headline).foregroundStyle(Color.appText)
                Text(detail).font(AppFont.callout).foregroundStyle(Color.appTextSecondary)
            }
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
        scanID = UUID()
    }
}

private struct Scanner: UIViewRepresentable {
    let session: ARSession
    @Binding var view: RoomCaptureView?
    let onProgress: (Int) -> Void
    let completion: (Result<CapturedRoom, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress, completion: completion)
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
        var captureConfiguration = RoomCaptureSession.Configuration()
        // RoomCaptureView's built-in coaching pill appears behind our scan
        // header. The bottom panel supplies one clear instruction instead.
        captureConfiguration.isCoachingEnabled = false
        capture.captureSession.run(configuration: captureConfiguration)
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
        let completion: (Result<CapturedRoom, Error>) -> Void
        private var delivered = false
        init(onProgress: @escaping (Int) -> Void,
             completion: @escaping (Result<CapturedRoom, Error>) -> Void) {
            self.onProgress = onProgress
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
        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
            if let error { finish(.failure(error)) }
        }
    }
}

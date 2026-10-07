import SwiftUI
import RoomPlan
import ARKit
import AVFoundation

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

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if RoomCaptureSession.isSupported && cameraAllowed {
                Scanner(session: session, view: $captureView) { result in
                    isProcessing = false
                    switch result {
                    case .success(let room): onScanned(room)
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
                    Button("Done") {
                        isProcessing = true
                        captureView?.captureSession.stop(pauseARSession: false)
                    }
                    .disabled(captureView == nil || isProcessing || errorMessage != nil)
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
                } else if isProcessing {
                    ProgressView("Building your room…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if let errorMessage {
                    Text(errorMessage).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Button("Scan again") {
                        self.errorMessage = nil
                        captureView = nil
                        scanID = UUID()
                    }.buttonStyle(.borderedProminent)
                } else {
                    Text("Move slowly to capture every wall, door, and window. Tap Done when the room is complete.")
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
}

private struct Scanner: UIViewRepresentable {
    let session: ARSession
    @Binding var view: RoomCaptureView?
    let completion: (Result<CapturedRoom, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIView(context: Context) -> RoomCaptureView {
        let capture = RoomCaptureView(frame: .zero, arSession: session)
        capture.delegate = context.coordinator
        capture.captureSession.run(configuration: .init())
        DispatchQueue.main.async { view = capture }
        return capture
    }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop(pauseARSession: false)
        uiView.delegate = nil
    }

    @objc(ARchitectRoomScanCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        let completion: (Result<CapturedRoom, Error>) -> Void
        private var delivered = false
        init(completion: @escaping (Result<CapturedRoom, Error>) -> Void) { self.completion = completion }
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
    }
}

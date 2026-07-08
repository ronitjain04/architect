//
//  ARCaptureView.swift
//  ARchitect
//
//  The AR create screen — replaces the UIKit ARViewController. Renders the
//  live AR session with SwiftUI chrome: back, add-furniture, movement toggle,
//  and a shutter that captures a snapshot and opens the New post composer.
//

import SwiftUI
import RealityKit

struct ARCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ARSessionManager()
    @State private var showGallery = false
    @State private var capturedImage: UIImage?
    @State private var showNewPost = false

    var body: some View {
        ZStack {
            if manager.isARSupported {
                ARViewContainer(manager: manager)
                    .ignoresSafeArea()
            } else {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "arkit")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(.appTextSecondary)
                    Text("AR needs a real device")
                        .font(AppFont.inter(17, .semibold))
                        .foregroundColor(.appText)
                    Text("World tracking isn't available in the simulator. You can still capture and share.")
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            }

            // Chrome
            VStack {
                HStack {
                    circleButton(icon: "chevron.left") { dismiss() }

                    Spacer()

                    if let mode = manager.selectedMovementMode {
                        circleButton(icon: mode == .horizontal
                                     ? "arrow.up.and.down.circle.fill"
                                     : "arrow.left.and.right.circle.fill") {
                            manager.toggleMovementMode()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

                Spacer()

                // Bottom controls: add furniture + shutter.
                ZStack {
                    HStack {
                        Button { showGallery = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chair.fill")
                                Text("Furniture")
                                    .font(AppFont.inter(14, .semibold))
                            }
                            .foregroundColor(.appOnPrimary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Capsule().fill(Color.appPrimary.opacity(0.92)))
                        }
                        Spacer()
                    }

                    // Shutter
                    Button {
                        manager.snapshot { image in
                            guard let image else { return }
                            capturedImage = image
                            showNewPost = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 6)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .onAppear {
            manager.attachGesturesIfNeeded()
            manager.start()
        }
        .onDisappear { manager.stop() }
        .sheet(isPresented: $showGallery) {
            FurnitureGallerySheet { modelName in
                showGallery = false
                manager.loadAndPlace(named: modelName)
            }
        }
        .fullScreenCover(isPresented: $showNewPost) {
            if let capturedImage {
                NewPostView(
                    image: capturedImage,
                    usedFurniture: manager.usedFurnitureModels,
                    onShared: { dismiss() }
                )
            }
        }
        .alert("Insufficient space", isPresented: $manager.placementFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There isn't enough open floor in front of you to place the furniture. Move to a more open area and try again.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
    }
}

/// Thin adapter hosting RealityKit's ARView — SwiftUI has no native AR view.
private struct ARViewContainer: UIViewRepresentable {
    let manager: ARSessionManager

    func makeUIView(context: Context) -> ARView {
        manager.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Themed picker for the bundled furniture models.
struct FurnitureGallerySheet: View {
    var onSelect: (String) -> Void

    // Bundled .usdz models (display name derived from the file name).
    private let models = ["Curved Comfort Chair", "Arm chair", "Grey Couch"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Add furniture")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm + 4)

            Divider().background(Color.appDivider)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(models, id: \.self) { model in
                        Button {
                            onSelect(model)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle().fill(Color.appSurfaceAlt)
                                    Image(systemName: "chair.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.appPrimary)
                                }
                                .frame(width: 44, height: 44)

                                Text(model.capitalized)
                                    .font(AppFont.inter(15, .regular))
                                    .foregroundColor(.appText)

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }

                        Divider()
                            .background(Color.appDivider)
                            .padding(.leading, 76)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

#Preview {
    ARCaptureView()
}

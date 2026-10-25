import SwiftUI
import RealityKit

struct FurnitureState {
    var parentContainer: Entity?         // Scaled and rotated
    var rotatingChild: Entity?           // Auto-rotated in virtual mode
    var isZoomed: Bool = false
}

struct FurnitureTryOutView: View {
    var model: RoomFurnitureModel = .comfortChair
    @State private var loadError: String?
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var state = FurnitureState()
    @State private var useWorldTracking = false
    @State private var initialized = false
    
    @State private var dragRotation: Float = 0      // Total accumulated angle
    @GestureState private var dragDelta: Float = 0  // Current gesture offset
    
    @State private var arRotationAngle: Float = 0
    @GestureState private var currentRotation: Angle = .degrees(0)
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.appText)
                            .frame(width: 44, height: 44)
                            .background(Color.appSurfaceAlt, in: Circle())
                    }
                    .accessibilityLabel("Close furniture preview")
                    Spacer()
                    Text(model.title)
                        .font(AppFont.headline)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appBackground.opacity(0.97))
                RealityView { content in
                    if !initialized {
                        content.camera = .virtual
                        initialized = true
                    }
                    
                    let anchor = AnchorEntity(world: SIMD3<Float>(0, -1.0, -1.5))
                    content.add(anchor)
                    
                    let parentContainer = Entity()
                    let rotatingChild = Entity()
                    
                    anchor.addChild(parentContainer)
                    parentContainer.addChild(rotatingChild)
                    
                    state.parentContainer = parentContainer
                    state.rotatingChild = rotatingChild
                    
                    if let couch = try? await ModelEntity(named: model.resourceName) {
                        couch.name = "armChair"
                        let width = couch.visualBounds(relativeTo: nil).extents.x
                        if width > 0 { couch.scale *= SIMD3<Float>(repeating: model.previewWidth / width) }
                        couch.components.set(InputTargetComponent())
                        rotatingChild.addChild(couch)
                    } else { loadError = "Could not load this furniture model." }
                    
                    let rotationSpeed: Float = .pi / 4.0
                    _ = content.subscribe(to: SceneEvents.Update.self) { event in
                        guard let rotating = state.rotatingChild else { return }
                        guard !useWorldTracking else { return }
                        
                        let delta = Float(event.deltaTime)
                        let angle = delta * rotationSpeed
                        let rotIncrement = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                        rotating.transform.rotation *= rotIncrement
                    }
                    
                    // Apply drag-based rotation to parent
                    if let parent = state.parentContainer {
                        let totalAngle = dragRotation + dragDelta
                        var current = parent.transform
                        current.rotation = simd_quatf(angle: totalAngle, axis: [0, 1, 0])
                        parent.transform = current
                    }
                    
                } update: { content in
                    content.camera = useWorldTracking ? .spatialTracking : .virtual
                }
                .gesture(
                    DragGesture()
                        .updating($dragDelta) { value, state, _ in
                            if useWorldTracking {
                                // In AR mode, no rotation — we move the object
                                state = 0
                            } else {
                                // In virtual mode, update rotation angle
                                state = Float(value.translation.width) * 0.005
                            }
                        }
                        .onChanged { value in
                            guard useWorldTracking, let parent = state.parentContainer else { return }
                            
                            // AR mode — move object along horizontal plane
                            let x = Float(value.translation.width) * 0.0001
                            let z = Float(value.translation.height) * 0.0001
                            
                            var current = parent.transform
                            current.translation += SIMD3<Float>(x, 0, z)
                            parent.transform = current
                        }
                        .onEnded { value in
                            if useWorldTracking {
                                // Nothing to accumulate in AR mode
                            } else {
                                // Accumulate drag rotation
                                dragRotation += Float(value.translation.width) * 0.005
                            }
                        }
                )
                
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            guard let parent = state.parentContainer else { return }
                            state.isZoomed.toggle()
                            
                            let targetScale = state.isZoomed ? SIMD3<Float>(2, 2, 2) : SIMD3<Float>(1, 1, 1)
                            let newTransform = Transform(
                                scale: targetScale,
                                rotation: parent.transform.rotation,
                                translation: parent.transform.translation
                            )
                            
                            parent.move(
                                to: newTransform,
                                relativeTo: parent.parent,
                                duration: 0.3,
                                timingFunction: .easeInOut
                            )
                        }
                )
                
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(useWorldTracking
                         ? "Move your phone to see how this piece fits."
                         : "Drag to turn · Double-tap to zoom. Dimensions are approximate.")
                        .font(AppFont.callout)
                        .foregroundStyle(Color.appTextSecondary)
                    Button {
                        useWorldTracking.toggle()
                    } label: {
                        Label(useWorldTracking ? "Back to 3D preview" : "View in your room",
                              systemImage: useWorldTracking ? "cube" : "arkit")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appBackground.opacity(0.97))
            }
            .alert("Model unavailable", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
                Button("Close") { dismiss() }
            } message: { Text(loadError ?? "") }
            .animation(.easeInOut, value: useWorldTracking)
        }
    }
}

#Preview {
    NavigationStack {
        FurnitureTryOutView()
    }
}

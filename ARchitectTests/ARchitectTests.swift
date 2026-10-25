import Testing
import Foundation
import SceneKit
@testable import ARchitect

struct ARchitectTests {
    private let identity: [Float] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]

    @Test func repeatedFurnitureSurvivesRoundTrip() throws {
        let rotated: [Float] = [0,0,-1,0, 0,1,0,0, 1,0,0,0, 2,0,-3,1]
        let scene = RoomExperience(roomJSON: Data("{}".utf8), furniture: [
            PlacedFurniture(id: "first", model: .armChair, transform: identity),
            PlacedFurniture(id: "second", model: .armChair, transform: rotated)
        ])
        let decoded = try RoomExperience.decode(scene.encoded())
        #expect(decoded.furniture.count == 2)
        #expect(decoded.furniture[1].id == "second")
        #expect(decoded.furniture[1].transform[12] == 2)
        #expect(decoded.furniture[1].transform[2] == -1)
    }

    @Test func rejectsUnknownVersionAndMalformedTransform() {
        var scene = RoomExperience(roomJSON: Data("{}".utf8), furniture: [])
        scene.version = 2
        #expect(throws: (any Error).self) { try scene.encoded() }
        scene.version = 1
        scene.furniture = [PlacedFurniture(model: .armChair, transform: [1])]
        #expect(throws: (any Error).self) { try scene.encoded() }
    }

    @Test func nativeRoomValidationRejectsMissingGeometry() {
        let scene = RoomExperience(roomJSON: Data("{}".utf8), furniture: [])
        #expect(throws: (any Error).self) { try scene.validatedRoom() }
    }

    @Test @MainActor func everyCatalogItemHasALoadableBundledModel() throws {
        for item in FurnitureData.allItems {
            let model = try #require(item.model)
            let url = try #require(Bundle.main.url(forResource: model.resourceName, withExtension: "usdz"))
            let scene = try SCNScene(url: url)
            let bounds = scene.rootNode.boundingBox
            #expect(bounds.max.x > bounds.min.x)
            #expect(bounds.max.y > bounds.min.y)
        }
    }

    @Test func horizontalDragFollowsScreenDirectionsAtAStableSpeed() {
        let target = FurnitureDragMath.screenAlignedTarget(
            anchorAtStart: SIMD3<Float>(1, 0, 2),
            fingerDelta: CGPoint(x: 100, y: -100),
            cameraTransform: matrix_identity_float4x4,
            metersPerPoint: 0.003)
        #expect(abs(target.x - 1.3) < 0.0001)
        #expect(target.y == 0)
        #expect(abs(target.z - 1.7) < 0.0001)
        let longDrag = FurnitureDragMath.screenAlignedTarget(
            anchorAtStart: SIMD3<Float>(1, 0, 2),
            fingerDelta: CGPoint(x: 1000, y: -1000),
            cameraTransform: matrix_identity_float4x4,
            metersPerPoint: 0.003)
        #expect(simd_distance(longDrag, SIMD3<Float>(1, 0, 2)) <= 0.6001)
    }

    @Test func verticalDragTracksScreenMotionAtTheObjectsDepth() {
        let metersPerPoint = FurnitureDragMath.verticalMetersPerPoint(depth: 2, viewportHeight: 800)
        #expect(metersPerPoint > 0.002)
        #expect(metersPerPoint < 0.004)
        let target = FurnitureDragMath.verticalTarget(startHeight: 0.5, fingerDeltaY: -100,
                                                      metersPerPoint: metersPerPoint)
        #expect(target > 0.7)
        #expect(target < 0.9)
    }
}

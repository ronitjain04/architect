import Foundation
import RoomPlan
import SceneKit
import simd

extension PlacedFurniture {
    var matrix: simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(transform[0], transform[1], transform[2], transform[3]),
            SIMD4(transform[4], transform[5], transform[6], transform[7]),
            SIMD4(transform[8], transform[9], transform[10], transform[11]),
            SIMD4(transform[12], transform[13], transform[14], transform[15])
        ))
    }

    init(id: String, model: RoomFurnitureModel, matrix: simd_float4x4) {
        self.init(id: id, model: model, transform: (0..<4).flatMap { column in
            (0..<4).map { row in matrix[column][row] }
        })
    }
}

extension RoomExperience {
    init(room: CapturedRoom, furniture: [PlacedFurniture]) throws {
        self.init(roomJSON: try JSONEncoder().encode(room), furniture: furniture)
        try validate()
        _ = try validatedRoom()
    }

    /// Validate native geometry before handing remote data to the renderer.
    func validatedRoom() throws -> CapturedRoom {
        try validate()
        let room = try JSONDecoder().decode(CapturedRoom.self, from: roomJSON)
        let surfaces = room.walls + room.doors + room.windows + room.openings + room.floors
        guard !room.walls.isEmpty, surfaces.count <= 500, room.objects.count <= 200 else {
            throw ValidationError.invalidScene
        }
        func valid(_ size: SIMD3<Float>, _ matrix: simd_float4x4) -> Bool {
            let values = (0..<4).flatMap { col in (0..<4).map { matrix[col][$0] } }
            return [size.x, size.y, size.z].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 100 }
                && values.allSatisfy { $0.isFinite && abs($0) <= 100 }
        }
        guard surfaces.allSatisfy({ valid($0.dimensions, $0.transform) }),
              room.objects.allSatisfy({ valid($0.dimensions, $0.transform) }) else {
            throw ValidationError.invalidScene
        }
        return room
    }

    /// Export only locally. Native export retains openings and floor geometry.
    @MainActor
    func makeScene() throws -> SCNScene {
        let room = try validatedRoom()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("room.usdz")
        try room.export(to: url, exportOptions: .parametric)
        let scene = try SCNScene(url: url, options: [.checkConsistency: true])
        for piece in furniture {
            guard let url = Bundle.main.url(forResource: piece.model.resourceName, withExtension: "usdz"),
                  let reference = SCNReferenceNode(url: url) else {
                throw RenderingError.missingModel(piece.model.title)
            }
            reference.load()
            reference.simdTransform = piece.matrix
            scene.rootNode.addChildNode(reference)
        }
        return scene
    }

    enum RenderingError: LocalizedError {
        case missingModel(String)
        var errorDescription: String? {
            switch self {
            case .missingModel(let name): return "The model for \(name) is missing from this app. Update ARchitect and try again."
            }
        }
    }
}

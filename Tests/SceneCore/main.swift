import Foundation

func expectFailure(_ label: String, _ operation: () throws -> Void) {
    do { try operation(); fatalError("Expected rejection: \(label)") }
    catch { print("PASS rejects \(label)") }
}
let identity: [Float] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
var moved = identity
moved[12] = 2
moved[14] = -3
// Independently specified 90-degree yaw and translation.
let rotated: [Float] = [0,0,-1,0, 0,1,0,0, 1,0,0,0, 2,0,-3,1]
let first = PlacedFurniture(id: "chair-1", model: .armChair, transform: identity)
let second = PlacedFurniture(id: "chair-2", model: .armChair, transform: rotated)
let scene = RoomExperience(roomJSON: Data("{\"walls\":[]}".utf8), furniture: [first, second])
let decoded = try RoomExperience.decode(scene.encoded())
assert(decoded.furniture.count == 2)
assert(decoded.furniture[0].id != decoded.furniture[1].id)
assert(decoded.furniture[1].transform[12] == 2)
assert(decoded.furniture[1].transform[2] == -1)
print("PASS scene round-trip preserves repeated instances, translation and rotation")
expectFailure("unknown schema version") {
    var bad = scene; bad.version = 99; _ = try bad.encoded()
}
expectFailure("duplicate instance IDs") {
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [first, first]).encoded()
}
expectFailure("invalid affine matrix") {
    var bad = first; bad.transform[15] = 0
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [bad]).encoded()
}
expectFailure("nonfinite transform") {
    var bad = first; bad.transform[12] = .infinity
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [bad]).encoded()
}
expectFailure("singular scale") {
    var bad = first; bad.transform[0] = 0
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [bad]).encoded()
}
expectFailure("oversized room") {
    _ = try RoomExperience(roomJSON: Data(repeating: 32, count: 200_001), furniture: []).encoded()
}
expectFailure("too many furniture instances") {
    let pieces = (0..<51).map { PlacedFurniture(id: String($0), model: .armChair, transform: identity) }
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: pieces).encoded()
}
expectFailure("oversized downloaded payload") {
    _ = try RoomExperience.decode(Data(repeating: 32, count: 300_001))
}
print("All scene contract tests passed")
expectFailure("extreme anisotropic scale") {
    var bad = first; bad.transform[0] = 1e20; bad.transform[5] = 1e-10; bad.transform[10] = 1e-10
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [bad]).encoded()
}
expectFailure("sheared transform") {
    var bad = first; bad.transform[4] = 0.5
    _ = try RoomExperience(roomJSON: scene.roomJSON, furniture: [bad]).encoded()
}
assert(RoomLink.postID(from: URL(string: "architect://room/abc123")!) == "abc123")
assert(RoomLink.postID(from: URL(string: "https://room/abc123")!) == nil)
assert(RoomLink.postID(from: URL(string: "architect://room/a/b")!) == nil)
assert(RoomLink.postID(from: URL(string: "architect://room/%2Fbad")!) == nil)
print("PASS room links reject unrelated schemes and malformed IDs")

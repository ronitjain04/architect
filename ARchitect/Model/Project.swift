import Foundation

struct Project: Identifiable {
    let id = UUID()
    var name: String
    var tags: [String]
    var isLocked: Bool = false
    var image: String
    var modified: String
}

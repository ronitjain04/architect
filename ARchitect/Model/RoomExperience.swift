import Foundation

/// Stable wire IDs are independent of display names and bundled file names.
enum RoomFurnitureModel: String, Codable, CaseIterable, Identifiable {
    case armChair, greyCouch, comfortChair, chelseySofa, blueCouch, dahliaCouch, leatherCouch, foldingCouch, orangeLamp, officeLamp, diningTable, glassTable, sciFiTable, simpleTable, officeTable, livingChair, europeanChair, dublinChair, blueChair, drawer
    var id: String { rawValue }
    var resourceName: String {
        switch self {
        case .armChair: return "Arm chair"
        case .greyCouch: return "Grey Couch"
        case .comfortChair: return "Curved Comfort Chair"
        case .chelseySofa: return "Chelsey_Couch_2m"
        case .blueCouch: return "Blue_Couch"
        case .dahliaCouch: return "Dahlia_couch"
        case .leatherCouch: return "Leather_couch"
        case .foldingCouch: return "Folding_Couch"
        case .orangeLamp: return "Orange Lamp"
        case .officeLamp: return "office_lamp"
        case .diningTable: return "Dining_table_wood"
        case .glassTable: return "Dining_Table_Glass"
        case .sciFiTable: return "Sci-Fi_Table"
        case .simpleTable: return "Simple_dining_table"
        case .officeTable: return "Office_Table"
        case .livingChair: return "Living_Room_Chair"
        case .europeanChair: return "European Chair"
        case .dublinChair: return "Dublin_Chair"
        case .blueChair: return "blueChair"
        case .drawer: return "Wooden Drawer"
        }
    }
    var title: String {
        switch self {
        case .armChair: return "Arm Chair"
        case .greyCouch: return "Grey Couch"
        case .comfortChair: return "Curved Comfort Chair"
        case .chelseySofa: return "Chelsey Sofa"
        case .blueCouch: return "Blue Couch"
        case .dahliaCouch: return "Dahlia Couch"
        case .leatherCouch: return "Leather Couch"
        case .foldingCouch: return "Folding Couch"
        case .orangeLamp: return "Orange Lamp"
        case .officeLamp: return "Office Lamp"
        case .diningTable: return "Dining Table"
        case .glassTable: return "Dining Table Glass"
        case .sciFiTable: return "Sci-Fi Table"
        case .simpleTable: return "Simple Dining Table"
        case .officeTable: return "Office Table"
        case .livingChair: return "Living Room Chair"
        case .europeanChair: return "European Chair"
        case .dublinChair: return "Dublin Chair"
        case .blueChair: return "Blue Chair"
        case .drawer: return "Wooden Drawer"
        }
    }
    var imageName: String {
        switch self {
        case .armChair: return "armChair"
        case .greyCouch: return "GreyCouch"
        case .comfortChair: return "armChair"
        case .chelseySofa: return "ChelseyCouch"
        case .blueCouch: return "BlueCouch"
        case .dahliaCouch: return "DahliaCouch"
        case .leatherCouch: return "LeatherCouch"
        case .foldingCouch: return "FoldingCouch"
        case .orangeLamp: return "Orange Lamp"
        case .officeLamp: return "Office Lamp"
        case .diningTable: return "DiningTableWood"
        case .glassTable: return "DiningTableGlass"
        case .sciFiTable: return "SciFiTable"
        case .simpleTable: return "SimpleDiningTable"
        case .officeTable: return "OfficeTable"
        case .livingChair: return "Living Room Chair"
        case .europeanChair: return "European Chair"
        case .dublinChair: return "DublinChair"
        case .blueChair: return "blueChair"
        case .drawer: return "Wooden Drawer"
        }
    }
    var previewWidth: Float {
        switch self {
        case .armChair: return 0.85
        case .greyCouch: return 2.2
        case .comfortChair: return 0.85
        case .chelseySofa: return 2
        case .blueCouch: return 2.2
        case .dahliaCouch: return 1.8
        case .leatherCouch: return 2.2
        case .foldingCouch: return 2
        case .orangeLamp: return 0.4
        case .officeLamp: return 0.4
        case .diningTable: return 1.8
        case .glassTable: return 1.8
        case .sciFiTable: return 1.5
        case .simpleTable: return 1.6
        case .officeTable: return 1.4
        case .livingChair: return 0.85
        case .europeanChair: return 0.6
        case .dublinChair: return 0.7
        case .blueChair: return 0.65
        case .drawer: return 0.6
        }
    }
}

struct PlacedFurniture: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var model: RoomFurnitureModel
    /// Column-major world transform, in the same coordinate system as RoomPlan.
    var transform: [Float]
}

struct RoomExperience: Codable, Equatable {
    var version = 1
    /// Native CapturedRoom JSON preserves openings and nonrectangular geometry.
    var roomJSON: Data
    var furniture: [PlacedFurniture]

    enum ValidationError: LocalizedError {
        case unsupportedVersion, invalidScene, tooLarge
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "This room needs a newer version of ARchitect."
            case .invalidScene: return "The room contains invalid geometry. Please scan it again."
            case .tooLarge: return "This experience is too large for the beta. Scan one smaller room and use at most 50 furniture pieces."
            }
        }
    }

    func encoded() throws -> Data {
        try validate()
        let result = try JSONEncoder().encode(self)
        guard result.count <= 300_000 else { throw ValidationError.tooLarge }
        return result
    }

    static func decode(_ data: Data) throws -> RoomExperience {
        guard data.count <= 300_000 else { throw ValidationError.tooLarge }
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }

    func validate() throws {
        guard version == 1 else { throw ValidationError.unsupportedVersion }
        guard roomJSON.count <= 200_000, furniture.count <= 50 else { throw ValidationError.tooLarge }
        guard !roomJSON.isEmpty,
              (try? JSONSerialization.jsonObject(with: roomJSON)) is [String: Any],
              Set(furniture.map(\.id)).count == furniture.count else {
            throw ValidationError.invalidScene
        }
        for item in furniture {
            let m = item.transform
            guard !item.id.isEmpty, item.id.utf8.count <= 100,
                  m.count == 16, m.allSatisfy(\.isFinite),
                  abs(m[3]) < 0.0001, abs(m[7]) < 0.0001,
                  abs(m[11]) < 0.0001, abs(m[15] - 1) < 0.0001,
                  (12...14).allSatisfy({ abs(m[$0]) <= 100 }) else {
                throw ValidationError.invalidScene
            }
            let axes = [0, 4, 8].map { offset in [m[offset], m[offset + 1], m[offset + 2]] }
            let lengths = axes.map { axis in sqrt(axis.reduce(Float(0)) { $0 + $1 * $1 }) }
            guard lengths.allSatisfy({ $0 >= 0.0001 && $0 <= 100 }) else {
                throw ValidationError.invalidScene
            }
            for (a, b) in [(0, 1), (0, 2), (1, 2)] {
                let dot = zip(axes[a], axes[b]).reduce(Float(0)) { $0 + $1.0 * $1.1 }
                guard abs(dot / (lengths[a] * lengths[b])) < 0.001 else {
                    throw ValidationError.invalidScene
                }
            }
            // Reject collapsed, reflected, or grossly oversized transforms.
            let determinant = m[0] * (m[5]*m[10] - m[9]*m[6])
                - m[4] * (m[1]*m[10] - m[9]*m[2])
                + m[8] * (m[1]*m[6] - m[5]*m[2])
            guard determinant > 1e-12, determinant <= 1_000_000 else {
                throw ValidationError.invalidScene
            }
        }
    }
}

/// Links open an installed beta; no paid hosting or Dynamic Links dependency.
enum RoomLink {
    static func postID(from url: URL) -> String? {
        guard url.scheme == "architect", url.host == "room",
              url.query == nil, url.fragment == nil else { return nil }
        let id = String(url.path.dropFirst())
        guard id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { return nil }
        return id
    }
    static func url(postID: String) -> URL? {
        guard postID.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { return nil }
        return URL(string: "architect://room/" + postID)
    }
}

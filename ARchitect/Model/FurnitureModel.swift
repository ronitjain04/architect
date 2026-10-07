//
//  furniture.swift
//  ARchitect
//
//  Created by Ivan Li on 3/31/25.
//
import SwiftUI

struct FurnitureItem: Identifiable {
    var model: RoomFurnitureModel? { RoomFurnitureModel.allCases.first { $0.title == name } }
    let id = UUID()
    let name: String
    let tags: [String]
    let imageName: String
    let category: String
}

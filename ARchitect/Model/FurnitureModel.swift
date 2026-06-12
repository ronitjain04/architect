//
//  furniture.swift
//  ARchitect
//
//  Created by Ivan Li on 3/31/25.
//
import SwiftUI

struct FurnitureItem: Identifiable {
    let id = UUID()
    let name: String
    let tags: [String]
    let imageName: String
    let category: String
}

//
//  VREnvironmentConfig.swift
//  ARchitect
//
//  Created by TANAY RAJKUMAR on 4/3/25.
//


import Foundation
import simd

// MARK: - VREnvironmentConfig
struct VREnvironmentConfig: Identifiable {
    let id: UUID               // Ties environment to Post ID
    let environmentModel: String?
    let environmentPosition: SIMD3<Float>
    let environmentScale: SIMD3<Float>
    let objects: [VRObjectConfig]
    
    // MARK: - VR Object Config
    struct VRObjectConfig: Identifiable {
        let id = UUID()
        let modelName: String
        let imageName: String
        let iconName: String
        let filter: String
        let displayName: String
        let description: String
        let position: SIMD3<Float>
        let scale: SIMD3<Float>
        let properties: [String: String]
    }
    
    // MARK: - Constructor to match Post ID
    init(postID: UUID) {
        self.id = postID
        
        // Example default environment setup
        self.environmentModel = "apartment_room" // Reality file or .usdz model name
        
        self.environmentPosition = SIMD3<Float>(0, 0, 0)
        self.environmentScale = SIMD3<Float>(2, 2, 2)
        
        self.objects = [
            VRObjectConfig(
                modelName: "Arm chair",
                imageName: "armChair",
                iconName: "chair.fill",
                filter: "Chairs",
                displayName: "Modern Chair",
                description: "A stylish modern chair with minimalist design.",
                position: SIMD3<Float>(0.3, -2.5, 2),
                scale: SIMD3<Float>(-0.012, 0.012, -0.012),
                properties: [
                    "Price": "$499.99",
                    "Material": "Leather and metal",
                    "Dimensions": "28\" × 30\" × 32\""
                ]
            ),
            VRObjectConfig(
                modelName: "Grey Couch",
                imageName: "GreyCouch",
                iconName: "sofa.fill",
                filter: "Sofas",
                displayName: "Grey Couch",
                description: "Comfortable grey couch for modern living rooms.",
                position: SIMD3<Float>(0.3, -2.5, -2),
                scale: SIMD3<Float>(0.00125, 0.00125, 0.00125),
                properties: [
                    "Price": "$299.99",
                    "Material": "Polyester",
                    "Dimensions": "48\" × 24\" × 18\""
                ]
            )
        ]
    }
}

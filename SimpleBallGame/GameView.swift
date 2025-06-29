//
//  GameView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI
import RealityKit


struct GameView: View {
    @State var selectedLevel: String?
    @Environment (\.openImmersiveSpace) var openImmersiveSpace
    
    var body: some View {
//        if selectedLevel != nil {

//        }
//        else {
//            LevelSelectView(selectedLevel: $selectedLevel)
//        }
    }
    
    func generateNonIntersectingPositions() -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        let sphereRadius: Float = 0.1 // 10cm radius
        let minDistance = sphereRadius * 2.1 // Minimum distance between sphere centers (with small buffer)
        
        // Volumetric space bounds (2x2x2 meters, so -1 to 1 on each axis)
        // Account for sphere radius to keep spheres fully inside
        let boundMin: Float = 0.0 + sphereRadius
        let boundMax: Float = 1.0 - sphereRadius
        
        let maxAttempts = 1000 // Prevent infinite loops
        
        for index in 0..<10 {
            var attempts = 0
            var validPosition = false
            var newPosition = SIMD3<Float>(0, 0, 0)
            
            while !validPosition && attempts < maxAttempts {
                // Generate random position within safe bounds
                newPosition = SIMD3<Float>(
                    Float.random(in: boundMin...boundMax),
                    Float.random(in: boundMin...boundMax),
                    Float.random(in: boundMin...boundMax)
                )
                
                // Check if this position is far enough from all existing spheres
                validPosition = true
                for existingPosition in positions {
                    let distance = length(newPosition - existingPosition)
                    if distance < minDistance {
                        validPosition = false
                        break
                    }
                }
                attempts += 1
            }
            print("\(index), \(newPosition)")
            positions.append(newPosition)
        }
        
        return positions
    }
    
    func createSphere(index: Int, position: SIMD3<Float>) -> Entity {
        // Create sphere mesh with 10cm radius (0.1 meters)
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        
        // Create material with random color
        let material = SimpleMaterial(
            color: randomColor(),
            roughness: 0.3,
            isMetallic: false
        )
        
        // Create model entity
        let sphereEntity = ModelEntity(
            mesh: sphereMesh,
            materials: [material]
        )
        
        // Set the pre-calculated position
        sphereEntity.position = position
        
        // Add some physics for interaction
        sphereEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
        sphereEntity.components.set(InputTargetComponent())
        
        // Add gentle rotation animation
        let rotationAnimation = FromToByAnimation(
            from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
            duration: Double.random(in: 5.0...15.0),
            timing: .linear,
            isAdditive: false,
            repeatMode: .repeat,
            fillMode: .forwards
        )
        
        if let animationResource = try? AnimationResource.generate(with: rotationAnimation) {
            sphereEntity.playAnimation(animationResource)
        }
        
        return sphereEntity
    }
    
    func randomColor() -> UIColor {
        return UIColor(
            red: CGFloat.random(in: 0.2...1.0),
            green: CGFloat.random(in: 0.2...1.0),
            blue: CGFloat.random(in: 0.2...1.0),
            alpha: 1.0
        )
    }
}

#Preview(windowStyle: .volumetric) {
    GameView()
        .environment(AppModel())
}

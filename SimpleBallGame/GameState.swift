//
//  GameState.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 7/8/25.
//
import Foundation
import SwiftUI
import RealityKit

class GameState: ObservableObject {
    @Published var currentLevel: GameLevel = .easy
    @Published var currentSubLevel: Int = 0
    @Published var currentGame: CurrentGameState = .init()
    
    private var anchorEntity: AnchorEntity?
    private var currentEntities: [BallModel] = []

    
    var textColor: UIColor = .white
    
    enum GameLevel: Int, CaseIterable {
        case easy = 1
        case medium = 2
        case hard = 3
        
        var title: String {
            switch self {
            case .easy:
                return "Easy"
            case .medium:
                return "Medium"
            case .hard:
                return "Hard"
            }
        }
        
        var numberOfObjects: Int {
            switch self {
            case .easy:
                return 10
            case .medium:
                return 20
            case .hard:
                return 30
            }
        }
    }
    
    func setupScene(content: RealityViewContent) {
        anchorEntity = AnchorEntity(.head)
        content.add(anchorEntity!)
        
        addCurrentLevelnbjects()
    }
    
    func updateScene(content: RealityViewContent) {
        // currently not needed
    }
    
    func handleTap(on entity: Entity) {
        // Check if the tapped entity is our current target
        if currentEntities.contains(where: { sphere in
            sphere.sphere == entity
        }) {
            objectTapped()
        }
    }
    
    private func objectTapped() {
        // Move to next level after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.currentSubLevel < 10{
                self.currentSubLevel += 1
                self.addCurrentLevelnbjects()
            } else if self.currentSubLevel == 10 && self.currentLevel != .hard {
                self.currentLevel = GameLevel(rawValue: self.currentLevel.rawValue + 1)!
                self.addCurrentLevelnbjects()
            } else {
                print("Game over!")
            }
        }
    }
    
    func addCurrentLevelnbjects() {
        currentEntities.forEach{ entity in
            entity.sphere.removeFromParent()
        }
        currentEntities.removeAll()
        
        let entities = createObjects(for: currentLevel, and: currentSubLevel)
        let usedColors: [UIColor] = entities.reduce([]) { result, ballModel in
            result.contains(ballModel.color) ? result : result + [ballModel.color]
        }
        if let firstColor = usedColors.first {
            textColor = firstColor
        }
        currentEntities = entities.filter{sphere in sphere.color == textColor}
    }
    
    func createObjects(for level: GameLevel, and subLevel: Int) -> [BallModel] {
        var ballModels: [BallModel] = []
        let colors = generateRandomColors(selectedLevel: level)
        let numberOfObjects = level.numberOfObjects + subLevel
        let positions = generateNonIntersectingPositions(for: numberOfObjects)
        
        for i in 0..<numberOfObjects {
            let color = colors.randomElement() ?? .white
            let sphere = createSphere(index: i, position: positions[i], useColor: color)
            let uuid = UUID(uuidString: sphere.name)!
            let ballModel = BallModel(id: uuid, position: sphere.position, pickedUp: false, color: color, sphere: sphere)
            currentGame.ballModels.append(ballModel)
            ballModels.append(ballModel)
        }
        
        return ballModels
    }
    
    private func createSphere(index: Int, position: SIMD3<Float>, useColor: UIColor) -> Entity {
        // Create sphere mesh with 10cm radius (0.1 meters)
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        // Create material with random color
        let material = SimpleMaterial(
            color: useColor,
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
        sphereEntity.name = UUID().uuidString
        
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
        
        let hoverComponent = HoverEffectComponent(.spotlight(
            HoverEffectComponent.SpotlightHoverEffectStyle(
                color: useColor, strength: 2.0
            )
        ))
        
        sphereEntity.components.set(hoverComponent)
        
        return sphereEntity
    }
    
    private func generateNonIntersectingPositions(for numberOfSpheres: Int) -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        let sphereRadius: Float = 0.1 // 10cm radius
        let minDistance = sphereRadius * 2.1 // Minimum distance between sphere centers (with small buffer)
        
        // Position spheres approximately 1 meter in front of user
        // Create a semicircle/hemisphere pattern in front of the head
        let baseDistance: Float = 1.0 // 1 meter forward
        let spreadRadius: Float = 0.5 // 40cm spread radius around the forward point
        
        let maxAttempts = 1000 // Prevent infinite loops
        
        for _ in 0..<numberOfSpheres {
            var attempts = 0
            var validPosition = false
            var newPosition = SIMD3<Float>(0, 0, 0)
            
            while !validPosition && attempts < maxAttempts {
                // Generate random position in a hemisphere in front of user
                // X: left-right spread
                // Y: up-down spread (slightly biased upward)
                // Z: forward distance with some variation
                newPosition = SIMD3<Float>(
                    Float.random(in: -spreadRadius...spreadRadius), // Left-right
                    Float.random(in: -spreadRadius/2...spreadRadius), // Slightly up-biased
                    -baseDistance + Float.random(in: -0.2...0.2) // 1m forward ± 20cm
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
            
            positions.append(newPosition)
        }
        
        return positions
    }
    
    private func generateRandomColors(selectedLevel: GameLevel) -> [UIColor] {
        var colors: [UIColor] = []
        let maxAttempts = 10000 // Prevent infinite loops
        let minColorDistance: Float = 0.3 // Minimum distance between colors in RGB space
        let numberOfColors = selectedLevel.numberOfObjects
        
        while colors.count < numberOfColors {
            var attempts = 0
            var validColor = false
            var newColor = UIColor.black
            
            while !validColor && attempts < maxAttempts {
                // Generate random color
                let red = Float.random(in: 0.2...1.0)
                let green = Float.random(in: 0.2...1.0)
                let blue = Float.random(in: 0.2...1.0)
                
                newColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
                
                // Check if this color is sufficiently different from existing colors
                validColor = true
                for existingColor in colors {
                    if let existingComponents = existingColor.cgColor.components,
                       existingComponents.count >= 3 {
                        let existingRed = Float(existingComponents[0])
                        let existingGreen = Float(existingComponents[1])
                        let existingBlue = Float(existingComponents[2])
                        
                        // Calculate Euclidean distance in RGB space
                        let distance = sqrt(pow(red - existingRed, 2) +
                                          pow(green - existingGreen, 2) +
                                          pow(blue - existingBlue, 2))
                        
                        if distance < minColorDistance {
                            validColor = false
                            break
                        }
                    }
                }
                attempts += 1
            }
            
            colors.append(newColor)
        }
        
        return colors
    }

}

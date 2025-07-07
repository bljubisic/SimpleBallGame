//
//  GameView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI
import RealityKit
import RealityKitContent


struct GameView: View {
    @State private var selectedSpheres: Set<String> = []
    @State var textColor: UIColor = .white
    @State var numberOfBalls: Int = 0
    @State var colors: [UIColor] = []
    @State var spherePositions: [SIMD3<Float>] = []
    @State var ballModels: [BallModel] = []
    @State var levelDone: Bool = false
    @Binding var selectedLevel: AppModel.Level
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Binding var game: Game
    @Binding var currentGame: CurrentGameState
    
    @ObservedObject var stopWatch = StopWatch()
    
    var body: some View {
        let minutes = String(format: "%02d", stopWatch.counter / 60)
        let seconds = String(format: "%02d", stopWatch.counter % 60)
        let union = minutes + " : " + seconds
//        var currentGame = setupTheGame()
        
        RealityView { content, attachments in
            currentGame = CurrentGameState(game: game)
            let numberOfBalls = (BASE_BALLS_NUM * (levelMultiplier[selectedLevel] ?? 1) + currentGame.game.subLevel) - 1
            // Create 10 spheres with random positions
            ballModels = createBallModels(for: game.level, and: game.subLevel)
            currentGame = CurrentGameState.currentGameBallModelsLens.set(ballModels, currentGame)
            let anchor = AnchorEntity(.head, trackingMode: .once)
            anchor.name = "HeadAnchor"
            for i in 0..<numberOfBalls  {
                anchor.addChild(currentGame.ballModels[i].sphere)
            }
            let usedColors: [UIColor] = currentGame.ballModels.reduce([]) { result, ballModel in
                result.contains(ballModel.color) ? result : result + [ballModel.color]
            }
            if let firstColor = usedColors.first {
                textColor = firstColor
            }
            content.add(anchor)
            if let instructions = attachments.entity(for: "Instructions") {
                instructions.position.z -= 1
                instructions.position.y += 1.8
                instructions.position.x += 0.9
                
                content.add(instructions)
            }
        } update: { content, attachments in
            if levelDone {
                let numberOfBalls = (BASE_BALLS_NUM * (levelMultiplier[currentGame.game.level] ?? 1) + currentGame.game.subLevel) - 1
//                content.entities.remo
                let anchor = AnchorEntity(.head, trackingMode: .once)
                for i in 0..<numberOfBalls  {
                    anchor.addChild(ballModels[i].sphere)
                }
                content.add(anchor)
                if let instructions = attachments.entity(for: "Instructions") {
                    instructions.position.z -= 1
                    instructions.position.y += 1.8
                    instructions.position.x += 0.9
                    
                    content.add(instructions)
                }
            }
        } attachments: {
            Attachment(id: "Instructions") {
                VStack {
                    HStack {
                        Text("Remove all balls with ")
                            .font(.title)
                        Text("this color!!")
                            .foregroundColor(Color(textColor))
                            .font(.title)
                    }
                    .padding()
                    Text("Time lapsed: \(union)")
                        .font(.title)
                        .padding()
                }

            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    levelDone = false
                    if stopWatch.counter == 0 {
                        stopWatch.start()
                    }
                    let name = value.entity.name
                    print(name, ballModels)
                    let ballModel = currentGame.ballModels.filter{ ballModel in ballModel.id.uuidString == name}.first
                    if var ballModel = ballModel {
                        ballModel = BallModel.ballModelPickedUpLens.set(true, ballModel)
                        value.entity.explode(color: ballModel.color)
                        if ballModel.color == textColor {
                            currentGame.ballModels.removeAll(where: { $0.id == ballModel.id })
                            let numberOfBallsLeft = currentGame.ballModels.filter{sphere in sphere.color == textColor}.count
                            if numberOfBallsLeft == 0 {
                                levelDone = true
                                print(numberOfBallsLeft, currentGame.game.subLevel)
                                if currentGame.game.subLevel < 10 {
                                    let subLevel = currentGame.game.subLevel + 1
                                    game.subLevel = subLevel
                                    currentGame.game = game
                                    ballModels = createBallModels(for: game.level, and: game.subLevel)
                                    currentGame.ballModels = ballModels
                                } else {
                                    if (currentGame.game.level == .easy) {
                                        let timePerLevel = currentGame.game.keptTimePerLevel
                                        game = Game(level: .medium, subLevel: 1)
//                                        game.keptTimePerLevel = timePerLevel
                                        currentGame.game = game
                                        ballModels = createBallModels(for: game.level, and: game.subLevel)
                                        currentGame.ballModels = ballModels
                                    }
                                }
                            }
                        }
                    }
                }
        )

    }
    
    func createBallModels(for level: AppModel.Level, and subLevel: Int) -> [BallModel] {
        let colors = generateRandomColors(selectedLevel: level)
        
        var ballModels = [] as [BallModel]
        let numberOfBalls = (BASE_BALLS_NUM * (levelMultiplier[selectedLevel] ?? 1) + currentGame.game.subLevel) - 1
        let positions = generateNonIntersectingPositions(for: numberOfBalls)
        for i in 0 ..< numberOfBalls {
            let color = colors.randomElement() ?? .white
            let sphere = createSphere(index: i, position: positions[i], useColor: color)
            let uuid = UUID(uuidString: sphere.name)!
            let ballModel = BallModel(id: uuid, position: sphere.position, pickedUp: false, color: color, sphere: sphere)
            currentGame.ballModels.append(ballModel)
            ballModels.append(ballModel)
        }
        return ballModels
    }
    
    func updateSphereAppearance(_ modelEntity: ModelEntity, isSelected: Bool) {
         if isSelected {
             // Selected state: brighter, slightly larger, with glow
             modelEntity.transform.scale = SIMD3<Float>(1.2, 1.2, 1.2)

         } else {
             // Normal state
             modelEntity.transform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
             
         }
     }
    
    func handleSphereSelection(_ entity: Entity) {
            
        // Toggle selection state
        if selectedSpheres.contains(entity.name) {
            selectedSpheres.remove(entity.name)
        } else {
            selectedSpheres.insert(entity.name)
        }
    }
    
    func generateRandomColors(selectedLevel: AppModel.Level) -> [UIColor] {
        var colors: [UIColor] = []
        let maxAttempts = 10000 // Prevent infinite loops
        let minColorDistance: Float = 0.3 // Minimum distance between colors in RGB space
        let numberOfColors = BASE_NUMBER_OF_COLORS * (levelMultiplier[selectedLevel] ?? 1)
        
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
}

extension Entity {
    func explode(color: UIColor) {
        // Create explosion particles
        createExplosionEffect(color: color)
        
        // Remove the original sphere after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.removeFromParent()
        }
    }
    
    func createExplosionEffect(color: UIColor) {
        let particleCount = 50
        let explosionForce: Float = 2.0
        
        for _ in 0..<particleCount {
            // Create small particle
            let particleMesh = MeshResource.generateSphere(radius: 0.01)
            var particleMaterial = SimpleMaterial()
            particleMaterial.color = .init(tint: color, texture: nil)
            
            let particle = ModelEntity(mesh: particleMesh, materials: [particleMaterial])
            
            // Set initial position at sphere center
            particle.position = self.position
            
            // Generate random direction
            let randomDirection = SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            )
            let normalizedDirection = normalize(randomDirection)
            
            // Add physics for particle movement
            let physicsMaterial = PhysicsMaterialResource.generate(
                friction: 0.2,
                restitution: 0.8
            )
            
            particle.components.set(PhysicsBodyComponent(
                massProperties: .default,
                material: physicsMaterial,
                mode: .dynamic
            ))
            
            // Add collision shape
            particle.components.set(CollisionComponent(
                shapes: [.generateSphere(radius: 0.01)]
            ))
            
            // Add to parent
            self.parent?.addChild(particle)
            
            // Apply explosion force
            let explosionVelocity = normalizedDirection * explosionForce
            particle.components.set(PhysicsMotionComponent(linearVelocity: explosionVelocity, angularVelocity: SIMD3<Float>(
                Float.random(in: -5...5),
                Float.random(in: -5...5),
                Float.random(in: -5...5)
            )))

            
            // Remove particle after some time
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                particle.removeFromParent()
            }
            
            // Fade out animation
            let fadeAnimation = FromToByAnimation<Float>(
                name: "fadeOut",
                from: 1.0,
                to: 0.0,
                duration: 2.5,
                timing: .easeOut,
                bindTarget: .opacity
            )
            
            let animationResource = try! AnimationResource.generate(with: fadeAnimation)
            particle.playAnimation(animationResource)
        }
    }
}

#Preview(windowStyle: .volumetric) {
    @Previewable @State var selectedLevel: AppModel.Level = .easy
    @Previewable @State var game: Game = Game(level: .easy, subLevel: 1)
    @Previewable @State var currentGame: CurrentGameState = CurrentGameState(game: Game(level: .easy, subLevel: 1))
    GameView(selectedLevel: $selectedLevel, game: $game, currentGame: $currentGame)
        .environment(AppModel())
}

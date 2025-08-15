//
//  GameView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI
import RealityKit


struct GameView: View {
    @Binding var gameState: GameState
    @State private var explosionEntity: Entity?
    
    @ObservedObject var stopWatch = StopWatch()
    
    var body: some View {
        ZStack {
            RealityView { content, attachments in
                gameState.setupScene(content: content, attachments: attachments)
            } update: { content, attachments in
                gameState.updateScene(content: content, attachments: attachments)
            } attachments: {
                Attachment(id: "Instructions") {
                    InstructionTextView(gameState: gameState)
                }
                
                Attachment(id: "game-complete") {
                    GameCompleteOverlay(gameState: gameState)
                }
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        let color = gameState.getColorOfEntity(value.entity)
                        createExplosionEffect(at: value.entity, with: color)
                        gameState.handleTap(on: value.entity)
                    }
            )
        }
    }
    
    private func createExplosionEffect(at entity: Entity, with color: UIColor) {
        
        // Create custom particle explosion using multiple small cubes
        let particleCount = 50
        let explosionEntity = Entity()
        explosionEntity.position = entity.position
        
        for _ in 0..<particleCount {
            // Create small particle cube
            let particleMesh = MeshResource.generateBox(size: 0.01) // Small particles
            var particleMaterial = SimpleMaterial()
            particleMaterial.color = .init(tint: color) // Same color as main box
            particleMaterial.roughness = 0.3
            particleMaterial.metallic = 0.7
            
            let particle = ModelEntity(mesh: particleMesh, materials: [particleMaterial])
            
            // Random direction for explosion
            let randomX = Float.random(in: -1...1)
            let randomY = Float.random(in: -0.5...1)
            let randomZ = Float.random(in: -1...1)
            let direction = normalize(SIMD3<Float>(randomX, randomY, randomZ))
            
            // Random speed
            let speed = Float.random(in: 1.5...3.0)
            let velocity = direction * speed
            
            // Set initial position with slight randomness
            let randomOffset = SIMD3<Float>(
                Float.random(in: -0.05...0.05),
                Float.random(in: -0.05...0.05),
                Float.random(in: -0.05...0.05)
            )
            particle.position = randomOffset
            
            explosionEntity.addChild(particle)
            
            // Animate particle movement with physics simulation
            animateParticle(particle, initialVelocity: velocity, duration: 2.0)
        }
        
        // Add explosion entity to scene
        entity.parent?.addChild(explosionEntity)
        self.explosionEntity = explosionEntity
        
        // Hide the box temporarily during explosion
        withAnimation(.easeOut(duration: 0.2)) {
            entity.isEnabled = false
        }
        
        // Clean up particle system after explosion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            explosionEntity.removeFromParent()
        }
    }
    
    private func animateParticle(_ particle: ModelEntity, initialVelocity: SIMD3<Float>, duration: Float) {
        let gravity: Float = -2.0
        let dampening: Float = 0.95
        
        var currentVelocity = initialVelocity
        let startTime = CACurrentMediaTime()
        
        // Create a timer for physics simulation
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in // ~60 FPS
            let currentTime = CACurrentMediaTime()
            let elapsedTime = Float(currentTime - startTime)
            
            if elapsedTime >= duration {
                timer.invalidate()
                // Fade out particle
                withAnimation(.easeOut(duration: 0.5)) {
                    particle.components[OpacityComponent.self] = OpacityComponent(opacity: 0.0)
                }
                return
            }
            
            // Apply gravity
            currentVelocity.y += gravity * 0.016 // 60 FPS timestep
            
            // Apply dampening
            currentVelocity *= dampening
            
            // Update position
            particle.position += currentVelocity * 0.016
            
            // Add rotation for visual appeal
            let rotationSpeed: Float = 2.0
            let currentRotation = particle.transform.rotation
            let additionalRotation = simd_quatf(angle: rotationSpeed * 0.016, axis: SIMD3<Float>(1, 1, 0))
            particle.transform.rotation = currentRotation * additionalRotation
        }
    }
}


#Preview(windowStyle: .volumetric) {
    @Previewable @State var selectedLevel: GameState.GameLevel = .easy
    @Previewable @State var gameState: GameState = GameState(currentLevel: .easy)
    GameView(gameState: $gameState)
        .environment(AppModel())
}

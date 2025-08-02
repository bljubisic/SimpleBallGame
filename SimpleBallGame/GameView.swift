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
    @Binding var gameState: GameState
    
    @ObservedObject var stopWatch = StopWatch()
    
    var body: some View {
        
        if gameState.isGameComplete {
            GameCompleteView(gameState: gameState)
        } else {
            RealityView { content, attachments in
                gameState.setupScene(content: content)
                if let instructions = attachments.entity(for: "Instructions") {
                    instructions.position.z -= 1
                    instructions.position.y += 1.8
                    instructions.position.x += 0.9

                    content.add(instructions)
                }
            } update: { content, attachments in
                gameState.updateScene(content: content)
            } attachments: {
                Attachment(id: "Instructions") {
                    InstructionTextView(gameState: gameState)
                }
            }
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        gameState.handleTap(on: value.entity)
                    }
            )
        }
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
    @Previewable @State var selectedLevel: GameState.GameLevel = .easy
    @Previewable @State var gameState: GameState = GameState(currentLevel: .easy)
    GameView(gameState: $gameState)
        .environment(AppModel())
}

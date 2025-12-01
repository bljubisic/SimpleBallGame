import SwiftUI
import RealityKit
import ARKit
import UIKit

#if !os(visionOS)
struct ARGameView: UIViewRepresentable {
    @Binding var gameState: GameState
    @Binding var resetPlacementTrigger: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // Add coaching overlay to guide user to find a plane
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .anyPlane
        arView.addSubview(coaching)
        context.coordinator.coaching = coaching

        // Add reticle entity
        let reticle = ModelEntity(mesh: .generateTorus(ringRadius: 0.03, pipeRadius: 0.002))
        reticle.model?.materials = [SimpleMaterial(color: .yellow.withAlphaComponent(0.8), isMetallic: true)]
        reticle.isEnabled = false
        let reticleAnchor = AnchorEntity(world: .zero)
        arView.scene.anchors.append(reticleAnchor)
        reticleAnchor.addChild(reticle)
        context.coordinator.reticle = reticle
        context.coordinator.reticleAnchor = reticleAnchor

        // Create ghost board
        let boardMesh = MeshResource.generatePlane(width: 0.6, depth: 0.6)
        var boardMaterial = SimpleMaterial()
        boardMaterial.color = .init(tint: UIColor.systemTeal.withAlphaComponent(0.25))
        boardMaterial.roughness = 0.2
        boardMaterial.metallic = 0.0
        let ghost = ModelEntity(mesh: boardMesh, materials: [boardMaterial])
        ghost.name = "ghost_board"
        ghost.isEnabled = false
        reticleAnchor.addChild(ghost)
        context.coordinator.ghostBoard = ghost

        // Add tap gesture recognizer for entity interactions and placement
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        context.coordinator.gameStateBinding = $gameState

        context.coordinator.successHaptic.prepare()
        context.coordinator.impactHaptic.prepare()

        context.coordinator.sceneUpdateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator = context.coordinator] _ in
            coordinator?.updateReticle()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if resetPlacementTrigger {
            context.coordinator.resetPlacement()
            // Re-add reticle anchor after clearing
            let reticleAnchor = AnchorEntity(world: .zero)
            uiView.scene.anchors.append(reticleAnchor)
            if let reticle = context.coordinator.reticle {
                reticle.isEnabled = false
                reticleAnchor.addChild(reticle)
                context.coordinator.reticleAnchor = reticleAnchor
            }
            if let ghost = context.coordinator.ghostBoard {
                ghost.isEnabled = false
                reticleAnchor.addChild(ghost)
            }
            DispatchQueue.main.async { self.resetPlacementTrigger = false }
        }
        // Update scene if needed; delegate to coordinator
        context.coordinator.updateScene(gameState: gameState)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var arView: ARView?
        weak var rootAnchorEntity: AnchorEntity?
        var gameStateBinding: Binding<GameState>?
        var rootAnchor: AnchorEntity?
        var hasPlacedContent = false
        var coaching: ARCoachingOverlayView?
        var reticle: ModelEntity?
        var reticleAnchor: AnchorEntity?
        var ghostBoard: ModelEntity?
        let successHaptic = UINotificationFeedbackGenerator()
        let impactHaptic = UIImpactFeedbackGenerator(style: .light)
        var sceneUpdateCancellable: Cancellable?

        func updateScene(gameState: GameState) {
            // Optional: synchronize any runtime changes
        }

        func updateReticle() {
            guard let arView = arView, let reticle = reticle else { return }
            guard !hasPlacedContent else {
                reticle.isEnabled = false
                ghostBoard?.isEnabled = false
                return
            }
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .any)
            if let first = results.first {
                reticle.isEnabled = true
                reticle.transform.matrix = first.worldTransform
                // Orient the ghost board to the plane and slightly lift it
                if let ghost = ghostBoard {
                    ghost.isEnabled = true
                    ghost.transform.matrix = first.worldTransform
                    ghost.position.y += 0.002
                }
            } else {
                reticle.isEnabled = false
                ghostBoard?.isEnabled = false
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = recognizer.location(in: arView)

            if !hasPlacedContent {
                let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
                if let first = results.first {
                    // Create a content anchor at the hit transform
                    let contentAnchor = AnchorEntity(world: first.worldTransform)
                    arView.scene.anchors.append(contentAnchor)
                    self.rootAnchor = contentAnchor
                    hasPlacedContent = true
                    if let gameState = gameStateBinding?.wrappedValue {
                        if let populate = (gameState as AnyObject) as? GameStatePopulating {
                            populate.populateScene(root: contentAnchor)
                        }
                    }
                    successHaptic.notificationOccurred(.success)
                    self.ghostBoard?.isEnabled = false
                }
                return
            }

            // Content already placed: try entity hit-test first
            if let result = arView.entity(at: location) {
                impactHaptic.impactOccurred()
                if let model = result as? ModelEntity {
                    self.spawnExplosion(at: model)
                }
                gameStateBinding?.wrappedValue.handleTap(on: result)
                return
            }

            // Optional: raycast for additional interactions after placement (currently no-op)
        }

        func spawnExplosion(at entity: ModelEntity) {
            guard let root = rootAnchor else { return }
            let particleCount = 40
            let explosion = Entity()
            explosion.transform = entity.transform
            root.addChild(explosion)

            for _ in 0..<particleCount {
                let mesh = MeshResource.generateBox(size: 0.01)
                var material = SimpleMaterial()
                if let simple = entity.model?.materials.first as? SimpleMaterial {
                    material.color = simple.color
                    material.roughness = simple.roughness
                    material.metallic = simple.metallic
                } else {
                    material.color = .init(tint: .white)
                    material.roughness = 0.3
                    material.metallic = 0.7
                }
                let particle = ModelEntity(mesh: mesh, materials: [material])
                particle.position = SIMD3<Float>(
                    Float.random(in: -0.02...0.02),
                    Float.random(in: -0.02...0.02),
                    Float.random(in: -0.02...0.02)
                )
                explosion.addChild(particle)

                var velocity = SIMD3<Float>(
                    Float.random(in: -2...2),
                    Float.random(in: 0...2.5),
                    Float.random(in: -2...2)
                )
                let gravity: Float = -3.0
                let damp: Float = 0.96
                let start = CACurrentMediaTime()
                _ = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
                    let elapsed = Float(CACurrentMediaTime() - start)
                    if elapsed > 2.0 {
                        t.invalidate()
                        particle.removeFromParent()
                        return
                    }
                    velocity.y += gravity * 0.016
                    velocity *= damp
                    particle.position += velocity * 0.016
                    let additionalRotation = simd_quatf(angle: 2.0 * 0.016, axis: SIMD3<Float>(1, 1, 0))
                    particle.transform.rotation = particle.transform.rotation * additionalRotation
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                explosion.removeFromParent()
            }
        }

        func resetPlacement() {
            if let arView = arView {
                for anchor in arView.scene.anchors {
                    arView.scene.anchors.remove(anchor)
                }
            }
            rootAnchor = nil
            hasPlacedContent = false
            reticle?.isEnabled = false
            ghostBoard?.isEnabled = false
        }
    }
}

// Optional protocol that GameState can conform to so ARGameView can conform to RealityKit scene population
protocol GameStatePopulating {
    func populateScene(root: AnchorEntity)
}

extension simd_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }
}
#endif

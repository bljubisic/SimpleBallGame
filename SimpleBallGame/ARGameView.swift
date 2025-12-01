import SwiftUI
import RealityKit
import ARKit
import AVFoundation

#if !os(visionOS)
struct ARGameView: View {
    @Binding var gameState: GameState
    @Binding var resetPlacementTrigger: Bool
    
    var body: some View {
        ARViewContainer(gameState: $gameState, resetPlacementTrigger: $resetPlacementTrigger)
            .ignoresSafeArea()
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var gameState: GameState
    @Binding var resetPlacementTrigger: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        arView.session.run(config)
        
        // Store reference to ARView in coordinator
        context.coordinator.arView = arView
        context.coordinator.gameState = gameState
        
        // Set session delegate to track plane detection
        arView.session.delegate = context.coordinator

        // Add tap gesture recognizer (only for entity interaction after placement)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Add coaching overlay for better UX
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)

        // Store reference to coaching overlay in coordinator
        context.coordinator.coachingOverlay = coachingOverlay

        // Setup audio session
        context.coordinator.setupAudioSession()
        
        return arView
    }
    
    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.gameState = gameState

        // Handle reset trigger
        if resetPlacementTrigger {
            context.coordinator.resetPlacement()
            DispatchQueue.main.async {
                resetPlacementTrigger = false
            }
        }

        // Handle game complete
        if gameState.isGameComplete && context.coordinator.isPlaced {
            context.coordinator.showGameComplete()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(gameState: gameState)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var gameState: GameState
        weak var arView: ARView?
        weak var coachingOverlay: ARCoachingOverlayView?
        var gameAnchor: AnchorEntity?
        var gameCompleteEntity: ModelEntity?
        var isPlaced = false
        private var previousLevel: GameLevel?
        private var previousSubLevel: Int?
        private var detectedPlanes: [ARPlaneAnchor] = []
        
        init(gameState: GameState) {
            self.gameState = gameState
            self.previousLevel = gameState.currentLevel
            self.previousSubLevel = gameState.currentSubLevel
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    detectedPlanes.append(planeAnchor)
                    print("Plane detected: \(planeAnchor.alignment.rawValue)")

                    // Automatically place game on first plane detected (horizontal or vertical)
                    if !isPlaced {
                        print("Auto-placing game on \(planeAnchor.alignment == .vertical ? "vertical" : "horizontal") plane")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.autoPlaceGame(on: planeAnchor)
                        }
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    if let index = detectedPlanes.firstIndex(where: { $0.identifier == planeAnchor.identifier }) {
                        detectedPlanes[index] = planeAnchor
                    }
                }
            }
        }
        
        func setupAudioSession() {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to setup audio session: \(error)")
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = gesture.location(in: arView)

            if gameState.isGameComplete {
                // If game is complete, allow restart
                print("Restarting game")
                return
            } else if isPlaced {
                // Interact with entities
                print("entity tap")
                handleEntityTap(at: location, in: arView)
            }
        }
        
        func autoPlaceGame(on planeAnchor: ARPlaneAnchor) {
            guard !isPlaced, let arView = arView else { return }

            // Use the center of the plane anchor
            let anchor = AnchorEntity(anchor: planeAnchor)
            gameAnchor = anchor

            // Add anchor to scene first
            arView.scene.addAnchor(anchor)

            // Use GameState's populateScene method to set up game objects
            gameState.populateScene(root: anchor)

            isPlaced = true

            // Track current level
            previousLevel = gameState.currentLevel
            previousSubLevel = gameState.currentSubLevel

            // Hide and remove the coaching overlay once game is placed
            UIView.animate(withDuration: 0.3, animations: {
                self.coachingOverlay?.alpha = 0
            }) { _ in
                self.coachingOverlay?.setActive(false, animated: false)
                self.coachingOverlay?.removeFromSuperview()
            }

            print("Game placed automatically on \(planeAnchor.alignment == .vertical ? "vertical" : "horizontal") plane")
        }

        private func inferAlignmentFromRaycastResult(result: ARRaycastResult) -> Bool {
            // Check if the raycast result has an associated anchor
            if let anchor = result.anchor as? ARPlaneAnchor {
                return anchor.alignment == .vertical
            }

            // If no anchor, try to match to a detected plane by proximity
            let resultPos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                         result.worldTransform.columns.3.y,
                                         result.worldTransform.columns.3.z)

            if let closest = detectedPlanes.min(by: { a, b in
                let ap = SIMD3<Float>(a.transform.columns.3.x, a.transform.columns.3.y, a.transform.columns.3.z)
                let bp = SIMD3<Float>(b.transform.columns.3.x, b.transform.columns.3.y, b.transform.columns.3.z)
                return distance(ap, resultPos) < distance(bp, resultPos)
            }) {
                return closest.alignment == .vertical
            }

            // Default to horizontal
            return false
        }
        
        func placeGame(at location: CGPoint, in arView: ARView) {
            // Use modern raycasting API - try existing planes first, then estimated planes
            var raycastResult: ARRaycastResult?
            var isVertical = false
            
            // First try to hit existing planes (both vertical and horizontal)
            if let existingPlaneQuery = arView.makeRaycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: .vertical),
               let result = arView.session.raycast(existingPlaneQuery).first {
                raycastResult = result
                isVertical = inferAlignmentFromRaycastResult(result: result)
            }
            // If no existing plane hit, try estimated vertical plane
            else if let verticalQuery = arView.makeRaycastQuery(from: location, allowing: .estimatedPlane, alignment: .vertical),
                    let result = arView.session.raycast(verticalQuery).first {
                raycastResult = result
                isVertical = true
            }
            
            guard let result = raycastResult else {
                print("No surface detected - try scanning more surfaces")
                return
            }
            
            // Create anchor at the raycast result location
            let anchor = AnchorEntity(world: result.worldTransform)
            gameAnchor = anchor
            
            // Add anchor to scene first
            arView.scene.addAnchor(anchor)

            // Use GameState's populateScene method to set up game objects
            gameState.populateScene(root: anchor)

            isPlaced = true
            
            // Track current level
            previousLevel = gameState.currentLevel
            previousSubLevel = gameState.currentSubLevel

            // Hide and remove the coaching overlay once game is placed
            UIView.animate(withDuration: 0.3, animations: {
                self.coachingOverlay?.alpha = 0
            }) { _ in
                self.coachingOverlay?.setActive(false, animated: false)
                self.coachingOverlay?.removeFromSuperview()
            }

            print("Game placed successfully using raycast (isVertical: \(isVertical))")
        }

        func handleEntityTap(at location: CGPoint, in arView: ARView) {
            // Perform entity hit test
            let results = arView.hitTest(location)
            
            guard let firstResult = results.first else { return }
            let entity = firstResult.entity
            
            // Check if entity has collision component (all game spheres should)
            guard entity.components.has(CollisionComponent.self) else { return }
            
            // Check if this is actually a game sphere (not instruction text)
            guard entity.name.contains("-") else { return }
            
            // Prevent double-tapping by disabling collision immediately
            entity.components.remove(CollisionComponent.self)
            
            // Get color before handling tap
            let color = gameState.getColorOfEntity(entity)
            
            // Play sound
            playBalloonPopSound()
            
            // Create explosion effect at current position
            createExplosionEffect(at: entity, with: color, in: arView)
            
            // Temporarily store entity reference and remove it from parent to prevent GameState from finding it
            let entityParent = entity.parent
            let entityPosition = entity.position
            entity.removeFromParent()
            
            // Re-add entity to parent so we can animate it
            entityParent?.addChild(entity)
            entity.position = entityPosition
            
            // Update game state logic (score, level progression) but entity is already removed from GameState's tracking
            updateGameStateLogic(for: entity)
            
            // Animate the sphere shrinking and then remove it manually
            animateSphereDissapear(entity: entity) { [weak self] in
                DispatchQueue.main.async {
                    // Manually remove the entity after animation
                    entity.removeFromParent()
                }
            }
        }
        
        func updateGameStateLogic(for entity: Entity) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Check if the tapped entity was a current target
                let wasTarget = self.gameState.isCurrentTarget(entity)
                
                // Update current entities list by removing this entity
                self.gameState.removeCurrentEntity(entity)
                
                // Update all entities list
                self.gameState.removeAllEntity(entity)
                
                if wasTarget {
                    // This was a correct target
                    if self.gameState.getCurrentEntitiesCount() == 0 {
                        // Level cleared - call the private method logic
                        self.levelClearedLogic()
                    }
                } else {
                    // Wrong target - reduce time
                    self.gameState.timeRemaining -= self.gameState.selectedLevel.punishTime
                }
            }
        }
        
        func levelClearedLogic() {
            gameState.stopTimer()
            // Move to next level after delay
            let carryOverTime = max(gameState.timeRemaining, 5.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                if self.gameState.currentSubLevel < 10 {
                    self.gameState.currentSubLevel += 1
                    self.gameState.timeRemaining = carryOverTime + self.gameState.selectedLevel.subLevelTimeIncrement
                    self.gameState.addCurrentLevelObjects()
                } else if self.gameState.currentSubLevel == 10 && self.gameState.currentLevel != .hard {
                    self.gameState.timeRemaining = carryOverTime + self.gameState.selectedLevel.timeRemainingPerLevel
                    self.gameState.currentSubLevel = 0
                    self.gameState.currentLevel = GameLevel(rawValue: self.gameState.currentLevel.rawValue + 1)!
                    self.gameState.addCurrentLevelObjects()
                } else {
                    // Game complete
                    self.gameState.removeAllEntitiesFromParent()
                    self.gameState.isGameComplete = true
                    
                    // Save score
                    let score = Score(remainingTime: self.gameState.timeRemaining, timeStamp: Date.now, selectedLevel: self.gameState.selectedLevel)

                    // Load existing scores
                    var scores: [Score] = []
                    if let scoresData = UserDefaults.standard.data(forKey: "scores") {
                        scores = (try? JSONDecoder().decode([Score].self, from: scoresData)) ?? []
                    }

                    // Add new score and save
                    scores.append(score)
                    if let encodedScores = try? JSONEncoder().encode(scores) {
                        UserDefaults.standard.set(encodedScores, forKey: "scores")
                    }
                }
            }
        }
        
        func playBalloonPopSound() {
            // Generate balloon pop sound programmatically using AVAudioEngine
            let audioEngine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            
            // Create a short burst of noise to simulate balloon pop
            let frameCount = AVAudioFrameCount(0.2 * audioFormat.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            
            for i in 0..<Int(frameCount) {
                let time = Float(i) / Float(audioFormat.sampleRate)
                let envelope = exp(-time * 15.0)
                let frequency = 800.0 * (1.0 - time * 2.0)
                let noise = Float.random(in: -1...1) * 0.3
                let tone = sin(2.0 * Float.pi * frequency * time)
                channelData[i] = (tone * 0.7 + noise * 0.3) * envelope * 0.8
            }
            
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
            
            do {
                try audioEngine.start()
                playerNode.scheduleBuffer(buffer, at: nil)
                playerNode.play()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioEngine.stop()
                }
            } catch {
                print("Failed to play balloon pop sound: \(error)")
            }
        }
        
        func createExplosionEffect(at entity: Entity, with color: UIColor, in arView: ARView) {
            let particleCount = 30
            let explosionEntity = Entity()
            explosionEntity.position = entity.position
            
            for _ in 0..<particleCount {
                let particleMesh = MeshResource.generateBox(size: 0.01)
                var particleMaterial = SimpleMaterial()
                particleMaterial.color = .init(tint: color)
                particleMaterial.roughness = 0.3
                particleMaterial.metallic = 0.7
                
                let particle = ModelEntity(mesh: particleMesh, materials: [particleMaterial])
                
                // Random direction
                let randomX = Float.random(in: -1...1)
                let randomY = Float.random(in: -0.5...1)
                let randomZ = Float.random(in: -1...1)
                let direction = normalize(SIMD3<Float>(randomX, randomY, randomZ))
                let speed = Float.random(in: 0.15...0.3)  // Reduced speed for better visibility
                let velocity = direction * speed
                
                let randomOffset = SIMD3<Float>(
                    Float.random(in: -0.01...0.01),
                    Float.random(in: -0.01...0.01),
                    Float.random(in: -0.01...0.01)
                )
                particle.position = randomOffset
                
                explosionEntity.addChild(particle)
                animateParticle(particle, initialVelocity: velocity)
            }
            
            entity.parent?.addChild(explosionEntity)
            
            // Clean up particles after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                explosionEntity.removeFromParent()
            }
        }
        
        func animateParticle(_ particle: ModelEntity, initialVelocity: SIMD3<Float>) {
            let gravity: Float = -0.5  // Reduced gravity for AR scale
            let dampening: Float = 0.98
            var currentVelocity = initialVelocity
            let startTime = CACurrentMediaTime()
            let duration: Float = 1.5
            
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                let elapsed = Float(CACurrentMediaTime() - startTime)
                if elapsed >= duration {
                    timer.invalidate()
                    withAnimation(.easeOut(duration: 0.3)) {
                        particle.components[OpacityComponent.self] = OpacityComponent(opacity: 0.0)
                    }
                    return
                }
                
                currentVelocity.y += gravity * 0.016
                currentVelocity *= dampening
                particle.position += currentVelocity * 0.016
                
                let rotationSpeed: Float = 3.0
                let currentRotation = particle.transform.rotation
                let additionalRotation = simd_quatf(angle: rotationSpeed * 0.016, axis: SIMD3<Float>(1, 1, 0))
                particle.transform.rotation = currentRotation * additionalRotation
            }
        }
        
        func animateSphereDissapear(entity: Entity, completion: @escaping () -> Void) {
            // Store the original scale
            let originalScale = entity.transform.scale
            
            // Animate the sphere shrinking with a bounce effect
            let shrinkDuration: TimeInterval = 0.4
            let startTime = CACurrentMediaTime()
            
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(elapsed / shrinkDuration, 1.0)
                
                if progress >= 1.0 {
                    timer.invalidate()
                    // Make sure it's completely gone
                    entity.transform.scale = SIMD3<Float>(0, 0, 0)
                    completion()
                    return
                }
                
                // Create a bounce-out easing effect
                let easeOutBounce = { (t: Double) -> Double in
                    if t < 1/2.75 {
                        return 7.5625 * t * t
                    } else if t < 2/2.75 {
                        let t2 = t - 1.5/2.75
                        return 7.5625 * t2 * t2 + 0.75
                    } else if t < 2.5/2.75 {
                        let t2 = t - 2.25/2.75
                        return 7.5625 * t2 * t2 + 0.9375
                    } else {
                        let t2 = t - 2.625/2.75
                        return 7.5625 * t2 * t2 + 0.984375
                    }
                }
                
                // Apply reverse bounce (shrinking)
                let scale = Float(1.0 - easeOutBounce(progress))
                entity.transform.scale = originalScale * scale
                
                // Add a subtle rotation for more dynamic effect
                let rotationAngle = Float(progress * .pi * 2)
                entity.transform.rotation = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
        
        func showGameComplete() {
            // Game complete UI is handled by GameView overlay
            // No 3D text needed in AR scene
        }
        
        func resetPlacement() {
            // Stop the game timer
            gameState.stopTimer()

            // Remove anchor and all children
            gameAnchor?.removeFromParent()
            gameAnchor = nil
            gameCompleteEntity = nil
            isPlaced = false
            previousLevel = nil
            previousSubLevel = nil

            // Recreate the coaching overlay
            if let arView = arView, coachingOverlay == nil || coachingOverlay?.superview == nil {
                let newCoachingOverlay = ARCoachingOverlayView()
                newCoachingOverlay.session = arView.session
                newCoachingOverlay.goal = .horizontalPlane
                newCoachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                newCoachingOverlay.alpha = 0
                arView.addSubview(newCoachingOverlay)
                coachingOverlay = newCoachingOverlay

                // Fade in the coaching overlay
                UIView.animate(withDuration: 0.3) {
                    newCoachingOverlay.alpha = 1
                }
                newCoachingOverlay.setActive(true, animated: true)
            } else {
                // If overlay still exists, just reactivate it
                coachingOverlay?.alpha = 0
                coachingOverlay?.setActive(true, animated: true)
                UIView.animate(withDuration: 0.3) {
                    self.coachingOverlay?.alpha = 1
                }
            }

            // Reset game state
            DispatchQueue.main.async { [weak self] in
                self?.gameState.resetGame()
            }
        }
    }
}
#endif

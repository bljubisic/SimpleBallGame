---
date: 2024-06-27 19:34
description: survey-md or How to Make a Survey Out of Markdown
tags: Svelte, Markdown, Survey, Typescript, Javascript
---

# Chasing Colors - Developing an Immersive Game

When the challenge of creating an immersive game for Apple Vision Pro came up, I was excited to explore the possibilities of this new platform. The goal was to create a game that would not only be visually stunning but also engaging and interactive, leveraging the unique capabilities of the Vision Pro.
I have already did a SwiftUI update for QuickToDo app, so I was familiar with the platform. The game, titled "Chasing Colors", is a simple yet captivating experience where players chase and collect colored orbs in a vibrant 3D environment. The game is intentionally designed to be simple, focusing on the immersive experience rather than complex mechanics. The main purpose of this app is to showcase the capabilities of the Vision Pro and provide a fun, engaging experience for users. I wanted to try out how to use RealityView and RealityKit to create a 3D environment that players can explore and interact with. Also, I wanted to experiment with Attachments and Anchors to create a more immersive experience.

## Game Overview
First thing that user see is difficulty selection screen, where user can choose between three different difficulties: Easy, Medium, and Hard. Each difficulty level changes the initial number of orbs in the game, with Easy starting with 10 orbs, Medium with 20, and Hard with 30. The game is designed to be played in an unobtrusive environment, allowing players to focus on the immersive experience without distractions. The gameplay is simple: player should 'tap' on the orbs to collect them, selecting only the orbs with specified color. Remaining time is displayed on the attachment screen and the level is completed when all orbs with specified color are collected, or time runs out. There are three major levels within the game, each containing 10 sublevels. In each sublevel, number of orbs is increased by one, and in each major level number of different colors is increased by number specified on selected difficulty level. For example, in Easy mode, first major level has 3 color, second has 6 colors, and third has 9 colors. In Medium mode, first major level has 5 colors, second has 10 colors, and third has 15 colors. In Hard mode, first major level has 9 colors, second has 18 colors, and third has 27 colors. Also, selected difficulty level determines the initial time for each level, time removed as punishment when selecting orb with wrong color and how many orbs will be added with each new level. The game is designed with intention that orbs are never intersecting and that colors be close to each other so that player should focus on finding the wright ones.

## Development of the Game

The game is built using SwiftUI and RealityKit, leveraging the capabilities of Apple Vision Pro. The main components of the game are:
- GameView: The main view of the game, where the RealityView is displayed.
- InstructionView: A view that provides info attachment view with remaining time and chosen color.
- LevelSelectView: A view that allows players to select the difficulty level.
- GameCompleteOverlay: An overlay that appears when the game is completed, showing the score and allowing players to restart or go back to the main menu.
- GameState: A class that manages the game state, including the current level, score, and remaining time.

### Display Immersive RealityView together with Windows within Mixed environment

For displaying the difficulty selection screen, I use normal 2D window that is displayed right in front of the user. This is done using SwiftUI WindowGroup, which allows us to create a window that can be displayed in the mixed environment. Once the level is selected the GameView is displayed. The code for this looks like this:

```swift
    var body: some SwiftUI.Scene {
        WindowGroup(id: "levelSelection") {
            LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        }.windowStyle(.automatic)
        
        ImmersiveSpace(id: "something") {
            GameView(gameState: $gameState)
        }
        .immersionStyle(selection: $gameImmersionStyle, in: .mixed)
    }
```
As you can see both WindowGroup and ImmersiveSpace have ids, so we could show them or hide them as needed. This is done using environment variables:

```swift
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
```

### Selecting positions for orbs
Once the difficulty level is selected, the GameState will be created and initialyied. This means that we need to create the initial positions for the orbs. This is done using a simple function that generates random positions within a specified range. The positions are stored in an array, which is then used to create the orbs in the RealityView. The code for this looks like this:

```Swift
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
                    -baseDistance + Float.random(in: -0.4...0.4) // 1m forward ± 20cm
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
```
As you can see the positions are generated in a hemisphere in front of the user, with some random variation in the forward distance. This ensures that the orbs are not too close to each other and that they are positioned in a way that is easy for the user to interact with. All of the variables are defined in the GameState class, so they can be easily adjusted.

### Attachments and Overlays
When the game has started, InstructionView is displayed in the front of the user, showing the remaining time and the color that needs to be collected. This is done using SwiftUI's attachment system, which allows us to create a view that is displayed in the mixed reality environment. The code for this looks like this:

```swift
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
                        playBalloonPopSound()
                        createExplosionEffect(at: value.entity, with: color)
                        gameState.handleTap(on: value.entity)
                    }
            )
        }
```
Where attachments will show up is set in the GameState class, in setupScene:
```Swift
        if let instructions = attachments.entity(for: "Instructions") {
            instructions.position = SIMD3(1, 1.8, -1)

            content.add(instructions)
        }
```
That position is set relative to the initial anchor of the realityView.

### Anchors
The main ancho for the game is set in the GameState class, which is used to position the RealityView in the mixed reality environment. The anchor is created using the `AnchorEntity` class, which allows us to create an anchor that can be used to position the RealityView. The code for this looks like this:

```swift
        anchorEntity = AnchorEntity(.head, trackingMode: .once)
        content.add(anchorEntity)
```
AnchorEntity is set to track the user's head, which allows the RealityView to be positioned in front of the user. Anchor is tracked only once, which means that the game objects will not move with the user's head, but will remain in the same position relative to the user's initial position. This is important for the game, as it allows the user to interact with the orbs without having to move their head.

### Explosion Effect
To create an explosion effect when the user taps on an orb, I used a simple particle system that is created in the RealityKit. The particle system is created using the `ParticleSystemComponent` class, which allows us to create a particle system that can be used to create the explosion effect. The code for this looks like this:

```swift
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
```
As we are dealing with orbs within the game, the particles are created to be small cubes that are randomly positioned around the orb that was tapped. The particles are animated to move in random directions with a random speed, creating an explosion effect. The explosion entity is added to the scene and is removed after a few seconds to clean up the resources. Animation for the particles is done using a simple function that applies a force to the particles, making them move in the specified direction with the specified speed. The code for this looks like this:

```swift
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
```

### Sound Effects
There is a sound effect that is played when the user taps on an orb. The sound effect is created using the `AVAudioPlayer` class, which allows us to play a sound file when the user taps on an orb. The code for this looks like this:

```swift
    private func playBalloonPopSound() {
        // Generate balloon pop sound programmatically using AVAudioEngine
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        // Create a short burst of noise to simulate balloon pop
        let frameCount = AVAudioFrameCount(0.2 * audioFormat.sampleRate) // 0.2 seconds
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        // Generate balloon pop sound - quick burst with frequency sweep
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(audioFormat.sampleRate)
            let envelope = exp(-time * 15.0) // Quick decay envelope
            let frequency = 800.0 * (1.0 - time * 2.0) // Frequency sweep down
            let noise = Float.random(in: -1...1) * 0.3 // Add some noise
            let tone = sin(2.0 * Float.pi * frequency * time)
            channelData[i] = (tone * 0.7 + noise * 0.3) * envelope * 0.8
        }
        
        // Setup and play the sound
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
            playerNode.scheduleBuffer(buffer, at: nil)
            playerNode.play()
            
            // Stop the engine after the sound finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                audioEngine.stop()
            }
        } catch {
            print("Failed to play balloon pop sound: \(error)")
        }
    }
```
As can been seen, I am not using any pre-recorded sound files, but rather generating the sound programmatically using `AVAudioEngine`. This allows for more flexibility and control over the sound effects, making them more dynamic and engaging. Probably there is a better way to do this, but I wanted to try out how to generate sound programmatically.

## Ending the Game
When the game is completed, the `GameCompleteOverlay` is displayed, showing the score and allowing players to restart or go back to the main menu. The overlay is created using SwiftUI's attachment system, which allows us to create a view that is displayed in the mixed reality environment. The code for this looks like this:

```swift
    Attachment(id: "game-complete") {
        GameCompleteOverlay(gameState: gameState)
    }
```
The overlay is displayed in the front of the user, allowing them to see their score and choose whether to restart the game or go back to the main menu. The score (remaining time) is stored in UserDefaults, allowing players to see their best score for each difficulty level. The game can be restarted by simply tapping on the "Restart" button in the overlay, which will reset the game state and start a new game.

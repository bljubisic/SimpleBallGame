//
//  GameState.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 7/8/25.
//
import Foundation
import SwiftUI
import RealityKit

struct Score: Codable {
    let remainingTime: Double
    let timeStamp: Date
    let selectedLevel: GameState.GameLevel
}

class GameState: ObservableObject {
    
    @Published var currentLevel: GameLevel = .easy
    @Published var currentSubLevel: Int = 0
    @Published var selectedLevel: GameLevel = .easy
    @Published var isGameComplete = false
    @Published var currentGame: CurrentGameState = .init()
    @Published var timeRemaining: Double = 0
    @Published var totalScore: Int = 0
    @Published var isTimerRunning = false
    @Published var scores: [Score] = []
    
    private var anchorEntity: AnchorEntity?
    private var timer: Timer?
    private var currentEntities: [BallModel] = []
    private var allEntities: [BallModel] = []
    private let initialTime: Double = 10.0

    
    @Published var textColor: UIColor = .white
    
    init(currentLevel: GameLevel) {
        self.selectedLevel = currentLevel
        self.currentSubLevel = 0
        self.scores = UserDefaults.standard.array(forKey: "scores") as? [Score] ?? []
    }
    
    enum GameLevel: Int, CaseIterable, Codable, Comparable {
        
        static func < (lhs: GameState.GameLevel, rhs: GameState.GameLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
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
        
        var timeRemainingPerLevel: Double {
            switch self {
            case .easy:
                return 30.0
            case .medium:
                return 20.0
            case .hard:
                return 10.0
            }
        }
        
        var subLevelTimeIncrement: Double {
            switch self {
            case .easy:
                return 20.0
            case .medium:
                return 15.0
            case .hard:
                return 10.0
            }
        }
        
        var initialObjectsPerLevel: Int {
            switch self {
            case .easy:
                return 10
            case .medium:
                return 15
            case .hard:
                return 20
            }
        }
        
        var colorsPerLevel: Int {
            switch self {
            case .easy:
                return 3
            case .medium:
                return 5
            case .hard:
                return 9
            }
        }
    
        var objectsPerLevelIncrement: Int {
            switch self {
            case .easy:
                return 10
            case .medium:
                return 12
            case .hard:
                return 15
            }
        }
        
        var punishTime: Double {
            switch self {
            case .easy:
                return 0.5
            case .medium:
                return 1.0
            case .hard:
                return 1.5
            }
        }
    }
    
    func setupScene(content: RealityViewContent, attachments: RealityViewAttachments) {
        self.timeRemaining = self.selectedLevel.timeRemainingPerLevel
        anchorEntity = AnchorEntity(.head, trackingMode: .once)
        var scoresData = UserDefaults.standard.object(forKey: "scores")
        do {
            if let scoresData = scoresData {
                let scores = try JSONDecoder().decode([Score].self, from: scoresData as! Data)
                self.scores = scores
            } else {
                self.scores = []
            }
        } catch {
            print(error)
            self.scores = []
        }
        content.add(anchorEntity!)
        
        if let instructions = attachments.entity(for: "Instructions") {
            instructions.position = SIMD3(1, 1.8, -1)

            content.add(instructions)
        }
        if let gameComplete = attachments.entity(for: "game-complete")  {
            gameComplete.position.z -= 1
            gameComplete.position.y += 2
            gameComplete.position.x -= 0
            content.add(gameComplete)
        }
        addCurrentLevelObjects()
    }
    
    func updateScene(content: RealityViewContent, attachments: RealityViewAttachments) {
        // Apply attachment to instruction entity if available
        if let instructions = attachments.entity(for: "Instructions") {
            // Try to get the attachment and apply it to our entity
            for entity in content.entities {
                if entity.name == "instruction-text" {
                    // Copy attachment components to our positioned entity
                    instructions.components = entity.components
                }
            }
        }
        
        // Handle game complete overlay
        if let gameComplete = attachments.entity(for: "game-complete") {
            gameComplete.position = SIMD3(0, 1.7, -1)
            content.add(gameComplete)
        }
    }
    
    func getColorOfEntity(_ entity: Entity) -> UIColor {
        return self.allEntities.filter { ballModel in
            ballModel.sphere == entity
        }.map { ballModel in
            ballModel.color
        }[0]
    }
    
    func handleTap(on entity: Entity) {
        // Check if the tapped entity is our current target
        entity.removeFromParent()

        if currentEntities.contains(where: { sphere in
            sphere.sphere == entity
        }) {
            currentEntities.removeAll { ballModel in
                ballModel.sphere == entity
            }
            if currentEntities .isEmpty {
                levelCleared()
            }
        } else {
            self.timeRemaining -= self.selectedLevel.punishTime
        }
    }
    
    private func levelCleared() {
        stopTimer()
        // Move to next level after delay
        // Carry over remaining time to next level (with minimum of 5 seconds)
        let carryOverTime = max(self.timeRemaining, 5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.currentSubLevel < 10{
                self.currentSubLevel += 1
                self.timeRemaining = carryOverTime + self.selectedLevel.subLevelTimeIncrement
                self.addCurrentLevelObjects()
            } else if self.currentSubLevel == 10 && self.currentLevel != .hard {
                self.timeRemaining = carryOverTime + self.selectedLevel.timeRemainingPerLevel
                self.currentSubLevel = 0
                self.currentLevel = GameLevel(rawValue: self.currentLevel.rawValue + 1)!
                self.addCurrentLevelObjects()
            } else {
                self.allEntities.forEach{ entity in
                    entity.sphere.removeFromParent()
                }
                self.allEntities.removeAll()
                self.isGameComplete = true
                // save the remainingTime as an object within the defaults
                let score = Score(remainingTime: self.timeRemaining, timeStamp: Date.now, selectedLevel: self.selectedLevel)
                var scoresData = UserDefaults.standard.object(forKey: "scores")
                var scores = try? JSONDecoder().decode([Score].self, from: scoresData as! Data)
                if scores == nil {
                    scores = []
                }
                if var scores = scores {
                    scores.append(score)
                    scoresData = try? JSONEncoder().encode(scores)
                    if let scoresData = scoresData {
                        UserDefaults.standard.set(scoresData, forKey: "scores")
                    }
                }

            }
        }
    }
    
    func startTimer() {
        isTimerRunning = true
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                } else {
                    // Time's up - game over
                    self.timeUp()
                }
            }
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func timeUp() {
        stopTimer()
        isGameComplete = true
        allEntities.forEach{ entity in
            entity.sphere.removeFromParent()
        }
        allEntities.removeAll()
    }
    
    func resetGame() {
        stopTimer()
        currentLevel = .easy
        isGameComplete = false
//        showCelebration = false
        timeRemaining = 0
        totalScore = 0
        self.scores = UserDefaults.standard.array(forKey: "scores") as? [Score] ?? []
//        addCurrentLevelObjects()
    }
    
    func addCurrentLevelObjects() {
        allEntities.forEach{ entity in
            entity.sphere.removeFromParent()
        }
        allEntities.removeAll()
        
        allEntities = createObjects(for: currentLevel, and: currentSubLevel)
        let usedColors: [UIColor] = allEntities.reduce([]) { result, ballModel in
            result.contains(ballModel.color) ? result : result + [ballModel.color]
        }
        if let firstColor = usedColors.first {
            textColor = firstColor
        }
        currentEntities = allEntities.filter{sphere in sphere.color == textColor}
        
        // Start timer for this level
        startTimer()
    }
    
    func createObjects(for level: GameLevel, and subLevel: Int) -> [BallModel] {
        var ballModels: [BallModel] = []
        let colors = generateRandomColors(selectedLevel: level)
        var numberOfObjects: Int = 0
        if self.currentLevel == .easy {
            numberOfObjects = self.selectedLevel.initialObjectsPerLevel
        }
        numberOfObjects += GameLevel.allCases.reduce(0, { partialResult, level in
            var intermediateResult = 0
            if self.currentLevel != .easy && (level <= self.currentLevel) {
                intermediateResult = self.selectedLevel.objectsPerLevelIncrement
            }
            return partialResult + intermediateResult
        }) + subLevel
        
        let positions = generateNonIntersectingPositions(for: numberOfObjects)
        
        for i in 0..<numberOfObjects {
            let color = colors.randomElement() ?? .white
            let sphere = createSphere(index: i, position: positions[i], useColor: color)
            let uuid = UUID(uuidString: sphere.name)!
            let ballModel = BallModel(id: uuid, position: sphere.position, pickedUp: false, color: color, sphere: sphere)
            currentGame.ballModels.append(ballModel)
            ballModels.append(ballModel)
            anchorEntity?.addChild(ballModel.sphere)
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
        let minDistance = sphereRadius * 2 // Minimum distance between sphere centers (with small buffer)
        
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
        
        return positions
    }
    
    private func generateRandomColors(selectedLevel: GameLevel) -> [UIColor] {
        var colors: [UIColor] = []
        let maxAttempts = 10000 // Prevent infinite loops
        let minColorDistance: Float = 0.3 // Minimum distance between colors in RGB space
        var numberOfColors: Int = 0
        if self.currentLevel == .easy {
            numberOfColors = self.selectedLevel.colorsPerLevel
        }
        numberOfColors += GameLevel.allCases.reduce(0, { partialResult, level in
            var intermediateResult = 0
            if self.currentLevel != .easy && (level <= self.currentLevel) {
                intermediateResult = self.selectedLevel.colorsPerLevel
            }
            return partialResult + intermediateResult
        })
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

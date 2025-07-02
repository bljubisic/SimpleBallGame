//
//  AppModel.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    enum Level: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
    }
}

let BASE_BALLS_NUM: Int = 10
let SUBLEVELS_PER_LEVEL: Int = 10
let BASE_NUMBER_OF_COLORS: Int = 3

let levelMultiplier: [AppModel.Level: Int] = [
    .easy: 1,
    .medium: 2,
    .hard: 3
]

struct BallModel {
    let id: UUID
    let position: SIMD3<Float>
    let pickedUp: Bool
    let color: UIColor
    
}

struct Game {
    let level: AppModel.Level
    let subLevel: Int
    let keptTimePerLevel: [String: TimeInterval]
    let colors: [UIColor]
}

extension Game {
    init() {
        self.level = .easy
        self.subLevel = 0
        self.keptTimePerLevel = [:]
        self.colors = []
    }
    
    init(level: AppModel.Level, subLevel: Int) {
        self.level = level
        self.subLevel = subLevel
        self.keptTimePerLevel = [:]
        self.colors = []
    }
}

struct CurrentGameState {
    var game: Game
    var ballModels: [BallModel]
}

extension CurrentGameState {
    init() {
        self.game = Game()
        self.ballModels = []
    }
    
    init(game: Game) {
        self.game = game
        self.ballModels = []
    }
}

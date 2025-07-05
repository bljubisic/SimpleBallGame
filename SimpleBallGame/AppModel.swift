//
//  AppModel.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//

import SwiftUI
import RealityKit

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
    let sphere: Entity
}

extension BallModel {
    static let ballModelPickedUpLens = Lens<BallModel, Bool>(
        get: { $0.pickedUp },
        set: { pickedUp, ballModel in
            BallModel(id: ballModel.id, position: ballModel.position, pickedUp: pickedUp, color: ballModel.color, sphere: ballModel.sphere)
        }
    )
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
    
    init (level: AppModel.Level, subLevel:Int, keepTimePerLevel: [String: TimeInterval], colors: [UIColor]) {
        self.level = level
        self.subLevel = subLevel
        self.keptTimePerLevel = keepTimePerLevel
        self.colors = colors
    }
    
    init(level: AppModel.Level, subLevel: Int) {
        self.level = level
        self.subLevel = subLevel
        self.keptTimePerLevel = [:]
        self.colors = []
    }
}
extension Game {
    static let gameLevelLens = Lens<Game, AppModel.Level>(
        get: { $0.level },
        set: { level, game in
            Game(level: level, subLevel: game.subLevel, keepTimePerLevel: [:], colors: [])
        }
    )
    
    static let gameTimePerLevelLens = Lens<Game, [String: TimeInterval]>(
        get: { $0.keptTimePerLevel },
        set: { keptTimePerLevel, game in
            Game(level: game.level, subLevel: game.subLevel, keepTimePerLevel: keptTimePerLevel, colors: game.colors)
        }
    )
    
    static let gameSubLevelLens = Lens<Game, Int>(
        get: { $0.subLevel },
        set: { subLevel, game in
            Game(level: game.level, subLevel: subLevel, keepTimePerLevel: game.keptTimePerLevel, colors: game.colors)
        }
    )
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

extension CurrentGameState {
    static let currentGameGameLens = Lens<CurrentGameState, Game>(
        get: { $0.game },
        set: { game, currentGameState in
            CurrentGameState(game: game, ballModels: currentGameState.ballModels)
        }
    )
    
    static let currentGameBallModelsLens = Lens<CurrentGameState, [BallModel]>(
        get: { $0.ballModels },
        set: { ballModels, currentGameState in
            CurrentGameState(game: currentGameState.game, ballModels: ballModels)
        }
    )
}

struct Lens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
}



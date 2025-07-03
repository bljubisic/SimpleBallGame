//
//  SimpleBallGameApp.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//

import SwiftUI
import RealityKit

@main
struct SimpleBallGameApp: App {
    @State var selectedLevel: AppModel.Level = .easy
    @State private var gameImmersionStyle: ImmersionStyle = .mixed
    
    @State var game: Game = Game()
    @State var currentGame: CurrentGameState = CurrentGameState()
    var body: some SwiftUI.Scene {
        WindowGroup(id: "levelSelection") {
            LevelSelectView(selectedLevel: $selectedLevel, game: $game)
        }.windowStyle(.automatic)
        
        ImmersiveSpace(id: "something") {
            GameView(selectedLevel: $selectedLevel, game: $game, currentGame: $currentGame)
        }
        .immersionStyle(selection: $gameImmersionStyle, in: .mixed)
    }
}

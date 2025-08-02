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
    @State var selectedLevel: GameState.GameLevel = .easy
    @State private var gameImmersionStyle: ImmersionStyle = .mixed
    
    @State var gameState: GameState = GameState(currentLevel: .easy)
    
    var body: some SwiftUI.Scene {
        WindowGroup(id: "levelSelection") {
            LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        }.windowStyle(.automatic)
        
        ImmersiveSpace(id: "something") {
            GameView(gameState: $gameState)
        }
        .immersionStyle(selection: $gameImmersionStyle, in: .mixed)
    }
}

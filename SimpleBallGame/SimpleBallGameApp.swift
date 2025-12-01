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
    @State private var selectedLevel: GameLevel = .easy
#if os(visionOS)
    @State private var gameImmersionStyle: ImmersionStyle = .mixed
#endif

    @State private var gameState: GameState = GameState()
    
    var body: some SwiftUI.Scene {
        WindowGroup(id: "levelSelection") {
            LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        }
#if os(macOS) || os(visionOS)
        .windowStyle(.automatic)
#endif
        
#if os(visionOS)
        ImmersiveSpace(id: "something") {
            GameView(gameState: $gameState)
        }
        .immersionStyle(selection: $gameImmersionStyle, in: .mixed)
#endif
    }
}

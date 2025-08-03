//
//  GameCompleteView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 8/1/25.
//
import SwiftUI

struct GameCompleteView: View {
    @Environment(\.dismissImmersiveSpace) var closeImmersiveSpace
    @ObservedObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🏆")
                .font(.system(size: 60))
            
            Text("Congratulations!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("You've completed all levels!")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("Play Again") {
                gameState.resetGame()
                Task {
                    await closeImmersiveSpace()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: gameState.isGameComplete)
    }
}

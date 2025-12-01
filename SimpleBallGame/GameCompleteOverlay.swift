//
//  GameCompleteView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 8/1/25.
//
import SwiftUI

// Game Complete Overlay for Immersive Space
struct GameCompleteOverlay: View {
    @ObservedObject var gameState: GameState
    @Environment(\.openWindow) var openWindow
    #if os(visionOS)
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif
    
    var body: some View {
        if gameState.isGameComplete {
            VStack(spacing: 10) {
                Text(gameState.timeRemaining <= 0 ? "⏰" : "🏆")
                    .font(.system(size: 40))
                
                Text(gameState.timeRemaining <= 0 ? "Time's Up!" : "Congratulations!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if gameState.timeRemaining > 0 {
                    Text("You've completed all levels!")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Better luck next time!")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Final Score Display
                VStack(spacing: 8) {
                    Text("FINAL SCORE")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(gameState.timeRemaining)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                    
                    Text("points")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                Button("Play Again") {
                    Task {
                        gameState.resetGame()
                        #if os(visionOS)
                        await dismissImmersiveSpace()
                        openWindow(id: "levelSelection")
                        #else
                        // On iOS, simply reset; presenting UI is handled by navigation.
                        #endif
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 10)
        } else {
            EmptyView()
        }
    }
}


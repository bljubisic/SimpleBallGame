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
    
    var body: some View {
        if gameState.isGameComplete {
            VStack(spacing: 20) {
                Text(gameState.timeRemaining <= 0 ? "⏰" : "🏆")
                    .font(.system(size: 80))
                
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
                    
                    Text("\(gameState.totalScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
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
                    gameState.resetGame()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 10)
        }  else {
            EmptyView()
        }
    }
}

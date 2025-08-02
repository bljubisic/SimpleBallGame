//
//  InstructionsTextView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 7/29/25.
//
import SwiftUI


struct InstructionTextView: View {
    @ObservedObject var gameState: GameState
    
    var body: some View {
        VStack {
            // Timer
            VStack {
                Text("TIME")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f", gameState.timeRemaining))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(timerColor)
                    .monospacedDigit()
            }
            Spacer()
            
            HStack {
                Text("Remove all balls with ")
                    .font(.title)
                Text("this color!!")
                    .foregroundColor(Color(gameState.textColor))
                    .font(.title)
            }
            .padding()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: gameState.currentLevel)
    }
    
    private var timerColor: Color {
        if gameState.timeRemaining > 5.0 {
            return .green
        } else if gameState.timeRemaining > 2.0 {
            return .orange
        } else {
            return .red
        }
    }
}

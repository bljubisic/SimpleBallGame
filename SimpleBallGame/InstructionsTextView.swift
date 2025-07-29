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
}

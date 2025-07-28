//
//  LevelSelectView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI

struct LevelSelectView: View {
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Binding var selectedLevel: GameState.GameLevel
    
    @Binding var gameState: GameState
    let difficulty = ["Easy", "Medium", "Hard"]
    
    var body : some View {
        NavigationStack {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.extraLargeTitle)
                    .padding()
                ForEach(GameState.GameLevel.allCases, id: \.self) { level in
                    Button(action: {
                        Task {
                            selectedLevel = level
                            gameState = GameState(currentLevel: selectedLevel)
                            await openImmersiveSpace(id: "something")
                        }
                    }, label: {
                        Text(level.title)
                            .foregroundColor(.white)
                            .frame(width: 100, height: 30) // Adjust width and height as needed
                            .cornerRadius(10)
                    })
                }
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    
    @Previewable @State var selectedLevel: GameState.GameLevel = .easy
    @Previewable @State var gameState: GameState = GameState(currentLevel: .easy)
    LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        .environment(AppModel())
}

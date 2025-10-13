//
//  LevelSelectView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI

struct LevelSelectView: View {
    
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
#endif
    @Binding var selectedLevel: GameState.GameLevel
    
    @Binding var gameState: GameState
    let difficulty = ["Easy", "Medium", "Hard"]
    
    var body : some View {
        NavigationStack {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.largeTitle)
                    .padding()
                ForEach(GameState.GameLevel.allCases, id: \.self) { level in
                    Button(action: {
                        startGame(for: level)
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
    
    private func startGame(for level: GameState.GameLevel) {
        selectedLevel = level
        gameState = GameState(currentLevel: selectedLevel)
    #if os(visionOS)
        Task {
            await openImmersiveSpace(id: "something")
            dismissWindow(id: "levelSelection")
        }
    #else
        // On iOS, simply proceed; navigation to the game view should be handled by the app's scene or a NavigationStack push.
    #endif
    }
}

#if os(visionOS)
#Preview {
    @Previewable @State var selectedLevel: GameState.GameLevel = .easy
    @Previewable @State var gameState: GameState = GameState(currentLevel: .easy)
    LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        .environment(AppModel())
}
#else
#Preview {
    @Previewable @State var selectedLevel: GameState.GameLevel = .easy
    @Previewable @State var gameState: GameState = GameState(currentLevel: .easy)
    LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
}
#endif

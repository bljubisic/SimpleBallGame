//
//  LevelSelectView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI

fileprivate enum _GameViewFactory {
    // Tries to construct `GameView` if it exists with a compatible initializer.
    // Adjust this to match your actual GameView signature if needed.
    static func makeIfAvailable(level: GameLevel, selectedLevel: Binding<GameLevel>, gameState: Binding<GameState>) -> AnyView? {
        // Common patterns tried via conditional compilation to avoid hard dependency.
        #if canImport(SwiftUI)
//         If you have a `GameView` that takes bindings, uncomment and tailor the line below and remove the fallback return nil.
        return AnyView(GameView(gameState: gameState))
        #endif
//        return nil
    }
}

struct LevelSelectView: View {
    
#if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
#endif
    @State private var navPath = NavigationPath()
    
    @Binding var selectedLevel: GameLevel
    
    @Binding var gameState: GameState
    let difficulty = ["Easy", "Medium", "Hard"]
    
    var body : some View {
        NavigationStack(path: $navPath) {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.largeTitle)
                    .padding()
                ForEach(GameLevel.allCases, id: \.self) { (level: GameLevel) in
                    Button(action: {
                        startGame(for: level)
                    }, label: {
                        Text((level as? any RawRepresentable & CustomStringConvertible) != nil ? String(describing: level).capitalized : (Mirror(reflecting: level).children.first?.label?.capitalized ?? String(describing: level)))
                            .foregroundColor(.white)
                            .frame(width: 140, height: 44)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    })
                }
            }
            .navigationDestination(for: GameLevel.self) { level in
#if canImport(SwiftUI)
                // Replace `GameView` with your actual game view if its name differs.
                // It should accept `gameState` and/or `selectedLevel` as needed.
                if let gameView = _GameViewFactory.makeIfAvailable(level: level, selectedLevel: $selectedLevel, gameState: $gameState) {
                    gameView
                } else {
                    VStack(spacing: 16) {
                        Text("Game View not found")
                            .font(.headline)
                        Text("Selected level: \(String(describing: level).capitalized)")
                        Text("Implement a navigation destination to your game view.")
                    }
                    .padding()
                }
#endif
            }
        }
    }
    
    private func startGame(for level: GameLevel) {
        selectedLevel = level
        gameState.selectedLevel = level
        gameState.resetGame()
    #if os(visionOS)
        Task { @MainActor in
            if #available(visionOS 1.0, *) {
                _ = await openImmersiveSpace(id: "something")
                dismissWindow()
            }
        }
    #else
        // On iOS, push into the game view using NavigationStack
        navPath.append(level)
    #endif
    }
}

#if os(visionOS)
#Preview {
    @Previewable @State var selectedLevel: GameLevel = GameLevel.easy
    @Previewable @State var gameState: GameState = GameState()
    LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
        .environment(AppModel())
}
#else
#Preview {
    @Previewable @State var selectedLevel: GameLevel = GameLevel.easy
    @Previewable @State var gameState: GameState = GameState()
    LevelSelectView(selectedLevel: $selectedLevel, gameState: $gameState)
}
#endif


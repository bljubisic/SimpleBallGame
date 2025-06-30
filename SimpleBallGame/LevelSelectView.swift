//
//  LevelSelectView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI

struct LevelSelectView: View {
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Binding var selectedLevel: AppModel.Level?
    
    @Binding var game: Game?
    let difficulty = ["Easy", "Medium", "Hard"]
    
    var body : some View {
        NavigationStack {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.extraLargeTitle)
                    .padding()
                ForEach(AppModel.Level.allCases, id: \.self) { level in
                    Button(action: {
                        Task {
                            selectedLevel = level
                            game = Game(level: selectedLevel ?? .easy, subLevel: 1)
                            await openImmersiveSpace(id: "something")
                        }
                    }, label: {
                        Text(level.rawValue)
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
    
    @Previewable @State var selectedLevel: AppModel.Level? = .easy
    @Previewable @State var game: Game? = Game()
    LevelSelectView(selectedLevel: $selectedLevel, game: $game)
        .environment(AppModel())
}

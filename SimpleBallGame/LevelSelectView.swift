//
//  LevelSelectView.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//
import SwiftUI

struct LevelSelectView: View {
    @Binding var selectedLevel: String?
    let difficulty = ["Easy", "Medium", "Hard"]
    
    var body : some View {
        NavigationStack {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.extraLargeTitle)
                    .padding()
                ForEach(AppModel.Level.allCases, id: \.self) { level in
                    Button(action: {
                        selectedLevel = level.rawValue
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
    
    @Previewable @State var selectedLevel: String? = "Easy"
    LevelSelectView(selectedLevel: $selectedLevel)
        .environment(AppModel())
}

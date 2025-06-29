//
//  SimpleBallGameApp.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic Home  on 6/26/25.
//

import SwiftUI
import RealityKit

@main
struct SimpleBallGameApp: App {
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    var body: some SwiftUI.Scene {
        WindowGroup {
            VStack {
                Text("Pick Your Difficulty")
                    .font(.extraLargeTitle)
                    .padding()
                ForEach(AppModel.Level.allCases, id: \.self) { level in
                    Button(action: {
                        Task {
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
        }.windowStyle(.automatic)
        
        ImmersiveSpace(id: "something") {
            RealityView { content in
                let sphereMesh = MeshResource.generateSphere(radius: 0.1)
                let material = SimpleMaterial(
                    color: .red,
                    roughness: 0.3,
                    isMetallic: false
                )
                let sphereEntity = ModelEntity(
                    mesh: sphereMesh,
                    materials: [material]
                )
                sphereEntity.position = SIMD3<Float>(0, 0, 0)
                content.add(sphereEntity)
                //                let spherePositions = generateNonIntersectingPositions()
                //                // Create 10 spheres with random positions
                //                for i in 0..<10 {
                //                    let sphere = createSphere(index: i, position: spherePositions[i])
                //                    content.add(sphere)
                //                }
            }
        }
    }
}

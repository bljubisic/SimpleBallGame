//
//  StopWatch.swift
//  SimpleBallGame
//
//  Created by Bratislav Ljubisic on 02.07.25.
//
import SwiftUI

class StopWatch: ObservableObject {
    @Published var counter: Int = 0
    var timer = Timer()
    
    func start() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0,
                                                   repeats: true) { _ in
            self.counter += 1
        }
    }
    func stop() {
        self.timer.invalidate()
    }
    func reset() {
        self.counter = 0
        self.timer.invalidate()
    }
}

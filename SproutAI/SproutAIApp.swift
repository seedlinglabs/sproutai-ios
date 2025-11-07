//
//  SproutAIApp.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import os.log

@main
struct SproutAIApp: App {
    
    init() {
        // Suppress haptic feedback warnings in simulator
        #if targetEnvironment(simulator)
        // Disable CHHapticPattern warnings in simulator
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        // Filter out haptic-related log messages
        OSLog.disabled = false
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

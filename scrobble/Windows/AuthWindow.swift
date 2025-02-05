//
//  AuthWindow.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI

struct AuthWindow: Scene {
    @ObservedObject var lastFmManager: LastFmDesktopManager
    @Binding var isAuthWindowShown: Bool
    
    
    var body: some Scene {
        Window("Last.fm Authentication", id: "auth") {
            AuthView(lastFmManager: lastFmManager, isAuthWindowShown: $isAuthWindowShown)
        }
        .defaultSize(width: 300, height: 200)
    }
}

//#Preview {
//    AuthWindow(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: ""), isAuthWindowShown: .constant(true))
//}

//
//  LastFMAuthSheetView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI

struct LastFmAuthSheet: View {
    @ObservedObject var lastFmManager: LastFmDesktopManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Last.fm Authentication")
                .font(.headline)
            
            Text("Please authorize the app in your browser.\nClick Continue once you've completed the authorization.")
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    lastFmManager.completeAuthorization(authorized: false)
                }
                
                Button("Continue") {
                    lastFmManager.completeAuthorization(authorized: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
#Preview {
    LastFmAuthSheet(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", password: ""))
}

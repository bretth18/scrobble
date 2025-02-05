//
//  MenuBarView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var scrobbler: Scrobbler
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Binding var isMainWindowShown: Bool
    @Binding var isPreferencesWindowShown: Bool
    
    var body: some View {
        VStack {
            MainView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
            
            Divider()
            
            HStack(alignment: .center) {
                Button("Open window") {
                    isMainWindowShown = true
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                
                Button("Preferences") {
                    isPreferencesWindowShown = true
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            .padding()
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal)
        }
    }
}
//#Preview {
//    MenuBarView()
//}

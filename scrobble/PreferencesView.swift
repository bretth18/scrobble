//
//  PreferencesView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        
        VStack {

            Form {
                Section(header: Text("Last.fm API Credentials").bold()) {
                    TextField("API Key", text: $preferencesManager.apiKey)
                    SecureField("API Secret", text: $preferencesManager.apiSecret)
                }
                
                Divider()
                
                Section(header: Text("Last.fm Account").bold()) {
                    TextField("Username", text: $preferencesManager.username)
                    SecureField("Password", text: $preferencesManager.password)
                }
            }
            .padding()
                        
            Text("Credentials are stored securely on-device and only transmitted to Last.Fm servers for authentication")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
#Preview {
    PreferencesView()
        .environmentObject(PreferencesManager())   
}

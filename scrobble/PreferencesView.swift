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
        Form {
            Section(header: Text("Last.fm API Credentials")) {
                TextField("API Key", text: $preferencesManager.apiKey)
                SecureField("API Secret", text: $preferencesManager.apiSecret)
            }
            
            Section(header: Text("Last.fm Account")) {
                TextField("Username", text: $preferencesManager.username)
                SecureField("Password", text: $preferencesManager.password)
            }
        }
        .padding()
    }
}
#Preview {
    PreferencesView()
}

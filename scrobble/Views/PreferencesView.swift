//
//  PreferencesView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Observation

struct WaveRenderer: TextRenderer {
    var strength: Double
    var frequency: Double
    var phase: Double  // animate this from 0 to 2π repeatedly

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(strength, phase) }
        set {
            strength = newValue.first
            phase = newValue.second
        }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                for (index, glyph) in run.enumerated() {
                    let yOffset = strength * sin(Double(index) * frequency + phase)
     
                    var copy = context
                    copy.translateBy(x: 0, y: yOffset)
                    copy.draw(glyph, options: .disablesSubpixelQuantization)
                }
            }
        }
    }
}

struct BillionsMustScrobbleView: View {
    @State private var phase: Double = 0


    var body: some View {
        Text("Billions must scrobble!")
            .font(.caption)
            .foregroundColor(.secondary)
//            .textRenderer(WaveRenderer(strength: 10.0, frequency: 0.1, phase:  phase))
//            .onAppear {
//                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
//                    phase = .pi * 2
//                }
//            }
    }
}

struct PreferencesView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState

    @State private var showingBlueskyHelp = false
    
    var body: some View {
        @Bindable var preferencesManager = preferencesManager
        VStack() {
            

            
            Form {
                
                Section("About") {
                    
                    HStack(alignment: .center) {
                        Text("scrobble v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("[build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")]")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Spacer()
                        
//                        Text("by COMPUTER DATA")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
                    }
                    
                    
                    BillionsMustScrobbleView()
                    
               
                        // repo link and license link
                    HStack(alignment: .center) {
                            Text("copyright © 2025 COMPUTER DATA")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()

                            Link("GitHub", destination: URL(string: "https://github.com/bretth18/scrobble")!)
                                .font(.caption2)
                            Link("License", destination: URL(string: "https://github.com/bretth18/scrobble/blob/main/LICENSE")!)
                                .font(.caption2)
                        }
                    
                }
                
                Section("Display") {
                    VStack {
                        LabeledStepper("Friends displayed:", value: $preferencesManager.numberOfFriendsDisplayed, in: 1...10)
//                        Stepper(
//                            "Friends shown: \(preferencesManager.numberOfFriendsDisplayed)",
//                            value: $preferencesManager.numberOfFriendsDisplayed,
//                            in: 1...10
//                        )
           
                        
                        LabeledStepper(
                            "Friend recent tracks",
                            value: $preferencesManager.numberOfFriendsRecentTracksDisplayed,
                            in: 1...20
                        )
                    }
                }
                
                Section("Scrobbling Services") {
                    ScrobblingServicesView()
                }
                
                Section("Music App") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music App Source")
                            .font(.headline)
                        
                        Picker("Select Music App", selection: $preferencesManager.selectedMusicApp) {
                            ForEach(SupportedMusicApp.allApps, id: \.self) { app in
                                Label(app.displayName, systemImage: app.icon)
                                    .tag(app)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: preferencesManager.selectedMusicApp) { _, newApp in
                            // Update the scrobbler when the app selection changes
                            scrobbler.setTargetMusicApp(newApp)
                        }
                        
                        Text("Select which app to monitor for scrobbling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            
            if let error = authState.authError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Text("credentials are stored securely on-device")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let prefManager = PreferencesManager()
    let authState = AuthState()
    let lastFmManager = LastFmDesktopManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        authState: authState
    )
    
    PreferencesView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(authState)
}


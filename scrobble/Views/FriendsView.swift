//
//  FriendsView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import SwiftUI

struct FriendsView: View {
    @Environment(Scrobbler.self) var scrobbler
    @Environment(PreferencesManager.self) var preferencesManager
    @State private var model: FriendsModel
    
    init(lastFmManager: LastFmManagerType) {
        _model = State(initialValue: FriendsModel(lastFmManager: lastFmManager))
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Friends Activity")
                    .font(.headline)
                Spacer()
                Button(action: { model.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .compatGlassButtonStyle()
            }
            .padding(.horizontal)
            .padding(.top)
            .compatScrollEdgeEffectStyle()
            
            if model.isLoading && model.friends.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if model.friends.isEmpty {
                Text("No friends found")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(model.friends, id: \.name) { friend in
                            FriendCardView(
                                friend: friend,
                                recentTracks: model.friendTracks[friend.name] ?? []
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .compatScrollEdgeEffectStyle()
                .refreshable {
                    model.refreshData()
                }
            }
            
            if let error = model.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            model.preferencesManager = preferencesManager
            model.updateLastFmManager(scrobbler.lastFmManager)
        }
        .onChange(of: preferencesManager.numberOfFriendsDisplayed) { _, _ in
            model.refreshData()
        }
    }
}




#Preview {
    @Previewable @State var preferencesManager = PreferencesManager()
    @Previewable @State var scrobbler = Scrobbler(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", authState: AuthState()))
    
    FriendsView(lastFmManager: scrobbler.lastFmManager)
        .environment(preferencesManager)
        .environment(scrobbler)
}

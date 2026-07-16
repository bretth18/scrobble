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
    @Environment(NetworkMonitor.self) var networkMonitor
    @State private var model: FriendsModel
    @State private var showingFilter = false

    init(lastFmManager: LastFmManagerType) {
        _model = State(initialValue: FriendsModel(lastFmManager: lastFmManager))
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingDefault) {
            HStack {
                Text("Friends Activity")
                    .font(.headline)
                Spacer()
                Button(action: { showingFilter = true }) {
                    Image(systemName: preferencesManager.selectedFriends.isEmpty
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .compatGlassButtonStyle()
                .accessibilityLabel("Filter friends")
                .popover(isPresented: $showingFilter, arrowEdge: .bottom) {
                    FriendsFilterView(allFriends: model.allFriends)
                        .environment(preferencesManager)
                }

                Button(action: { model.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .compatGlassButtonStyle()
                .accessibilityLabel("Refresh friends")
            }
            .padding(.horizontal)
            .padding(.top)
            .compatScrollEdgeEffectStyle()

            if model.isLoading && model.friends.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if model.friends.isEmpty {
                ContentUnavailableView(
                    "No Friends Found",
                    systemImage: "person.2.slash",
                    description: Text("Connect with friends on Last.fm to see their activity here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingLarge) {
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

            if !networkMonitor.isConnected {
                Label("Offline — will retry when connection returns", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding()
            } else if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            model.preferencesManager = preferencesManager
            model.setLastFmManager(scrobbler.lastFmManager)
            model.loadIfNeeded()
        }
        .onChange(of: preferencesManager.numberOfFriendsDisplayed) { _, _ in
            model.selectionDidChange()
        }
        .onChange(of: preferencesManager.selectedFriends) { _, _ in
            model.selectionDidChange()
        }
        .onChange(of: networkMonitor.isConnected) { wasConnected, isConnected in
            // Auto-recover from a stale network error once the link comes back.
            guard !wasConnected, isConnected else { return }
            if model.errorMessage != nil || model.friends.isEmpty {
                model.refreshData()
            }
        }
    }
}

#Preview {
    @Previewable @State var preferencesManager = PreferencesManager()
    @Previewable @State var scrobbler = Scrobbler(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", authState: AuthState()))

    FriendsView(lastFmManager: scrobbler.lastFmManager)
        .environment(preferencesManager)
        .environment(scrobbler)
        .environment(NetworkMonitor())
}

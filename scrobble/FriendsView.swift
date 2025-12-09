//
//  FriendsView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var scrobbler: Scrobbler
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
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            .padding(.top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            
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
                .scrollEdgeEffectStyle(.soft, for: .all)
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

struct FriendCardView: View {
    let friend: Friend
    let recentTracks: [RecentTracksResponse.RecentTracks.Track]
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AsyncImage(url: URL(string: friend.image.last?.text ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(friend.realname ?? friend.name)
                        .font(.headline)
                    HStack {
                        Text(friend.name)
                            .font(.caption)
                        if let country = friend.country {
                            Text("• \(country)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if recentTracks.isEmpty {
                Text("No recent tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recentTracks.prefix(5), id: \.url) { track in
                        HStack {
                            if track.nowplaying {
                                Image(systemName: "music.note")
                                    .foregroundColor(.green)
                            }
                            
                            AsyncImage(url: URL(string: track.image.first?.text ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 24, height: 24)
                            .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text("\(track.artist.text) - \(track.name)")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                HStack {
                                    if !track.album.text.isEmpty {
                                        Text(track.album.text)
                                            .lineLimit(1)
                                    }
                                    
                                    if let date = track.date {
                                        Text("•")
                                        Text(formatDate(uts: date.uts))
                                    } else if track.nowplaying {
                                        Text("• Now Playing")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 10))
        .shadow(radius: 1)

    }
    
    private func formatDate(uts: String) -> String {
        guard let timestamp = Double(uts) else { return "" }
        let date = Date(timeIntervalSince1970: timestamp)
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}


#Preview {
    @Previewable @State var preferencesManager = PreferencesManager()
    @Previewable @StateObject var scrobbler = Scrobbler(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", authState: AuthState()))
    
    FriendsView(lastFmManager: scrobbler.lastFmManager)
        .environment(preferencesManager)
        .environmentObject(scrobbler)
}

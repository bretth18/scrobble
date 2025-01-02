//
//  FriendsView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var scrobbler: Scrobbler
    @StateObject private var viewModel: FriendsViewModel
    
    
    init(lastFmManager: LastFmManager) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(lastFmManager: lastFmManager))


    }
    
    
    var body: some View {
        VStack {
            HStack {
                Text("Friends Activity")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal)
            
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if viewModel.friends.isEmpty {
                Text("No friends found")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.friends, id: \.name) { friend in
                            FriendCardView(
                                friend: friend,
                                recentTracks: viewModel.friendTracks[friend.name] ?? []
                            )
                        }
                    }
                    .padding()
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .frame(minWidth: 300, minHeight: 400)
        .onAppear {
            // Update the viewModel with the correct LastFmManager from the environment
            viewModel.updateLastFmManager(scrobbler.lastFmManager)
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
                        }
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(.ultraThinMaterial)
                .shadow(radius: 1)
        }
    }
    
    private func formatDate(uts: String) -> String {
        guard let timestamp = Double(uts) else { return "" }
        let date = Date(timeIntervalSince1970: timestamp)
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}


#Preview {
    @EnvironmentObject @Previewable var scrobbler: Scrobbler
    FriendsView(lastFmManager: scrobbler.lastFmManager)
     
}

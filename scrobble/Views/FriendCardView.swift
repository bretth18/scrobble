//
//  FriendCardView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
//

import SwiftUI

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
    FriendCardView(friend: mockFriend, recentTracks: [])
}

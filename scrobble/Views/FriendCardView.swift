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

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
            HStack {
                AsyncImage(url: URL(string: friend.image.last?.text ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: DesignTokens.artworkSizeThumbnail, height: DesignTokens.artworkSizeThumbnail)
                .clipShape(Circle())
                .accessibilityLabel("\(friend.realname ?? friend.name) avatar")

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
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if recentTracks.isEmpty {
                Label("No recent tracks", systemImage: "music.note.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
                    ForEach(recentTracks.prefix(5), id: \.url) { track in
                        HStack {
                            if track.nowplaying {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Now playing")
                            }

                            AsyncImage(url: URL(string: track.image.first?.text ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: DesignTokens.artworkSizeInline, height: DesignTokens.artworkSizeInline)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))

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
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .compatGlass(cornerRadius: DesignTokens.cornerRadiusMedium)
    }

    private func formatDate(uts: String) -> String {
        guard let timestamp = Double(uts) else { return "" }
        let date = Date(timeIntervalSince1970: timestamp)
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    FriendCardView(
        friend: Friend(
            name: "test",
            realname: "Test User",
            url: "https://example.com",
            image: [Friend.Image(text: "https://example.com/image.jpg", size: "medium")],
            country: "USA",
            playcount: "100",
            registered: Friend.Registered(unixtime: "1234567890"),
            subscriber: "0"
        ),
        recentTracks: []
    )
}

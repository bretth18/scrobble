//
//  OnboardingWelcomeView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            // Welcome text
            VStack(spacing: 8) {
                Text("scrobble")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("track your desktop music listening with last.fm compatilble services")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "music.note.list",
                    title: "Automatic Scrobbling",
                    description: "Tracks what you play in Apple Music, Spotify, and more"
                )

                FeatureRow(
                    icon: "person.2",
                    title: "See What Friends Listen To",
                    description: "View your Last.fm friends' recent tracks"
                )

                FeatureRow(
                    icon: "menubar.rectangle",
                    title: "Lives in Your Menu Bar",
                    description: "Quick access without cluttering your dock"
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()

            Text("Get set up in just a few steps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView()
        .frame(width: 500, height: 450)
}

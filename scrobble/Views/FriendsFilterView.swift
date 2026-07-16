//
//  FriendsFilterView.swift
//  scrobble
//
//  Popover for choosing which friends appear in the Friends tab. An empty
//  selection means no filter: the first `numberOfFriendsDisplayed` friends
//  are shown, matching the pre-filter behavior.
//

import SwiftUI

struct FriendsFilterView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    let allFriends: [Friend]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
            HStack {
                Text("Show Friends")
                    .font(.headline)
                Spacer()
                if !preferencesManager.selectedFriends.isEmpty {
                    Button("Show All") {
                        preferencesManager.selectedFriends = []
                    }
                    .font(.caption)
                }
            }

            if allFriends.isEmpty {
                Text("No friends loaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(allFriends, id: \.name) { friend in
                            Toggle(isOn: isSelected(friend.name)) {
                                Text(friend.name)
                                    .lineLimit(1)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 260)
    }

    private var footerText: String {
        let count = preferencesManager.selectedFriends.count
        if count == 0 {
            return "No filter — showing your first \(preferencesManager.numberOfFriendsDisplayed) friends."
        }
        return "Showing \(count) selected \(count == 1 ? "friend" : "friends")."
    }

    private func isSelected(_ name: String) -> Binding<Bool> {
        Binding(
            get: { preferencesManager.selectedFriends.contains(name) },
            set: { isOn in
                var selected = preferencesManager.selectedFriends
                if isOn {
                    if !selected.contains(name) { selected.append(name) }
                } else {
                    selected.removeAll { $0 == name }
                }
                preferencesManager.selectedFriends = selected
            }
        )
    }
}

#Preview {
    FriendsFilterView(allFriends: [])
        .environment(PreferencesManager())
}

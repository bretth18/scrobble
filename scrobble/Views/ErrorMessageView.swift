//
//  ErrorMessageView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/17/25.
//

import SwiftUI

struct ErrorMessageView: View {
    var body: some View {
        VStack {
            Text("Error")
                .font(.headline)
            Text("Something went wrong.")
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red)
        }
    }
}

#Preview {
    ErrorMessageView()
}

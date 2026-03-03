

import SwiftUI

struct LineCheckDetailView: View {

    let lineCheckId: String
    let locationId: String

    var body: some View {
        VStack(spacing: 20) {

            Text("Line Check Detail")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Line Check ID:")
                .font(.headline)

            Text(lineCheckId)
                .foregroundColor(.secondary)

            Text("Location ID:")
                .font(.headline)
                .padding(.top)

            Text(locationId)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Line Check")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct LocationDetailView: View {

    let locationId: String
    let account: Account
    let locationName: String

    @EnvironmentObject var sessionManager: SessionManager

    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {

        VStack {

            if isLoading {
                ProgressView("Loading location...")
            }

            else if let errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }

            else {

                LocationStationsView(
                    locationId: locationId,
                    locationName: locationName,
                    account: account
                )
                .environmentObject(sessionManager)
            }
        }
        .navigationTitle("Stations – \(account.name)")
        .task {
            await validateLocation()
        }
   
    }
    private func validateLocation() async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let locations = try await LocationApi.getLocationsForUser(
                userId: sessionManager.session?.userId ?? ""
            )

            if !locations.contains(where: { $0.id == locationId }) {
                errorMessage = "Location not found"
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

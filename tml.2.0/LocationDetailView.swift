import SwiftUI

struct LocationDetailView: View {
    
    let locationId: String
    let userId: String
    let accountName: String
    let locationName: String
    
    @State private var isLoading = true
    @State private var errorMessage: String?
  
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading location...")
            } else if let errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                LocationStationsView(locationId: locationId, userId: userId, locationName: locationName)
            }
        }
        .navigationTitle("Stations – \(accountName)")
        .task {
            await validateLocation()
        }
    }
    
    private func validateLocation() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let locations = try await LocationApi.getLocationsForUser(userId: userId)
            
            if !locations.contains(where: { $0.id == locationId }) {
                errorMessage = "Location not found"
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

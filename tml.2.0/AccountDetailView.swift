import SwiftUI
import GoogleSignIn

struct AccountDetailView: View {
    
    let accountId: String
    let accountName: String
    let userId: String
    let onLogout: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var locations: [Location] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading) {
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                if locations.isEmpty && !isLoading {
                    Text("No locations are set up for this account.\nPlease configure them on the website.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    
                    Text("Locations for \(accountName)")
                        .font(.title)
                        .padding(.horizontal)
                        .foregroundStyle(Color(Color.blue))
                    
                    Text("Select your location:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List(locations, id: \.id) { location in
                        NavigationLink(
                            destination: LocationDetailView(
                                locationId: location.id,
                                userId: userId,
                                accountName: accountName,
                                locationName: location.name,
                                
                            )
                        ) {
                            HStack {
                                Text(location.name)
                                Spacer()
                                
                                if location.active {
                                    Text("Active")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
           // .navigationTitle("Locations for \(accountName)")
            .toolbar {
                
                //            ToolbarItem(placement: .navigationBarLeading) {
                //                Button("Back") {
                //                    dismiss()
                //                }
                //            }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        signOut()
                    }
                }
            }
            .task {
                await loadLocations()
            }
        }
    }
    
    private func loadLocations() async {
        isLoading = true
          
          //print("🔎 Loading locations for accountId:", accountId)
          
          locations = await LocationApi.shared.getLocationsForAccount(accountId: accountId)
        
//        do {
//          //  locations = try await LocationApi.getLocationsForUser(userId: userId)
//            locations = try await LocationApi.getLocationForAccount(accountId: accountId)
//        } catch {
//            print("❌ Failed loading locations:", error)
//            locations = []
//        }
          
          print("📦 Locations returned:", locations.count)
          
          isLoading = false
    }
    
    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        onLogout()
    }
}


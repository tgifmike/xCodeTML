import SwiftUI

struct StationChip: View {
    
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Text(title)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? Color.blue.opacity(0.25)
                : Color.gray.opacity(0.2)
            )
            .foregroundColor(isSelected ? .black : .gray)
            .cornerRadius(8)
            .onTapGesture {
                onTap()
            }
    }
}

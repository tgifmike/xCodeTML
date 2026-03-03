import Foundation
import SwiftUI

struct LineCheckStationSection: View {
    
    let stationName: String
    @State private var isExpanded: Bool = true
    
    @Binding var items: [LineCheckItemInput]
    @FocusState.Binding var focusedField: LineCheckField?
    
    var body: some View {
        
        VStack(spacing: 12) {
            
            // MARK: - Station Header (Collapsible)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    
                    Image(systemName: "fork.knife")
                        .foregroundColor(.blue)
                    
                    Text(stationName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            
            // MARK: - Items (Collapsible Content)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array($items.enumerated()), id: \.element.id) { index, $item in
                        
                        LineCheckItemRow(
                            input: $item,
                            focusedField: $focusedField
                        )
                        
                        // Divider between items (not after last one)
                        if index < items.count - 1 {
                            Divider()
                                .padding(.vertical, 12)
                                
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

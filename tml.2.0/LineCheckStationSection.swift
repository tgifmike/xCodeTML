import Foundation
import SwiftUI

struct LineCheckStationSection: View {
    
    let stationName: String
    let sectionIndex: Int
    
    @Binding var items: [LineCheckItemInput]
    @Binding var expandedSection: Int?
    
    @FocusState.Binding var focusedField: LineCheckField?
    
    // MARK: Metrics
    
    private var totalItems: Int {
        items.count
    }
    
    private var completedItems: Int {
        items.filter {
            !$0.temperature.isEmpty ||
            $0.isMissing ||
            $0.isChecked != nil
        }.count
    }
    
    private var progress: Double {
        totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
    }
    
    private var percent: Int {
        Int(progress * 100)
    }
    
    private var isComplete: Bool {
        totalItems > 0 && completedItems == totalItems
    }
    
    private var isExpanded: Bool {
        expandedSection == sectionIndex
    }
    
    private var progressColor: Color {
        if isComplete { return .green }
        if progress >= 0.7 { return .orange }
        return .red
    }
    
    // MARK: Body
    
    var body: some View {
        
        VStack(spacing: 12) {
            
            header
            
            if isExpanded {
                itemsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .id(sectionIndex)
        .onChange(of: isComplete) { _, newValue in
            
            guard newValue else { return }
            
            // Auto-open next section when completed
            if expandedSection == sectionIndex {
                withAnimation(.easeInOut) {
                    expandedSection = sectionIndex + 1
                }
            }
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedSection = isExpanded ? nil : sectionIndex
            }
        } label: {
            
            VStack(spacing: 10) {
                
                HStack(spacing: 12) {
                    
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "fork.knife")
                        .foregroundColor(isComplete ? .green : .blue)
                    
                    Text(stationName)
                        .font(.title3.weight(.semibold))
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        
                        Text("\(completedItems)/\(totalItems)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(percent)%")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(progressColor.opacity(0.15))
                            .foregroundColor(progressColor)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progress)
                    .tint(progressColor)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Items
    
    private var itemsSection: some View {
        
        VStack(spacing: 0) {
            
            ForEach(Array($items.enumerated()), id: \.element.id) { index, $item in
                
                LineCheckItemRow(
                    input: $item,
                    focusedField: $focusedField
                )
                
                if index < items.count - 1 {
                    Divider()
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

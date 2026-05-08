import SwiftUI

struct LineCheckDetailView: View {

    let lineCheckId: String
    let locationId: String
    let locationName: String
    let accountName: String
    

    @StateObject private var vm = LineCheckDetailVM()

//    @State private var lineCheck: LineCheckDto?

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: LineCheckField?

    var body: some View {

        NavigationStack {

            content
                .navigationTitle("Line Check")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await vm.load(lineCheckId: lineCheckId)
        }
        .overlay {

            if let error = vm.saveError ?? vm.error {

                CustomAlertView(
                    title: "Error",
                    message: error,
                    buttonTitle: "OK"
                ) {
                    vm.error = nil
                    vm.saveError = nil
                }
            }
        }
        .alert("Success", isPresented: $vm.saveSuccess) {

            Button("OK") { }

        } message: {

            Text("Line Check saved successfully.")
        }
    }

    // MARK: CONTENT

    @ViewBuilder
    private var content: some View {

        if vm.isLoading {

            ProgressView("Loading…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.error {

            Text(error)
                .foregroundColor(.red)

        } else {

            mainView
        }
    }

    // MARK: MAIN VIEW

//    private var mainView: some View {
//
//        let stationNames = Array(
//            Set(vm.items.map(\.stationName))
//        ).sorted()
//
//        return VStack(spacing: 0) {
//
//            // STICKY HEADER
//            progressHeader
//                .padding(.horizontal)
//                .padding(.top, 4)
//                .background(.ultraThinMaterial)
//                .zIndex(1)
//            
//            ScrollView {
//
//                LazyVStack(spacing: 12) {
//
//                    headerSection
//
//                    ForEach(stationNames, id: \.self) { stationName in
//
//                        LineCheckStationSection(
//                            stationName: stationName,
//                            items: bindingForStation(stationName),
//                            focusedField: $focusedField
//                        )
//                    }
//
//                    saveButton
//                        .padding(.top, 8)
//                }
//                .padding()
//                .padding(.top, 4)
//            }
//            .scrollDismissesKeyboard(.interactively)
//        }
//        .toolbar {
//
//            ToolbarItemGroup(placement: .keyboard) {
//
//                Spacer()
//
//                Button("Done") {
//                    focusedField = nil
//                }
//            }
//        }
//    }
    
    private var mainView: some View {

        let stationNames = Array(
            Set(vm.items.map(\.stationName))
        ).sorted()

        return VStack(spacing: 0) {

            // TOP STICKY PROGRESS
            progressHeader
                .padding(.horizontal)
                .padding(.top, 4)
                .background(.ultraThinMaterial)
                .zIndex(1)

            // SCROLL CONTENT
            ScrollView {

                LazyVStack(spacing: 12) {

                    headerSection

                    ForEach(stationNames, id: \.self) { stationName in

                        LineCheckStationSection(
                            stationName: stationName,
                            items: bindingForStation(stationName),
                            focusedField: $focusedField
                        )
                    }

                    Spacer()
                        .frame(height: 100)
                }
                .padding()
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            
            // BOTTOM STICKY SAVE BUTTON
            VStack {

                saveButton
            }
            .padding()
            .background(.ultraThinMaterial)
            
        }
        .toolbar {

            ToolbarItemGroup(placement: .keyboard) {

                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    // MARK: BINDING

    private func bindingForStation(
        _ stationName: String
    ) -> Binding<[LineCheckItemState]> {

        Binding {

            vm.items.filter {
                $0.stationName == stationName
            }

        } set: { updatedItems in

            for updated in updatedItems {

                if let index = vm.items.firstIndex(where: {
                    $0.id == updated.id
                }) {

                    vm.items[index] = updated
                }
            }
        }
    }

    // MARK: PROGRESS

    private var progressHeader: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text("Total Line Check Progress")
                    .font(.headline)

                Spacer()

                Text("\(vm.completedItems)/\(vm.totalItems)")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(vm.progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vm.progressColor.opacity(0.10))
                    .foregroundColor(vm.progressColor)
                    .clipShape(Capsule())
            }

            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(vm.progressColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }

    
    // MARK: HEADER

    private var headerSection: some View {

        VStack(spacing: 14) {

            HStack(alignment: .top) {

                // ACCOUNT
                VStack(alignment: .leading, spacing: 6) {

                    Label("Account", systemImage: "building.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(accountName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Spacer()

                // LOCATION
                VStack(alignment: .trailing, spacing: 6) {

                    Label("Location", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(locationName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }

            Divider()

            HStack(alignment: .top) {

                // USERNAME
                VStack(alignment: .leading, spacing: 6) {

                    Label("Conducted By", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(vm.lineCheck?.username ?? "-")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Spacer()

                // START TIME
                VStack(alignment: .trailing, spacing: 6) {

                    Label("Started", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(startTimeText)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: START TIME FORMAT

    private var startTimeText: String {

        guard let checkTime = vm.lineCheck?.checkTime else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: checkTime)
    }
    
    // MARK: SAVE

    private var saveButton: some View {

        Button {

            Task {
                await vm.save(current: vm.lineCheck)
                
                if(vm.saveSuccess){
                    dismiss()
                }
            }

        } label: {

            if vm.isSaving {

                ProgressView()
                    .frame(maxWidth: .infinity)

            } else {

                Text("Save Line Check")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .font(.headline)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.isSaving || !vm.hasChanges)
    }
}

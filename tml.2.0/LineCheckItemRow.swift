import SwiftUI
import PhotosUI
import UIKit

struct LineCheckItemRow: View {

    @Binding var item: LineCheckItemState
    @FocusState.Binding var focusedField: LineCheckField?

    let isReadOnly: Bool
    let onFinalizeAction: () -> Void

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @State private var photos: [LineCheckPhotoDto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isLoadingPhotos = false
    @State private var isUploadingPhoto = false
    @State private var isPhotosExpanded = false
    @State private var photoError: String?

    // MARK: Validation

    private enum TempValidation {
        case empty
        case valid
        case invalid
    }

    private var validation: TempValidation {

        guard !item.temperature.isEmpty,
              let value = Float(item.temperature),
              let min = item.item.minTemp,
              let max = item.item.maxTemp else {
            return .empty
        }

        return (value >= min && value <= max)
        ? .valid
        : .invalid
    }

    private var hasInvalidTemperature: Bool {
        validation == .invalid
    }

    private var isPreparedIncorrectly: Bool {
        item.isChecked == false
    }

    // MARK: Body

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            headerSection

            adaptiveTopSection

            if hasNotes {
                notesSection
            }

            photoArea

            observationsSection
        }
        .task(id: item.id) {
            await loadPhotos()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }

            Task {
                await uploadSelectedPhoto(newValue)
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await uploadPhoto(image)
                }
            }
            .ignoresSafeArea()
        }
        .padding(18)
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: validation
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: item.isChecked
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: item.isMissing
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: isPhotosExpanded
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: photos.isEmpty
        )
    }

    // MARK: Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(item.item.itemName ?? "-")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {

                if item.isMissing {

                    statusBadge(
                        title: "Item Marked Missing",
                        systemImage: "exclamationmark.circle.fill"
                    )
                }

                if hasInvalidTemperature {

                    statusBadge(
                        title: "Temperature Out of Range",
                        systemImage: "thermometer.medium"
                    )
                }

                if isPreparedIncorrectly {

                    statusBadge(
                        title: "Item Not Prepared Correctly",
                        systemImage: "xmark.shield.fill"
                    )
                }
            }
        }
    }

    // MARK: Adaptive Top Section

    private var adaptiveTopSection: some View {

        Group {

            if horizontalSizeClass == .regular {

                VStack(spacing: 18) {

                    HStack(alignment: .top, spacing: 18) {

                        detailsCard
                            .frame(maxWidth: .infinity)

                        compactValidationCard
                            .frame(maxWidth: .infinity)
                    }

                    missingCard
                }

            } else {

                VStack(spacing: 18) {

                    detailsCard
                    compactValidationCard
                    missingCard
//                    missingToggle
                }
            }
        }
    }
    // MARK: Details Card

    private var detailsCard: some View {

        VStack(alignment: .leading, spacing: 20) {

            sectionHeader(
                title: "Details",
                systemImage: "info.circle"
            )

            VStack(spacing: 14) {

                metadataRow(
                    icon: "clock",
                    label: "Shelf Life",
                    value: item.item.shelfLife
                )

                metadataRow(
                    icon: "square.grid.2x2",
                    label: "Pan Size",
                    value: item.item.panSize
                )

                metadataRow(
                    icon: "wrench.and.screwdriver",
                    label: "Tool",
                    value: item.item.toolName
                )

                metadataRow(
                    icon: "scalemass",
                    label: "Portion Size",
                    value: item.item.portionSize
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Validation Card

    private var compactValidationCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Validation",
                systemImage: "checkmark.shield"
            )

            if item.item.tempTaken {
                temperatureSection
            }

            if item.item.checkMark {
                preparedCorrectlySection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    //MARK: missing card
    private var missingCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Item Missing",
                systemImage: "exclamationmark.triangle"
            )

            VStack(alignment: .leading, spacing: 12) {

                Toggle("Mark Item Missing", isOn: $item.isMissing)
                    .tint(.red)
                    .disabled(isReadOnly)
                    .onChange(of: item.isMissing) { _, newValue in

                        if newValue {
                            item.temperature = ""
                            item.isChecked = nil
                            item.observations = ""
                            focusedField = nil
                            onFinalizeAction()
                        }
                    }
            }
        }
        .padding(16)
        .background(
            item.isMissing
            ? Color.red.opacity(0.12)
            : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Temperature

    private var temperatureBorderColor: Color {

        switch validation {

        case .valid:
            return Color.green.opacity(0.8)

        case .invalid:
            return Color.red.opacity(0.8)

        case .empty:
            return Color.primary.opacity(0.08)
        }
    }

    private var temperatureBorderWidth: CGFloat {

        validation == .empty ? 1 : 1.5
    }
    
    @ViewBuilder
    private var temperatureSection: some View {

        if item.item.tempTaken {

            VStack(alignment: .leading, spacing: 12) {

                fieldLabel(
                    title: "Temperature",
                    systemImage: "thermometer.medium"
                )

                HStack(spacing: 10) {

                    HStack(spacing: 6) {

                        TextField("", text: $item.temperature)
                            .keyboardType(.decimalPad)
                            .focused(
                                $focusedField,
                                equals: .temperature(item.id)
                            )
                            .disabled(isReadOnly || item.isMissing)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("°F")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(
                        Color(.systemBackground)
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            temperatureBorderColor,
                            lineWidth: temperatureBorderWidth
                        )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )

                    Button {
                        focusedField = nil
                        onFinalizeAction()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isReadOnly || item.isMissing)
                }

                if hasInvalidTemperature,
                   let min = item.item.minTemp,
                   let max = item.item.maxTemp {

                    Text("Allowed range: \(Int(min))°F – \(Int(max))°F")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(
                hasInvalidTemperature
                ? Color.red.opacity(0.08)
                : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
    }

    // MARK: Prepared Correctly

    @ViewBuilder
    private var preparedCorrectlySection: some View {

        if item.item.checkMark {

            VStack(alignment: .leading, spacing: 14) {

                fieldLabel(
                    title: "Prepared Correctly",
                    systemImage: "checklist"
                )

                HStack(spacing: 12) {

                    Button {

                        item.isChecked = true
                        onFinalizeAction()

                    } label: {

                        Label("Yes", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(
                        item.isChecked == true
                        ? .green
                        : .gray.opacity(0.35)
                    )

                    Button {

                        item.isChecked = false
                        onFinalizeAction()

                    } label: {

                        Label("No", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(
                        item.isChecked == false
                        ? .red
                        : .gray
                    )
                }
            }
            .padding(14)
            .background(
                isPreparedIncorrectly
                ? Color.red.opacity(0.08)
                : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .disabled(isReadOnly || item.isMissing)
        }
    }

    // MARK: Missing Toggle

    private var missingToggle: some View {

        VStack(alignment: .leading, spacing: 14) {

            fieldLabel(
                title: "Item Missing",
                systemImage: "nosign"
            )

            Toggle("Mark Item Missing", isOn: $item.isMissing)
                .tint(.red)
                .disabled(isReadOnly)
                .onChange(of: item.isMissing) { _, newValue in

                    if newValue {

                        item.temperature = ""
                        item.isChecked = nil
                        item.observations = ""

                        focusedField = nil

                        onFinalizeAction()
                    }
                }
        }
        .padding(14)
        .background(
            item.isMissing
            ? Color.red.opacity(0.12)
            : Color.clear
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    // MARK: Notes

    private var notesSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Notes",
                systemImage: "note.text"
            )

            Text(item.item.templateNotes ?? "")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Photos

    private var hasPhotoRelevantIssue: Bool {
        hasInvalidTemperature || isPreparedIncorrectly || item.isMissing
    }

    private var shouldShowPhotoControls: Bool {
        hasPhotoRelevantIssue || isPhotosExpanded
    }

    private var shouldShowFullPhotoSection: Bool {
        shouldShowPhotoControls || !photos.isEmpty || isLoadingPhotos || isUploadingPhoto || photoError != nil
    }

    @ViewBuilder
    private var photoArea: some View {
        if shouldShowFullPhotoSection {
            photosSection
        } else if !isReadOnly {
            compactAddPhotoButton
        }
    }

    private var compactAddPhotoButton: some View {
        Button {
            isPhotosExpanded = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera")
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text("Add Photo")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var photosSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {

                sectionHeader(
                    title: "Photos",
                    systemImage: "camera"
                )

                Spacer()

                if isLoadingPhotos || isUploadingPhoto {
                    ProgressView()
                }

                if !hasPhotoRelevantIssue && !isUploadingPhoto && !isReadOnly {
                    Button {
                        isPhotosExpanded.toggle()
                    } label: {
                        Image(systemName: isPhotosExpanded ? "chevron.up" : "camera.badge.plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if shouldShowPhotoControls {
                HStack(spacing: 12) {

                    Button {
                        isShowingCamera = true
                    } label: {
                        photoActionLabel(
                            title: "Take Photo",
                            systemImage: "camera.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isReadOnly ||
                        isUploadingPhoto ||
                        !UIImagePickerController.isSourceTypeAvailable(.camera)
                    )

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        photoActionLabel(
                            title: "Choose Photo",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(isReadOnly || isUploadingPhoto)
                }
            }

            if let photoError {
                Text(photoError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if photos.isEmpty && !isLoadingPhotos {
                Text("No photos added")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func photoActionLabel(
        title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }

    private func photoThumbnail(_ photo: LineCheckPhotoDto) -> some View {

        Group {
            if let urlString = photo.url,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        photoPlaceholder

                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: 84, height: 84)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var photoPlaceholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    // MARK: Observations

    private var observationsSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Observations",
                systemImage: "square.and.pencil"
            )

            TextEditor(text: $item.observations)
                .disabled(isReadOnly)
                .focused(
                    $focusedField,
                    equals: .observation(item.id)
                )
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(
                    minHeight: horizontalSizeClass == .regular
                    ? 90
                    : 110
                )
                .background(
                    Color(.systemBackground)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
                }
        }
        .padding(18)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Photo Actions

    private func loadPhotos() async {
        guard let lineCheckItemId else { return }

        isLoadingPhotos = true
        photoError = nil

        do {
            photos = try await LineCheckPhotoApi.shared.getPhotos(
                lineCheckItemId: lineCheckItemId
            )
        } catch {
            photoError = error.localizedDescription
        }

        isLoadingPhotos = false
    }

    private func uploadSelectedPhoto(_ photoItem: PhotosPickerItem) async {
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                photoError = "Could not read selected image."
                return
            }

            await uploadPhoto(image)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func uploadPhoto(_ image: UIImage) async {
        guard let lineCheckItemId else {
            photoError = "Line check item is missing an ID."
            return
        }

        guard let imageData = jpegData(from: image) else {
            photoError = "Could not prepare image for upload."
            return
        }

        isUploadingPhoto = true
        photoError = nil

        do {
            _ = try await LineCheckPhotoApi.shared.uploadPhoto(
                lineCheckItemId: lineCheckItemId,
                imageData: imageData,
                fileName: "line-check-\(lineCheckItemId)-\(UUID().uuidString).jpg",
                photoType: .item,
                notes: item.observations
            )

            photos = try await LineCheckPhotoApi.shared.getPhotos(
                lineCheckItemId: lineCheckItemId
            )
        } catch {
            photoError = error.localizedDescription
        }

        isUploadingPhoto = false
    }

    private func jpegData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 900
        let maxUploadBytes = 600 * 1024
        let size = image.size
        let largestDimension = max(size.width, size.height)
        let targetSize: CGSize

        if largestDimension > maxDimension {
            let scale = maxDimension / largestDimension
            targetSize = CGSize(
                width: size.width * scale,
                height: size.height * scale
            )
        } else {
            targetSize = size
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        let compressionQualities: [CGFloat] = [0.72, 0.62, 0.52, 0.42, 0.32]
        var smallestData: Data?

        for quality in compressionQualities {
            guard let data = resizedImage.jpegData(compressionQuality: quality) else {
                continue
            }

            smallestData = data

            if data.count <= maxUploadBytes {
                return data
            }
        }

        return smallestData
    }

    private var lineCheckItemId: String? {
        item.item.id ?? item.id.uuidString
    }

    // MARK: Helpers

    private var hasNotes: Bool {

        !(item.item.templateNotes?.isEmpty ?? true)
    }

    private func sectionHeader(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
    }

    private func fieldLabel(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private func statusBadge(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
    }

    @ViewBuilder
    private func metadataRow(
        icon: String,
        label: String,
        value: String?
    ) -> some View {

        if let value, !value.isEmpty {

            HStack(alignment: .center, spacing: 12) {

                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)

                Text(label)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 20)

                Text(value)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }
}

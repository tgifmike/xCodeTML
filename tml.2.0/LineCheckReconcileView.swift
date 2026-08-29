import SwiftUI
import PhotosUI
import UIKit

extension Notification.Name {
    static let lineCheckCorrectionsDidChange = Notification.Name("lineCheckCorrectionsDidChange")
}

enum LineCheckCorrectionNotificationKey {
    static let lineCheckId = "lineCheckId"
    static let itemId = "itemId"
}

struct LineCheckReconcileView: View {

    let locationId: String
    let locationName: String
    let accountName: String

    @State private var lineChecks: [LineCheckDto] = []
    @State private var photosByItemId: [String: [LineCheckPhotoDto]] = [:]
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var locallyCorrectedItemIds: Set<String> = []

    var body: some View {
        content
            .navigationTitle("Corrections")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !hasLoaded {
                    await loadLineChecks()
                }
            }
            .onAppear {
                guard hasLoaded else { return }

                Task {
                    await loadLineChecks()
                }
            }
            .refreshable {
                await loadLineChecks()
            }
            .task {
                for await notification in NotificationCenter.default.notifications(named: .lineCheckCorrectionsDidChange) {
                    applyCorrectionChange(from: notification)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading corrections...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load Corrections",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if lineCheckSummaries.isEmpty {
            ContentUnavailableView(
                "No Corrections Needed",
                systemImage: "checkmark.seal",
                description: Text("Line checks needing follow-up will appear here.")
            )
        } else {
            List(lineCheckSummaries) { summary in
                NavigationLink {
                    LineCheckReconcileDetailView(
                        lineCheck: summary.lineCheck,
                        locationName: locationName
                    )
                } label: {
                    ReconcileLineCheckRow(summary: summary)
                }
            }
            .listStyle(.plain)
        }
    }

    private var lineCheckSummaries: [ReconcileLineCheckSummary] {
        lineChecks.compactMap { lineCheck in
            let issues = ReconcileIssue.issues(in: lineCheck, includeCorrected: true)
            let pendingCount = issues.filter { !isResolved($0) }.count
            guard pendingCount > 0 else { return nil }

            return ReconcileLineCheckSummary(
                lineCheck: lineCheck,
                pendingCount: pendingCount,
                correctedCount: issues.filter { isResolved($0) }.count
            )
        }
    }

    private func isResolved(_ issue: ReconcileIssue) -> Bool {
        issue.isCorrected
    }

    private func loadLineChecks() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedLineChecks = try await LineCheckApi.shared.getCompletedLineChecksByLocation(
                locationId: locationId
            )
            lineChecks = lineChecksApplyingLocalCorrections(fetchedLineChecks)

            await loadPhotosForIssueItems()
        } catch {
            errorMessage = error.localizedDescription
        }

        hasLoaded = true
        isLoading = false
    }

    private func loadPhotosForIssueItems() async {
        let itemIds = Set(
            lineChecks.flatMap { lineCheck in
                ReconcileIssue.issues(in: lineCheck, includeCorrected: true).compactMap { $0.item.id }
            }
        )

        for itemId in itemIds {
            do {
                photosByItemId[itemId] = try await LineCheckPhotoApi.shared.getPhotos(
                    lineCheckItemId: itemId
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyCorrectionChange(from notification: Notification) {
        guard let lineCheckId = notification.userInfo?[LineCheckCorrectionNotificationKey.lineCheckId] as? String,
              let itemId = notification.userInfo?[LineCheckCorrectionNotificationKey.itemId] as? String else {
            return
        }

        locallyCorrectedItemIds.insert(itemId)

        guard let lineCheckIndex = lineChecks.firstIndex(where: { $0.id == lineCheckId }) else {
            return
        }

        var lineCheck = lineChecks[lineCheckIndex]

        for stationIndex in lineCheck.stations.indices {
            guard let itemIndex = lineCheck.stations[stationIndex]
                .items
                .firstIndex(where: { $0.id == itemId }) else {
                continue
            }

            let station = lineCheck.stations[stationIndex]
            var items = station.items
            items[itemIndex].isCorrected = true
            lineCheck.stations[stationIndex] = LineCheckStationDto(
                id: station.id,
                stationName: station.stationName,
                items: items
            )
            lineChecks[lineCheckIndex] = lineCheck
            return
        }
    }

    private func lineChecksApplyingLocalCorrections(_ fetchedLineChecks: [LineCheckDto]) -> [LineCheckDto] {
        fetchedLineChecks.map { fetchedLineCheck in
            var lineCheck = fetchedLineCheck

            lineCheck.stations = lineCheck.stations.map { station in
                var items = station.items
                for itemIndex in items.indices {
                    guard let itemId = items[itemIndex].id,
                          locallyCorrectedItemIds.contains(itemId) else {
                        continue
                    }

                    items[itemIndex].isCorrected = true
                }

                return LineCheckStationDto(
                    id: station.id,
                    stationName: station.stationName,
                    items: items
                )
            }

            return lineCheck
        }
    }
}

private struct LineCheckReconcileDetailView: View {

    @State private var lineCheck: LineCheckDto
    let locationName: String

    @State private var activeIssueId: ReconcileIssue.ID?
    @State private var cameraIssue: ReconcileIssue?
    @State private var photosByItemId: [String: [LineCheckPhotoDto]] = [:]
    @State private var loadingPhotoItemIds: Set<String> = []
    @State private var errorMessage: String?

    init(lineCheck: LineCheckDto, locationName: String) {
        _lineCheck = State(initialValue: lineCheck)
        self.locationName = locationName
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header

                if !pendingIssues.isEmpty {
                    issueSection(
                        title: "Needs Correction",
                        issues: pendingIssues,
                        isCorrectedSection: false
                    )
                }

                if !correctedIssues.isEmpty {
                    issueSection(
                        title: "Corrected",
                        issues: correctedIssues,
                        isCorrectedSection: true
                    )
                }

                if pendingIssues.isEmpty && correctedIssues.isEmpty {
                    ContentUnavailableView(
                        "No Corrections Needed",
                        systemImage: "checkmark.seal",
                        description: Text("This line check has no unresolved follow-up items.")
                    )
                    .padding(.top, 24)
                }
            }
            .padding()
        }
        .navigationTitle("Correct Line Check")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: lineCheck.id) {
            await loadPhotosForVisibleIssues()
        }
        .overlay {
            if let errorMessage {
                CustomAlertView(
                    title: "Error",
                    message: errorMessage,
                    buttonTitle: "OK"
                ) {
                    self.errorMessage = nil
                }
            }
        }
        .fullScreenCover(item: $cameraIssue) { issue in
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await resolveIssue(issue.id, image: image)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(primaryDateText)
                .font(.title2.weight(.semibold))

            Text(locationName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label("\(pendingIssues.count) pending", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(pendingIssues.isEmpty ? Color.secondary : Color.orange)

                Label("\(correctedIssues.count) corrected", systemImage: "checkmark.circle")
                    .foregroundStyle(correctedIssues.isEmpty ? Color.secondary : Color.green)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.bottom, 4)
    }

    private func issueSection(
        title: String,
        issues: [ReconcileIssue],
        isCorrectedSection: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)

            ForEach(issues) { issue in
                ReconcileIssueCard(
                    issue: issue,
                    photos: photos(for: issue),
                    isBusy: activeIssueId == issue.id,
                    isLoadingPhotos: isLoadingPhotos(for: issue),
                    isCorrected: isCorrectedSection,
                    correctiveNotes: correctiveNotesBinding(for: issue),
                    onTakePhoto: {
                        cameraIssue = issue
                    },
                    onChoosePhoto: { photoItem in
                        await resolveIssue(issue.id, photoItem: photoItem)
                    },
                    onMarkCorrected: {
                        await markIssueCorrected(issue)
                    }
                )
            }
        }
    }

    private var pendingIssues: [ReconcileIssue] {
        ReconcileIssue.issues(in: lineCheck, includeCorrected: true).filter { !isResolved($0) }
    }

    private var correctedIssues: [ReconcileIssue] {
        ReconcileIssue.issues(in: lineCheck, includeCorrected: true).filter { isResolved($0) }
    }

    private func isResolved(_ issue: ReconcileIssue) -> Bool {
        issue.isCorrected
    }

    private func photos(for issue: ReconcileIssue) -> [LineCheckPhotoDto] {
        guard let itemId = issue.item.id else { return [] }
        return photosByItemId[itemId] ?? []
    }

    private func isLoadingPhotos(for issue: ReconcileIssue) -> Bool {
        guard let itemId = issue.item.id else { return false }
        return loadingPhotoItemIds.contains(itemId)
    }

    private func correctiveNotesBinding(for issue: ReconcileIssue) -> Binding<String> {
        Binding(
            get: {
                guard lineCheck.stations.indices.contains(issue.stationIndex),
                      lineCheck.stations[issue.stationIndex].items.indices.contains(issue.itemIndex) else {
                    return ""
                }

                return lineCheck.stations[issue.stationIndex]
                    .items[issue.itemIndex]
                    .correctiveNotes ?? ""
            },
            set: { newValue in
                guard lineCheck.stations.indices.contains(issue.stationIndex),
                      lineCheck.stations[issue.stationIndex].items.indices.contains(issue.itemIndex) else {
                    return
                }

                let station = lineCheck.stations[issue.stationIndex]
                var items = station.items
                items[issue.itemIndex].correctiveNotes = newValue
                lineCheck.stations[issue.stationIndex] = LineCheckStationDto(
                    id: station.id,
                    stationName: station.stationName,
                    items: items
                )
            }
        )
    }

    private func correctiveNotes(for issue: ReconcileIssue) -> String {
        guard lineCheck.stations.indices.contains(issue.stationIndex),
              lineCheck.stations[issue.stationIndex].items.indices.contains(issue.itemIndex) else {
            return ""
        }

        return lineCheck.stations[issue.stationIndex]
            .items[issue.itemIndex]
            .correctiveNotes ?? ""
    }

    private func loadPhotosForVisibleIssues() async {
        let visibleIssues = pendingIssues + correctedIssues

        for issue in visibleIssues {
            guard let itemId = issue.item.id,
                  photosByItemId[itemId] == nil else {
                continue
            }

            await loadPhotos(for: itemId)
        }
    }

    private func loadPhotos(for itemId: String) async {
        loadingPhotoItemIds.insert(itemId)

        do {
            photosByItemId[itemId] = try await LineCheckPhotoApi.shared.getPhotos(
                lineCheckItemId: itemId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        loadingPhotoItemIds.remove(itemId)
    }

    private var primaryDateText: String {
        guard let completedAt = lineCheck.completedAt ?? lineCheck.checkTime else {
            return "Unknown date"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    private func resolveIssue(_ issueId: ReconcileIssue.ID, photoItem: PhotosPickerItem) async {
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not read selected image."
                return
            }

            await resolveIssue(issueId, image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveIssue(_ issueId: ReconcileIssue.ID, image: UIImage) async {
        guard let issue = pendingIssues.first(where: { $0.id == issueId }) else { return }

        guard let itemId = issue.item.id else {
            errorMessage = "Line check item is missing an ID."
            return
        }

        guard let imageData = jpegData(from: image) else {
            errorMessage = "Could not prepare image for upload."
            return
        }

        activeIssueId = issueId
        errorMessage = nil

        do {
            let notes = correctiveNotes(for: issue)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            _ = try await LineCheckPhotoApi.shared.uploadPhoto(
                lineCheckItemId: itemId,
                imageData: imageData,
                fileName: "corrective-\(itemId)-\(UUID().uuidString).jpg",
                photoType: .corrective,
                notes: notes.isEmpty ? "Corrective follow-up" : notes
            )

            photosByItemId[itemId] = nil
            await loadPhotos(for: itemId)
        } catch {
            errorMessage = error.localizedDescription
        }

        activeIssueId = nil
    }

    private func markIssueCorrected(_ issue: ReconcileIssue) async {
        activeIssueId = issue.id
        errorMessage = nil

        do {
            try await markCorrected(issue)
        } catch {
            errorMessage = error.localizedDescription
        }

        activeIssueId = nil
    }

    private func markCorrected(_ issue: ReconcileIssue) async throws {
        let station = lineCheck.stations[issue.stationIndex]
        var items = station.items
        var item = items[issue.itemIndex]
        item.isCorrected = true
        items[issue.itemIndex] = item

        lineCheck.stations[issue.stationIndex] = LineCheckStationDto(
            id: station.id,
            stationName: station.stationName,
            items: items
        )

        let savedLineCheck = try await LineCheckApi.shared.saveLineCheck(lineCheck)
        guard savedLineCheck.containsCorrectedItem(withId: item.id) else {
            throw CorrectionSaveError.notPersisted
        }

        lineCheck = savedLineCheck
        if let itemId = item.id {
            NotificationCenter.default.post(
                name: .lineCheckCorrectionsDidChange,
                object: nil,
                userInfo: [
                    LineCheckCorrectionNotificationKey.lineCheckId: lineCheck.id,
                    LineCheckCorrectionNotificationKey.itemId: itemId
                ]
            )
        }
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
}

private struct ReconcileLineCheckSummary: Identifiable {
    let lineCheck: LineCheckDto
    let pendingCount: Int
    let correctedCount: Int

    var id: String { lineCheck.id }

    var primaryDateText: String {
        guard let completedAt = lineCheck.completedAt ?? lineCheck.checkTime else {
            return "Unknown date"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }
}

private struct ReconcileLineCheckRow: View {

    let summary: ReconcileLineCheckSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.primaryDateText)
                        .font(.headline)

                    Text(summary.lineCheck.username ?? "Unknown user")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(summary.pendingCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 14) {
                Label("\(summary.lineCheck.stations.count) stations", systemImage: "square.grid.2x2")
                Label("\(summary.pendingCount) pending", systemImage: "exclamationmark.triangle")

                if summary.correctedCount > 0 {
                    Label("\(summary.correctedCount) corrected", systemImage: "checkmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct ReconcileIssue: Identifiable, Equatable {
    typealias ID = String

    let stationIndex: Int
    let itemIndex: Int
    let lineCheckId: String
    let stationName: String
    let item: LineCheckItemDto
    let reasons: [String]

    var id: String {
        "\(lineCheckId)-\(stationIndex)-\(itemIndex)-\(item.id ?? "missing-id")"
    }

    var isCorrected: Bool {
        item.isCorrected == true
    }

    static func issues(in lineCheck: LineCheckDto, includeCorrected: Bool) -> [ReconcileIssue] {
        lineCheck.stations.enumerated().flatMap { stationIndex, station in
            station.items.enumerated().compactMap { itemIndex, item in
                let reasons = correctionReasons(for: item)
                guard !reasons.isEmpty else { return nil }

                if !includeCorrected, item.isCorrected == true {
                    return nil
                }

                return ReconcileIssue(
                    stationIndex: stationIndex,
                    itemIndex: itemIndex,
                    lineCheckId: lineCheck.id,
                    stationName: station.stationName ?? "Unnamed Station",
                    item: item,
                    reasons: reasons
                )
            }
        }
    }

    private static func correctionReasons(for item: LineCheckItemDto) -> [String] {
        var reasons: [String] = []

        if item.isMissing == true {
            reasons.append("Missing")
        }

        if isOutOfTemperatureRange(item) {
            reasons.append("Temp out of range")
        }

        reasons.append(contentsOf: failedCriterionReasons(for: item))

        if hasIncorrectPrep(item) {
            reasons.append("Prepared wrong")
        }

        return reasons
    }

    private static func isOutOfTemperatureRange(_ item: LineCheckItemDto) -> Bool {
        guard let temperature = item.temperature else { return false }

        if let minTemp = item.minTemp, temperature < minTemp {
            return true
        }

        if let maxTemp = item.maxTemp, temperature > maxTemp {
            return true
        }

        return false
    }

    private static func hasIncorrectPrep(_ item: LineCheckItemDto) -> Bool {
        if item.criterionResponses?.isEmpty == false {
            return false
        }

        return item.itemChecked == false
    }

    private static func failedCriterionReasons(for item: LineCheckItemDto) -> [String] {
        item.criterionResponses?.compactMap { response in
            if isMissingCriterion(response) {
                return nil
            }

            let failed = response.requiresCorrection == true
            || response.booleanAnswer == false
            || isFailedNumber(response)

            guard failed else { return nil }
            return response.label ?? response.criterionName ?? "Criterion failed"
        } ?? []
    }

    private static func isFailedNumber(_ response: LineCheckCriterionResponseDto) -> Bool {
        guard let numberAnswer = response.numberAnswer else { return false }

        if let minValue = response.minValue, numberAnswer < minValue {
            return true
        }

        if let maxValue = response.maxValue, numberAnswer > maxValue {
            return true
        }

        return false
    }

    private static func isMissingCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        [response.criterionType, response.responseType, response.criterionName, response.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .contains("missing")
    }
}

private struct ReconcileIssueCard: View {

    let issue: ReconcileIssue
    let photos: [LineCheckPhotoDto]
    let isBusy: Bool
    let isLoadingPhotos: Bool
    let isCorrected: Bool
    @Binding var correctiveNotes: String
    let onTakePhoto: () -> Void
    let onChoosePhoto: (PhotosPickerItem) async -> Void
    let onMarkCorrected: () async -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?

    private var hasCorrectivePhoto: Bool {
        photos.contains { $0.photoType == .corrective }
    }

    private var canMarkCorrected: Bool {
        hasCorrectivePhoto || !correctiveNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCorrected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(isCorrected ? .green : .orange)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.item.itemName ?? "Unnamed Item")
                        .font(.headline)

                    Text(issue.stationName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isBusy {
                    ProgressView()
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(issue.reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCorrected ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isCorrected ? Color.green : Color.orange).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            correctiveNotesSection

            photoStrip

            if isCorrected {
                Label("Corrected", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 12) {
                    Button {
                        onTakePhoto()
                    } label: {
                        Label("Take Follow-up", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || !UIImagePickerController.isSourceTypeAvailable(.camera))

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }

                Button {
                    Task {
                        await onMarkCorrected()
                    }
                } label: {
                    Label("Mark Corrected", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isBusy || !canMarkCorrected)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }

            Task {
                await onChoosePhoto(newValue)
                selectedPhotoItem = nil
            }
        }
    }

    private var correctiveNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Correction Notes")
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $correctiveNotes)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 86)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .disabled(isCorrected || isBusy)
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingPhotos {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading photos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if photos.isEmpty {
                Text("No photos attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            VStack(alignment: .leading, spacing: 4) {
                                photoThumbnail(photo)

                                Text(photo.photoType.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(photo.photoType == .corrective ? .green : .secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
        .frame(width: 76, height: 76)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var photoPlaceholder: some View {
        Image(systemName: "photo")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}

private enum CorrectionSaveError: LocalizedError {
    case notPersisted

    var errorDescription: String? {
        "The correction was sent, but the server did not save it as corrected. Please check that the backend save endpoint persists the corrected field."
    }
}

private extension LineCheckDto {
    func containsCorrectedItem(withId itemId: String?) -> Bool {
        guard let itemId else { return false }

        return stations.contains { station in
            station.items.contains { item in
                item.id == itemId && item.isCorrected == true
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {

    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content
            }

            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}

//
//  MainView.swift
//  QuickLookIPA
//
//  Complete UI revamp with modern design
//

import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject var inspector: IPAInspectorService
    @EnvironmentObject var history: HistoryManager

    @State private var showFilePicker = false
    @State private var showHistory = false
    @State private var showComparison = false
    @State private var showResignSheet = false
    @State private var searchText = ""
    @State private var selectedSection: InspectionSection? = .overview
    @State private var comparisonIPAs: [IPAInfo] = []
    @State private var isTargeted = false
    @State private var errorMessage: String?

    enum InspectionSection: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case details = "Details"
        case provisioning = "Provisioning"
        case entitlements = "Entitlements"
        case fileAnalysis = "File Analysis"
        case extensions = "Extensions"
        case localization = "Localization"
        case network = "Network"
        case validation = "Validation"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "doc.text.magnifyingglass"
            case .details: return "info.circle"
            case .provisioning: return "doc.badge.gearshape"
            case .entitlements: return "key.fill"
            case .fileAnalysis: return "chart.bar.doc.horizontal"
            case .extensions: return "puzzlepiece.extension"
            case .localization: return "globe"
            case .network: return "network"
            case .validation: return "checkmark.shield"
            }
        }
    }

    var body: some View {
        HSplitView {
            // Sidebar
            sidebar
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 300)

            // Main Content
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()

                // Content Area
                if inspector.isInspecting {
                    inspectionProgressView
                } else if let ipaInfo = inspector.currentInspection {
                    contentView(for: ipaInfo)
                } else if !comparisonIPAs.isEmpty {
                    comparisonView
                } else {
                    dropZoneView
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFilePickerResult(result)
        }
        .sheet(isPresented: $showHistory) {
            historyView
        }
        .sheet(isPresented: $showResignSheet) {
            if let ipaInfo = inspector.currentInspection,
               let ipaURL = inspector.currentIpaURL {
                ResignView(ipaInfo: ipaInfo, ipaURL: ipaURL, isPresented: $showResignSheet)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("QuickLookIPA")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Navigation
            if inspector.currentInspection != nil {
                List(InspectionSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                            .font(.system(size: 13))
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack(spacing: 16) {
                    Text("No IPA loaded")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 40)

                    Button(action: { showFilePicker = true }) {
                        Label("Open IPA", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { showHistory = true }) {
                        Label("Recent Files", systemImage: "clock")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding()
            }

            Divider()

            // Footer with actions
            VStack(spacing: 8) {
                if inspector.debugLoggingEnabled {
                    HStack {
                        Image(systemName: "ant.circle.fill")
                            .foregroundColor(.orange)
                        Text("Debug Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                HStack {
                    Text("Built with ❤️ by Sidhant Chadha")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
        }
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)

            Spacer()

            // Actions
            if let ipaInfo = inspector.currentInspection {
                Menu {
                    Button(action: { exportAs(.json, ipaInfo: ipaInfo) }) {
                        Label("Export as JSON", systemImage: "doc.text")
                    }
                    Button(action: { exportAs(.markdown, ipaInfo: ipaInfo) }) {
                        Label("Export as Markdown", systemImage: "doc.richtext")
                    }
                    Button(action: { exportAs(.text, ipaInfo: ipaInfo) }) {
                        Label("Export as Text", systemImage: "doc.plaintext")
                    }
                    Button(action: { exportAs(.pdf, ipaInfo: ipaInfo) }) {
                        Label("Export as PDF", systemImage: "doc.fill")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)

                Button(action: { showComparison.toggle() }) {
                    Label("Compare", systemImage: "rectangle.split.2x1")
                }

                Button(action: { showResignSheet = true }) {
                    Label("Resign", systemImage: "signature")
                }
                .help("Resign IPA with new provisioning profile")

                Button(action: { clearInspection() }) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .help("Clear current inspection")

                Button(action: { showFilePicker = true }) {
                    Label("New", systemImage: "plus")
                }
            }

            Button(action: { showHistory = true }) {
                Label("History", systemImage: "clock")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Drop Zone
    private var dropZoneView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)
                    .frame(width: 300, height: 300)
                    .animation(.easeInOut, value: isTargeted)

                VStack(spacing: 16) {
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.zipper")
                        .font(.system(size: 80))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text(isTargeted ? "Drop to Inspect" : "Drop IPA Here")
                        .font(.title)
                        .fontWeight(.medium)

                    Text("or")
                        .foregroundColor(.secondary)

                    Button(action: { showFilePicker = true }) {
                        Text("Browse Files")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            Spacer()

            if !history.recentInspections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Files")
                        .font(.headline)

                    ForEach(history.recentInspections.prefix(5)) { inspection in
                        Button(action: { loadFromHistory(inspection) }) {
                            HStack {
                                if let iconData = inspection.appIcon,
                                   let nsImage = NSImage(data: iconData) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .cornerRadius(6)
                                } else {
                                    Image(systemName: "app.fill")
                                        .frame(width: 24, height: 24)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(inspection.appName ?? inspection.fileName)
                                        .font(.subheadline)
                                    Text(inspection.version ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(timeAgo(inspection.inspectionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Inspection Progress
    private var inspectionProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: inspector.inspectionProgress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 300)

            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Inspecting IPA...")
                    .font(.title2)
                    .fontWeight(.medium)

                Text(inspector.inspectionStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("\(Int(inspector.inspectionProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content View
    @ViewBuilder
    private func contentView(for ipaInfo: IPAInfo) -> some View {
        ScrollView {
            switch selectedSection {
            case .overview:
                OverviewView(ipaInfo: ipaInfo, searchText: searchText)
            case .details:
                DetailsView(ipaInfo: ipaInfo, searchText: searchText)
            case .provisioning:
                ProvisioningView(ipaInfo: ipaInfo, searchText: searchText)
            case .entitlements:
                EntitlementsView(ipaInfo: ipaInfo, searchText: searchText)
            case .fileAnalysis:
                FileAnalysisView(ipaInfo: ipaInfo, searchText: searchText)
            case .extensions:
                ExtensionsView(ipaInfo: ipaInfo, searchText: searchText)
            case .localization:
                LocalizationView(ipaInfo: ipaInfo, searchText: searchText)
            case .network:
                NetworkView(ipaInfo: ipaInfo, searchText: searchText)
            case .validation:
                ValidationView(ipaInfo: ipaInfo, searchText: searchText)
            case .none:
                OverviewView(ipaInfo: ipaInfo, searchText: searchText)
            }
        }
    }

    // MARK: - Comparison View
    private var comparisonView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("Comparison View")
                .font(.title)
                .fontWeight(.medium)

            Text("Coming Soon")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Compare two IPA files side-by-side to see differences in size, entitlements, frameworks, and more.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Go Back") {
                showComparison = false
                comparisonIPAs.removeAll()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - History View
    private var historyView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Inspections")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Clear All") {
                    // Safely clear history
                    history.clearHistory()
                }
                .foregroundColor(.red)
                .disabled(history.recentInspections.isEmpty)
            }
            .padding()

            Divider()

            List(history.recentInspections) { inspection in
                HStack {
                    if let iconData = inspection.appIcon,
                       let nsImage = NSImage(data: iconData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(inspection.appName ?? inspection.fileName)
                            .font(.headline)
                        Text("\(inspection.version ?? "") (\(inspection.buildNumber ?? ""))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(inspection.bundleIdentifier ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDate(inspection.inspectionDate))
                            .font(.caption)
                        HStack(spacing: 8) {
                            Button("Load") {
                                loadFromHistory(inspection)
                                showHistory = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                // Safely remove inspection
                                history.removeInspection(id: inspection.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from history")
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Helper Functions
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Failed to load file: \(error.localizedDescription)"
                }
                return
            }

            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid file format"
                }
                return
            }

            guard url.pathExtension.lowercased() == "ipa" else {
                DispatchQueue.main.async {
                    errorMessage = "Please drop an IPA file"
                }
                return
            }

            DispatchQueue.main.async {
                inspectIPA(at: url)
            }
        }
        return true
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file selected"
                return
            }

            // Validate file extension
            guard url.pathExtension.lowercased() == "ipa" else {
                errorMessage = "Selected file is not an IPA file"
                return
            }

            // Start accessing security-scoped resource (don't stop it - we need it for resign)
            let gotAccess = url.startAccessingSecurityScopedResource()
            if !gotAccess {
                errorMessage = "Failed to access the selected file"
                return
            }

            // Store the original URL for resign functionality
            inspector.currentIpaURL = url

            // Copy to temp location
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).ipa")

            do {
                // Check if file is readable
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    errorMessage = "File is not readable. Check permissions."
                    return
                }

                // Check file size
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int64, fileSize == 0 {
                    errorMessage = "File is empty"
                    return
                }

                // Copy file
                try FileManager.default.copyItem(at: url, to: tempURL)
                inspectIPA(at: tempURL)
            } catch let error as NSError {
                if error.code == NSFileWriteFileExistsError {
                    // File already exists in temp, use it
                    inspectIPA(at: tempURL)
                } else if error.code == NSFileReadNoPermissionError {
                    errorMessage = "Permission denied. Please grant file access."
                } else if error.code == NSFileReadNoSuchFileError {
                    errorMessage = "File not found"
                } else {
                    errorMessage = "Failed to access file: \(error.localizedDescription)"
                }
            } catch {
                errorMessage = "Failed to access file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "File picker error: \(error.localizedDescription)"
        }
    }

    private func inspectIPA(at url: URL) {
        // Validate URL before inspection
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "IPA file not found at path"
            return
        }

        inspector.inspect(ipaURL: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ipaInfo):
                    // Add to history with error handling
                    history.addInspection(ipaInfo)
                case .failure(let error):
                    errorMessage = "Inspection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadFromHistory(_ inspection: IPAInfo) {
        // Validate inspection data before loading
        guard inspection.fileName.isEmpty == false else {
            errorMessage = "Invalid inspection data"
            return
        }

        // Load inspection on main thread
        DispatchQueue.main.async {
            inspector.currentInspection = inspection
        }
    }

    private func clearInspection() {
        // Clear the current inspection and reset UI
        inspector.clearCurrentInspection()

        // Reset any selected section
        selectedSection = .overview

        // Clear any error messages
        errorMessage = nil
    }

    private func exportAs(_ format: ExportFormat, ipaInfo: IPAInfo) {
        // Validate data before export
        guard !ipaInfo.fileName.isEmpty else {
            errorMessage = "Invalid IPA data for export"
            return
        }

        ExportService.shared.showSavePanel(for: ipaInfo, format: format) { success in
            DispatchQueue.main.async {
                if !success {
                    errorMessage = "Export \(format.rawValue) failed or cancelled"
                }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
//
//  StubViews.swift
//  QuickLookIPA
//
//  Stub implementations of detail views for MainView
//

import SwiftUI

// MARK: - Overview View
struct OverviewView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if let appName = ipaInfo.appName {
                    InfoRow(label: "App Name", value: appName)
                }
                if let bundleId = ipaInfo.bundleIdentifier {
                    InfoRow(label: "Bundle ID", value: bundleId)
                }
                if let version = ipaInfo.version {
                    InfoRow(label: "Version", value: version)
                }
                if let build = ipaInfo.buildNumber {
                    InfoRow(label: "Build", value: build)
                }
                if let minOS = ipaInfo.minimumOSVersion {
                    InfoRow(label: "Min iOS", value: minOS)
                }
                InfoRow(label: "File Size", value: formatBytes(ipaInfo.fileSize))
            }
        }
        .padding()
    }
}

// MARK: - Details View
struct DetailsView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoRow(label: "File Name", value: ipaInfo.fileName)
            InfoRow(label: "Inspection Date", value: formatDate(ipaInfo.inspectionDate))

            if let architectures = ipaInfo.architectures {
                InfoRow(label: "Architectures", value: architectures.joined(separator: ", "))
            }

            if let binarySize = ipaInfo.binarySize {
                InfoRow(label: "Binary Size", value: formatBytes(binarySize))
            }
        }
        .padding()
    }
}

// MARK: - Provisioning View
struct ProvisioningView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let profile = ipaInfo.provisioningProfile {
                Group {
                    if let name = profile.name {
                        InfoRow(label: "Profile Name", value: name)
                    }
                    if let teamName = profile.teamName {
                        InfoRow(label: "Team Name", value: teamName)
                    }
                    if let uuid = profile.uuid {
                        InfoRow(label: "UUID", value: uuid)
                    }
                    if let expiration = profile.expirationDate {
                        InfoRow(label: "Expires", value: formatDate(expiration))
                    }
                    if let devices = profile.provisionedDevices {
                        Text("Provisioned Devices (\(devices.count))")
                            .font(.headline)
                        ForEach(devices, id: \.self) { device in
                            Text(device)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            } else {
                Text("No provisioning profile found")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

/// MARK: - Entitlements View
struct EntitlementsView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entitlements = ipaInfo.entitlements, !entitlements.isEmpty {
                ForEach(entitlements) { entitlement in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlement.key)
                            .font(.headline)
                        Text(entitlement.value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        if !entitlement.description.isEmpty {
                            Text(entitlement.description)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No entitlements found")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

// MARK: - File Analysis View
struct FileAnalysisView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let frameworks = ipaInfo.frameworks {
                Text("Frameworks (\(frameworks.count))")
                    .font(.headline)
                ForEach(frameworks) { framework in
                    HStack {
                        Text(framework.name)
                        Spacer()
                        Text(formatBytes(framework.size))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let assets = ipaInfo.largestAssets {
                Text("Largest Assets")
                    .font(.headline)
                ForEach(assets) { asset in
                    HStack {
                        Text(asset.name)
                        Spacer()
                        Text(formatBytes(asset.size))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Extensions View
struct ExtensionsView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let extensions = ipaInfo.extensions {
                ForEach(extensions) { ext in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ext.name)
                            .font(.headline)
                        Text(ext.bundleIdentifier)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        HStack {
                            Text(ext.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                            Text(formatBytes(ext.size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No extensions found")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Localization View
struct LocalizationView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let languages = ipaInfo.supportedLanguages {
                Text("Supported Languages (\(languages.count))")
                    .font(.headline)
                ForEach(languages, id: \.self) { language in
                    Text(language)
                        .padding(.vertical, 2)
                }
            } else {
                Text("No localization info found")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Network View
struct NetworkView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let network = ipaInfo.networkSettings {
                if let allowsArbitrary = network.allowsArbitraryLoads {
                    InfoRow(label: "Allows Arbitrary Loads", value: allowsArbitrary ? "Yes" : "No")
                }

                if let domains = network.allowedDomains {
                    Text("Allowed Domains")
                        .font(.headline)
                    ForEach(domains, id: \.self) { domain in
                        Text(domain)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let exceptions = network.exceptionDomains {
                    Text("Exception Domains")
                        .font(.headline)
                    ForEach(exceptions, id: \.self) { domain in
                        Text(domain)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } else {
                Text("No network settings found")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Validation View
struct ValidationView: View {
    let ipaInfo: IPAInfo
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let issues = ipaInfo.validationIssues, !issues.isEmpty {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: issue.icon)
                            .foregroundColor(issue.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.title)
                                .font(.headline)
                            Text(issue.message)
                                .font(.body)
                            if let suggestion = issue.suggestion {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No validation issues found")
                }
            }
        }
        .padding()
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Helper Functions
private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

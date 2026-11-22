//
//  ResignView.swift
//  QuickLookIPA
//
//  Created by Claude Code on 11/21/26.
//  User interface for IPA resigning workflow including provisioning profile selection,
//  certificate management, bundle identifier modification, and progress tracking.
//

import SwiftUI
import UniformTypeIdentifiers

struct ResignView: View {
    let ipaInfo: IPAInfo
    let ipaURL: URL
    @Binding var isPresented: Bool

    @State private var provisioningProfileURL: URL?
    @State private var selectedCertificate: String = ""
    @State private var newBundleIdentifier: String = ""
    @State private var availableCertificates: [String] = []
    @State private var isResigning = false
    @State private var resignProgress: Double = 0.0
    @State private var resignStatus: String = ""
    @State private var errorMessage: String?
    @State private var showProfilePicker = false
    @State private var resignSuccessURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Resign IPA")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
            }
            .padding()

            Divider()

            if isResigning {
                // Progress View
                resignProgressView
            } else if let successURL = resignSuccessURL {
                // Success View
                successView(url: successURL)
            } else {
                // Configuration View
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Current IPA Info
                        infoSection

                        Divider()

                        // Provisioning Profile
                        provisioningProfileSection

                        Divider()

                        // Certificate Selection
                        certificateSection

                        Divider()

                        // Bundle Identifier (Optional)
                        bundleIdentifierSection

                        Divider()

                        // Resign Button
                        resignButtonSection
                    }
                    .padding()
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadCertificates()
            newBundleIdentifier = ipaInfo.bundleIdentifier ?? ""
        }
        .fileImporter(
            isPresented: $showProfilePicker,
            allowedContentTypes: [UTType(filenameExtension: "mobileprovision") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleProfileSelection(result)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current IPA")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ipaInfo.appName ?? "Unknown")
                        .font(.subheadline)
                    Text(ipaInfo.bundleIdentifier ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Provisioning Profile Section
    private var provisioningProfileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provisioning Profile")
                .font(.headline)

            HStack {
                if let profileURL = provisioningProfileURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileURL.lastPathComponent)
                            .font(.subheadline)
                        Text(profileURL.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Button(action: { provisioningProfileURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No provisioning profile selected")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    Spacer()

                    Button("Select Profile...") {
                        showProfilePicker = true
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Certificate Section
    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signing Certificate")
                .font(.headline)

            if availableCertificates.isEmpty {
                Text("No code signing certificates found")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                Picker("Certificate", selection: $selectedCertificate) {
                    Text("Select Certificate").tag("")
                    ForEach(availableCertificates, id: \.self) { cert in
                        Text(cert).tag(cert)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Bundle Identifier Section
    private var bundleIdentifierSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bundle Identifier (Optional)")
                .font(.headline)

            TextField("com.example.app", text: $newBundleIdentifier)
                .textFieldStyle(.roundedBorder)

            Text("Leave unchanged to keep the original bundle identifier")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Resign Button Section
    private var resignButtonSection: some View {
        HStack {
            Spacer()

            Button("Resign IPA") {
                resignIPA()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(provisioningProfileURL == nil || selectedCertificate.isEmpty)
        }
    }

    // MARK: - Progress View
    private var resignProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: resignProgress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 400)

            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Resigning IPA...")
                    .font(.title2)
                    .fontWeight(.medium)

                Text(resignStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("\(Int(resignProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
    }

    // MARK: - Success View
    private func successView(url: URL) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("IPA Resigned Successfully!")
                .font(.title2)
                .fontWeight(.medium)

            Text("Saved to:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(url.path)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

            HStack(spacing: 12) {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Helper Methods
    private func loadCertificates() {
        availableCertificates = ResignService.shared.getAvailableCertificates()
        if !availableCertificates.isEmpty {
            selectedCertificate = availableCertificates[0]
        }
    }

    private func handleProfileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                provisioningProfileURL = url
            }
        case .failure(let error):
            errorMessage = "Failed to select provisioning profile: \(error.localizedDescription)"
        }
    }

    private func resignIPA() {
        guard let profileURL = provisioningProfileURL else { return }

        isResigning = true
        resignProgress = 0.0

        // Show save panel for output
        let savePanel = NSSavePanel()
        savePanel.title = "Save Resigned IPA"
        savePanel.nameFieldStringValue = "\(ipaInfo.fileName.replacingOccurrences(of: ".ipa", with: ""))-resigned.ipa"
        if let contentType = UTType(filenameExtension: "ipa") {
            savePanel.allowedContentTypes = [contentType]
        }

        savePanel.begin { response in
            guard response == .OK, let outputURL = savePanel.url else {
                isResigning = false
                return
            }

            // Create resign options
            let bundleID = newBundleIdentifier.isEmpty ? nil : newBundleIdentifier
            let options = ResignService.ResignOptions(
                ipaURL: ipaURL,
                provisioningProfileURL: profileURL,
                certificateName: selectedCertificate,
                bundleIdentifier: bundleID,
                outputURL: outputURL
            )

            // Perform resign
            ResignService.shared.resign(options: options) { status, progress in
                DispatchQueue.main.async {
                    resignStatus = status
                    resignProgress = progress
                }
            } completion: { result in
                DispatchQueue.main.async {
                    isResigning = false

                    switch result {
                    case .success(let url):
                        resignSuccessURL = url
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
